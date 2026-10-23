"use client";

import React from "react";
import Link from "next/link";

interface MatrixEntry {
  actor: string;
  roleDescription: string;
  platform: string;
  device: string;
  responsibilities: string;
  status: string;
  actionLink?: string;
  actionText?: string;
}

const matrixEntries: MatrixEntry[] = [
  {
    actor: "Gast am Tisch",
    roleDescription: "Gäste vor Ort, Abholung, Reservierung",
    platform: "KitchenLink Gast-Web",
    device: "Mobiler Browser (Safari, Chrome, Firefox) auf beliebigem Smartphone oder Desktop",
    responsibilities: "Tisch-QR scannen, Speisekarte mit 14 EU-Allergenen einsehen, bestellen, Apple/Google Pay oder Bar am Tisch",
    status: "Live (Web)",
    actionLink: "/alte-muehle/menu",
    actionText: "Speisekarte",
  },
  {
    actor: "Lieferant & Erzeuger",
    roleDescription: "Großhändler, Getränkelogistik, Winzer",
    platform: "B2B Lieferanten-Portal",
    device: "Web-Portal auf Desktop, Tablet oder Smartphone",
    responsibilities: "Eingehende Purchase Orders (PO) prüfen, Liefertermin bestätigen, digitalen Lieferschein (PDF/Druck) generieren",
    status: "Live (Web)",
    actionLink: "/vendors",
    actionText: "Portal",
  },
  {
    actor: "Service & Kassenpersonal",
    roleDescription: "Kellner, Restaurantleitung, Bar",
    platform: "KitchenLink Business",
    device: "Apple iPhone & iPad (iOS)",
    responsibilities: "Mobiles POS am Tisch, Bonierung, Split-Zahlungen, TSE-Absicherung (§ 146a AO) und Tap to Pay",
    status: "Native iOS",
    actionLink: "#business-app",
    actionText: "Details",
  },
  {
    actor: "Küche & Bar",
    roleDescription: "Köche, Küchenchef, Ausgabepass",
    platform: "KitchenLink Küchenmonitor (KDS)",
    device: "iPad (Montage am Pass, Farbschema Immer Tief)",
    responsibilities: "Stationsweise Bons, Zubereitungszeiten, Bon-Bumps mit automatischem Zutatenabzug aus dem Lagerledger",
    status: "Native iPadOS",
    actionLink: "#business-app",
    actionText: "Details",
  },
  {
    actor: "Betriebsleitung & Inhaber",
    roleDescription: "Gastronom, Buchhaltung, Steuerberater",
    platform: "Management & Kassenbuch",
    device: "iPhone App & Web-Verwaltung",
    responsibilities: "GoBD-Kassenbuch, Schicht- und Dienstplanung, DATEV EXTF 700 & DSFinV-K 2.3 Steuerprüfexporte",
    status: "iOS & Web",
    actionLink: "#business-app",
    actionText: "Details",
  },
];

export function PlatformCompatibilityMatrix() {
  return (
    <section className="kl-matrix-section">
      <div className="kl-matrix-container">
        <div className="kl-surface-meta">
          <span className="kl-surface-kicker">Architektur</span>
          <h2 className="kl-surface-heading">Plattform-Kompatibilitäts-Matrix</h2>
          <p className="kl-type-secondary">
            Gastronomie erfordert Rollentrennung: Gäste und Lieferanten verlangen
            sofortigen Zugriff im Web ohne App-Store-Download, während Kasse und
            Küchenpass auf die Zuverlässigkeit dedizierter Apple-Hardware setzen.
          </p>
        </div>

        <div className="kl-matrix-table-wrapper">
          <table className="kl-matrix-table">
            <thead>
              <tr>
                <th style={{ width: "22%" }}>Akteur & Rolle</th>
                <th style={{ width: "24%" }}>Plattform & Gerät</th>
                <th>Aufgaben im Betrieb</th>
                <th style={{ width: "16%", textAlign: "right" }}>Einstieg</th>
              </tr>
            </thead>
            <tbody>
              {matrixEntries.map((entry) => (
                <tr key={entry.actor}>
                  <td>
                    <strong>{entry.actor}</strong>
                    <div className="kl-type-meta kl-text-muted">
                      {entry.roleDescription}
                    </div>
                  </td>
                  <td>
                    <span className="kl-type-secondary">
                      <strong>{entry.platform}</strong>
                    </span>
                    <div className="kl-type-meta kl-text-muted">
                      {entry.device}
                    </div>
                  </td>
                  <td className="kl-type-secondary">
                    {entry.responsibilities}
                  </td>
                  <td style={{ textAlign: "right" }}>
                    {entry.actionLink && (
                      <Link href={entry.actionLink} className="kl-table-action-link">
                        {entry.actionText} →
                      </Link>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
