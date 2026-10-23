import Link from "next/link";
import { sandboxVenues } from "@/lib/venue-data";
import { sandboxSuppliers } from "@/lib/vendor-data";
import { PlatformCompatibilityMatrix } from "@/components/PlatformCompatibilityMatrix";
import { ThemeToggle } from "@/components/ThemeToggle";

export default function Home() {
  return (
    <div className="kl-home-root">
      {/* 1. Hauptnavigation / Header */}
      <header className="kl-navbar">
        <div className="kl-nav-inner">
          <div className="kl-nav-brand">
            <Link href="/" className="kl-brand-link">
              <span className="kl-brand-symbol">KL</span>
              <span className="kl-brand-text">KitchenLink</span>
            </Link>
            <span className="kl-brand-badge">Restaurant-OS</span>
          </div>

          <nav className="kl-nav-links" aria-label="Hauptnavigation">
            <a href="#saeulen" className="kl-nav-link">
              Ökosystem
            </a>
            <a href="#gast-ordering" className="kl-nav-link">
              Gast-Web
            </a>
            <a href="#lieferanten" className="kl-nav-link">
              Lieferanten (B2B)
            </a>
            <a href="#business-app" className="kl-nav-link">
              iPhone App
            </a>
            <a href="#plattform" className="kl-nav-link">
              Kompatibilität
            </a>
            <a href="#sandbox-demos" className="kl-nav-link">
              Demos
            </a>
          </nav>

          <div className="kl-nav-actions">
            <Link href="/alte-muehle/menu" className="kl-btn-primary kl-btn-nav">
              Speisekarte testen
            </Link>
            <Link href="/vendors" className="kl-btn-secondary kl-btn-nav">
              Lieferanten-Portal
            </Link>
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main className="kl-home-main">
        {/* 2. Hero Section / Signboard (Aushängeschild) */}
        <section className="kl-hero-section">
          <div className="kl-hero-inner">
            <div className="kl-hero-eyebrow">
              <span className="kl-hero-pulse" aria-hidden="true" />
              <span>Das ganzheitliche Restaurant-Betriebssystem · Stand 2026</span>
            </div>

            <h1 className="kl-type-display kl-hero-title">
              Smartphone-First Gastronomie.
              <br />
              <span className="kl-hero-accent">Web & iOS</span> nahtlos vereint.
            </h1>

            <p className="kl-hero-lead">
              Ein komplettes Betriebssystem für Restaurants, Bars und Cafés.
              Vom mobilen POS und Küchenmonitor auf dem iPhone über die
              barrierefreie Web-Speisekarte für Gäste bis zum integrierten
              B2B-Lieferantenportal: KitchenLink schließt die Lücke zwischen
              Gästen, Betreibern und Lieferanten.
            </p>

            <div className="kl-hero-ctas">
              <Link
                href="/alte-muehle/menu"
                className="kl-btn-primary kl-btn-hero"
              >
                <span>Live-Speisekarte & Bestellung (Gast-Web)</span>
                <span className="kl-cta-arrow" aria-hidden="true">→</span>
              </Link>
              <Link
                href="/vendors"
                className="kl-btn-secondary kl-btn-hero"
              >
                <span>B2B Lieferanten-Portal</span>
                <span className="kl-cta-arrow" aria-hidden="true">→</span>
              </Link>
              <Link
                href="/alte-muehle/reserve"
                className="kl-btn-subtle kl-btn-hero"
              >
                <span>Tisch online reservieren</span>
              </Link>
            </div>

            {/* Quick-Facts-Leiste */}
            <div className="kl-hero-stats-grid">
              <div className="kl-hero-stat">
                <div className="kl-stat-icon">📱</div>
                <div className="kl-stat-content">
                  <strong className="kl-stat-value">100% Smartphone-First</strong>
                  <span className="kl-stat-desc">
                    Keine teure POS-Hardware. Ein iPhone genügt zum Betrieb.
                  </span>
                </div>
              </div>
              <div className="kl-hero-stat">
                <div className="kl-stat-icon">🌐</div>
                <div className="kl-stat-content">
                  <strong className="kl-stat-value">0 App-Zwang für Gäste</strong>
                  <span className="kl-stat-desc">
                    Tisch-QR öffnet sofort das reaktionsschnelle Gast-Web.
                  </span>
                </div>
              </div>
              <div className="kl-hero-stat">
                <div className="kl-stat-icon">🚚</div>
                <div className="kl-stat-content">
                  <strong className="kl-stat-value">B2B Lieferanten-Hub</strong>
                  <span className="kl-stat-desc">
                    Web-Gegenstück für Großhändler, Lieferscheine & Wareneingang.
                  </span>
                </div>
              </div>
              <div className="kl-hero-stat">
                <div className="kl-stat-icon">🇩🇪</div>
                <div className="kl-stat-content">
                  <strong className="kl-stat-value">KassenSichV & GoBD</strong>
                  <span className="kl-stat-desc">
                    TSE-Simulation, DATEV EXTF 700 & 14 EU-Allergene lückenlos.
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 3. Die 3 Säulen des KitchenLink Ökosystems */}
        <section className="kl-section kl-pillars-section" id="saeulen">
          <div className="kl-section-header">
            <span className="kl-hero-badge">Architektur</span>
            <h2 className="kl-type-section kl-section-title">
              Drei Säulen, eine gemeinsame Datenbasis
            </h2>
            <p className="kl-type-secondary kl-section-subtitle">
              Echte Plattform-Kompatibilität bedeutet: Jede Nutzergruppe
              erhält genau das passende Werkzeug, ohne Medienbrüche oder
              proprietäre Einbahnstraßen.
            </p>
          </div>

          <div className="kl-pillars-grid">
            {/* Säule 1: Gast-Web */}
            <article className="kl-pillar-card" id="gast-ordering">
              <div className="kl-pillar-header">
                <div className="kl-pillar-badge kl-pillar-badge-lemon">
                  Säule 1 · Web-First
                </div>
                <h3 className="kl-type-section">Gast-Web & Tisch-Ordering</h3>
                <p className="kl-type-secondary">
                  Die Schnittstelle zu Ihren Gästen vor Ort und unterwegs.
                  Funktioniert direkt in Safari, Chrome und Firefox auf jedem
                  Smartphone und PC.
                </p>
              </div>

              <ul className="kl-pillar-features">
                <li>
                  <strong>Tisch-QR-Code & Sofort-Bestellung:</strong> Anonyme
                  Bestellung am Tisch ohne Kontozwang oder App-Installation.
                </li>
                <li>
                  <strong>Lückenlose 14 EU-Allergene:</strong> Vollständige
                  Transparenz im Fließtext gem. LMIV und deutscher Kennzeichnung.
                </li>
                <li>
                  <strong>Rezeptur- & Konfigurations-Engine:</strong> Portionen,
                  Extras und Sonderwünsche mit verbindlicher Preiskalkulation.
                </li>
                <li>
                  <strong>Moderne Zahlarten & Reservierung:</strong> Apple Pay,
                  Google Pay, Bar am Tisch und integrierte Tischreservierung.
                </li>
              </ul>

              <div className="kl-pillar-footer">
                <Link href="/alte-muehle/menu" className="kl-btn-primary">
                  Gast-Speisekarte testen →
                </Link>
              </div>
            </article>

            {/* Säule 2: Lieferanten-Portal */}
            <article className="kl-pillar-card" id="lieferanten">
              <div className="kl-pillar-header">
                <div className="kl-pillar-badge kl-pillar-badge-grape">
                  Säule 2 · B2B-Plattform
                </div>
                <h3 className="kl-type-section">B2B Lieferanten-Portal</h3>
                <p className="kl-type-secondary">
                  Das Web-Gegenstück für Großhändler, Winzer und regionale
                  Erzeuger. Keine App nötig – reibungslose Bestellabwicklung im
                  Browser.
                </p>
              </div>

              <ul className="kl-pillar-features">
                <li>
                  <strong>Digitale Purchase Orders (PO):</strong> Bestellungen
                  direkt aus dem Warenwirtschaftsmodul der Küchenleitung empfangen.
                </li>
                <li>
                  <strong>Liefertermin-Bestätigung mit 1 Klick:</strong> Schnelle
                  Disposition und Terminauskunft an den Gastronomen.
                </li>
                <li>
                  <strong>Standardisierter digitaler Lieferschein:</strong>{" "}
                  Druck- und PDF-fähiger Lieferschein mit Positionsnachweisen für Fahrer.
                </li>
                <li>
                  <strong>Automatischer Wareneingang:</strong> Bestätigte
                  Lieferungen buchen sich direkt in das Bestandsledger ein.
                </li>
              </ul>

              <div className="kl-pillar-footer">
                <Link href="/vendors" className="kl-btn-primary">
                  Lieferanten-Portal öffnen →
                </Link>
              </div>
            </article>

            {/* Säule 3: KitchenLink Business App */}
            <article className="kl-pillar-card" id="business-app">
              <div className="kl-pillar-header">
                <div className="kl-pillar-badge kl-pillar-badge-accent">
                  Säule 3 · Native iOS / iPad
                </div>
                <h3 className="kl-type-section">KitchenLink Business App</h3>
                <p className="kl-type-secondary">
                  Die operative Schaltzentrale für Betreiber, Service und
                  Küche vor Ort auf dem iPhone und iPad.
                </p>
              </div>

              <ul className="kl-pillar-features">
                <li>
                  <strong>Mobiles POS & Gang-Steuerung:</strong> Bonierung,
                  Tischwechsel, Split-Zahlungen und Tap to Pay on iPhone.
                </li>
                <li>
                  <strong>Digitaler Küchenmonitor (KDS):</strong> Stationsansicht
                  in ruhigen Erdtönen (Immer Tief) mit automatischem Rezeptabzug.
                </li>
                <li>
                  <strong>Fiskal & KassenSichV:</strong> GoBD-Kassenbuch,
                  TSE-Signatur (§ 146a AO) und DATEV EXTF 700 / DSFinV-K Exporte.
                </li>
                <li>
                  <strong>Dienstplan & Zeiterfassung:</strong> Schichtplanung,
                  Sollbesetzung und Zeiterfassung nach deutschem Arbeitszeitrecht.
                </li>
              </ul>

              <div className="kl-pillar-footer">
                <a href="#plattform" className="kl-btn-secondary">
                  Architektur & Details ansehen →
                </a>
              </div>
            </article>
          </div>
        </section>

        {/* 4. Plattform-Kompatibilitäts-Matrix */}
        <PlatformCompatibilityMatrix />

        {/* 5. Interaktive Live-Sandbox Venues & Demos */}
        <section className="kl-section kl-venues-section" id="sandbox-demos">
          <div className="kl-section-header">
            <span className="kl-hero-badge">Interaktive Demos</span>
            <h2 className="kl-type-section kl-section-title">
              Direkt ausprobieren in der Sandbox
            </h2>
            <p className="kl-type-secondary kl-section-subtitle">
              Testen Sie die End-to-End-Schleife: Bestellen Sie als Gast am Tisch,
              bestätigen Sie die Beschaffung als Lieferant oder werfen Sie einen
              Blick auf die Kassenfunktionen.
            </p>
          </div>

          <div className="kl-venues-grid">
            {sandboxVenues.map((venue) => (
              <div key={venue.slug} className="kl-venue-demo-card">
                <div className="kl-venue-demo-header">
                  <div>
                    <h3 className="kl-type-section">{venue.name}</h3>
                    <span className="kl-type-meta kl-slip-muted">
                      Referenzbetrieb · Volldeklarierte Speisekarte
                    </span>
                  </div>
                  <span
                    className={`kl-venue-status-pill ${
                      venue.isOpen ? "kl-status-open" : "kl-status-closed"
                    }`}
                  >
                    {venue.isOpen ? "Geöffnet (Sandbox)" : "Geschlossen"}
                  </span>
                </div>

                <p className="kl-type-secondary kl-venue-demo-desc">
                  Klassisches Full-Service-Gasthaus mit regionaler Küche:
                  Elsässer Flammkuchen, Kürbissuppe mit Ingwer, Käsespätzle,
                  hausgemachte Limonade und 11-Icon-Referenzgericht (Wiener Schnitzel).
                </p>

                <div className="kl-venue-demo-actions">
                  <Link
                    href={`/${venue.slug}/menu`}
                    className="kl-btn-primary"
                  >
                    Speisekarte & Bestellung öffnen →
                  </Link>
                  <Link
                    href={`/${venue.slug}/reserve`}
                    className="kl-btn-secondary"
                  >
                    Tisch reservieren
                  </Link>
                </div>
              </div>
            ))}

            {/* B2B Lieferanten-Demo-Karte */}
            <div className="kl-venue-demo-card kl-venue-demo-card-supplier">
              <div className="kl-venue-demo-header">
                <div>
                  <h3 className="kl-type-section">B2B Lieferanten-Hub</h3>
                  <span className="kl-type-meta kl-slip-muted">
                    {sandboxSuppliers.length} registrierte Lieferpartner
                  </span>
                </div>
                <span className="kl-venue-status-pill kl-status-supplier">
                  B2B Live-Portal
                </span>
              </div>

              <p className="kl-type-secondary kl-venue-demo-desc">
                Lieferanten wie Kochberg Frischegroßhandel, Weingut Hölle und
                Bio-Gemüsehof Lindner empfangen Bestellungen der Alten Mühle,
                bestätigen Liefertermine und drucken Lieferscheine.
              </p>

              <div className="kl-venue-demo-actions">
                <Link href="/vendors" className="kl-btn-primary">
                  Lieferanten-Portal aufrufen →
                </Link>
              </div>
            </div>
          </div>
        </section>

        {/* 6. Hardware-Unabhängigkeit & Rechtskonformität */}
        <section className="kl-section kl-compliance-section">
          <div className="kl-compliance-inner">
            <div className="kl-compliance-header">
              <span className="kl-hero-badge">Rechtssicher in Deutschland</span>
              <h2 className="kl-type-section">
                Entwickelt für deutsche Gastro-Standards & Gesetze
              </h2>
            </div>

            <div className="kl-compliance-grid">
              <div className="kl-compliance-box">
                <h3 className="kl-type-primary">§ KassenSichV & TSE-Simulation</h3>
                <p className="kl-type-secondary">
                  Konform zu § 146a AO: Fortlaufende Signaturzähler,
                  seriennummernbasierte Belegabsicherung, DSFinV-K-2.3-Prüfstring
                  und QR-Code-Darstellung auf jedem Kassenbeleg.
                </p>
              </div>

              <div className="kl-compliance-box">
                <h3 className="kl-type-primary">📊 GoBD-Kassenbuch & DATEV</h3>
                <p className="kl-type-secondary">
                  Laufendes Kassenbuch mit unveränderbarem Audit-Log, getrenntem
                  7% / 19% MwSt-Split und direktem DATEV EXTF 700
                  Buchungsstapel-Export (SKR03 / SKR04) für den Steuerberater.
                </p>
              </div>

              <div className="kl-compliance-box">
                <h3 className="kl-type-primary">🌿 14 EU-Hauptallergene & Zusatzstoffe</h3>
                <p className="kl-type-secondary">
                  Konform zur Lebensmittelinformations-Verordnung (LMIV): Alle 14
                  Allergene und Pflichtzusatzstoffe werden ruhig und
                  rechtsverbindlich im Fließtext deklariert.
                </p>
              </div>

              <div className="kl-compliance-box">
                <h3 className="kl-type-primary">⚡ Unabhängig von Kassenhardware</h3>
                <p className="kl-type-secondary">
                  Keine monatlichen Leasingverträge für klobige Monitore. Das
                  System läuft vollständig auf Standard-iPhones, iPads und
                  modernen Webbrowsern.
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* 7. Footer / Rechtliches & Transparenz */}
      <footer className="kl-home-footer">
        <div className="kl-footer-inner">
          <div className="kl-footer-brand-col">
            <div className="kl-brand-link">
              <span className="kl-brand-symbol">KL</span>
              <span className="kl-brand-text">KitchenLink</span>
            </div>
            <p className="kl-type-secondary kl-footer-text">
              Das smartphone-first Restaurantbetriebssystem für Gäste,
              Mitarbeiter, Betreiber und Lieferanten.
            </p>
            <div className="kl-type-meta kl-slip-muted">
              Referenzmarkt: Deutschland · Währung: Euro (€)
            </div>
          </div>

          <div className="kl-footer-links-col">
            <h4 className="kl-type-primary">Ökosystem & Demos</h4>
            <ul>
              <li>
                <Link href="/alte-muehle/menu">Gast-Speisekarte Alte Mühle</Link>
              </li>
              <li>
                <Link href="/alte-muehle/reserve">Tischreservierung</Link>
              </li>
              <li>
                <Link href="/vendors">B2B Lieferanten-Portal</Link>
              </li>
              <li>
                <a href="#plattform">Plattform-Kompatibilitäts-Matrix</a>
              </li>
            </ul>
          </div>

          <div className="kl-footer-links-col">
            <h4 className="kl-type-primary">Recht & Standards</h4>
            <ul>
              <li>KassenSichV § 146a AO (TSE)</li>
              <li>GoBD & DSFinV-K 2.3 Prüfexport</li>
              <li>DATEV EXTF 700 Schnittstelle</li>
              <li>LMIV 14 EU-Hauptallergene</li>
            </ul>
          </div>
        </div>

        <div className="kl-footer-bottom">
          <p className="kl-type-meta">
            © 2026 KitchenLink. Integrierte Sandbox-Umgebung – keine echten
            Zahlungen oder verbindlichen Buchungen.
          </p>
        </div>
      </footer>
    </div>
  );
}
