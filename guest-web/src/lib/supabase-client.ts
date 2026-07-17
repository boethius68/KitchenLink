/**
 * Browserseitiger Supabase-Client für das Gast-Web.
 *
 * Der Client nutzt ausschließlich die öffentlichen Anon-Key-/URL-Umgebungs-
 * variablen (NEXT_PUBLIC_*). Die autoritative Bestellgrenze läuft serverseitig
 * als PostgreSQL-RPC (ADR-001 §6); der Browser hat keinen direkten Schreib-
 * zugriff auf Bestelltabellen.
 *
 * Ohne konfigurierte Supabase-Instanz schlagen Anmeldungs- und RPC-Aufrufe zur
 * Laufzeit fehl — das ist für die Sandbox in Ordnung und in ORDER_GATE.md
 dokumentiert. Die reine Logik (order-submit/order-ack) ist trotzdem über
 * Vitest abgedeckt.
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let cached: SupabaseClient | null = null;

/**
 * Liefert den Singleton-Client oder `null`, wenn die Umgebung nicht
 * konfiguriert ist. Aufrufer entscheiden, ob sie ohne Instanz hart scheitern
 * (Bestellverdrahtung) oder nur die Fixture weiterlaufen lassen wollen.
 */
export function getSupabase(): SupabaseClient | null {
  if (cached) {
    return cached;
  }
  if (!supabaseUrl || !supabaseAnonKey) {
    return null;
  }
  cached = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
  return cached;
}
