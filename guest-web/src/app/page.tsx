import Link from "next/link";
import { sandboxVenues } from "@/lib/venue-data";

// Interner Sandbox-Index. Gäste erreichen eine Venue-Route direkt per QR;
// diese Seite existiert nur, damit der Sandbox-Einstieg auffindbar bleibt.
export default function Home() {
  return (
    <main className="kl-page">
      <h1 className="kl-type-display kl-menu-section-title">
        KitchenLink Gast-Web
      </h1>
      <p className="kl-type-secondary">
        Sandbox-Einstieg: wähle eine Demo-Venue. Im echten Betrieb führt der
        Tisch-QR-Code direkt zur Speisekarte.
      </p>
      <ul className="kl-index-list">
        {sandboxVenues.map((venue) => (
          <li key={venue.slug}>
            <Link href={`/${venue.slug}/menu`}>
              <span className="kl-type-primary">{venue.name}</span>
              <br />
              <span className="kl-type-secondary">
                {venue.isOpen ? "geöffnet" : "geschlossen"}
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
