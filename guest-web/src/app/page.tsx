import Link from "next/link";
import { sandboxVenues } from "@/lib/venue-data";
import { getVendorPurchaseOrders, formatCents } from "@/lib/vendor-data";
import { PlatformCompatibilityMatrix } from "@/components/PlatformCompatibilityMatrix";
import { ThemeToggle } from "@/components/ThemeToggle";

export default function Home() {
  const referenceVenue = sandboxVenues[0]; // Alte Mühle
  const sampleOrders = getVendorPurchaseOrders().slice(0, 2);

  return (
    <div className="kl-brand-home">
      {/* 1. Masthead */}
      <header className="kl-brand-header">
        <div className="kl-brand-header-inner">
          <div className="kl-brand-logo-group">
            <Link href="/" className="kl-brand-wordmark">
              KitchenLink
            </Link>
            <span className="kl-brand-env-tag">Sandbox</span>
          </div>

          <nav className="kl-brand-nav" aria-label="Plattformbereiche">
            <a href="#gast-web" className="kl-brand-nav-item">
              Gast-Web
            </a>
            <a href="#lieferanten-portal" className="kl-brand-nav-item">
              Lieferanten (B2B)
            </a>
            <a href="#business-app" className="kl-brand-nav-item">
              Business (iOS)
            </a>
            <a href="#kompatibilitaet" className="kl-brand-nav-item">
              Plattform-Matrix
            </a>
          </nav>

          <div className="kl-brand-header-actions">
            <Link href={`/${referenceVenue.slug}/menu`} className="kl-action-link">
              Speisekarte
            </Link>
            <Link href="/vendors" className="kl-action-link">
              Lieferanten
            </Link>
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main className="kl-brand-main">
        {/* 2. Hero: Ruhig, präzise, typografisch geführt */}
        <section className="kl-editorial-hero">
          <div className="kl-editorial-hero-container">
            <div className="kl-editorial-label">
              Restaurantbetriebssystem · Deutschland
            </div>

            <h1 className="kl-editorial-title">
              Das Betriebssystem für den Restaurantbetrieb.
              <br />
              Natives iOS und barrierefreies Web.
            </h1>

            <p className="kl-editorial-lead">
              Kasse, Tischservice und Küchenmonitor laufen auf dem iPhone und iPad.
              Gäste bestellen und zahlen direkt am Tisch über das Gast-Web.
              Lieferanten empfangen Bestellungen und drucken Lieferscheine im Web-Portal.
            </p>

            <div className="kl-editorial-actions">
              <Link
                href={`/${referenceVenue.slug}/menu`}
                className="kl-primary-button kl-btn-standalone"
              >
                Speisekarte der Alten Mühle öffnen
              </Link>
              <Link href="/vendors" className="kl-secondary-button kl-btn-standalone">
                B2B Lieferanten-Portal
              </Link>
              <Link
                href={`/${referenceVenue.slug}/reserve`}
                className="kl-text-link"
              >
                Tischreservierung →
              </Link>
            </div>
          </div>
        </section>

        {/* 3. Live-Oberflächen: Echte Einblicke statt Werbekarten */}
        <section className="kl-live-surfaces">
          <div className="kl-surface-split" id="gast-web">
            {/* Linke Spalte: Gast-Web Speisekarte */}
            <div className="kl-surface-block">
              <div className="kl-surface-meta">
                <span className="kl-surface-kicker">01 · Gast-Web</span>
                <h2 className="kl-surface-heading">Bestellung am Tisch</h2>
                <p className="kl-type-secondary">
                  Gäste scannen den Tisch-QR-Code und bestellen im mobilen Browser.
                  Kein App-Download, keine Registrierung. Pflichtkennzeichnungen
                  laufen nach deutscher LMIV im Fließtext.
                </p>
              </div>

              {/* Realer Speisekarten-Ausschnitt */}
              <div className="kl-preview-card">
                <div className="kl-preview-header">
                  <div>
                    <span className="kl-type-primary">{referenceVenue.name}</span>
                    <div className="kl-type-meta kl-text-muted">Tisch 4 · QR-Code erkannt</div>
                  </div>
                  <span className="kl-status-badge kl-status-active">Geöffnet</span>
                </div>

                <div className="kl-preview-menu-list">
                  {referenceVenue.menu.slice(0, 3).map((item) => (
                    <div key={item.id} className="kl-preview-menu-row">
                      <div className="kl-preview-menu-details">
                        <div className="kl-preview-dish-title">
                          <strong>{item.name}</strong>
                          {item.tag && (
                            <span className="kl-badge kl-badge-on-light kl-type-meta">
                              {item.tag}
                            </span>
                          )}
                        </div>
                        <p className="kl-type-secondary kl-preview-dish-desc">
                          {item.description}
                          {item.allergens && item.allergens.length > 0 && (
                            <span className="kl-preview-allergen-tags">
                              {" · "}{item.allergens.map((a) => a.code.toUpperCase()).join(", ")}
                            </span>
                          )}
                        </p>
                      </div>
                      <div className="kl-preview-dish-price kl-tabular">
                        {(item.priceCents / 100).toFixed(2).replace(".", ",")} €
                      </div>
                    </div>
                  ))}
                </div>

                <div className="kl-preview-footer">
                  <Link
                    href={`/${referenceVenue.slug}/menu`}
                    className="kl-primary-button"
                  >
                    Vollständige Karte mit 8 Positionen ansehen
                  </Link>
                </div>
              </div>
            </div>

            {/* Rechte Spalte: B2B Lieferanten-Portal */}
            <div className="kl-surface-block" id="lieferanten-portal">
              <div className="kl-surface-meta">
                <span className="kl-surface-kicker">02 · B2B Lieferanten-Portal</span>
                <h2 className="kl-surface-heading">Warenwirtschaft & Einkauf</h2>
                <p className="kl-type-secondary">
                  Lieferanten benötigen keine Gastronomie-Kassen-App. Eingehende
                  Bestellungen werden direkt im Web bestätigt und als digitaler
                  Lieferschein mit Unterschriftennachweis gedruckt.
                </p>
              </div>

              {/* Realer Bestellungs-Ausschnitt */}
              <div className="kl-preview-card">
                <div className="kl-preview-header">
                  <div>
                    <span className="kl-type-primary">Eingehende Lieferanten-Aufträge</span>
                    <div className="kl-type-meta kl-text-muted">
                      Verknüpft mit der Küchen-Warenwirtschaft
                    </div>
                  </div>
                  <span className="kl-status-badge">B2B Web</span>
                </div>

                <div className="kl-preview-po-list">
                  {sampleOrders.map((po) => (
                    <div key={po.id} className="kl-preview-po-row">
                      <div className="kl-preview-po-top">
                        <span className="kl-tabular-code">{po.orderNumber}</span>
                        <span className="kl-type-primary">{formatCents(po.totalCents)}</span>
                      </div>
                      <div className="kl-type-secondary">
                        <strong>{po.supplierName}</strong>
                      </div>
                      <div className="kl-type-meta kl-text-muted">
                        Lieferung bis: {po.expectedDeliveryDate} · {po.lines.length} Artikel
                      </div>
                    </div>
                  ))}
                </div>

                <div className="kl-preview-footer">
                  <Link href="/vendors" className="kl-secondary-button">
                    Lieferanten-Portal aufrufen & Lieferschein drucken
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 4. Dritte Säule: KitchenLink Business auf iPhone & iPad */}
        <section className="kl-business-surface" id="business-app">
          <div className="kl-business-inner">
            <div className="kl-business-copy">
              <span className="kl-surface-kicker">03 · Vor Ort im Betrieb</span>
              <h2 className="kl-editorial-subtitle">
                KitchenLink Business auf iPhone und iPad
              </h2>
              <p className="kl-type-secondary kl-business-lead">
                Ein Betrieb benötigt keine festinstallierten Terminalburgen. Service,
                Küche und Management arbeiten auf handelsüblichen Apple-Geräten.
              </p>

              <div className="kl-business-spec-list">
                <div className="kl-spec-item">
                  <div className="kl-spec-title">Mobiles POS & Gang-Steuerung</div>
                  <div className="kl-spec-text">
                    Bonierung, Split-Zahlungen, Trinkgeldabrechnung und Tischpläne
                    direkt am Tisch auf dem iPhone.
                  </div>
                </div>

                <div className="kl-spec-item">
                  <div className="kl-spec-title">Küchenmonitor (KDS)</div>
                  <div className="kl-spec-text">
                    Ruhige Stationsansicht im Farbschema „Immer Tief“. Automatische
                    Abbuchung von Rezepturzutaten beim Servieren.
                  </div>
                </div>

                <div className="kl-spec-item">
                  <div className="kl-spec-title">KassenSichV & GoBD-Kassenbuch</div>
                  <div className="kl-spec-text">
                    Laufende Kassenführung mit TSE-Signaturzählern, 7% / 19% MwSt-Split,
                    DSFinV-K 2.3 Prüfexport und DATEV EXTF 700 Schnittstelle.
                  </div>
                </div>

                <div className="kl-spec-item">
                  <div className="kl-spec-title">Schichtplanung & Zeiterfassung</div>
                  <div className="kl-spec-text">
                    Arbeitszeitaufzeichnung und Sollbesetzungswarnungen nach
                    deutschem Arbeitsrecht direkt in der App.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 5. Plattform-Kompatibilitäts-Matrix */}
        <div id="kompatibilitaet">
          <PlatformCompatibilityMatrix />
        </div>

        {/* 6. Partner für Lieferanten */}
        <section className="kl-supplier-partner-section">
          <div className="kl-supplier-partner-inner">
            <div className="kl-partner-text-block">
              <span className="kl-surface-kicker">Für Großhändler & Winzer</span>
              <h3 className="kl-type-section">
                Lieferanten-Schnittstelle ohne Terminalbindung
              </h3>
              <p className="kl-type-secondary">
                Sie beliefern Gastronomiebetriebe? KitchenLink ermöglicht es Ihren
                Kunden, Bestellungen direkt aus der Warenwirtschaft an Ihre
                Disposition zu senden. Sie bestätigen im Web-Browser und erhalten
                automatisierte Lieferscheine.
              </p>
            </div>
            <div className="kl-partner-action-block">
              <Link href="/vendors" className="kl-secondary-button">
                B2B-Portal öffnen & ansehen →
              </Link>
            </div>
          </div>
        </section>
      </main>

      {/* 7. Footer */}
      <footer className="kl-brand-footer">
        <div className="kl-brand-footer-inner">
          <div className="kl-footer-col">
            <span className="kl-brand-wordmark">KitchenLink</span>
            <p className="kl-type-secondary kl-footer-desc">
              Smartphone-first Betriebssystem für Restaurants, Bars und Cafés.
            </p>
            <div className="kl-type-meta kl-text-muted">
              Referenzmarkt Deutschland · Sandbox-Betrieb
            </div>
          </div>

          <div className="kl-footer-col">
            <div className="kl-footer-heading">Oberflächen</div>
            <ul className="kl-footer-nav">
              <li>
                <Link href={`/${referenceVenue.slug}/menu`}>Gast-Speisekarte (Alte Mühle)</Link>
              </li>
              <li>
                <Link href={`/${referenceVenue.slug}/reserve`}>Tischreservierung</Link>
              </li>
              <li>
                <Link href="/vendors">B2B Lieferanten-Portal</Link>
              </li>
            </ul>
          </div>

          <div className="kl-footer-col">
            <div className="kl-footer-heading">Recht & Standards</div>
            <ul className="kl-footer-nav">
              <li>KassenSichV § 146a AO (TSE)</li>
              <li>GoBD-Kassenbuch & DSFinV-K 2.3</li>
              <li>DATEV EXTF 700 Buchungsstapel</li>
              <li>LMIV 14 EU-Hauptallergene</li>
            </ul>
          </div>
        </div>

        <div className="kl-footer-subline">
          <span className="kl-type-meta kl-text-muted">
            KitchenLink Gast-Web · Keine echten Zahlungen im Sandbox-Betrieb.
          </span>
        </div>
      </footer>
    </div>
  );
}
