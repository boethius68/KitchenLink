import { describe, expect, it } from "vitest";
import {
  mapVenueRowToGuestVenue,
  type VenueWithMenuRow,
} from "@/lib/menu-loader";

function row(overrides: Partial<VenueWithMenuRow> = {}): VenueWithMenuRow {
  return {
    slug: "alte-muehle",
    name: "Gasthaus Alte Mühle",
    menus: [
      {
        active: true,
        menu_categories: [
          {
            kind: "food",
            sort_order: 0,
            menu_items: [
              {
                slug: "kuerbissuppe",
                name: "Kürbissuppe",
                description: "Mit Ingwer",
                price_cents: 690,
                kind: "food",
                tag: null,
                available: true,
                sort_order: 0,
              },
              {
                slug: "flammkuchen",
                name: "Flammkuchen",
                description: "Elsässer Art",
                price_cents: 1150,
                kind: "food",
                tag: "beliebt",
                available: true,
                sort_order: 1,
              },
            ],
          },
          {
            kind: "drink",
            sort_order: 1,
            menu_items: [
              {
                slug: "hauslimonade",
                name: "Hauslimonade",
                description: "0,4 l",
                price_cents: 490,
                kind: "drink",
                tag: null,
                available: true,
                sort_order: 0,
              },
            ],
          },
        ],
      },
    ],
    ...overrides,
  };
}

describe("mapVenueRowToGuestVenue", () => {
  it("mappt eine gültige Venue-Zeile auf GuestVenue", () => {
    const venue = mapVenueRowToGuestVenue(row());
    expect(venue).not.toBeNull();
    expect(venue?.slug).toBe("alte-muehle");
    expect(venue?.name).toBe("Gasthaus Alte Mühle");
    expect(venue?.isOpen).toBe(true);
    expect(venue?.menu).toHaveLength(3);
  });

  it("INVARIANTE: GuestMenuItem.id ist der slug, nicht die UUID", () => {
    // cartToSubmitItems in order-submit.ts schickt item.id an die RPC; die RPC
    // löst über menu_items.slug auf. id MUSS slug sein, sonst schlägt jede
    // Bestellung fehl.
    const venue = mapVenueRowToGuestVenue(row());
    const ids = venue?.menu.map((i) => i.id);
    expect(ids).toEqual(
      expect.arrayContaining(["kuerbissuppe", "flammkuchen", "hauslimonade"]),
    );
  });

  it("übernimmt Tag-Pills (Round-04-visuelles Ergebnis)", () => {
    const venue = mapVenueRowToGuestVenue(row());
    const flamm = venue?.menu.find((i) => i.id === "flammkuchen");
    expect(flamm?.tag).toBe("beliebt");
    const supp = venue?.menu.find((i) => i.id === "kuerbissuppe");
    expect(supp?.tag).toBeUndefined();
  });

  it("filtert nicht-verfügbare Items heraus (available !== true)", () => {
    const r = row();
    r.menus[0].menu_categories[0].menu_items[0].available = false;
    const venue = mapVenueRowToGuestVenue(r);
    expect(venue?.menu.find((i) => i.id === "kuerbissuppe")).toBeUndefined();
    expect(venue?.menu).toHaveLength(2);
  });

  it("ignoriert Items aus inaktiven Menüs", () => {
    const r = row();
    r.menus[0].active = false;
    const venue = mapVenueRowToGuestVenue(r);
    expect(venue?.menu).toHaveLength(0);
  });

  it("verwirft Items mit fehlendem slug oder negativem Preis (defensiv)", () => {
    const r = row();
    r.menus[0].menu_categories[0].menu_items.push(
      {
        slug: null,
        name: "Ohne Slug",
        description: "",
        price_cents: 500,
        kind: "food",
        tag: null,
        available: true,
        sort_order: 9,
      },
      {
        slug: "negativ",
        name: "Negativpreis",
        description: "",
        price_cents: -1,
        kind: "food",
        tag: null,
        available: true,
        sort_order: 9,
      },
    );
    const venue = mapVenueRowToGuestVenue(r);
    expect(venue?.menu.find((i) => i.id === "negativ")).toBeUndefined();
    expect(venue?.menu.find((i) => i.name === "Ohne Slug")).toBeUndefined();
  });

  it("erbt den Kategorie-kind, wenn der Item-kind fehlt", () => {
    const r = row();
    // Setze item-kind null, Kategorie ist drink
    r.menus[0].menu_categories[1].menu_items[0].kind = null;
    const venue = mapVenueRowToGuestVenue(r);
    const limo = venue?.menu.find((i) => i.id === "hauslimonade");
    expect(limo?.kind).toBe("drink");
  });

  it("normalisiert unbekannten kind auf 'food'", () => {
    const r = row();
    r.menus[0].menu_categories[0].menu_items[0].kind = "komisch";
    const venue = mapVenueRowToGuestVenue(r);
    expect(venue?.menu.find((i) => i.id === "kuerbissuppe")?.kind).toBe("food");
  });

  it("sortiert food vor drink, dann nach slug (stabile Sections)", () => {
    const venue = mapVenueRowToGuestVenue(row());
    const kinds = venue?.menu.map((i) => i.kind);
    // food-Items kommen zuerst, drink danach
    expect(kinds).toEqual(["food", "food", "drink"]);
  });

  it("lehnt eine Venue ohne slug/name ab", () => {
    expect(mapVenueRowToGuestVenue({ ...row(), slug: "" })).toBeNull();
    expect(mapVenueRowToGuestVenue({ ...row(), name: "" })).toBeNull();
  });
});
