import Link from "next/link";
import { ThemeToggle } from "@/components/ThemeToggle";

export default function Home() {
  return (
    <div className="min-h-screen bg-kl-dark text-kl-canvas selection:bg-kl-terracotta/20 selection:text-kl-terracotta">
      {/* 1. Top Navigation Bar */}
      <header className="sticky top-0 z-40 bg-kl-dark/95 backdrop-blur border-b border-neutral-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3.5 flex items-center justify-between gap-4">
          {/* Left: Brand mark + Title + Version badge */}
          <div className="flex items-center gap-3">
            <span
              className="w-2.5 h-2.5 rounded-full bg-kl-terracotta flex-shrink-0 animate-pulse"
              aria-hidden="true"
            />
            <Link
              href="/"
              className="font-sans font-semibold text-lg text-kl-canvas tracking-tight hover:opacity-90 transition-opacity"
            >
              KitchenLink
            </Link>
            <span className="font-mono text-xs text-neutral-400 bg-neutral-900 border border-neutral-700/80 px-2 py-0.5 rounded-md">
              OS 1.4
            </span>
          </div>

          {/* Center/Right: Status pill */}
          <div className="hidden md:inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-950/60 border border-emerald-800/60 text-kl-emerald font-mono text-xs">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-kl-emerald opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-kl-emerald" />
            </span>
            <span>BONJOUR LAN RELAY • OFFLINE-FIRST</span>
          </div>

          {/* CTA & Controls */}
          <div className="flex items-center gap-3">
            <Link
              href="/vendors"
              className="hidden lg:inline-flex text-xs font-mono text-neutral-400 hover:text-kl-canvas transition-colors px-2 py-1"
            >
              B2B Lieferanten
            </Link>
            <Link
              href="/alte-muehle/menu"
              className="inline-flex items-center gap-1.5 bg-kl-terracotta hover:bg-kl-terracotta/90 text-white font-sans text-xs sm:text-sm font-medium px-4 py-2 rounded-lg transition-colors shadow-sm"
            >
              <span>Live-Sandbox</span>
              <span aria-hidden="true">→</span>
            </Link>
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main>
        {/* 2. Hero Section */}
        <section className="bg-kl-dark text-kl-canvas pt-12 pb-20 md:pt-20 md:pb-28 border-b border-neutral-800 relative overflow-hidden">
          {/* Subtle atmospheric glow */}
          <div
            className="absolute -top-24 -right-24 w-96 h-96 bg-kl-terracotta/10 rounded-full blur-3xl pointer-events-none"
            aria-hidden="true"
          />
          <div
            className="absolute -bottom-24 -left-24 w-96 h-96 bg-kl-emerald/10 rounded-full blur-3xl pointer-events-none"
            aria-hidden="true"
          />

          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center">
              {/* Left Column: Copy & Actions */}
              <div className="lg:col-span-7">
                <div className="inline-flex items-center gap-2 mb-4">
                  <span className="font-mono text-xs uppercase tracking-widest text-kl-terracotta font-semibold">
                    FÜR DIE DACH-GASTRONOMIE ENTWICKELT
                  </span>
                </div>

                <h1 className="font-serif text-4xl sm:text-5xl lg:text-6xl font-medium tracking-tight text-kl-canvas leading-[1.12]">
                  Ruhe im Service,
                  <br />
                  <span className="italic text-kl-border">selbst wenn das WLAN brennt.</span>
                </h1>

                <p className="text-neutral-400 text-base sm:text-lg lg:text-xl font-sans mt-6 max-w-2xl leading-relaxed">
                  Smartphone-first Kasse (native SwiftUI), sekundenschnelles QR-Table-Ordering
                  ohne App-Zwang und unterbrechungsfreier Offline-Betrieb per lokalem LAN-Relay.
                </p>

                <div className="flex flex-wrap items-center gap-4 mt-8">
                  <Link
                    href="/alte-muehle/menu"
                    className="inline-flex items-center justify-center gap-2 bg-kl-terracotta hover:opacity-95 text-white font-sans font-medium text-base px-6 py-3.5 rounded-xl transition-all shadow-lg shadow-kl-terracotta/20 hover:shadow-kl-terracotta/30"
                  >
                    <span>Gast-Speisekarte testen (Alte Mühle)</span>
                    <span aria-hidden="true">→</span>
                  </Link>
                  <a
                    href="https://github.com/boethius68/KitchenLink"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center justify-center gap-2 bg-neutral-900 hover:bg-neutral-850 border border-neutral-700 text-kl-canvas font-mono text-sm px-5 py-3.5 rounded-xl transition-all"
                  >
                    <span>GitHub & Architektur</span>
                    <span aria-hidden="true">→</span>
                  </a>
                </div>

                <div className="flex flex-wrap items-center gap-6 mt-10 pt-6 border-t border-neutral-800/80 text-xs font-mono text-neutral-400">
                  <div className="flex items-center gap-2">
                    <span className="text-kl-emerald font-bold">✓</span>
                    <span>TSE-KassensichV § 146a AO</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-kl-emerald font-bold">✓</span>
                    <span>GoBD & DSFinV-K 2.3</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-kl-emerald font-bold">✓</span>
                    <span>14 EU-Hauptallergene (LMIV)</span>
                  </div>
                </div>
              </div>

              {/* Right Column: Dual Live UI Artifact (Pure Layered CSS/JSX) */}
              <div className="lg:col-span-5 relative min-h-[460px] sm:min-h-[500px] flex items-center justify-center">
                {/* 1. POS Dark Card (Simulated SwiftUI Order Ticket) */}
                <div className="bg-[#141413] border border-neutral-700/80 rounded-2xl p-5 sm:p-6 shadow-2xl w-full max-w-sm sm:max-w-md transform lg:-rotate-2 transition-transform duration-300 hover:rotate-0 z-10">
                  <div className="flex items-center justify-between border-b border-neutral-800 pb-3 mb-3.5">
                    <div className="flex items-center gap-2">
                      <span className="w-2 h-2 rounded-full bg-kl-emerald animate-pulse" />
                      <span className="font-mono text-xs font-bold text-kl-canvas tracking-wider">
                        TISCH 12 • BON #084
                      </span>
                    </div>
                    <span className="font-mono text-[11px] text-neutral-400">
                      Service: Anna • 19:42 Uhr
                    </span>
                  </div>

                  <div className="space-y-3 font-sans text-sm">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="font-semibold text-neutral-100">
                          2× Geschmorte Rote Bete
                        </div>
                        <div className="text-xs text-neutral-400 font-mono">
                          Gang 1 • Vorspeise
                        </div>
                      </div>
                      <div className="font-mono tabular-nums text-neutral-200 font-medium">
                        29,00 €
                      </div>
                    </div>

                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="font-semibold text-neutral-100">
                          1× Dry Aged Entrecôte (300g)
                        </div>
                        <div className="text-xs text-neutral-400 font-mono">
                          Medium-rare • Rosmarinjus • Gang 2
                        </div>
                      </div>
                      <div className="font-mono tabular-nums text-neutral-200 font-medium">
                        38,50 €
                      </div>
                    </div>
                  </div>

                  <div className="border-b border-dashed border-neutral-700 my-3.5" />

                  <div className="flex items-center justify-between font-mono">
                    <span className="text-xs text-neutral-400 uppercase tracking-wider">
                      Gesamtbetrag
                    </span>
                    <span className="text-base font-bold tabular-nums text-kl-canvas">
                      67,50 €
                    </span>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 mt-4 pt-3 border-t border-neutral-800 text-[11px] font-mono">
                    <span className="text-kl-emerald bg-emerald-950/60 border border-emerald-800/60 px-2 py-0.5 rounded">
                      TSE-Signatur: OK • DSFinV-K
                    </span>
                    <span className="text-neutral-300 bg-neutral-850 border border-neutral-700 px-2 py-0.5 rounded">
                      Sync: 12ms (Local LAN)
                    </span>
                  </div>
                </div>

                {/* 2. Guest Web Paper Card (Simulated Mini Dining Room Preview) */}
                <div className="absolute -bottom-6 -right-2 sm:right-2 sm:-bottom-8 max-w-xs sm:max-w-sm w-full bg-kl-canvas text-kl-charcoal border border-kl-border rounded-2xl p-5 shadow-2xl transform lg:rotate-2 hover:rotate-0 transition-transform duration-300 z-20">
                  <div className="flex items-center justify-between border-b border-kl-border pb-2.5 mb-3">
                    <span className="font-serif font-medium text-sm text-kl-charcoal">
                      Gasthaus Alte Mühle
                    </span>
                    <span className="font-mono text-[10px] bg-kl-subtle text-kl-muted px-2 py-0.5 rounded-full">
                      Tisch 12 • QR Live
                    </span>
                  </div>

                  <div>
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="font-sans font-semibold text-sm text-kl-charcoal">
                        Geschmorte Rote Bete
                      </span>
                      <span className="bg-kl-sage/15 text-kl-sage text-[10px] px-1.5 py-0.5 rounded font-medium">
                        Vegetarisch
                      </span>
                    </div>

                    <p className="font-sans text-xs text-kl-muted mt-1 leading-relaxed">
                      Ziegenfrischkäse, geröstete Walnüsse, Wildkräuter & alter Balsamico.
                    </p>

                    <div className="flex items-center gap-1 mt-2">
                      <span className="bg-kl-subtle text-kl-muted font-mono text-[10px] px-1.5 py-0.5 rounded">
                        G · Milch
                      </span>
                      <span className="bg-kl-subtle text-kl-muted font-mono text-[10px] px-1.5 py-0.5 rounded">
                        H · Walnuss
                      </span>
                    </div>

                    <div className="flex items-center justify-between mt-3 pt-2.5 border-t border-kl-border/70">
                      <span className="font-mono tabular-nums text-sm font-semibold text-kl-charcoal">
                        14,50 €
                      </span>
                      <Link
                        href="/alte-muehle/menu"
                        className="inline-flex items-center gap-1 bg-kl-dark text-kl-canvas hover:bg-neutral-800 font-sans text-xs font-medium px-3 py-1.5 rounded-lg transition-colors shadow-sm"
                      >
                        <span>Speisekarte öffnen</span>
                        <span className="font-mono text-[10px] text-kl-terracotta">→</span>
                      </Link>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 3. Core Pillars Bento Grid */}
        <section className="bg-kl-canvas text-kl-charcoal py-20 lg:py-28 border-b border-kl-border">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="max-w-3xl">
              <span className="font-mono text-xs uppercase tracking-widest text-kl-terracotta font-semibold">
                ARCHITEKTUR & BETRIEBSSYSTEM
              </span>
              <h2 className="font-serif text-3xl sm:text-4xl md:text-5xl font-medium tracking-tight text-kl-charcoal mt-2">
                Technologische Präzision für den echten Gastronomie-Alltag.
              </h2>
              <p className="text-kl-muted text-base sm:text-lg max-w-2xl mt-4 font-sans leading-relaxed">
                Vier Säulen, die KitchenLink vom ersten Gast-Scan bis zum revisionssicheren
                Tagesabschluss kompromisslos zuverlässig machen.
              </p>
            </div>

            {/* Asymmetric Bento Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-6 mt-12">
              {/* Card 1 (7 Cols): Offline-First LAN Resilienz */}
              <div className="lg:col-span-7 bg-kl-surface border border-kl-border rounded-2xl p-8 flex flex-col justify-between shadow-sm hover:shadow-md transition-shadow">
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <span className="font-mono text-xs font-semibold text-kl-emerald bg-emerald-950/10 border border-emerald-800/20 px-2.5 py-1 rounded-full">
                      mDNS Bonjour Mesh
                    </span>
                    <span className="font-mono text-xs text-kl-muted">Pillar 01</span>
                  </div>

                  <h3 className="font-serif text-2xl font-medium text-kl-charcoal">
                    Offline-First LAN-Resilienz
                  </h3>

                  <p className="font-sans text-sm text-kl-muted mt-3 leading-relaxed">
                    Wenn das Restaurant-WLAN oder der DSL-Uplink während der Samstags-Rush-Hour
                    abreißt, bricht bei herkömmlichen Cloud-Kassen der Betrieb zusammen.
                    KitchenLink schaltet latenzfrei auf lokales Bonjour-Multicast um: Service-iPhones
                    und Küchen-Displays synchronisieren im geschützten Subnetz direkt von Gerät zu Gerät.
                    Alle Bestellungen verbleiben in einem append-only Event Store und synchronisieren
                    bei Wiederkehr des Internets konfliktfrei in die Cloud.
                  </p>
                </div>

                <div className="mt-8 pt-6 border-t border-kl-border/70 flex flex-wrap items-center gap-3 font-mono text-xs text-kl-charcoal">
                  <span className="bg-kl-subtle px-2.5 py-1 rounded-md">Sub-50ms Latenz</span>
                  <span className="bg-kl-subtle px-2.5 py-1 rounded-md">Kein Cloud-SPOF</span>
                  <span className="bg-kl-subtle px-2.5 py-1 rounded-md">Zero-Config mDNS</span>
                </div>
              </div>

              {/* Card 2 (5 Cols): Dish-First Guest Web & 14 EU-Allergene */}
              <div className="lg:col-span-5 bg-kl-surface border border-kl-border rounded-2xl p-8 flex flex-col justify-between shadow-sm hover:shadow-md transition-shadow">
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <span className="font-mono text-xs font-semibold text-kl-terracotta bg-kl-terracotta/10 border border-kl-terracotta/20 px-2.5 py-1 rounded-full">
                      Quiet UI • LMIV
                    </span>
                    <span className="font-mono text-xs text-kl-muted">Pillar 02</span>
                  </div>

                  <h3 className="font-serif text-2xl font-medium text-kl-charcoal">
                    Dish-First Guest Web & 14 EU-Allergene
                  </h3>

                  <p className="font-sans text-sm text-kl-muted mt-3 leading-relaxed">
                    Gäste scannen den Tisch-QR-Code und bestellen sofort im Safari oder Chrome —
                    ohne App-Download, ohne Registrierung, ohne Werbe-Banner. Alle 14 EU-Hauptallergene
                    und deutschen Zusatzstoffe (§ 5 LMZDV) sind ruhig und lesbar im Fließtext
                    als unaufdringliche Monospace-Pills integriert.
                  </p>
                </div>

                <div className="mt-8 pt-6 border-t border-kl-border/70 flex flex-wrap items-center gap-2">
                  <span className="bg-kl-subtle text-kl-muted font-mono text-[10px] px-2 py-0.5 rounded">
                    A1 · Weizen
                  </span>
                  <span className="bg-kl-subtle text-kl-muted font-mono text-[10px] px-2 py-0.5 rounded">
                    G · Milch
                  </span>
                  <span className="bg-kl-subtle text-kl-muted font-mono text-[10px] px-2 py-0.5 rounded">
                    L · Sellerie
                  </span>
                  <span className="bg-kl-sage/15 text-kl-sage font-sans text-xs px-2 py-0.5 rounded-full font-medium ml-auto">
                    Vegan/Veggie
                  </span>
                </div>
              </div>

              {/* Card 3 (5 Cols): Native SwiftUI POS & Schichtbetrieb */}
              <div className="lg:col-span-5 bg-kl-surface border border-kl-border rounded-2xl p-8 flex flex-col justify-between shadow-sm hover:shadow-md transition-shadow">
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <span className="font-mono text-xs font-semibold text-kl-charcoal bg-neutral-200/80 px-2.5 py-1 rounded-full">
                      120Hz Swift & SwiftUI
                    </span>
                    <span className="font-mono text-xs text-kl-muted">Pillar 03</span>
                  </div>

                  <h3 className="font-serif text-2xl font-medium text-kl-charcoal">
                    Native SwiftUI POS & Schichtbetrieb
                  </h3>

                  <p className="font-sans text-sm text-kl-muted mt-3 leading-relaxed">
                    Keine träge Electron- oder Web-Wrapper-Kasse am Tisch: Entwickelt mit Swift
                    für maximale Energieeffizienz und Haptik auf dem iPhone. Mit Tischplan-Management,
                    präziser Gangsteuerung (Vorspeise, Hauptgang, Dessert), Zeiterfassung nach
                    deutschem Arbeitsrecht und blitzschneller Manager-PIN-Autorisierung.
                  </p>
                </div>

                <div className="mt-8 pt-6 border-t border-kl-border/70 flex flex-wrap items-center gap-3 font-mono text-xs text-kl-charcoal">
                  <span className="bg-kl-subtle px-2.5 py-1 rounded-md">Gangfeuerung</span>
                  <span className="bg-kl-subtle px-2.5 py-1 rounded-md">Tap to Pay bereit</span>
                  <span className="bg-kl-subtle px-2.5 py-1 rounded-md">Sollbesetzungswarnung</span>
                </div>
              </div>

              {/* Card 4 (7 Cols): DACH-Fiskal & Buchhaltung Ready */}
              <div className="lg:col-span-7 bg-kl-surface border border-kl-sage/40 rounded-2xl p-8 flex flex-col justify-between shadow-sm hover:shadow-md transition-shadow bg-gradient-to-br from-kl-surface to-kl-sage/5">
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <span className="font-mono text-xs font-semibold text-kl-sage bg-kl-sage/15 border border-kl-sage/30 px-2.5 py-1 rounded-full">
                      KassenSichV • GoBD • DATEV
                    </span>
                    <span className="font-mono text-xs text-kl-muted">Pillar 04</span>
                  </div>

                  <h3 className="font-serif text-2xl font-medium text-kl-charcoal">
                    DACH-Fiskal & Buchhaltung Ready
                  </h3>

                  <p className="font-sans text-sm text-kl-muted mt-3 leading-relaxed">
                    Rechtssicherheit von Tag eins an: Gesetzliche TSE-Signaturketten (§ 146a AO)
                    über Cloud- und Hardware-TSE, lückenloses Kassenbuch mit Zählprotokoll,
                    vollständiger DSFinV-K 2.3 Prüfexport für Finanzprüfer und automatisierter
                    DATEV EXTF 700 Buchungsstapel-Export für die Steuerberatungskanzlei.
                  </p>
                </div>

                <div className="mt-8 pt-6 border-t border-kl-border/70 grid grid-cols-2 sm:grid-cols-4 gap-3 font-mono text-xs text-kl-charcoal text-center">
                  <div className="bg-kl-subtle/80 p-2 rounded-lg">
                    <div className="text-kl-muted text-[10px]">PARAGRAPH</div>
                    <div className="font-bold">§ 146a AO</div>
                  </div>
                  <div className="bg-kl-subtle/80 p-2 rounded-lg">
                    <div className="text-kl-muted text-[10px]">EXPORT</div>
                    <div className="font-bold">DSFinV-K 2.3</div>
                  </div>
                  <div className="bg-kl-subtle/80 p-2 rounded-lg">
                    <div className="text-kl-muted text-[10px]">SCHNITTSTELLE</div>
                    <div className="font-bold">DATEV 700</div>
                  </div>
                  <div className="bg-kl-subtle/80 p-2 rounded-lg">
                    <div className="text-kl-muted text-[10px]">MWST</div>
                    <div className="font-bold">7% / 19% Split</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 4. Interactive Sandbox Callout Banner */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div className="bg-kl-dark text-kl-canvas rounded-3xl p-8 sm:p-12 lg:p-16 border border-neutral-800 shadow-2xl relative overflow-hidden">
            <div
              className="absolute top-0 right-0 w-80 h-80 bg-kl-terracotta/15 rounded-full blur-3xl pointer-events-none"
              aria-hidden="true"
            />
            <div
              className="absolute bottom-0 left-0 w-80 h-80 bg-kl-emerald/15 rounded-full blur-3xl pointer-events-none"
              aria-hidden="true"
            />

            <div className="relative z-10 max-w-3xl">
              <span className="font-mono text-xs uppercase tracking-widest text-kl-terracotta font-semibold">
                INTERAKTIVE SANDBOX-UMGEBUNG
              </span>
              <h2 className="font-serif text-3xl sm:text-4xl lg:text-5xl font-medium tracking-tight text-kl-canvas mt-3">
                Jetzt die Speisekarte der Alten Mühle testen.
              </h2>
              <p className="text-neutral-400 text-base sm:text-lg mt-4 font-sans leading-relaxed">
                Öffne die Live-Gast-Speisekarte direkt in deinem Browser. Konfiguriere ein Gericht,
                sende eine Bestellung ab, teste das interaktive Rechnungs-Splitting am Tisch
                und erlebe das Tactile Hospitality Tech Design am eigenen Bildschirm.
              </p>

              <div className="flex flex-wrap items-center gap-4 mt-8">
                <Link
                  href="/alte-muehle/menu"
                  className="inline-flex items-center gap-2 bg-kl-terracotta hover:bg-kl-terracotta/90 text-white font-sans font-medium text-base px-6 py-3.5 rounded-xl transition-all shadow-lg shadow-kl-terracotta/20 hover:shadow-kl-terracotta/30"
                >
                  <span>Speisekarte der Alten Mühle öffnen</span>
                  <span aria-hidden="true">→</span>
                </Link>
                <Link
                  href="/alte-muehle/reserve"
                  className="inline-flex items-center gap-2 bg-neutral-900 hover:bg-neutral-850 border border-neutral-700 text-neutral-300 hover:text-white font-mono text-sm px-5 py-3.5 rounded-xl transition-all"
                >
                  <span>Tischreservierung ansehen</span>
                  <span aria-hidden="true">→</span>
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* 5. Clean Footer */}
      <footer className="bg-kl-dark text-neutral-400 border-t border-neutral-800 py-14">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-10">
            {/* Col 1: Brand & Philosophy */}
            <div className="md:col-span-1">
              <div className="flex items-center gap-2.5">
                <span className="w-2.5 h-2.5 rounded-full bg-kl-terracotta flex-shrink-0" />
                <span className="font-serif text-xl font-bold text-kl-canvas">KitchenLink</span>
              </div>
              <p className="font-sans text-xs sm:text-sm text-neutral-400 mt-3 leading-relaxed">
                Smartphone-First Restaurant Operating System für den modernen DACH-Gastronomiebetrieb.
              </p>
              <div className="font-mono text-xs text-neutral-400 mt-4">
                Open Source & Architecture • MIT License
              </div>
            </div>

            {/* Col 2: Oberflächen */}
            <div>
              <div className="font-mono text-xs uppercase tracking-wider text-kl-canvas font-semibold mb-3">
                Oberflächen
              </div>
              <ul className="space-y-2.5 text-sm font-sans">
                <li>
                  <Link
                    href="/alte-muehle/menu"
                    className="hover:text-kl-canvas transition-colors"
                  >
                    Gast-Speisekarte (Alte Mühle)
                  </Link>
                </li>
                <li>
                  <Link
                    href="/alte-muehle/reserve"
                    className="hover:text-kl-canvas transition-colors"
                  >
                    Tischreservierung
                  </Link>
                </li>
                <li>
                  <Link
                    href="/vendors"
                    className="hover:text-kl-canvas transition-colors"
                  >
                    B2B Lieferanten-Portal
                  </Link>
                </li>
              </ul>
            </div>

            {/* Col 3: Dokumentation & Architektur */}
            <div>
              <div className="font-mono text-xs uppercase tracking-wider text-kl-canvas font-semibold mb-3">
                Architektur & Docs
              </div>
              <ul className="space-y-2.5 text-xs font-mono">
                <li>
                  <a
                    href="https://github.com/boethius68/KitchenLink/blob/main/docs/PRODUCT_BLUEPRINT.md"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="hover:text-kl-canvas transition-colors"
                  >
                    docs/PRODUCT_BLUEPRINT.md ↗
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/boethius68/KitchenLink/blob/main/docs/DESIGN_SYSTEM.md"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="hover:text-kl-canvas transition-colors"
                  >
                    docs/DESIGN_SYSTEM.md ↗
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/boethius68/KitchenLink"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="hover:text-kl-canvas transition-colors"
                  >
                    GitHub: boethius68/KitchenLink ↗
                  </a>
                </li>
              </ul>
            </div>

            {/* Col 4: Recht & Standards */}
            <div>
              <div className="font-mono text-xs uppercase tracking-wider text-kl-canvas font-semibold mb-3">
                Recht & Standards
              </div>
              <ul className="space-y-2.5 text-xs font-mono text-neutral-400">
                <li>KassenSichV § 146a AO (TSE)</li>
                <li>GoBD-Kassenbuch & DSFinV-K 2.3</li>
                <li>DATEV EXTF 700 Buchungsstapel</li>
                <li>LMIV 14 EU-Hauptallergene</li>
              </ul>
            </div>
          </div>

          <div className="mt-12 pt-8 border-t border-neutral-800 flex flex-col sm:flex-row items-center justify-between gap-4 font-mono text-xs text-neutral-400 text-center sm:text-left">
            <span>
              © 2026 KitchenLink • Sandbox-Umgebung (keine echten Zahlungen)
            </span>
            <span>
              Designed with Tactile Hospitality Tech
            </span>
          </div>
        </div>
      </footer>
    </div>
  );
}
