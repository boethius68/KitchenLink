"use client";

import React, { useMemo } from "react";
import { formatEuro } from "@/lib/cart";
import {
  getVenueTaxInfo,
  isDrinkItem,
  type GuestTablePaymentReceipt,
  type VatBreakdown,
} from "@/lib/table-check";

interface HospitalityReceiptModalProps {
  receipt: GuestTablePaymentReceipt | null;
  venueSlug: string;
  venueName: string;
  isOpen: boolean;
  onClose: () => void;
}

export function HospitalityReceiptModal({
  receipt,
  venueSlug,
  venueName,
  isOpen,
  onClose,
}: HospitalityReceiptModalProps) {
  const taxInfo = useMemo(
    () => getVenueTaxInfo(venueSlug || venueName),
    [venueSlug, venueName],
  );

  const vat = useMemo<VatBreakdown>(() => {
    if (!receipt) {
      return {
        rate7: { ratePercent: 7, netCents: 0, vatCents: 0, grossCents: 0 },
        rate19: { ratePercent: 19, netCents: 0, vatCents: 0, grossCents: 0 },
        totalNetCents: 0,
        totalVatCents: 0,
        totalGrossCents: 0,
        tipCents: 0,
        grandTotalCents: 0,
      };
    }
    if (receipt.vatBreakdown) {
      return receipt.vatBreakdown;
    }
    const r7Gross = Math.round(receipt.amountCents * 0.7);
    const r7Net = Math.round(r7Gross / 1.07);
    const r7Vat = r7Gross - r7Net;

    const r19Gross = Math.round(receipt.amountCents * 0.3);
    const r19Net = Math.round(r19Gross / 1.19);
    const r19Vat = r19Gross - r19Net;

    const totalNet = r7Net + r19Net;
    const totalVat = r7Vat + r19Vat;
    const totalGross = r7Gross + r19Gross;
    const tip = receipt.tipCents;

    return {
      rate7: { ratePercent: 7, netCents: r7Net, vatCents: r7Vat, grossCents: r7Gross },
      rate19: { ratePercent: 19, netCents: r19Net, vatCents: r19Vat, grossCents: r19Gross },
      totalNetCents: totalNet,
      totalVatCents: totalVat,
      totalGrossCents: totalGross,
      tipCents: tip,
      grandTotalCents: totalGross + tip,
    };
  }, [receipt]);

  if (!isOpen || !receipt) return null;

  const isBewirtung = Boolean(receipt.bewirtungsbeleg?.enabled);

  const handlePrint = () => {
    if (typeof window !== "undefined") {
      window.print();
    }
  };

  const formatDate = (isoStr?: string) => {
    if (!isoStr) {
      return new Date().toLocaleDateString("de-DE", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    }
    const d = new Date(isoStr);
    return isNaN(d.getTime())
      ? isoStr
      : d.toLocaleDateString("de-DE", {
          day: "2-digit",
          month: "2-digit",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        });
  };

  const items = receipt.paidItems && receipt.paidItems.length > 0
    ? receipt.paidItems
    : [
        {
          orderItemId: "paid-item-1",
          orderId: "ord-1",
          name: "Restaurantbewirtung Speisen & Getränke",
          quantity: 1,
          unitPriceCents: receipt.amountCents,
          lineTotalCents: receipt.amountCents,
          paid: true,
          paymentId: receipt.paymentId,
          source: "guest_qr" as const,
          vatRate: 19 as const,
        },
      ];

  const totalPayable = receipt.amountCents + receipt.tipCents;
  const receiptNumber = receipt.tseTransactionNumber
    ? `#${receipt.tseTransactionNumber.replace("TSE-TX-#", "RE-")}`
    : `#RE-${receipt.paymentId.slice(0, 10).toUpperCase()}`;

  return (
    <div
      className="fixed inset-0 z-50 bg-kl-dark/70 backdrop-blur-sm overflow-y-auto p-2 sm:p-6 flex items-start justify-center print:p-0 print:bg-white print:static"
      role="dialog"
      aria-modal="true"
      aria-labelledby="hospitality-receipt-title"
    >
      <div className="w-full max-w-2xl bg-kl-canvas rounded-2xl shadow-2xl border border-kl-border overflow-hidden print:border-none print:shadow-none print:rounded-none print:max-w-none print:w-full">
        {/* Kontroll-Leiste (beim Drucken ausgeblendet) */}
        <div className="no-print bg-kl-dark text-kl-canvas px-4 sm:px-6 py-3.5 flex items-center justify-between border-b border-neutral-800">
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-kl-emerald" aria-hidden="true" />
            <span className="font-mono text-xs text-kl-emerald font-semibold uppercase tracking-wider">
              {isBewirtung ? "Bewirtungsbeleg § 4 EStG" : "Kassenbeleg KassenSichV"}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handlePrint}
              className="bg-kl-terracotta hover:opacity-95 text-white font-sans text-xs sm:text-sm font-medium px-4 py-2 rounded-lg flex items-center gap-1.5 shadow-sm transition-opacity"
            >
              <span>Drucken / PDF</span>
              <span aria-hidden="true">🖨️</span>
            </button>
            <button
              type="button"
              onClick={onClose}
              className="bg-neutral-800 hover:bg-neutral-700 text-kl-canvas text-xs sm:text-sm font-sans px-3.5 py-2 rounded-lg transition-colors"
              aria-label="Schließen"
            >
              Schließen
            </button>
          </div>
        </div>

        {/* Druckdokument: Echtes Papier-Layout */}
        <div className="p-6 sm:p-10 bg-white text-kl-charcoal kl-receipt-printable">
          {/* Kopfzeile: Gastronomiebetrieb */}
          <header className="border-b-2 border-kl-charcoal pb-4 mb-6">
            <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-3">
              <div>
                <h1
                  id="hospitality-receipt-title"
                  className="font-serif text-2xl sm:text-3xl font-bold tracking-tight text-kl-charcoal"
                >
                  {taxInfo.name}
                </h1>
                <p className="font-sans text-xs text-neutral-600 mt-0.5">
                  {taxInfo.legalName}
                </p>
                <p className="font-sans text-xs text-neutral-600">
                  {taxInfo.address} · {taxInfo.postalCity}
                </p>
                <p className="font-mono text-[11px] text-neutral-500 mt-1">
                  USt-IdNr.: {taxInfo.vatId} · St.-Nr.: {taxInfo.taxNumber}
                </p>
              </div>

              <div className="sm:text-right">
                <span className="inline-block bg-kl-subtle text-kl-charcoal font-mono text-[11px] font-semibold px-2 py-1 rounded border border-kl-border">
                  {isBewirtung ? "BEWIRTUNGSBELEG" : "KASSENBELEG"}
                </span>
                <p className="font-mono tabular-nums text-xs font-bold mt-1 text-kl-charcoal">
                  {receiptNumber}
                </p>
                <p className="font-mono tabular-nums text-xs text-neutral-600">
                  {formatDate(receipt.issuedAt)}
                </p>
                <p className="font-mono text-xs text-neutral-600">
                  Tisch: {receipt.tableLabel || "3"} {receipt.tableArea ? `(${receipt.tableArea})` : ""}
                </p>
              </div>
            </div>
          </header>

          {/* Positionstabelle */}
          <section className="mb-6" aria-label="Rechnungspositionen">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-neutral-300 font-mono text-xs uppercase text-neutral-600">
                  <th className="py-2 font-semibold">Pos. / Artikel</th>
                  <th className="py-2 text-center font-semibold">Menge</th>
                  <th className="py-2 text-right font-semibold">Einzelpreis</th>
                  <th className="py-2 text-center font-semibold">MwSt.</th>
                  <th className="py-2 text-right font-semibold">Gesamt</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-200 font-sans text-sm">
                {items.map((item, idx) => {
                  const vatCode = item.vatRate === 19 || isDrinkItem(item.name, item.kind) ? "B" : "A";
                  return (
                    <tr key={item.orderItemId || idx}>
                      <td className="py-2.5 font-medium text-kl-charcoal">
                        {item.name}
                      </td>
                      <td className="py-2.5 text-center font-mono tabular-nums text-neutral-700">
                        {item.quantity}×
                      </td>
                      <td className="py-2.5 text-right font-mono tabular-nums text-neutral-700">
                        {formatEuro(item.unitPriceCents)}
                      </td>
                      <td className="py-2.5 text-center font-mono text-xs text-neutral-500">
                        {vatCode}
                      </td>
                      <td className="py-2.5 text-right font-mono tabular-nums font-semibold text-kl-charcoal">
                        {formatEuro(item.lineTotalCents)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </section>

          {/* MwSt.-Aufschlüsselung & Summen */}
          <section className="border-t-2 border-neutral-300 pt-4 mb-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-start">
              {/* Steueraufschlüsselung (Tabelle) */}
              <div>
                <h3 className="font-mono text-xs uppercase font-bold text-neutral-700 tracking-wider mb-2">
                  Mehrwertsteuer-Aufschlüsselung
                </h3>
                <table className="w-full text-xs font-mono tabular-nums border-collapse">
                  <thead>
                    <tr className="border-b border-neutral-200 text-neutral-500">
                      <th className="text-left py-1">Satz</th>
                      <th className="text-right py-1">Netto</th>
                      <th className="text-right py-1">MwSt.</th>
                      <th className="text-right py-1">Brutto</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-100">
                    {vat.rate7.grossCents > 0 && (
                      <tr>
                        <td className="py-1">A: 7,0 % (Speisen)</td>
                        <td className="text-right py-1">{formatEuro(vat.rate7.netCents)}</td>
                        <td className="text-right py-1">{formatEuro(vat.rate7.vatCents)}</td>
                        <td className="text-right py-1">{formatEuro(vat.rate7.grossCents)}</td>
                      </tr>
                    )}
                    {vat.rate19.grossCents > 0 && (
                      <tr>
                        <td className="py-1">B: 19,0 % (Getränke)</td>
                        <td className="text-right py-1">{formatEuro(vat.rate19.netCents)}</td>
                        <td className="text-right py-1">{formatEuro(vat.rate19.vatCents)}</td>
                        <td className="text-right py-1">{formatEuro(vat.rate19.grossCents)}</td>
                      </tr>
                    )}
                    <tr className="border-t border-neutral-300 font-bold">
                      <td className="py-1">Summe</td>
                      <td className="text-right py-1">{formatEuro(vat.totalNetCents)}</td>
                      <td className="text-right py-1">{formatEuro(vat.totalVatCents)}</td>
                      <td className="text-right py-1">{formatEuro(vat.totalGrossCents)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              {/* Endbetrag & Trinkgeld */}
              <div className="bg-neutral-50 p-3.5 rounded-xl border border-neutral-200 text-right space-y-1.5 font-sans">
                <div className="flex justify-between text-sm">
                  <span className="text-neutral-600">Rechnungsbetrag (Brutto):</span>
                  <span className="font-mono tabular-nums font-medium">{formatEuro(receipt.amountCents)}</span>
                </div>
                {receipt.tipCents > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-neutral-600">Trinkgeld (§ 3 Nr. 51 EStG steuerfrei):</span>
                    <span className="font-mono tabular-nums font-medium text-kl-terracotta">
                      +{formatEuro(receipt.tipCents)}
                    </span>
                  </div>
                )}
                <div className="flex justify-between text-base font-bold border-t border-neutral-300 pt-2 text-kl-charcoal">
                  <span>Gesamtzahlbetrag:</span>
                  <span className="font-mono tabular-nums text-lg text-kl-charcoal">
                    {formatEuro(totalPayable)}
                  </span>
                </div>
                <p className="text-[11px] text-neutral-500 font-mono mt-1">
                  Zahlungsart: {receipt.method === "online" ? "Elektronische Zahlung / Tap to Pay" : receipt.method} · Sandbox
                </p>
              </div>
            </div>
          </section>

          {/* Gesetzlicher Bewirtungsbeleg-Abschnitt (§ 4 Abs. 5 Nr. 2 EStG) */}
          <section className="border-2 border-dashed border-neutral-300 rounded-xl p-4 sm:p-5 mb-6 bg-neutral-50/50">
            <div className="flex items-center justify-between mb-3 border-b border-neutral-200 pb-2">
              <h3 className="font-serif text-base font-bold text-kl-charcoal">
                Angaben zur geschäftlichen Bewirtung (§ 4 Abs. 5 Nr. 2 EStG)
              </h3>
              <span className="font-mono text-[10px] uppercase tracking-wider text-neutral-500 font-semibold">
                Steuerlicher Nachweis
              </span>
            </div>

            <div className="space-y-3 font-sans text-xs sm:text-sm">
              <div>
                <span className="font-semibold text-neutral-700 block">
                  1. Bewirtende Person / Firma (Gastgeber):
                </span>
                <p className="mt-0.5 text-neutral-900 border-b border-neutral-400 pb-1 font-mono">
                  {receipt.bewirtungsbeleg?.hostName || "________________________________________________________"}
                </p>
              </div>

              <div>
                <span className="font-semibold text-neutral-700 block">
                  2. Bewirtete Personen (Teilnehmer):
                </span>
                <p className="mt-0.5 text-neutral-900 border-b border-neutral-400 pb-1 font-mono">
                  {receipt.bewirtungsbeleg?.guests || "________________________________________________________"}
                </p>
              </div>

              <div>
                <span className="font-semibold text-neutral-700 block">
                  3. Konkreter Anlass der Bewirtung:
                </span>
                <p className="mt-0.5 text-neutral-900 border-b border-neutral-400 pb-1 font-mono">
                  {receipt.bewirtungsbeleg?.purpose || "________________________________________________________"}
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
                <div>
                  <span className="font-semibold text-neutral-700 block">
                    4. Aufwendungen lt. Beleg:
                  </span>
                  <p className="mt-0.5 font-mono tabular-nums font-semibold text-kl-charcoal">
                    {formatEuro(totalPayable)}
                    {receipt.tipCents > 0 ? ` (inkl. ${formatEuro(receipt.tipCents)} Trinkgeld)` : ""}
                  </p>
                </div>
                <div>
                  <span className="font-semibold text-neutral-700 block">
                    5. Ort, Datum & Unterschrift des Gastgebers:
                  </span>
                  <p className="mt-3 border-b border-neutral-400 text-neutral-500 text-[11px] pb-1">
                    Ort, Datum / Eigenhändige Unterschrift
                  </p>
                </div>
              </div>
            </div>
          </section>

          {/* KassenSichV TSE-Sicherheitsblock (§ 6 KassenSichV) */}
          <footer className="border-t border-neutral-200 pt-4 text-neutral-600 font-mono text-[11px] leading-relaxed">
            <div className="flex items-center gap-2 mb-2 font-semibold text-neutral-800 text-xs">
              <span className="text-kl-sage" aria-hidden="true">🔒</span>
              <span>KASSENSICHV-TSE-SICHERHEITSPROTOKOLL (§ 6 KassenSichV / DSFinV-K V2.3)</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-1">
              <div>
                <span className="text-neutral-500">TSE-Seriennummer: </span>
                <span className="text-neutral-900">{receipt.tseSerialNumber || "TSE-KL-DEMO-001"}</span>
              </div>
              <div>
                <span className="text-neutral-500">Transaktionsnummer: </span>
                <span className="text-neutral-900">{receipt.tseTransactionNumber || "TSE-TX-#849201"}</span>
              </div>
              <div>
                <span className="text-neutral-500">Signaturzähler: </span>
                <span className="text-neutral-900">#{receipt.tseSignatureCounter || 14892}</span>
              </div>
              <div>
                <span className="text-neutral-500">Algorithmus: </span>
                <span className="text-neutral-900">ECDSA-SHA256 (BSI TR-03153)</span>
              </div>
              <div>
                <span className="text-neutral-500">Start: </span>
                <span className="text-neutral-900">{formatDate(receipt.tseStartedAt)}</span>
              </div>
              <div>
                <span className="text-neutral-500">Ende: </span>
                <span className="text-neutral-900">{formatDate(receipt.tseFinishedAt)}</span>
              </div>
            </div>

            <div className="mt-2.5 bg-neutral-50 p-2.5 rounded border border-neutral-200">
              <span className="text-neutral-500 block text-[10px] uppercase font-bold mb-0.5">
                Kryptografischer Signaturprüfwert:
              </span>
              <p className="break-all font-mono text-[10px] text-neutral-800 select-all">
                {receipt.tseSignature}
              </p>
            </div>

            {receipt.tseQrData && (
              <div className="mt-2 text-[10px] text-neutral-500 break-all">
                <span>DSFinV-K QR: </span>
                <span>{receipt.tseQrData}</span>
              </div>
            )}

            <p className="text-center text-xs text-neutral-500 mt-4 font-serif italic">
              Vielen Dank für Ihren Besuch im {taxInfo.name}!
            </p>
          </footer>
        </div>
      </div>
    </div>
  );
}