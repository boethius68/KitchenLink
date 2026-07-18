/**
 * Lese-Schicht: holt eine Venue mit ihrem Menü aus Supabase und mappt das
 * DB-Ergebnis auf den gastseitigen `GuestVenue`-Typ aus venue-data.ts.
 *
 * Ersatz für die lokale Fixture an der Naht, die KL-WEB-001 dokumentiert hat
 * (venue-data.ts:1-8). Die Bestellseite bleibt autoritativ (order-submit/RPC);
 * nur die Datenquelle der Anzeige wechselt von der TS-Fixture auf die DB.
 *
 * LASTENDE INVARIANTE: `GuestMenuItem.id` ist der `menu_items.slug`, NICHT die
 * UUID. `order-submit.ts:cartToSubmitItems` schickt `item.id` als Bestell-Slug
 * an die RPC `guest_web_submit_order`; die RPC löst über `menu_items.slug`
 * auf. Würden wir hier die UUID setzen, ginge jede Bestellung kaputt
 * (`guest_web_unknown_item`).
 *
 * Der Lese-Pfad braucht KEIN signInAnonymously: venues/menus/menu_categories/
 * menu_items haben eine anon-Lese-Policy (RLS, siehe Migration 20260717120000).
 */

import type { SupabaseClient } from "@supabase/supabase-js";
import type { GuestMenuItem, GuestMenuItemKind, GuestVenue } from "./venue-data";

/** Rohe Venue-Zeile mit eingebettetem Menü, wie sie Supabase-js aus dem
 *  embedded-select zurückgibt (snake_case aus der DB). */
export interface VenueWithMenuRow {
  slug: string;
  name: string;
  menus: Array<{
    active: boolean | null;
    menu_categories: Array<{
      kind: string | null;
      sort_order: number | null;
      menu_items: Array<{
        slug: string | null;
        name: string | null;
        description: string | null;
        price_cents: number | null;
        kind: string | null;
        tag: string | null;
        available: boolean | null;
        sort_order: number | null;
      }>;
    }>;
  }>;
}

/**
 * Reiner Mapper: VenueWithMenuRow -> GuestVenue. Testbar ohne echte Instanz.
 * - nur Items aus aktiven Menüs,
 * - nur verfügbare Items (`available = true`),
 * - `id := slug` (die Invariante oben),
 * - ungültige/leere slugs oder Preise werden verworfen (defensiv).
 * - isOpen ist hier immer true; die echte Öffnungszeiten-Prüfung ist der RPC
 *   vorbehalten (siehe ORDER_GATE.md §5: aktuell „immer offen" simuliert).
 */
export function mapVenueRowToGuestVenue(row: VenueWithMenuRow): GuestVenue | null {
  if (!row || !row.slug || !row.name) {
    return null;
  }

  const sortableItems: Array<{
    item: GuestMenuItem;
    categorySortOrder: number;
    itemSortOrder: number;
  }> = [];
  for (const menu of row.menus ?? []) {
    if (menu.active === false) {
      continue;
    }
    for (const category of menu.menu_categories ?? []) {
      for (const mi of category.menu_items ?? []) {
        if (!mi || mi.available !== true) {
          continue;
        }
        if (!mi.slug || mi.name == null || mi.price_cents == null) {
          continue;
        }
        if (!Number.isInteger(mi.price_cents) || mi.price_cents < 0) {
          continue;
        }
        const kind = normalizeKind(mi.kind ?? category.kind);
        sortableItems.push({
          item: {
            id: mi.slug, // INVARIANTE: id == slug, nicht die UUID
            name: mi.name,
            tag: mi.tag ?? undefined,
            description: mi.description ?? "",
            priceCents: mi.price_cents,
            kind,
          },
          categorySortOrder: category.sort_order ?? Number.MAX_SAFE_INTEGER,
          itemSortOrder: mi.sort_order ?? Number.MAX_SAFE_INTEGER,
        });
      }
    }
  }

  // Stabile Reihenfolge: erst nach Art (food vor drink), dann nach der
  // DB-Reihenfolge von Kategorie und Item, zuletzt Slug als Tie-Breaker.
  // GuestMenuCard gruppiert anschliessend per kind.
  sortableItems.sort((a, b) => {
    if (a.item.kind !== b.item.kind) {
      return a.item.kind === "food" ? -1 : 1;
    }
    if (a.categorySortOrder !== b.categorySortOrder) {
      return a.categorySortOrder - b.categorySortOrder;
    }
    if (a.itemSortOrder !== b.itemSortOrder) {
      return a.itemSortOrder - b.itemSortOrder;
    }
    return a.item.id.localeCompare(b.item.id);
  });

  const items = sortableItems.map(({ item }) => item);

  return {
    slug: row.slug,
    name: row.name,
    isOpen: true,
    menu: items,
  };
}

function normalizeKind(value: string | null): GuestMenuItemKind {
  return value === "drink" ? "drink" : "food";
}

/**
 * Holt eine Venue per Slug aus Supabase. Gibt null zurück bei: Fehler, Client
 * nicht konfiguriert, Venue nicht gefunden. Der Aufrufer (page.tsx) entscheidet
 * über notFound() vs. Fallback; diese Funktion wirft bewusst nicht, damit ein
 * Build ohne Instanz nicht abstürzt.
 */
export async function fetchVenueBySlugFromSupabase(
  slug: string,
  supabase: SupabaseClient,
): Promise<GuestVenue | null> {
  const { data, error } = await supabase
    .from("venues")
    .select(
      "slug, name, menus!inner(active, menu_categories(menu_items(slug, name, description, price_cents, kind, tag, available, sort_order), kind, sort_order))",
    )
    .eq("slug", slug)
    .maybeSingle();

  if (error || !data) {
    return null;
  }
  return mapVenueRowToGuestVenue(data as unknown as VenueWithMenuRow);
}
