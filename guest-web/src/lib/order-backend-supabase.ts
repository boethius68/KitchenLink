/**
 * Produktions-Backend für order-submit: echte Supabase-Aufrufe.
 *
 * - signInAnonymously vor der Bestellung (ADR-001 §6.3, DECISIONS.md Guest
 *   Web). Ohne laufende Supabase-Instanz schlägt das zur Laufzeit fehl (für
 *   die Sandbox in Ordnung, siehe ORDER_GATE.md).
 * - Aufruf der RPC guest_web_submit_order_v2; der Browser hat keinen direkten
 *   Schreibpfad in Bestelltabellen.
 */

import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabase } from "./supabase-client";
import type {
  OrderBackend,
  OrderRpcRow,
  ServiceMode,
  SubmitItem,
} from "./order-submit";

export function createSupabaseOrderBackend(
  client?: SupabaseClient | null,
): OrderBackend | null {
  const supabase = client ?? getSupabase();
  if (!supabase) {
    return null;
  }

  return {
    async signInAnonymously() {
      const { error } = await supabase.auth.signInAnonymously();
      if (error) {
        throw new Error(error.message);
      }
    },

    async submitOrderRpc({
      venueSlug,
      idempotencyKey,
      items,
      serviceMode,
      customerNote,
      tableToken,
    }: {
      venueSlug: string;
      idempotencyKey: string;
      items: SubmitItem[];
      serviceMode: ServiceMode;
      customerNote: string;
      tableToken: string | null;
    }): Promise<OrderRpcRow> {
      const { data, error } = await supabase.rpc("guest_web_submit_order_v2", {
        p_venue_slug: venueSlug,
        p_idempotency_key: idempotencyKey,
        p_items: items,
        p_service_mode: serviceMode,
        p_customer_note: customerNote,
        // KL-TABLE-001: zusaetzlicher, vorbelegter Parameter derselben RPC.
        p_table_token: tableToken,
      });

      if (error) {
        throw new Error(error.message);
      }

      // Die RPC liefert genau eine Zeile. Supabase-js gibt bei set returning
      // ein Array zurück; bei single-row returns ein Objekt. Beide Fälle
      // normieren wir hier.
      const row = Array.isArray(data) ? data[0] : data;
      if (!row) {
        throw new Error("guest_web_empty_response: kein ACK");
      }
      return row as OrderRpcRow;
    },
  };
}
