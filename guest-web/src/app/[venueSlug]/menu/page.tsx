import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { GuestMenuCard } from "@/components/GuestMenuCard";
import { fetchVenueBySlugFromSupabase } from "@/lib/menu-loader";
import { getSupabase } from "@/lib/supabase-client";
import { getVenueBySlug, sandboxVenues } from "@/lib/venue-data";

// ISR aus Supabase (KL-WEB-004). Die Seite bleibt statisch cachebar (CDN), aber
// DB-Änderungen werden nach max. 60s sichtbar. ADR-001 §3 hält am SSG/CDN-Modell
// fest; ISR ist die minimalinvasive Variante davon.
export const revalidate = 60;

interface MenuPageProps {
  params: Promise<{ venueSlug: string }>;
}

// Beim reinen SSG würden unbekannte Slugs 404 bekommen. Mit ISR erlauben wir
// dynamische Slugs zur Runtime, damit neu in der DB angelegte Venues ohne
// Rebuild erreichbar sind (der Cache revalidiert sie beim ersten Treffer).
export const dynamicParams = true;

/**
 * Statische Vorab-Generierung zur Build-Zeit. Versucht, die Slugs aus Supabase
 * zu holen; fällt bei nicht erreichbarer DB auf die Sandbox-Fixture
 * (["alte-muehle"]) zurück, damit ein Hostinger-Rebuild niemals am
 * Supabase-Ausfall rot wird. Weitere Slugs werden zur Runtime per ISR
 * nachgeliefert (dynamicParams = true).
 */
export async function generateStaticParams() {
  const supabase = getSupabase();
  if (supabase) {
    try {
      const { data, error } = await supabase
        .from("venues")
        .select("slug")
        .order("slug");
      if (!error && Array.isArray(data) && data.length > 0) {
        return data
          .map((row: { slug?: string | null }) =>
            row.slug ? { venueSlug: row.slug } : null,
          )
          .filter((x): x is { venueSlug: string } => x !== null);
      }
    } catch {
      // DB nicht erreichbar -> Fallback auf Fixture (unten).
    }
  }
  return sandboxVenues.map((venue) => ({ venueSlug: venue.slug }));
}

export async function generateMetadata({
  params,
}: MenuPageProps): Promise<Metadata> {
  const { venueSlug } = await params;
  const venue = await resolveVenue(venueSlug);
  return {
    title: venue ? `${venue.name} – Speisekarte` : "Speisekarte",
  };
}

export default async function MenuPage({ params }: MenuPageProps) {
  const { venueSlug } = await params;
  const venue = await resolveVenue(venueSlug);
  if (!venue) {
    notFound();
  }
  return <GuestMenuCard venue={venue} />;
}

/**
 * Löst eine Venue auf: primär aus Supabase (ISR/CDN-revalidiert), als Fallback
 * aus der lokalen Fixture, damit die Seite auch ohne DB-Verbindung rendert.
 * Gibt null zurück, wenn weder DB noch Fixture die Venue kennen.
 */
async function resolveVenue(slug: string) {
  const supabase = getSupabase();
  if (supabase) {
    const fromDb = await fetchVenueBySlugFromSupabase(slug, supabase);
    if (fromDb) {
      return fromDb;
    }
  }
  // Fallback: lokale Fixture (z. B. Supabase nicht erreichbar oder Build ohne
  // Env). Bewusst, damit die Route niemals komplett leer bleibt.
  return getVenueBySlug(slug);
}
