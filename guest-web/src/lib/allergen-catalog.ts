/**
 * Standard-Katalog für Allergen-/Zusatzstoff-Codes (Klartext auf Deutsch).
 *
 * Spiegelt den `AllergenCatalog` der iOS-App: Standard-EU-Allergene a–p und
 * Zusatzstoffe 1–14 haben einen festen, app-einheitlichen Klartext. Die pro
 * Kategorie in der DB gespeicherte `allergen_legend` (vom Betreiber/Import
 * erfasst) hat Vorrang; fehlt ein Code dort, greift dieser Katalog, damit ein
 * Standardcode nie nur als kryptischer Buchstabe erscheint.
 */

export interface GuestAllergen {
  /** Der Code, wie auf der Karte (klein, z. B. "a" oder "2"). */
  code: string;
  /** Klartext-Bedeutung (aus der Karten-Legende oder dem Standard-Katalog). */
  label: string;
}

/** Code→Klartext für die Standardcodes; identisch zur iOS-App. */
export const STANDARD_ALLERGEN_LABELS: Readonly<Record<string, string>> = {
  a: "Glutenhaltiges Getreide",
  b: "Krebstiere",
  c: "Eier",
  d: "Fisch",
  e: "Erdnüsse",
  f: "Soja",
  g: "Milch / Laktose",
  h: "Schalenfrüchte (Nüsse)",
  i: "Sellerie",
  j: "Senf",
  k: "Sesamsamen",
  l: "Schwefeldioxid / Sulfite",
  m: "Lupinen",
  n: "Weichtiere",
  o: "Knoblauch",
  p: "Zwiebeln",
  "1": "mit Farbstoff",
  "2": "mit Konservierungsstoff",
  "3": "mit Antioxidationsmittel",
  "4": "mit Geschmacksverstärker",
  "5": "geschwefelt",
  "6": "geschwärzt",
  "7": "gewachst",
  "8": "mit Phosphat",
  "9": "mit Süßungsmittel",
  "10": "enthält eine Phenylalaninquelle",
  "11": "koffeinhaltig",
  "12": "chininhaltig",
  "13": "alkoholhaltig",
  "14": "taurin-haltig",
};

/** Baut aus einer rohen Legende ein Lookup mit klein geschriebenen Keys. */
function normalizeLegend(
  legend: Record<string, unknown> | null | undefined,
): Record<string, string> {
  const out: Record<string, string> = {};
  if (!legend || typeof legend !== "object") {
    return out;
  }
  for (const [rawKey, rawValue] of Object.entries(legend)) {
    const key = rawKey.trim().toLowerCase();
    const value = typeof rawValue === "string" ? rawValue.trim() : "";
    if (key && value) {
      out[key] = value;
    }
  }
  return out;
}

/**
 * Löst die Code-Liste eines Artikels gegen die Karten-Legende und den
 * Standard-Katalog in `{ code, label }`-Paare auf. Reihenfolge bleibt erhalten,
 * Dubletten und leere Codes fallen weg.
 */
export function resolveAllergens(
  codes: readonly (string | null | undefined)[] | null | undefined,
  legend: Record<string, unknown> | null | undefined,
): GuestAllergen[] {
  const lookup = normalizeLegend(legend);
  const seen = new Set<string>();
  const result: GuestAllergen[] = [];
  for (const raw of codes ?? []) {
    const code = (raw ?? "").toString().trim().toLowerCase();
    if (!code || seen.has(code)) {
      continue;
    }
    seen.add(code);
    const label = lookup[code] ?? STANDARD_ALLERGEN_LABELS[code] ?? `Code ${code.toUpperCase()}`;
    result.push({ code, label });
  }
  return result;
}
