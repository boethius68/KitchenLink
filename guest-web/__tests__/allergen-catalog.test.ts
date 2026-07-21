import { describe, expect, it } from "vitest";
import { resolveAllergens } from "@/lib/allergen-catalog";

describe("resolveAllergens", () => {
  it("bevorzugt die Karten-Legende vor dem Standard-Katalog", () => {
    const result = resolveAllergens(["a"], { a: "Hausmehl" });
    expect(result).toEqual([{ code: "a", label: "Hausmehl" }]);
  });

  it("fällt auf den Standard-Katalog zurück, wenn die Legende den Code nicht führt", () => {
    const result = resolveAllergens(["g", "2"], {});
    expect(result).toEqual([
      { code: "g", label: "Milch / Laktose" },
      { code: "2", label: "mit Konservierungsstoff" },
    ]);
  });

  it("normalisiert Groß-Keys der Legende und Codes auf Kleinbuchstaben", () => {
    const result = resolveAllergens(["A"], { A: "Weizen" });
    expect(result).toEqual([{ code: "a", label: "Weizen" }]);
  });

  it("entfernt Dubletten und leere Codes, behält die Reihenfolge", () => {
    const result = resolveAllergens(["a", "a", "", "  ", "c"], null);
    expect(result.map((r) => r.code)).toEqual(["a", "c"]);
  });

  it("kennzeichnet unbekannte Codes generisch statt sie zu verwerfen", () => {
    const result = resolveAllergens(["z"], {});
    expect(result).toEqual([{ code: "z", label: "Code Z" }]);
  });

  it("verträgt fehlende Codes/Legende", () => {
    expect(resolveAllergens(null, null)).toEqual([]);
    expect(resolveAllergens(undefined, undefined)).toEqual([]);
  });
});
