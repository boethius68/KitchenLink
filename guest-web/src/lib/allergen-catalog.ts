/**
 * Semantischer Katalog der Lebensmittel-Kennzeichnungen im Gast-Web.
 *
 * Buchstaben/Zahlen aus einer Speisekarte sind Quellencodes und werden zuerst
 * gegen deren Legende aufgelöst. Die 14 EU-Hauptallergene, die Angaben für
 * lose Ware nach § 5 LMZDV und weitere Verbraucherhinweise bilden nur den
 * semantischen Piktogramm-Wortschatz – keine erfundene Universallegende.
 */

export type FoodDeclarationGroup =
  | "allergen"
  | "additive"
  | "consumerNotice"
  | "sourceNotice";

export type FoodDeclarationGlyph =
  | "wheat"
  | "crustacean"
  | "egg"
  | "fish"
  | "peanut"
  | "soy"
  | "milk"
  | "treeNut"
  | "celery"
  | "mustard"
  | "sesame"
  | "sulfite"
  | "lupin"
  | "mollusc"
  | "colorant"
  | "preservative"
  | "antioxidant"
  | "nitrite"
  | "nitrate"
  | "curingSalts"
  | "flavorEnhancer"
  | "blackened"
  | "waxed"
  | "phosphate"
  | "sweetener"
  | "tableSweetener"
  | "phenylalanine"
  | "polyols"
  | "quinine"
  | "caffeine"
  | "liquorice"
  | "genericAdditive"
  | "notice"
  | "unknown";

export interface GuestAllergen {
  code: string;
  label: string;
  glyph: FoodDeclarationGlyph;
  group: FoodDeclarationGroup;
  groupLabel: string;
  detail: string;
  priority: number;
}

const GROUP_LABELS: Readonly<Record<FoodDeclarationGroup, string>> = {
  allergen: "EU-Hauptallergen",
  additive: "Zusatzstoffhinweis",
  consumerNotice: "Verbraucherhinweis",
  sourceNotice: "Angabe der Speisekarte",
};

const ALLERGEN_DETAIL =
  "Dieses Allergen gehört zu den 14 kennzeichnungspflichtigen Hauptallergenen der EU.";
const ADDITIVE_DETAIL =
  "Diese Formulierung gehört zu den Zusatzstoffangaben für lose Ware nach § 5 LMZDV.";
const SOURCE_DETAIL =
  "Die Bedeutung dieses Codes stammt aus der Legende der Speisekarte und ist kein einheitlicher gesetzlicher Code.";

function entry(
  code: string,
  label: string,
  glyph: FoodDeclarationGlyph,
  group: FoodDeclarationGroup,
  priority: number,
  detail: string,
): GuestAllergen {
  return { code, label, glyph, group, groupLabel: GROUP_LABELS[group], detail, priority };
}

export const STANDARD_ALLERGENS: readonly GuestAllergen[] = [
  entry("a", "Glutenhaltiges Getreide", "wheat", "allergen", 0, ALLERGEN_DETAIL),
  entry("b", "Krebstiere", "crustacean", "allergen", 11, ALLERGEN_DETAIL),
  entry("c", "Eier", "egg", "allergen", 2, ALLERGEN_DETAIL),
  entry("d", "Fisch", "fish", "allergen", 5, ALLERGEN_DETAIL),
  entry("e", "Erdnüsse", "peanut", "allergen", 4, ALLERGEN_DETAIL),
  entry("f", "Sojabohnen", "soy", "allergen", 6, ALLERGEN_DETAIL),
  entry("g", "Milch einschließlich Laktose", "milk", "allergen", 1, ALLERGEN_DETAIL),
  entry("h", "Schalenfrüchte (Nüsse)", "treeNut", "allergen", 3, ALLERGEN_DETAIL),
  entry("i", "Sellerie", "celery", "allergen", 8, ALLERGEN_DETAIL),
  entry("j", "Senf", "mustard", "allergen", 7, ALLERGEN_DETAIL),
  entry("k", "Sesamsamen", "sesame", "allergen", 9, ALLERGEN_DETAIL),
  entry("l", "Schwefeldioxid / Sulfite", "sulfite", "allergen", 10, "Kennzeichnungspflichtig oberhalb des in Anhang II der LMIV festgelegten Schwellenwerts."),
  entry("m", "Lupinen", "lupin", "allergen", 12, ALLERGEN_DETAIL),
  entry("n", "Weichtiere", "mollusc", "allergen", 13, ALLERGEN_DETAIL),
] as const;

