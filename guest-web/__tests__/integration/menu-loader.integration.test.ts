/**
 * Integrationstest: Menü-Lese-Pfad gegen eine ECHTE Supabase-Instanz.
 * Beweist, was der Unit-Test (Mock) nicht beweisen kann: der embedded-select
 * querystring ist korrekt, die anon-Lese-RLS-Policy greift, und die
 * gemappte Venue stimmt mit dem DB-Seed überein (8 Items, korrekte Preise,
 * Tag-Pills vorhanden).
 *
 * Skippt sauber ohne KL_INTEGRATION=1 + NEXT_PUBLIC_SUPABASE_* (siehe
 * guest-web/__tests__/integration/load-env.ts und order-submit.integration).
 */

import { beforeAll, describe, expect, it } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { fetchVenueBySlugFromSupabase } from "@/lib/menu-loader";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const integrationEnabled =
  !!supabaseUrl && !!supabaseAnonKey && process.env.KL_INTEGRATION === "1";

const itMaybe = integrationEnabled ? it : it.skip;

function client(): SupabaseClient {
  return createClient(supabaseUrl as string, supabaseAnonKey as string, {
    auth: { persistSession: false },
  });
}

describe("menu-loader (Integration, echte Supabase)", () => {
  beforeAll(() => {
    if (!integrationEnabled) {
      throw new Error(
        "Integrationstest ohne Instanz: setze NEXT_PUBLIC_SUPABASE_URL, " +
          "NEXT_PUBLIC_SUPABASE_ANON_KEY und KL_INTEGRATION=1 (siehe SANDBOX_SETUP.md).",
      );
    }
  });

  itMaybe(
    "liest die Sandbox-Venue mit allen 8 Items, ohne signInAnonymously",
    async () => {
      const supabase = client();
      // WICHTIG: kein signInAnonymously — der Lese-Pfad muss mit der bloßen
      // anon-Rolle funktionieren (RLS public_read auf venues/menu_items).
      const venue = await fetchVenueBySlugFromSupabase("alte-muehle", supabase);
      expect(venue).not.toBeNull();
      expect(venue?.name).toBe("Gasthaus Alte Mühle");
      expect(venue?.menu).toHaveLength(8);
    },
  );

  itMaybe(
    "liefert die korrekten DB-Preise und die id=slug-Invariante (Bestellpfad)",
    async () => {
      const supabase = client();
      const venue = await fetchVenueBySlugFromSupabase("alte-muehle", supabase);
      const bySlug = Object.fromEntries(venue!.menu.map((i) => [i.id, i]));
      expect(bySlug.kuerbissuppe.priceCents).toBe(690);
      expect(bySlug["wiener-schnitzel"].priceCents).toBe(2180);
      expect(bySlug["muehlen-radler"].priceCents).toBe(450);
      // id ist der slug, damit cartToSubmitItems die RPC korrekt füttert.
      for (const item of venue!.menu) {
        expect(item.id).toMatch(/^[a-z-]+$/); // kein UUID-Format
      }
    },
  );

  itMaybe(
    "enthält die Tag-Pills aus der tag-Spalte (beliebt/vegetarisch)",
    async () => {
      const supabase = client();
      const venue = await fetchVenueBySlugFromSupabase("alte-muehle", supabase);
      const bySlug = Object.fromEntries(venue!.menu.map((i) => [i.id, i]));
      expect(bySlug.flammkuchen.tag).toBe("beliebt");
      expect(bySlug["wiener-schnitzel"].tag).toBe("beliebt");
      expect(bySlug.kaesespaetzle.tag).toBe("vegetarisch");
      // Items ohne Tag liefern undefined (nicht "null" als String).
      expect(bySlug.kuerbissuppe.tag).toBeUndefined();
    },
  );

  itMaybe("gibt null für eine unbekannte Venue zurück", async () => {
    const supabase = client();
    const venue = await fetchVenueBySlugFromSupabase(
      "gibt-es-nicht-12345",
      supabase,
    );
    expect(venue).toBeNull();
  });
});
