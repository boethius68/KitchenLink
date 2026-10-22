import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ReservationForm } from "@/components/ReservationForm";
import { fetchVenueBySlugFromSupabase } from "@/lib/menu-loader";
import { getSupabase } from "@/lib/supabase-client";
import { getVenueBySlug, sandboxVenues } from "@/lib/venue-data";

export const revalidate = 60;
export const dynamicParams = true;

interface ReservePageProps {
  params: Promise<{ venueSlug: string }>;
}

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
      // Fallback auf Fixture
    }
  }
  return sandboxVenues.map((venue) => ({ venueSlug: venue.slug }));
}

export async function generateMetadata({
  params,
}: ReservePageProps): Promise<Metadata> {
  const { venueSlug } = await params;
  const venue = await resolveVenue(venueSlug);
  return {
    title: venue ? `${venue.name} – Tisch reservieren` : "Tisch reservieren",
  };
}

async function resolveVenue(slug: string) {
  const supabase = getSupabase();
  if (supabase) {
    const fromDb = await fetchVenueBySlugFromSupabase(slug, supabase);
    if (fromDb) {
      return fromDb;
    }
  }
  return getVenueBySlug(slug);
}

export default async function ReservePage({ params }: ReservePageProps) {
  const { venueSlug } = await params;
  const venue = await resolveVenue(venueSlug);
  if (!venue) {
    notFound();
  }
  return <ReservationForm venue={venue} />;
}
