/**
 * Lokale Sandbox-Venue-Daten für das Gast-Web-Fundament.
 *
 * Bewusste Naht: Diese Datei ist die einzige Datenquelle der Menüroute.
 * Der spätere Supabase-Pfad (RLS-lesbares Menü, generierte Typen) ersetzt
 * nur diese Implementierung, nicht die Aufrufer. Sandbox-Daten bleiben
 * gemäß Blueprint auch nach Cloud-Anbindung erhalten.
 */

export type GuestMenuItemKind = "food" | "drink";

export interface GuestMenuItem {
  id: string;
  name: string;
  /** Kleine neutrale Pille neben dem Namen, z. B. "beliebt" oder "vegetarisch". */
  tag?: string;
  description: string;
  priceCents: number;
  kind: GuestMenuItemKind;
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