export const STANDARD_ADDITIVES: readonly GuestAllergen[] = [
  entry("farbstoff", "mit Farbstoff", "colorant", "additive", 100, ADDITIVE_DETAIL),
  entry("konserviert", "mit Konservierungsstoff / konserviert", "preservative", "additive", 101, ADDITIVE_DETAIL),
  entry("antioxidationsmittel", "mit Antioxidationsmittel", "antioxidant", "additive", 102, ADDITIVE_DETAIL),
  entry("nitritpoekelsalz", "mit Nitritpökelsalz", "nitrite", "additive", 103, ADDITIVE_DETAIL),
  entry("nitrat", "mit Nitrat", "nitrate", "additive", 104, ADDITIVE_DETAIL),
  entry("nitritundnitrat", "mit Nitritpökelsalz und Nitrat", "curingSalts", "additive", 105, ADDITIVE_DETAIL),
  entry("geschmacksverstaerker", "mit Geschmacksverstärker", "flavorEnhancer", "additive", 106, ADDITIVE_DETAIL),
  entry("geschwaerzt", "geschwärzt", "blackened", "additive", 107, ADDITIVE_DETAIL),
  entry("gewachst", "gewachst", "waxed", "additive", 108, ADDITIVE_DETAIL),
  entry("phosphat", "mit Phosphat", "phosphate", "additive", 109, ADDITIVE_DETAIL),
  entry("suessungsmittel", "mit Süßungsmittel(n)", "sweetener", "additive", 110, ADDITIVE_DETAIL),
  entry("tafelsuesse", "auf der Grundlage von …", "tableSweetener", "additive", 111, "Bei Tafelsüßen wird der verwendete Süßstoff im Wortlaut ergänzt."),
  entry("phenylalanin", "enthält eine Phenylalaninquelle", "phenylalanine", "additive", 112, "Vorgeschriebener Hinweis bei Aspartam/Aspartam-Acesulfamsalz entsprechend der Kennzeichnungsregeln."),
  entry("polyole", "kann bei übermäßigem Verzehr abführend wirken", "polyols", "additive", 113, "Vorgeschriebener Hinweis bei Lebensmitteln mit mehr als 10 % zugesetzten mehrwertigen Alkoholen."),
] as const;

export const ADDITIONAL_NOTICES: readonly GuestAllergen[] = [
  entry("chininhaltig", "chininhaltig", "quinine", "consumerNotice", 200, "Verbraucherhinweis für chininhaltige Getränke beziehungsweise Aromen nach § 5 AromenDV."),
  entry("koffeinhaltig", "koffeinhaltig", "caffeine", "consumerNotice", 201, "Hinweis der Speisekarte auf Koffein; der je nach Produkt vorgeschriebene Wortlaut bleibt maßgeblich."),
  entry("koffeinwarnung", "erhöhter Koffeingehalt", "caffeine", "consumerNotice", 202, "Für bestimmte Getränke und Lebensmittel verlangt Anhang III LMIV einen erweiterten Warnhinweis."),
  entry("lakritz", "enthält Süßholz", "liquorice", "consumerNotice", 203, "Hinweis für bestimmte Lebensmittel mit Glycyrrhizinsäure beziehungsweise Ammoniumglycyrrhizinat."),
  entry("lakritzblutdruck", "enthält Süßholz – bei hohem Blutdruck übermäßigen Verzehr vermeiden", "liquorice", "consumerNotice", 204, "Erweiterter Hinweis bei Überschreiten der in Anhang III LMIV genannten Schwellenwerte."),
] as const;

