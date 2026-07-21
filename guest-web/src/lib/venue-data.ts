/**
 * Lokale Sandbox-Venue-Daten für das Gast-Web-Fundament.
 *
 * Bewusste Naht: Diese Datei ist die einzige Datenquelle der Menüroute.
 * Der spätere Supabase-Pfad (RLS-lesbares Menü, generierte Typen) ersetzt
 * nur diese Implementierung, nicht die Aufrufer. Sandbox-Daten bleiben
 * gemäß Blueprint auch nach Cloud-Anbindung erhalten.
 */

import type { GuestAllergen } from "./allergen-catalog";

export type { GuestAllergen } from "./allergen-catalog";

export type GuestMenuItemKind = "food" | "drink";

export type GuestVariantKind = "portion" | "extra" | "variant";

/** Eine Auswahloption eines Artikels (Portion, Extra oder Variante). */
export interface GuestVariantOption {
  name: string;
  priceCents: number;
  kind: GuestVariantKind;
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
        allergens: [
          { code: "g", label: "Milch / Laktose" },
          { code: "i", label: "Sellerie" },
        ],
        variants: [
          { name: "Große Portion", priceCents: 890, kind: "portion" },
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
        allergens: [
          { code: "a", label: "Glutenhaltiges Getreide" },
          { code: "c", label: "Eier" },
          { code: "g", label: "Milch / Laktose" },
        ],
        variants: [
          { name: "Pommes statt Salat", priceCents: 150, kind: "extra" },
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
