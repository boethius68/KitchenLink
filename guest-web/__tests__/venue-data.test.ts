import { describe, expect, it } from "vitest";
import { getVenueBySlug, sandboxVenues } from "@/lib/venue-data";

describe("sandbox venue fixture", () => {
  it("provides the eight-dish guest card required by KL-WEB-001", () => {
    const venue = sandboxVenues[0];
    expect(venue.menu).toHaveLength(8);
  });

  it("has unique item ids and positive fixed prices", () => {
    for (const venue of sandboxVenues) {
      const ids = venue.menu.map((item) => item.id);
      expect(new Set(ids).size).toBe(ids.length);
      for (const item of venue.menu) {
        expect(item.priceCents).toBeGreaterThan(0);
        expect(Number.isInteger(item.priceCents)).toBe(true);
        expect(item.name.trim()).not.toHaveLength(0);
      }
    }
  });

  it("resolves venues by slug and rejects unknown slugs", () => {
    expect(getVenueBySlug("alte-muehle")?.name).toBe("Gasthaus Alte Mühle");
    expect(getVenueBySlug("unbekannt")).toBeUndefined();
  });

  it("keeps an alcohol declaration in the visible guest fixture", () => {
    const radler = sandboxVenues[0].menu.find((item) => item.id === "muehlen-radler");
    expect(radler?.allergens).toEqual([
      expect.objectContaining({ glyph: "alcohol", label: "alkoholhaltig" }),
    ]);
  });
});
