import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { sandboxVenues } from "../src/lib/venue-data";
import { sandboxSuppliers } from "../src/lib/vendor-data";
import { hospitalityMoments } from "../src/lib/hospitality-moments";

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

  it("configures all four living hospitality moments with animated photography and video companions", () => {
    expect(hospitalityMoments.length).toBe(4);
    const momentIds = hospitalityMoments.map((m) => m.id);
    expect(momentIds).toEqual(["dining", "kitchen", "terrace", "bar"]);

    const publicDir = path.resolve(__dirname, "../public");

    for (const moment of hospitalityMoments) {
      expect(moment.title).toBeTruthy();
      expect(moment.headline).toBeTruthy();
      expect(moment.description).toBeTruthy();
      expect(moment.quote).toBeTruthy();
      expect(moment.ctaHref.startsWith("/")).toBe(true);

      // Verify that referenced media files exist in public/
      const gifPath = path.join(publicDir, moment.gifSrc);
      const mp4Path = path.join(publicDir, moment.mp4Src);
      const posterPath = path.join(publicDir, moment.posterSrc);

      expect(fs.existsSync(gifPath), `Missing GIF: ${gifPath}`).toBe(true);
      expect(fs.existsSync(mp4Path), `Missing MP4: ${mp4Path}`).toBe(true);
      expect(fs.existsSync(posterPath), `Missing Poster: ${posterPath}`).toBe(true);
    }
  });
});