const LEGACY_CODES: readonly GuestAllergen[] = [
  entry("1", "mit Farbstoff", "colorant", "sourceNotice", 250, SOURCE_DETAIL),
  entry("2", "mit Konservierungsstoff", "preservative", "sourceNotice", 250, SOURCE_DETAIL),
  entry("3", "mit Antioxidationsmittel", "antioxidant", "sourceNotice", 250, SOURCE_DETAIL),
  entry("4", "mit Geschmacksverstärker", "flavorEnhancer", "sourceNotice", 250, SOURCE_DETAIL),
  entry("5", "geschwefelt", "sulfite", "sourceNotice", 250, SOURCE_DETAIL),
  entry("6", "geschwärzt", "blackened", "sourceNotice", 250, SOURCE_DETAIL),
  entry("7", "gewachst", "waxed", "sourceNotice", 250, SOURCE_DETAIL),
  entry("8", "mit Phosphat", "phosphate", "sourceNotice", 250, SOURCE_DETAIL),
  entry("9", "mit Süßungsmittel", "sweetener", "sourceNotice", 250, SOURCE_DETAIL),
  entry("10", "enthält eine Phenylalaninquelle", "phenylalanine", "sourceNotice", 250, SOURCE_DETAIL),
  entry("11", "koffeinhaltig", "caffeine", "sourceNotice", 250, SOURCE_DETAIL),
  entry("12", "chininhaltig", "quinine", "sourceNotice", 250, SOURCE_DETAIL),
  entry("13", "alkoholhaltig", "notice", "sourceNotice", 250, SOURCE_DETAIL),
  entry("14", "taurinhaltig", "notice", "sourceNotice", 250, SOURCE_DETAIL),
] as const;

const CATALOG = new Map(
  [...STANDARD_ALLERGENS, ...STANDARD_ADDITIVES, ...ADDITIONAL_NOTICES, ...LEGACY_CODES].map(
    (item) => [item.code, item] as const,
  ),
);

/** Abwärtskompatibler Export für bestehende Aufrufer. */
export const STANDARD_ALLERGEN_LABELS: Readonly<Record<string, string>> =
  Object.fromEntries([...CATALOG].map(([code, item]) => [code, item.label]));

function normalizeLegend(
  legend: Record<string, unknown> | null | undefined,
): Record<string, string> {
  const out: Record<string, string> = {};
  if (!legend || typeof legend !== "object") return out;
  for (const [rawKey, rawValue] of Object.entries(legend)) {
    const key = rawKey.trim().toLowerCase();
    const value = typeof rawValue === "string" ? rawValue.trim() : "";
    if (key && value) out[key] = value;
  }
  return out;
}

