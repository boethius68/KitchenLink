import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { GuestMenuCard } from "@/components/GuestMenuCard";
import { getVenueBySlug, sandboxVenues } from "@/lib/venue-data";

interface MenuPageProps {
  params: Promise<{ venueSlug: string }>;
}

export const dynamicParams = false;

export function generateStaticParams() {
  return sandboxVenues.map((venue) => ({ venueSlug: venue.slug }));
}

export async function generateMetadata({
  params,
}: MenuPageProps): Promise<Metadata> {
  const { venueSlug } = await params;
  const venue = getVenueBySlug(venueSlug);
  return {
    title: venue ? `${venue.name} – Speisekarte` : "Speisekarte",
  };
}

export default async function MenuPage({ params }: MenuPageProps) {
  const { venueSlug } = await params;
  const venue = getVenueBySlug(venueSlug);
  if (!venue) {
    notFound();
  }
  return <GuestMenuCard venue={venue} />;
}
