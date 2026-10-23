"use client";

import React from "react";
import { type DeliverySlipData, formatCents } from "@/lib/vendor-data";

interface Props {
  slip: DeliverySlipData | null;
  onClose: () => void;
}

export function VendorDeliverySlipModal({ slip, onClose }: Props) {
  if (!slip) return null;

  const handlePrint = () => {
    if (typeof window !== "undefined") {
      window.print();
    }
  };

  return (
    <div
      className="kl-modal-backdrop"
      role="dialog"
      aria-modal="true"
      aria-labelledby="kl-slip-title"
    >
      <div className="kl-slip-container">
        {/* Kontrollleiste (beim Drucken ausgeblendet) */}
        <div className="kl-slip-actions-bar no-print">
          <div className="kl-slip-actions-left">
            <span className="kl-type-meta">Digitaler Lieferschein (PDF/Druck)</span>
          </div>
          <div className="kl-slip-actions-right">
            <button
              type="button"
              className="kl-btn-primary"
              onClick={handlePrint}
            >
              Lieferschein drucken
            </button>
            <button
              type="button"
              className="kl-btn-secondary"
              onClick={onClose}
              aria-label="Schließen"
            >
              Schließen
            </button>
          </div>
        </div>

        {/* Druckdokument */}
        <div className="kl-slip-document">
          <header className="kl-slip-header">
            <div>
              <h2 id="kl-slip-title" className="kl-type-display">
                LIEFERSCHEIN
              </h2>
              <div className="kl-type-meta kl-slip-muted">
                Beleg-Nr.: {slip.slipNumber} · Datum: {slip.slipDate}
              </div>
            </div>
            <div className="kl-slip-barcode-area">
              <div className="kl-slip-barcode" aria-hidden="true">
                ||| | |||| | ||| |||| | || |||
              </div>
              <div className="kl-type-meta">{slip.orderNumber}</div>
            </div>
          </header>

          <div className="kl-slip-addresses-grid">
            <div className="kl-slip-address-box">
              <span className="kl-type-meta kl-slip-muted">Lieferant / Absender:</span>
              <p className="kl-type-primary">
                <strong>{slip.supplierName}</strong>
                <br />
                {slip.supplierAddress}
                <br />
                Kontakt: {slip.supplierContact}
              </p>
            </div>
            <div className="kl-slip-address-box">
              <span className="kl-type-meta kl-slip-muted">Empfänger / Restaurant:</span>
              <p className="kl-type-primary">
                <strong>{slip.venueName}</strong>
                <br />
                {slip.venueAddress}
              </p>
            </div>
          </div>

          <div className="kl-slip-meta-strip">
            <div>
              <span className="kl-type-meta kl-slip-muted">Bestellreferenz:</span>{" "}
              <strong>{slip.orderNumber}</strong>
            </div>
            <div>
              <span className="kl-type-meta kl-slip-muted">Liefertermin:</span>{" "}
              <strong>{slip.expectedDeliveryDate}</strong>
            </div>
          </div>

          {slip.notes && (
            <div className="kl-slip-notes">
              <span className="kl-type-meta">Anlieferhinweis:</span> {slip.notes}
            </div>
          )}

          <table className="kl-slip-table">
            <thead>
              <tr>
                <th style={{ width: "8%" }}>Pos.</th>
                <th>Bezeichnung / Artikel</th>
                <th style={{ width: "16%", textAlign: "right" }}>Menge</th>
                <th style={{ width: "18%", textAlign: "right" }}>Einzelpreis</th>
                <th style={{ width: "18%", textAlign: "right" }}>Gesamt</th>
              </tr>
            </thead>
            <tbody>
              {slip.lines.map((line) => (
                <tr key={line.position}>
                  <td className="kl-tabular">{line.position}</td>
                  <td>
                    <strong>{line.name}</strong>
                  </td>
                  <td className="kl-tabular" style={{ textAlign: "right" }}>
                    {line.quantity} {line.unit}
                  </td>
                  <td className="kl-tabular" style={{ textAlign: "right" }}>
                    {formatCents(line.pricePerUnitCents)}
                  </td>
                  <td className="kl-tabular" style={{ textAlign: "right" }}>
                    <strong>{formatCents(line.totalCents)}</strong>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ textAlign: "right" }}>
                  <strong>Gesamtbetrag (Netto B2B):</strong>
                </td>
                <td className="kl-tabular" style={{ textAlign: "right" }}>
                  <strong className="kl-type-section">
                    {formatCents(slip.totalCents)}
                  </strong>
                </td>
              </tr>
            </tfoot>
          </table>

          <div className="kl-slip-signatures">
            <div className="kl-slip-signature-box">
              <div className="kl-slip-sign-line" />
              <div className="kl-type-meta">Unterschrift Fahrer / Logistik</div>
            </div>
            <div className="kl-slip-signature-box">
              <div className="kl-slip-sign-line" />
              <div className="kl-type-meta">
                Wareneingang geprüft & übernommen (Restaurant)
              </div>
            </div>
          </div>

          <footer className="kl-slip-footer">
            <p className="kl-type-meta">
              Erstellt über KitchenLink B2B-Plattform · Automatische Verbuchung im
              Warenwirtschaftsledger des Restaurants (KL-PURCHASE-001).
            </p>
          </footer>
        </div>
      </div>
    </div>
  );
}
