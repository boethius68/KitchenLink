/**
 * Lokale Sandbox-Venue-Daten für das Gast-Web-Fundament.
 *
 * Bewusste Naht: Diese Datei ist die einzige Datenquelle der Menüroute.
 * Der spätere Supabase-Pfad (RLS-lesbares Menü, generierte Typen) ersetzt
 * nur diese Implementierung, nicht die Aufrufer. Sandbox-Daten bleiben
 * gemäß Blueprint auch nach Cloud-Anbindung erhalten.
 */

import { resolveAllergens, type GuestAllergen } from "./allergen-catalog";

export type { GuestAllergen } from "./allergen-catalog";

export type GuestMenuItemKind = "food" | "drink";

export type GuestVariantKind = "portion" | "extra" | "variant";
export type GuestOptionPriceKind = "fixed" | "delta" | "included" | "free";

/** Eine Auswahloption eines Artikels (Portion, Extra oder Variante). */
export interface GuestVariantOption {
  id: string;
  name: string;
  priceCents: number;
  kind: GuestVariantKind;
  priceKind: GuestOptionPriceKind;
  groupID?: string;
  groupTitle?: string;
  minimumSelections?: number;
  maximumSelections?: number;
  selectionMode?: string;
  freeSelectionCount?: number;
  allowsRepeats?: boolean;
}

export interface GuestMenuItem {
  id: string;
  name: string;
  /** Kleine neutrale Pille neben dem Namen, z. B. "beliebt" oder "vegetarisch". */
  tag?: string;
  description: string;
  priceCents: number;
  kind: GuestMenuItemKind;
  /** Aufgelöste Allergen-/Zusatzstoff-Kennzeichnung (Code + Klartext). */
  allergens?: GuestAllergen[];
  /** Varianten/Portionen/Extras des Artikels. */
  variants?: GuestVariantOption[];
}

export interface GuestVenue {
  slug: string;
  name: string;
  isOpen: boolean;
  menu: GuestMenuItem[];
}

export const sandboxVenues: GuestVenue[] = [
  {
    slug: "alte-muehle",
    name: "Gasthaus Alte Mühle",
    isOpen: true,
    menu: [
      {
        id: "kuerbissuppe",
        name: "Kürbissuppe",
        description: "Mit Ingwer, Kürbiskernöl und Bauernbrot",
        priceCents: 690,
        kind: "food",
        allergens: resolveAllergens(["g", "i"], null),
        variants: [
          {
            id: "suppe-gross",
            name: "Große Portion",
            priceCents: 890,
            kind: "portion",
            priceKind: "fixed",
            groupID: "suppe-groesse",
            groupTitle: "Größe",
            minimumSelections: 0,
            maximumSelections: 1,
          },
        ],
      },
      {
        id: "flammkuchen",
        name: "Flammkuchen Elsässer Art",
        tag: "beliebt",
        description: "Crème fraîche, Zwiebeln und geräucherter Speck",
        priceCents: 1150,
        kind: "food",
      },
      {
        id: "kaesespaetzle",
        name: "Käsespätzle",
        tag: "vegetarisch",
        description: "Bergkäse, Röstzwiebeln und kleiner Blattsalat",
        priceCents: 1490,
        kind: "food",
      },
      {
        id: "wiener-schnitzel",
        name: "Wiener Schnitzel",
        tag: "beliebt",
        description: "Kartoffel-Gurken-Salat und Preiselbeeren",
        priceCents: 2180,
        kind: "food",
        allergens: resolveAllergens(["a", "c", "g"], null),
        variants: [
          {
            id: "schnitzel-pommes",
            name: "Pommes statt Salat",
            priceCents: 150,
            kind: "extra",
            priceKind: "delta",
            groupID: "schnitzel-dazu",
            groupTitle: "Dazu",
            minimumSelections: 0,
            maximumSelections: 1,
            selectionMode: "single",
            freeSelectionCount: 0,
            allowsRepeats: false,
          },
          {
            id: "schnitzel-sauce",
            name: "Bratensauce",
            priceCents: 100,
            kind: "extra",
            priceKind: "delta",
            groupID: "schnitzel-saucen",
            groupTitle: "Saucen",
            minimumSelections: 0,
            maximumSelections: 3,
            selectionMode: "quantity",
            freeSelectionCount: 1,
            allowsRepeats: true,
          },
        ],
      },
      {
        id: "zander",
        name: "Gebratener Zander",
        description: "Rahmwirsing und Petersilienkartoffeln",
        priceCents: 2350,
        kind: "food",
      },
      {
        id: "apfelstrudel",
        name: "Apfelstrudel",
        description: "Mit Vanillesauce und Schlagsahne",
        priceCents: 780,
        kind: "food",
      },
      {
        id: "hauslimonade",
        name: "Hauslimonade Holunder",
        description: "0,4 l, hausgemacht",
        priceCents: 490,
        kind: "drink",
      },
      {
        id: "muehlen-radler",
        name: "Mühlen-Radler",
        description: "0,5 l, naturtrüb",
        priceCents: 450,
        kind: "drink",
      },
    ],
  },
];

export function getVenueBySlug(slug: string): GuestVenue | undefined {
  return sandboxVenues.find((venue) => venue.slug === slug);
}
