import { describe, expect, it } from "vitest";
import {
  ADDITIONAL_NOTICES,
  STANDARD_ADDITIVES,
  STANDARD_ALLERGENS,
  resolveAllergens,
} from "@/lib/allergen-catalog";

describe("food declaration catalog", () => {
  it("enthält genau die 14 EU-Hauptallergene ohne Knoblauch/Zwiebel als Standard", () => {
    expect(STANDARD_ALLERGENS).toHaveLength(14);
    expect(STANDARD_ALLERGENS.map((item) => item.code)).toEqual(
      "abcdefghijklmn".split(""),
    );
    expect(STANDARD_ALLERGENS.some((item) => /Knoblauch|Zwiebel/.test(item.label))).toBe(false);
  });

  it("enthält alle 14 LMZDV-Angabefälle und getrennte Verbraucherhinweise", () => {
    expect(STANDARD_ADDITIVES).toHaveLength(14);
    expect(ADDITIONAL_NOTICES.map((item) => item.code)).toContain("chininhaltig");
    expect(ADDITIONAL_NOTICES.map((item) => item.code)).toContain("koffeinwarnung");
  });

  it("bevorzugt die Karten-Legende und leitet daraus das semantische Icon ab", () => {
    const result = resolveAllergens(["1"], { "1": "Milch und Laktose" });
    expect(result[0]).toMatchObject({
      code: "1",
      label: "Milch und Laktose",
      glyph: "milk",
      group: "allergen",
    });
  });

  it("fällt auf den Katalog zurück, wenn die Legende einen Code nicht führt", () => {
    const result = resolveAllergens(["g", "2"], {});
    expect(result.map(({ code, label, glyph }) => ({ code, label, glyph }))).toEqual([
      { code: "g", label: "Milch einschließlich Laktose", glyph: "milk" },
      { code: "2", label: "mit Konservierungsstoff", glyph: "preservative" },
    ]);
  });

  it("zeigt alkoholhaltige Einträge als verständliches Alkohol-Piktogramm", () => {
    expect(resolveAllergens(["13"], null)[0]).toMatchObject({
      code: "13",
      glyph: "alcohol",
    });
    expect(resolveAllergens(["x"], { x: "mit Alkohol" })[0]).toMatchObject({
      code: "x",
      label: "mit Alkohol",
      glyph: "alcohol",
    });
    expect(resolveAllergens(["y"], { y: "mehrwertige Alkohole" })[0]).toMatchObject({
      glyph: "polyols",
    });
  });

  it("priorisiert die im Testkorpus häufigsten, eindeutigen Icons", () => {
    const result = resolveAllergens(["i", "c", "g", "a"], null);
    expect(result.map((item) => item.code)).toEqual(["a", "g", "c", "i"]);
  });

  it("stellt konkrete E-Nummern neutral dar, ohne eine statische Stoffliste vorzutäuschen", () => {
    expect(resolveAllergens(["E621"], null)[0]).toMatchObject({
      code: "e621",
      label: "Zusatzstoff E621",
      glyph: "genericAdditive",
      group: "additive",
    });
  });

  it("normalisiert Groß-Keys, entfernt Dubletten und hält unbekannte Hauscodes", () => {
    const result = resolveAllergens(["A", "a", "", "z"], { A: "Weizen" });
    expect(result.map((item) => ({ code: item.code, label: item.label }))).toEqual([
      { code: "a", label: "Weizen" },
      { code: "z", label: "Weitere Angabe der Speisekarte" },
    ]);
  });

  it("verträgt fehlende Codes und Legenden", () => {
    expect(resolveAllergens(null, null)).toEqual([]);
    expect(resolveAllergens(undefined, undefined)).toEqual([]);
  });
});
