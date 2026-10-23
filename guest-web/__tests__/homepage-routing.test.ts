import { describe, it, expect } from "vitest";
import { sandboxVenues } from "../src/lib/venue-data";
import { sandboxSuppliers } from "../src/lib/vendor-data";

describe("KitchenLink Web Platform & Homepage routing fixtures", () => {
  it("provides available sandbox venues for live guest-ordering", () => {
    expect(sandboxVenues.length).toBeGreaterThanOrEqual(1);
    const alteMuehle = sandboxVenues.find((v) => v.slug === "alte-muehle");
    expect(alteMuehle).toBeDefined();
    expect(alteMuehle?.isOpen).toBe(true);
    expect(alteMuehle?.menu.length).toBeGreaterThan(0);
  });

  it("links directly to supplier counterparts for procurement compatibility", () => {
    expect(sandboxSuppliers.length).toBeGreaterThanOrEqual(3);
    const supplierIds = sandboxSuppliers.map((s) => s.id);
    expect(supplierIds).toContain("kochberg");
    expect(supplierIds).toContain("weingut-hoelle");
  });
});