function normalizedText(value: string): string {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function withSource(base: GuestAllergen, code: string, label: string): GuestAllergen {
  return { ...base, code, label };
}

function definitionFromLegend(code: string, label: string): GuestAllergen {
  const text = normalizedText(label);
  const find = (items: readonly GuestAllergen[], index: number) => withSource(items[index], code, label);

  if (text.includes("gluten") || text.includes("getreide") || text.includes("weizen")) return find(STANDARD_ALLERGENS, 0);
  if (/krebstier|garnel|scampi|krabbe/.test(text)) return find(STANDARD_ALLERGENS, 1);
  if (text === "ei" || /eier|eiprodukt/.test(text)) return find(STANDARD_ALLERGENS, 2);
  if (text.includes("fisch")) return find(STANDARD_ALLERGENS, 3);
  if (text.includes("erdnuss")) return find(STANDARD_ALLERGENS, 4);
  if (text.includes("soja")) return find(STANDARD_ALLERGENS, 5);
  if (/milch|laktose/.test(text)) return find(STANDARD_ALLERGENS, 6);
  if (/schalenfrucht|nuss|mandel/.test(text)) return find(STANDARD_ALLERGENS, 7);
  if (text.includes("sellerie")) return find(STANDARD_ALLERGENS, 8);
  if (text.includes("senf")) return find(STANDARD_ALLERGENS, 9);
  if (text.includes("sesam")) return find(STANDARD_ALLERGENS, 10);
  if (/sulfit|schwefeldioxid|geschwefelt/.test(text)) return find(STANDARD_ALLERGENS, 11);
  if (text.includes("lupin")) return find(STANDARD_ALLERGENS, 12);
  if (/weichtier|mollusk|muschel/.test(text)) return find(STANDARD_ALLERGENS, 13);

  if (text.includes("farbstoff")) return find(STANDARD_ADDITIVES, 0);
  if (text.includes("konserv")) return find(STANDARD_ADDITIVES, 1);
  if (text.includes("antioxid")) return find(STANDARD_ADDITIVES, 2);
  if (text.includes("nitrit") && text.includes("nitrat")) return find(STANDARD_ADDITIVES, 5);
  if (text.includes("nitrit")) return find(STANDARD_ADDITIVES, 3);
  if (text.includes("nitrat")) return find(STANDARD_ADDITIVES, 4);
  if (text.includes("geschmacksverst")) return find(STANDARD_ADDITIVES, 6);
  if (text.includes("geschwarz")) return find(STANDARD_ADDITIVES, 7);
  if (text.includes("gewachst")) return find(STANDARD_ADDITIVES, 8);
  if (/phosphat|phosphor/.test(text)) return find(STANDARD_ADDITIVES, 9);
  if (text.includes("grundlage von")) return find(STANDARD_ADDITIVES, 11);
  if (/phenylalanin|aspartam/.test(text)) return find(STANDARD_ADDITIVES, 12);
  if (/abfuhr|polyol|mehrwertige alkohole/.test(text)) return find(STANDARD_ADDITIVES, 13);
  if (/sussungsmittel|suessungsmittel/.test(text)) return find(STANDARD_ADDITIVES, 10);
  if (text.includes("chinin")) return find(ADDITIONAL_NOTICES, 0);
  if (text.includes("koffein")) return find(ADDITIONAL_NOTICES, 1);
  if (/susholz|suessholz|lakritz/.test(text)) return find(ADDITIONAL_NOTICES, 3);

  const fallback = CATALOG.get(code);
  return fallback
    ? withSource(fallback, code, label)
    : entry(code, label, "notice", "sourceNotice", 300, SOURCE_DETAIL);
}

export function resolveAllergens(
  codes: readonly (string | null | undefined)[] | null | undefined,
  legend: Record<string, unknown> | null | undefined,
): GuestAllergen[] {
  const lookup = normalizeLegend(legend);
  const seen = new Set<string>();
  const result: Array<{ index: number; item: GuestAllergen }> = [];
  for (const [index, raw] of (codes ?? []).entries()) {
    const code = (raw ?? "").toString().trim().toLowerCase();
    if (!code || seen.has(code)) continue;
    seen.add(code);

    const legendLabel = lookup[code];
    if (legendLabel) {
      result.push({ index, item: definitionFromLegend(code, legendLabel) });
      continue;
    }
    const catalogItem = CATALOG.get(code);
    if (catalogItem) {
      result.push({ index, item: { ...catalogItem } });
      continue;
    }
    if (/^e\d{3,4}[a-z]?$/.test(code)) {
      result.push({
        index,
        item: entry(code, `Zusatzstoff ${code.toUpperCase()}`, "genericAdditive", "additive", 150,
          "Konkrete E-Nummer aus der Speisekarte. Für Funktion und Verwendung ist die Kartenlegende beziehungsweise Produktinformation maßgeblich."),
      });
      continue;
    }
    result.push({ index, item: entry(code, `Code ${code.toUpperCase()}`, "unknown", "sourceNotice", 300, SOURCE_DETAIL) });
  }

  return result
    .sort((left, right) => left.item.priority - right.item.priority || left.index - right.index)
    .map(({ item }) => item);
}
