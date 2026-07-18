/**
 * Integrationstest: autoritative Bestellgrenze gegen eine ECHTE Supabase-
 * Instanz. Beweist das, was die Unit-Tests (Mock-Backend) nicht beweisen
 * können (siehe docs/architecture/guest-web/ORDER_GATE.md §7):
 *   - die PL/pgSQL-RPC guest_web_submit_order läuft wirklich,
 *   - Supabase Anonymous Sign-in erzeugt eine authenticated-Session mit
 *     is_anonymous, und die RPC akzeptiert sie,
 *   - serverseitige Neubepreisung aus menu_items.price_cents,
 *   - Idempotenz: gleicher Key + gleicher Payload -> Replay (idempotent_replay),
 *   - Idempotenz-Konflikt: gleicher Key + anderer Payload -> Fehler,
 *   - RLS-Durchsetzung: die bloße anon-Rolle kann nicht bestellen.
 *
 * Voraussetzung: eine laufende Sandbox-Instanz mit angewendeten Migrationen
 * (20260318011000 + 20260717120000 + 20260718010000) und aktiviertem Anonymous
 * Sign-in. Siehe docs/architecture/guest-web/SANDBOX_SETUP.md.
 *
 * Ohne konfigurierte NEXT_PUBLIC_SUPABASE_URL/ANON_KEY (oder explizites
 * KL_INTEGRATION=1) skippt dieser Test sauber statt rot zu werden — so bleibt
 * `npm test` (Unit) immer grün und `npm run test:integration` macht nur dann
 * echte Aussagen, wenn eine Instanz da ist.
 */

import { beforeAll, describe, expect, it } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
// Expliziter Opt-in schützt davor, dass zufällig gesetzte Env-Variablen aus
// einer produktiven Konfiguration versehentlich eine echte Instanz triggern.
const integrationEnabled =
  (!!supabaseUrl && !!supabaseAnonKey && process.env.KL_INTEGRATION === "1");

const itMaybe = integrationEnabled ? it : it.skip;

function client(): SupabaseClient {
  return createClient(supabaseUrl as string, supabaseAnonKey as string, {
    auth: { persistSession: false },
  });
}

describe("guest_web_submit_order (Integration, echte Supabase)", () => {
  beforeAll(() => {
    if (!integrationEnabled) {
      // Sicherheitsnetz: falls der Skip-Mechanismus versagt, fail loud mit
      // einer klaren Erklärung statt stiller grüner Tests.
      throw new Error(
        "Integrationstest ohne Instanz: setze NEXT_PUBLIC_SUPABASE_URL, " +
          "NEXT_PUBLIC_SUPABASE_ANON_KEY und KL_INTEGRATION=1 (siehe SANDBOX_SETUP.md).",
      );
    }
  });

  itMaybe(
    "akzeptiert eine anonyme Bestellung und bestätigt mit ACK aus der Serverantwort",
    async () => {
      const supabase = client();
      const { error: signInError } = await supabase.auth.signInAnonymously();
      expect(signInError).toBeNull();

      const items = [{ slug: "kuerbissuppe", quantity: 1 }];
      const idempotencyKey = `it-accept-${Date.now()}`;

      const { data, error } = await supabase.rpc("guest_web_submit_order", {
        p_venue_slug: "alte-muehle",
        p_idempotency_key: idempotencyKey,
        p_items: items,
        p_service_mode: "dine_in",
        p_customer_note: "",
      });

      expect(error).toBeNull();
      const row = Array.isArray(data) ? data?.[0] : data;
      expect(row).toBeTruthy();
      expect(row.accepted).toBe(true);
      expect(row.idempotent_replay).toBe(false);
      expect(row.total_cents).toBe(690); // aus menu_items.price_cents, nicht Client
      expect(row.status).toBe("pending");
    },
  );

  itMaybe(
    "replayed dieselbe Bestellung (gleicher Key + gleicher Payload) ohne zweiten INSERT",
    async () => {
      const supabase = client();
      await supabase.auth.signInAnonymously();

      const items = [{ slug: "flammkuchen", quantity: 2 }];
      const idempotencyKey = `it-replay-${Date.now()}`;
      const args = {
        p_venue_slug: "alte-muehle",
        p_idempotency_key: idempotencyKey,
        p_items: items,
        p_service_mode: "dine_in",
        p_customer_note: "",
      };

      const first = await supabase.rpc("guest_web_submit_order", args);
      expect(first.error).toBeNull();

      const second = await supabase.rpc("guest_web_submit_order", args);
      expect(second.error).toBeNull();

      const firstRow = Array.isArray(first.data) ? first.data[0] : first.data;
      const secondRow = Array.isArray(second.data)
        ? second.data[0]
        : second.data;

      expect(secondRow.order_id).toBe(firstRow.order_id);
      expect(secondRow.idempotent_replay).toBe(true);
    },
  );

  itMaybe(
    "lehnt denselben Key mit anderem Payload als Konflikt ab (kein stilles Überschreiben)",
    async () => {
      const supabase = client();
      await supabase.auth.signInAnonymously();

      const idempotencyKey = `it-conflict-${Date.now()}`;
      const base = {
        p_venue_slug: "alte-muehle",
        p_idempotency_key: idempotencyKey,
        p_service_mode: "dine_in",
        p_customer_note: "",
      };

      const first = await supabase.rpc("guest_web_submit_order", {
        ...base,
        p_items: [{ slug: "kuerbissuppe", quantity: 1 }],
      });
      expect(first.error).toBeNull();

      const second = await supabase.rpc("guest_web_submit_order", {
        ...base,
        p_items: [{ slug: "kuerbissuppe", quantity: 2 }], // anderer Payload
      });

      expect(second.error).not.toBeNull();
      expect(second.error?.message).toMatch(/idempotency_conflict/i);
    },
  );

  itMaybe(
    "lehnt eine Bestellung ohne Auth (bloße anon-Rolle) ab — RLS/Identity-Durchsetzung",
    async () => {
      // Frischer Client ohne signInAnonymously: kein auth.uid() in der RPC.
      const supabase = client();

      const { error } = await supabase.rpc("guest_web_submit_order", {
        p_venue_slug: "alte-muehle",
        p_idempotency_key: `it-anon-${Date.now()}`,
        p_items: [{ slug: "kuerbissuppe", quantity: 1 }],
        p_service_mode: "dine_in",
        p_customer_note: "",
      });

      expect(error).not.toBeNull();
      // Entweder der unauthenticated-Check der RPC oder RLS/Permission vorab.
      expect(error?.message).toMatch(/unauthenticated|permission|denied/i);
    },
  );
});
