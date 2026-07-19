/**
 * Hub-Presence: erkennt, ob das Service-Gerät des Restaurants online ist
 * (KL-CLOUD-001).
 *
 * Das Service-Gerät (iPhone im Bereich „Service") schreibt, solange es
 * Internet hat, alle ~15 s einen Heartbeat nach `venue_hub_presence` —
 * zusammen mit der aktuellen lokalen Gast-URL seines Foreground-Hubs.
 * Das Gast-Web liest diese Zeile (öffentliche RLS-Lese-Policy) und leitet
 * daraus ab:
 *
 *   - Heartbeat frisch                  -> online: normale Cloud-Bestellung.
 *   - Heartbeat veraltet + lokale URL   -> das Gerät hat die Internet-
 *     verbindung verloren, der lokale Hub läuft aber vermutlich weiter:
 *     Gäste im Restaurant-WLAN werden auf die lokale Bestellseite verwiesen,
 *     die Cloud-Übermittlung wird nicht mehr angeboten (niemand würde die
 *     Bestellung sehen).
 *   - keine Zeile / keine URL / kein parsebarer Zeitstempel -> unknown:
 *     die Cloud-Bestellung bleibt aktiv (heutiges, verifiziertes Verhalten
 *     für Venues ohne Presence-Daten).
 *
 * Grenze (dokumentiert, nicht lösbar aus der Cloud): schließt der Betreiber
 * die Service-Ansicht, während das Gerät offline ist, kann der Eintrag nicht
 * mehr geräumt werden; die lokale URL zeigt dann ins Leere, bis das Gerät
 * wieder online kommt. Der Verweis bleibt trotzdem der beste Hinweis für
 * Gäste vor Ort.
 */

import type { SupabaseClient } from "@supabase/supabase-js";

/** Rohe Presence-Zeile (snake_case aus der DB). */
export interface HubPresenceRow {
  updated_at: string | null;
  local_guest_url: string | null;
}

export type HubAvailability =
  | { kind: "online" }
  | { kind: "local_fallback"; localGuestUrl: string }
  | { kind: "unknown" };

/** Drei verpasste 15-s-Heartbeats gelten als Verbindungsverlust. */
export const HUB_STALE_AFTER_MS = 45_000;

/** Poll-Intervall des Gast-Webs (bewusst grob; die Seite ist statisch). */
export const HUB_POLL_INTERVAL_MS = 20_000;

/**
 * Nur echte http(s)-URLs mit Host werden als lokale Bestell-Links gerendert.
 * Der Wert stammt aus der DB und wird als Anchor ausgegeben — alles andere
 * (etwa `javascript:`) wird verworfen.
 */
export function sanitizeLocalGuestUrl(value: string | null): string | null {
  if (!value) {
    return null;
  }
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return null;
  }
  if (!parsed.hostname) {
    return null;
  }
  return parsed.toString();
}

/** Reine, testbare Auswertung einer Presence-Zeile. */
export function evaluateHubPresence(
  row: HubPresenceRow | null,
  nowMs: number,
  staleAfterMs: number = HUB_STALE_AFTER_MS,
): HubAvailability {
  if (!row || !row.updated_at) {
    return { kind: "unknown" };
  }
  const updatedAtMs = Date.parse(row.updated_at);
  if (Number.isNaN(updatedAtMs)) {
    return { kind: "unknown" };
  }
  // Leicht zukünftige Zeitstempel (Uhrendrift) zählen als frisch.
  const age = nowMs - updatedAtMs;
  if (age <= staleAfterMs) {
    return { kind: "online" };
  }
  const localGuestUrl = sanitizeLocalGuestUrl(row.local_guest_url);
  if (localGuestUrl) {
    return { kind: "local_fallback", localGuestUrl };
  }
  return { kind: "unknown" };
}

/**
 * Holt die Presence-Zeile einer Venue über den Slug (embedded Filter, da der
 * Client die Venue-UUID nicht kennt). Wirft bewusst nicht: jeder Fehler wird
 * zu `null` (-> unknown), damit die Karte nie an der Presence-Abfrage
 * scheitert.
 */
export async function fetchHubPresence(
  venueSlug: string,
  supabase: SupabaseClient,
): Promise<HubPresenceRow | null> {
  try {
    const { data, error } = await supabase
      .from("venue_hub_presence")
      .select("updated_at, local_guest_url, venues!inner(slug)")
      .eq("venues.slug", venueSlug)
      .maybeSingle();
    if (error || !data) {
      return null;
    }
    return {
      updated_at: (data as { updated_at?: string | null }).updated_at ?? null,
      local_guest_url:
        (data as { local_guest_url?: string | null }).local_guest_url ?? null,
    };
  } catch {
    return null;
  }
}
