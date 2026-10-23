"use client";

import React from "react";
import Link from "next/link";

interface PlatformRow {
  role: string;
  targetUser: string;
  primarySurface: string;
  deviceRequirement: string;
  keyFeatures: string[];
  status: string;
  demoLink?: string;
  demoLabel?: string;
}

const platformRows: PlatformRow[] = [
  {
    role: "Gäste & Besteller",
    targetUser: "Restaurantgäste vor Ort & Abholer",
    primarySurface: "KitchenLink Gast-Web",
    deviceRequirement: "Beliebiger Browser (iOS Safari, Android Chrome, Mac/PC)",
    keyFeatures: [
      "Keine App-Installation nötig",
      "Tisch-QR-Code-Erkennung",
      "Rechtssichere 14 EU-Allergene im Fließtext",
      "Tischreservierung & Vorbestellung",
      "Apple Pay, Google Pay & Bar am Tisch",
    ],
    status: "Live in Sandbox",
    demoLink: "/alte-muehle/menu",
    demoLabel: "Speisekarte testen",
  },
  {
    role: "Lieferanten & Partner",
    targetUser: "Großhändler, Winzer & Erzeuger",
    primarySurface: "B2B Lieferanten-Portal",
    deviceRequirement: "Web-Portal auf Tablet, PC & Smartphone",
    keyFeatures: [
      "Purchase Orders direkt aus der Küchen-Warenwirtschaft",
      "Verbindliche Bestätigung von Lieferterminen",
      "Standardisierter digitaler Lieferschein (Druck/PDF)",
      "Automatischer Wareneingang & Bestandsbuchung",
    ],
    status: "Live in Sandbox",
    demoLink: "/vendors",
    demoLabel: "Lieferanten-Portal öffnen",
  },
  {
    role: "Service & Kassenpersonal",
    targetUser: "Kellner, Servicekräfte & Barista",
    primarySurface: "KitchenLink Business App",
    deviceRequirement: "iPhone (iOS) & iPad",
    keyFeatures: [
      "Mobiles POS am Tisch",
      "GoBD- & KassenSichV-konform mit simulierter TSE",
      "Tischpläne & Gang-Steuerung",
      "Tap to Pay & Kartenterminals",
    ],
    status: "Native iOS / Simulator",
    demoLink: "#app-showcase",
    demoLabel: "App-Funktionen einsehen",
  },
  {
    role: "Küche & Bar (KDS)",
    targetUser: "Küchenchef, Köche & Bar-Team",
    primarySurface: "KitchenLink Kitchen Display",
    deviceRequirement: "iPad (Tief-Modus) & iPhone",
    keyFeatures: [
      "Stationsbezogene digitale Küchenbons",
      "Automatische Rezeptauflösung",
      "Automatischer Bestandsabzug beim KDS-Bump",
      "Ruhe-Farbschema (Immer Tief)",
    ],
    status: "Native iOS / Simulator",
    demoLink: "#kds-showcase",
    demoLabel: "KDS-Architektur",
  },
  {
    role: "Betriebsleitung & Inhaber",
    targetUser: "Gastronomen, Betriebsleiter & Steuerberater",
    primarySurface: "Management & Browser-Verwaltung",
    deviceRequirement: "Web-Verwaltung & iPhone",
    keyFeatures: [
      "Laufendes GoBD-Kassenbuch",
      "DATEV EXTF 700 & DSFinV-K Steuerprüfexporte",
      "Schicht- & Zeiterfassung nach deutschem Arbeitsrecht",
      "Warenwirtschaft, Rezepturen & Rohertragsanalysen",
    ],
    status: "Hybrid iOS / Web",
    demoLink: "#management-showcase",
    demoLabel: "Betriebs-Funktionen",
  },
];

export function PlatformCompatibilityMatrix() {
  return (
    <section className="kl-matrix-section" id="plattform">
      <div className="kl-matrix-header">
        <span className="kl-hero-badge">Plattform-Kompatibilität</span>
        <h2 className="kl-type-section">
          Das KitchenLink Ökosystem: iPhone & Web im Einklang
        </h2>
        <p className="kl-type-secondary">
          Warum nicht nur eine iPhone-App? Weil Gastronomie ein vernetztes
          Ökosystem ist: Gäste und Lieferanten verlangen sofortigen Zugriff ohne
          Hürden, während Service und Küche von der Zuverlässigkeit nativer
          Apple-Hardware profitieren.
        </p>
      </div>

      <div className="kl-matrix-grid">
        {platformRows.map((row) => (
          <div key={row.role} className="kl-matrix-card">
            <div className="kl-matrix-card-top">
              <span className="kl-matrix-status-pill">{row.status}</span>
              <h3 className="kl-type-primary">{row.role}</h3>
              <div className="kl-type-meta kl-slip-muted">{row.targetUser}</div>
            </div>

            <div className="kl-matrix-card-surface">
              <div className="kl-type-meta">Oberfläche & Gerät:</div>
              <strong className="kl-type-secondary">{row.primarySurface}</strong>
              <div className="kl-type-meta kl-slip-muted">{row.deviceRequirement}</div>
            </div>

            <ul className="kl-matrix-features-list">
              {row.keyFeatures.map((f, i) => (
                <li key={i} className="kl-type-secondary">
                  <span className="kl-matrix-check" aria-hidden="true">✓</span> {f}
                </li>
              ))}
            </ul>

            {row.demoLink && (
              <div className="kl-matrix-card-action">
                <Link href={row.demoLink} className="kl-btn-subtle">
                  {row.demoLabel} →
                </Link>
              </div>
            )}
          </div>
        ))}
      </div>
    </section>
  );
}
