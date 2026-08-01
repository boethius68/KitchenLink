/**
 * Tischkontext aus dem QR-Code (KL-TABLE-001).
 *
 * Der QR-Code auf dem Tisch zeigt auf die normale Karte plus Tisch-Token:
 *
 *   https://kitchenlink.luneq.eu/alte-muehle/menu?tisch=<token>
 *
 * Das Token ist der Schluessel, nicht die Tischnummer: es steht in
 * `qr_tokens`, laesst sich stilllegen und rotieren, und ein Umbenennen des
 * Tisches macht gedruckte Codes nicht ungueltig.
 *
 * Warum der Token clientseitig gelesen wird: die Menueseite ist ISR-gerendert
 * (`revalidate = 60`) und damit CDN-cachebar. Wuerde die Serverkomponente
 * `searchParams` lesen, wuerde die Route dynamisch und der Cache entfiele —
 * fuer jede Karte, auch ohne Tisch. `useSearchParams` wiederum zwingt den
 * Baum bis zur naechsten Suspense-Grenze ins clientseitige Rendern, was hier
 * die gesamte Karte waere. Deshalb: Seite bleibt prerendert, der Tisch wird
 * nach der Hydration aus der URL gelesen und aufgeloest.
 *
 * Die Aufloesung laeuft ueber `guest_web_resolve_table`; die Tabellen
 * `tables`/`qr_tokens` sind fuer Gaeste nicht lesbar. Ohne gueltiges Token
 * gibt es keine Auskunft und keine Tischliste.
 */

import type { SupabaseClient } from "@supabase/supabase-js";

/** Query-Parameter des Tisch-QR-Codes. Deutsch, weil Gaeste die URL sehen. */
export const TABLE_QUERY_PARAM = "tisch";

export type TableContext =
  | { kind: "none" }
  | { kind: "resolving"; token: string }
  | { kind: "resolved"; token: string; label: string; area: string }
  | { kind: "unknown"; token: string };

/** Aufgeloeste Tischangabe aus der Datenbank. */
export interface ResolvedTable {
  label: string;
  area: string;
}

/**
 * Liest das Tisch-Token aus einem Query-String (`window.location.search` oder
 * eine komplette URL). Leere, ueberlange oder offensichtlich unsinnige Werte
 * gelten als „kein Tisch", damit ein manipulierter Link nicht in die RPC
 * durchschlaegt.
 */
export function readTableToken(search: string): string | null {
  if (!search) {
    return null;
  }
  let params: URLSearchParams;
  try {
    const query = search.includes("?") ? search.slice(search.indexOf("?")) : search;
    params = new URLSearchParams(query);
  } catch {
    return null;
  }
  const raw = params.get(TABLE_QUERY_PARAM);
  if (raw === null) {
    return null;
  }
  const token = raw.trim();
  if (token === "" || token.length > 128) {
    return null;
  }
  // Tokens sind Hex bzw. kurze Sandbox-Kennungen. Alles andere waere kein
  // Token, das diese Datenbank je ausgegeben hat.
  if (!/^[A-Za-z0-9_-]+$/.test(token)) {
    return null;
  }
  return token;
}

/** Baut die Gast-URL fuer einen Tisch — die Nutzlast des gedruckten QR-Codes. */
export function tableGuestUrl(menuUrl: string, token: string): string {
  const separator = menuUrl.includes("?") ? "&" : "?";
  return `${menuUrl}${separator}${TABLE_QUERY_PARAM}=${encodeURIComponent(token)}`;
}

/**
 * Sichtbare Bezeichnung: „3" wird zu „Tisch 3", „A1" zu „Tisch A1", „Theke"
 * bleibt „Theke". Regel: ein zusammenhaengendes Kuerzel mit mindestens einer
 * Ziffer ist eine Tischnummer; alles mit Leerzeichen oder ganz ohne Ziffer ist
 * ein Name. Muss mit `KitchenLinkTableLabel.headline` in iOS uebereinstimmen.
 */
export function tableHeadline(label: string): string {
  const trimmed = label.trim();
  if (trimmed === "") {
    return "";
  }
  const isTableCode = /\d/.test(trimmed) && /^[\p{L}\p{N}]+$/u.test(trimmed);
  return isTableCode ? `Tisch ${trimmed}` : trimmed;
}

/** Vollstaendige Kopfzeile inklusive Bereich, sofern gepflegt. */
export function tableContextLabel(context: TableContext): string | null {
  switch (context.kind) {
    case "resolved": {
      const headline = tableHeadline(context.label);
      return context.area.trim() === ""
        ? headline
        : `${headline} · ${context.area.trim()}`;
    }
    case "resolving":
      return "Tisch wird geprüft …";
    case "unknown":
      return "Tisch nicht erkannt";
    case "none":
      return null;
  }
}

/**
 * Loest ein Token in die sichtbare Tischangabe auf. Gibt `null` zurueck, wenn
 * das Token unbekannt, stillgelegt oder abgelaufen ist — die RPC wirft in dem
 * Fall, und ein Fehler ist hier eine Aussage, kein Ausfall.
 */
export async function fetchTable(
  venueSlug: string,
  token: string,
  supabase: SupabaseClient,
): Promise<ResolvedTable | null> {
  try {
    const { data, error } = await supabase.rpc("guest_web_resolve_table", {
      p_venue_slug: venueSlug,
      p_token: token,
    });
    if (error) {
      return null;
    }
    const row = Array.isArray(data) ? data[0] : data;
    if (!row || typeof row !== "object") {
      return null;
    }
    const label = (row as { label?: unknown }).label;
    if (typeof label !== "string" || label.trim() === "") {
      return null;
    }
    const area = (row as { area?: unknown }).area;
    return {
      label,
      area: typeof area === "string" ? area : "",
    };
  } catch {
    return null;
  }
}
