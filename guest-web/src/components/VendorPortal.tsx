"use client";

import React, { useState, useMemo } from "react";
import Link from "next/link";
import {
  type VendorPurchaseOrder,
  type DeliverySlipData,
  sandboxSuppliers,
  getVendorPurchaseOrders,
  confirmPurchaseOrder,
  markPurchaseOrderInTransit,
  markPurchaseOrderDelivered,
  generateDeliverySlip,
  formatCents,
  getStatusBadgeInfo,
  resetVendorOrdersDemo,
} from "@/lib/vendor-data";
import { VendorDeliverySlipModal } from "./VendorDeliverySlipModal";
import { ThemeToggle } from "./ThemeToggle";

export function VendorPortal() {
  const [selectedSupplierId, setSelectedSupplierId] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [orderVersion, setOrderVersion] = useState<number>(0);
  const [activeSlip, setActiveSlip] = useState<DeliverySlipData | null>(null);
  const [confirmingOrderId, setConfirmingOrderId] = useState<string | null>(null);
  const [customDeliveryDate, setCustomDeliveryDate] = useState<string>("");
  const [supplierNote, setSupplierNote] = useState<string>("");
  const [expandedOrders, setExpandedOrders] = useState<Record<string, boolean>>({
    "po-081": true,
  });

  // Partner-Anfrage State
  const [partnerSubmitted, setPartnerSubmitted] = useState<boolean>(false);
  const [partnerForm, setPartnerForm] = useState({
    companyName: "",
    contactName: "",
    email: "",
    category: "Frische & Molkerei",
    city: "",
  });

  const orders: VendorPurchaseOrder[] = useMemo(
    () =>
      getVendorPurchaseOrders(
        selectedSupplierId === "all" ? undefined : selectedSupplierId,
      ),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [selectedSupplierId, orderVersion],
  );

  const reloadOrders = () => {
    setOrderVersion((v) => v + 1);
  };

  const filteredOrders = orders.filter((po) => {
    if (statusFilter === "all") return true;
    if (statusFilter === "open") return po.status === "sent";
    if (statusFilter === "active")
      return po.status === "confirmed" || po.status === "in_transit";
    if (statusFilter === "completed") return po.status === "received";
    return true;
  });

  const handleToggleExpand = (orderId: string) => {
    setExpandedOrders((prev) => ({
      ...prev,
      [orderId]: !prev[orderId],
    }));
  };

  const handleStartConfirm = (po: VendorPurchaseOrder) => {
    setConfirmingOrderId(po.id);
    setCustomDeliveryDate(po.expectedDeliveryDate);
    setSupplierNote("");
  };

  const handleExecuteConfirm = (orderId: string) => {
    confirmPurchaseOrder(orderId, customDeliveryDate, supplierNote);
    setConfirmingOrderId(null);
    reloadOrders();
  };

  const handleTransit = (orderId: string) => {
    markPurchaseOrderInTransit(orderId);
    reloadOrders();
  };

  const handleDelivered = (orderId: string) => {
    markPurchaseOrderDelivered(orderId);
    reloadOrders();
  };

  const handleResetDemo = () => {
    resetVendorOrdersDemo();
    reloadOrders();
  };

  const handleViewSlip = (orderId: string) => {
    const slip = generateDeliverySlip(orderId);
    if (slip) {
      setActiveSlip(slip);
    }
  };

  const handlePartnerSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (partnerForm.companyName && partnerForm.email) {
      setPartnerSubmitted(true);
    }
  };

  // KPIs berechnen
  const openCount = orders.filter((o) => o.status === "sent").length;
  const inProgressCount = orders.filter(
    (o) => o.status === "confirmed" || o.status === "in_transit",
  ).length;
  const completedCount = orders.filter((o) => o.status === "received").length;
  const totalVolumeCents = orders
    .filter((o) => o.status !== "cancelled")
    .reduce((sum, o) => sum + o.totalCents, 0);

  return (
    <div className="kl-vendor-page">
      {/* Kopfbereich */}
      <header className="kl-vendor-navbar">
        <div className="kl-vendor-nav-inner">
          <div className="kl-vendor-nav-brand">
            <Link href="/" className="kl-vendor-brand-link">
              <span className="kl-vendor-brand-icon">KL</span>
              <span className="kl-vendor-brand-name">KitchenLink</span>
            </Link>
            <span className="kl-vendor-brand-badge">B2B Lieferanten-Portal</span>
          </div>

          <div className="kl-vendor-nav-actions">
            <Link href="/" className="kl-btn-subtle">
              ← Zur Startseite
            </Link>
            <Link href="/alte-muehle/menu" className="kl-btn-subtle">
              Gast-Speisekarte
            </Link>
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main className="kl-vendor-main">
        {/* Hero & Rolle des Lieferantenportals */}
        <section className="kl-vendor-hero">
          <div className="kl-vendor-hero-content">
            <div className="kl-hero-badge">
              Plattform-Gegenstück zur iOS-App · Blueprint §11
            </div>
            <h1 className="kl-type-display kl-vendor-title">
              Lieferanten & Beschaffungsportal
            </h1>
            <p className="kl-vendor-lead">
              Willkommen im KitchenLink Lieferanten-Gegenstück. Als Großhändler,
              Erzeuger oder Getränkelieferant verwalten Sie hier eingehende
              Bestellungen aus der Restaurant-Warenwirtschaft, bestätigen
              Liefertermine und drucken standardisierte digitale Lieferscheine
              – geräteunabhängig im Web.
            </p>
          </div>

          {/* KPI Dashboard */}
          <div className="kl-vendor-kpi-grid">
            <div className="kl-vendor-kpi-card">
              <div className="kl-type-meta kl-slip-muted">Offene Bestellungen</div>
              <div className="kl-vendor-kpi-number kl-tabular">{openCount}</div>
              <div className="kl-type-meta">Warten auf Terminbestätigung</div>
            </div>
            <div className="kl-vendor-kpi-card">
              <div className="kl-type-meta kl-slip-muted">In Kommission / Zustellung</div>
              <div className="kl-vendor-kpi-number kl-tabular">{inProgressCount}</div>
              <div className="kl-type-meta">Avisierte Lieferungen</div>
            </div>
            <div className="kl-vendor-kpi-card">
              <div className="kl-type-meta kl-slip-muted">Abgeschlossen</div>
              <div className="kl-vendor-kpi-number kl-tabular">{completedCount}</div>
              <div className="kl-type-meta">Wareneingang im Restaurant gebucht</div>
            </div>
            <div className="kl-vendor-kpi-card kl-vendor-kpi-card-highlight">
              <div className="kl-type-meta">Gesamtwert der Aufträge</div>
              <div className="kl-vendor-kpi-number kl-tabular">
                {formatCents(totalVolumeCents)}
              </div>
              <div className="kl-type-meta">Netto B2B-Umsatzvolumen</div>
            </div>
          </div>
        </section>

        {/* Lieferanten-Filter & Ansichten */}
        <section className="kl-vendor-controls-section">
          <div className="kl-vendor-filter-group">
            <label htmlFor="supplier-select" className="kl-type-meta">
              Ansicht als Lieferant:
            </label>
            <div className="kl-chips-grid" id="supplier-select">
              <button
                type="button"
                className={`kl-chip ${selectedSupplierId === "all" ? "kl-chip-selected" : ""}`}
                onClick={() => setSelectedSupplierId("all")}
              >
                Alle Partner ({orders.length})
              </button>
              {sandboxSuppliers.map((supplier) => (
                <button
                  key={supplier.id}
                  type="button"
                  className={`kl-chip ${selectedSupplierId === supplier.id ? "kl-chip-selected" : ""}`}
                  onClick={() => setSelectedSupplierId(supplier.id)}
                >
                  {supplier.name}
                </button>
              ))}
            </div>
          </div>

          <div className="kl-vendor-filter-group">
            <label htmlFor="status-filter" className="kl-type-meta">
              Status-Filter:
            </label>
            <div className="kl-chips-grid" id="status-filter">
              <button
                type="button"
                className={`kl-chip ${statusFilter === "all" ? "kl-chip-selected" : ""}`}
                onClick={() => setStatusFilter("all")}
              >
                Alle Status
              </button>
              <button
                type="button"
                className={`kl-chip ${statusFilter === "open" ? "kl-chip-selected" : ""}`}
                onClick={() => setStatusFilter("open")}
              >
                Neu / Offen ({openCount})
              </button>
              <button
                type="button"
                className={`kl-chip ${statusFilter === "active" ? "kl-chip-selected" : ""}`}
                onClick={() => setStatusFilter("active")}
              >
                Aktiv ({inProgressCount})
              </button>
              <button
                type="button"
                className={`kl-chip ${statusFilter === "completed" ? "kl-chip-selected" : ""}`}
                onClick={() => setStatusFilter("completed")}
              >
                Erledigt ({completedCount})
              </button>
            </div>
          </div>

          <div className="kl-vendor-reset-bar">
            <span className="kl-type-meta kl-slip-muted">
              Demo-Sandbox: Änderungen werden im Browser gespeichert.
            </span>
            <button
              type="button"
              className="kl-btn-subtle"
              onClick={handleResetDemo}
              title="Setzt die Demo-Bestellungen auf den Ursprungszustand zurück"
            >
              Demo-Daten zurücksetzen
            </button>
          </div>
        </section>

        {/* Bestellungsliste */}
        <section className="kl-vendor-orders-section">
          <div className="kl-vendor-section-header">
            <h2 className="kl-type-section">
              Eingehende Lieferanten-Bestellungen ({filteredOrders.length})
            </h2>
            <span className="kl-type-meta kl-slip-muted">
              Synchronisiert mit der iOS-Warenwirtschaft (KL-PURCHASE-001)
            </span>
          </div>

          {filteredOrders.length === 0 ? (
            <div className="kl-empty-card">
              <p className="kl-type-primary">
                Keine Bestellungen für diese Auswahl gefunden.
              </p>
              <button
                type="button"
                className="kl-btn-subtle"
                onClick={() => {
                  setSelectedSupplierId("all");
                  setStatusFilter("all");
                }}
              >
                Filter zurücksetzen
              </button>
            </div>
          ) : (
            <div className="kl-vendor-orders-list">
              {filteredOrders.map((po) => {
                const badge = getStatusBadgeInfo(po.status);
                const isExpanded = !!expandedOrders[po.id];
                const isConfirming = confirmingOrderId === po.id;

                return (
                  <article key={po.id} className="kl-vendor-order-card">
                    {/* Header der Karte */}
                    <div className="kl-order-card-header">
                      <div className="kl-order-card-title-area">
                        <div className="kl-order-number-row">
                          <span className="kl-order-number">{po.orderNumber}</span>
                          <span className={`kl-vendor-status-badge ${badge.cssModifier}`}>
                            {badge.label}
                          </span>
                        </div>
                        <h3 className="kl-type-primary kl-order-venue-name">
                          {po.venueName}
                        </h3>
                        <p className="kl-type-meta kl-slip-muted">
                          Lieferant: <strong>{po.supplierName}</strong> ({po.supplierContact})
                        </p>
                      </div>

                      <div className="kl-order-card-summary-area">
                        <div className="kl-order-total-sum">
                          <span className="kl-type-meta">Bestellsumme</span>
                          <span className="kl-type-section kl-tabular">
                            {formatCents(po.totalCents)}
                          </span>
                        </div>
                        <div className="kl-order-dates-summary">
                          <span className="kl-type-meta">
                            Gewünschter Termin:{" "}
                            <strong>
                              {new Date(po.expectedDeliveryDate).toLocaleDateString("de-DE")}
                            </strong>
                          </span>
                          {po.confirmedDeliveryDate && (
                            <span className="kl-type-meta kl-urgency-fresh-text">
                              Bestätigter Termin:{" "}
                              <strong>
                                {new Date(po.confirmedDeliveryDate).toLocaleDateString("de-DE")}
                              </strong>
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Notiz / Anfahrtshinweis */}
                    {po.notes && (
                      <div className="kl-order-notes-strip">
                        <span className="kl-type-meta">Hinweis des Küchenchefs:</span>
                        <p className="kl-type-secondary">{po.notes}</p>
                      </div>
                    )}

                    {/* Ausklappbare Artikelübersicht */}
                    <div className="kl-order-expand-strip">
                      <button
                        type="button"
                        className="kl-btn-subtle"
                        onClick={() => handleToggleExpand(po.id)}
                        aria-expanded={isExpanded}
                      >
                        {isExpanded
                          ? `▲ Artikel ausblenden (${po.lines.length} Positionen)`
                          : `▼ ${po.lines.length} Positionen einsehen`}
                      </button>
                    </div>

                    {isExpanded && (
                      <div className="kl-order-lines-container">
                        <table className="kl-order-lines-table">
                          <thead>
                            <tr>
                              <th>Artikelbezeichnung</th>
                              <th style={{ textAlign: "right" }}>Bestellmenge</th>
                              <th style={{ textAlign: "right" }}>Einzelpreis</th>
                              <th style={{ textAlign: "right" }}>Gesamtbetrag</th>
                            </tr>
                          </thead>
                          <tbody>
                            {po.lines.map((line) => (
                              <tr key={line.id}>
                                <td>
                                  <strong>{line.ingredientName}</strong>
                                </td>
                                <td className="kl-tabular" style={{ textAlign: "right" }}>
                                  {line.quantity} {line.unit}
                                </td>
                                <td className="kl-tabular" style={{ textAlign: "right" }}>
                                  {formatCents(line.pricePerUnitCents)}
                                </td>
                                <td className="kl-tabular" style={{ textAlign: "right" }}>
                                  <strong>{formatCents(line.lineTotalCents)}</strong>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}

                    {/* Inline-Bestätigungsdialog */}
                    {isConfirming && (
                      <div className="kl-order-confirm-box">
                        <h4 className="kl-type-primary">
                          Lieferung bestätigen & disponieren
                        </h4>
                        <div className="kl-confirm-fields-grid">
                          <div>
                            <label
                              htmlFor={`date-${po.id}`}
                              className="kl-type-meta"
                            >
                              Avisierter Liefertermin:
                            </label>
                            <input
                              id={`date-${po.id}`}
                              type="date"
                              className="kl-text-input"
                              value={customDeliveryDate}
                              onChange={(e) => setCustomDeliveryDate(e.target.value)}
                            />
                          </div>
                          <div>
                            <label
                              htmlFor={`note-${po.id}`}
                              className="kl-type-meta"
                            >
                              Nachricht an Restaurant (optional):
                            </label>
                            <input
                              id={`note-${po.id}`}
                              type="text"
                              className="kl-text-input"
                              placeholder="z.B. Lieferung erfolgt vor 09:30 Uhr"
                              value={supplierNote}
                              onChange={(e) => setSupplierNote(e.target.value)}
                            />
                          </div>
                        </div>

                        <div className="kl-confirm-actions">
                          <button
                            type="button"
                            className="kl-btn-primary"
                            onClick={() => handleExecuteConfirm(po.id)}
                          >
                            Lieferung jetzt verbindlich bestätigen
                          </button>
                          <button
                            type="button"
                            className="kl-btn-secondary"
                            onClick={() => setConfirmingOrderId(null)}
                          >
                            Abbrechen
                          </button>
                        </div>
                      </div>
                    )}

                    {/* Aktionsleiste */}
                    <div className="kl-order-card-actions">
                      <div className="kl-order-actions-left">
                        <button
                          type="button"
                          className="kl-btn-secondary"
                          onClick={() => handleViewSlip(po.id)}
                        >
                          Lieferschein einsehen / drucken
                        </button>
                      </div>

                      <div className="kl-order-actions-right">
                        {po.status === "sent" && !isConfirming && (
                          <button
                            type="button"
                            className="kl-btn-primary"
                            onClick={() => handleStartConfirm(po)}
                          >
                            Bestellung annehmen & bestätigen
                          </button>
                        )}

                        {po.status === "confirmed" && (
                          <button
                            type="button"
                            className="kl-btn-primary"
                            onClick={() => handleTransit(po.id)}
                          >
                            Fahrzeug beladen / In Zustellung
                          </button>
                        )}

                        {po.status === "in_transit" && (
                          <button
                            type="button"
                            className="kl-btn-primary"
                            onClick={() => handleDelivered(po.id)}
                          >
                            Als geliefert melden (Wareneingang)
                          </button>
                        )}

                        {po.status === "received" && (
                          <span className="kl-type-meta kl-urgency-fresh-text">
                            ✓ Ware im Restaurant übernommen
                          </span>
                        )}
                      </div>
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </section>

        {/* B2B Onboarding für neue Lieferanten */}
        <section className="kl-vendor-onboarding-section">
          <div className="kl-onboarding-card">
            <div className="kl-onboarding-header">
              <span className="kl-hero-badge">Für Großhändler & Erzeuger</span>
              <h2 className="kl-type-section">
                Werden Sie Partner im KitchenLink Beschaffungs-Netzwerk
              </h2>
              <p className="kl-type-secondary">
                Beliefern Sie Restaurants, Bars oder Cafés? Sparen Sie sich
                unleserliche Faxe, verpasste Anrufe und manuelle Tipparbeit. Mit
                KitchenLink empfangen Sie standardisierte B2B-Bestellungen direkt
                in Ihren Web-Browser.
              </p>
            </div>

            {partnerSubmitted ? (
              <div className="kl-partner-success-box" role="status">
                <h3 className="kl-type-primary">Vielen Dank für Ihre Anfrage!</h3>
                <p className="kl-type-secondary">
                  Wir haben Ihre Registrierung für <strong>{partnerForm.companyName}</strong>{" "}
                  erfasst. Ein Ansprechpartner des KitchenLink Netzwerks meldet
                  sich zur Verknüpfung mit Gastronomiebetrieben in Ihrer Region.
                </p>
                <button
                  type="button"
                  className="kl-btn-subtle"
                  onClick={() => setPartnerSubmitted(false)}
                >
                  Weitere Anfrage stellen
                </button>
              </div>
            ) : (
              <form onSubmit={handlePartnerSubmit} className="kl-partner-form">
                <div className="kl-form-grid-2">
                  <div>
                    <label htmlFor="company" className="kl-type-meta">
                      Unternehmensname / Großhandel:
                    </label>
                    <input
                      id="company"
                      type="text"
                      className="kl-text-input"
                      required
                      placeholder="z.B. Alpenfrische Großmarkt GmbH"
                      value={partnerForm.companyName}
                      onChange={(e) =>
                        setPartnerForm({ ...partnerForm, companyName: e.target.value })
                      }
                    />
                  </div>
                  <div>
                    <label htmlFor="contact" className="kl-type-meta">
                      Ansprechpartner:
                    </label>
                    <input
                      id="contact"
                      type="text"
                      className="kl-text-input"
                      placeholder="Vorname Nachname"
                      value={partnerForm.contactName}
                      onChange={(e) =>
                        setPartnerForm({ ...partnerForm, contactName: e.target.value })
                      }
                    />
                  </div>
                </div>

                <div className="kl-form-grid-3">
                  <div>
                    <label htmlFor="email" className="kl-type-meta">
                      E-Mail-Adresse:
                    </label>
                    <input
                      id="email"
                      type="email"
                      className="kl-text-input"
                      required
                      placeholder="dispo@ihr-grosshandel.de"
                      value={partnerForm.email}
                      onChange={(e) =>
                        setPartnerForm({ ...partnerForm, email: e.target.value })
                      }
                    />
                  </div>
                  <div>
                    <label htmlFor="category" className="kl-type-meta">
                      Sortiment / Warengruppe:
                    </label>
                    <select
                      id="category"
                      className="kl-select"
                      value={partnerForm.category}
                      onChange={(e) =>
                        setPartnerForm({ ...partnerForm, category: e.target.value })
                      }
                    >
                      <option value="Frische & Molkerei">Frische & Molkerei</option>
                      <option value="Obst & Gemüse">Obst & Gemüse</option>
                      <option value="Fleisch & Geflügel">Fleisch & Geflügel</option>
                      <option value="Fisch & Meeresfrüchte">Fisch & Meeresfrüchte</option>
                      <option value="Getränke & Wein">Getränke & Wein</option>
                      <option value="Trockensortiment & Gewürze">
                        Trockensortiment & Gewürze
                      </option>
                      <option value="Backwaren">Backwaren</option>
                    </select>
                  </div>
                  <div>
                    <label htmlFor="city" className="kl-type-meta">
                      Standort / Liefergebiet:
                    </label>
                    <input
                      id="city"
                      type="text"
                      className="kl-text-input"
                      placeholder="z.B. Großraum München"
                      value={partnerForm.city}
                      onChange={(e) =>
                        setPartnerForm({ ...partnerForm, city: e.target.value })
                      }
                    />
                  </div>
                </div>

                <div className="kl-partner-form-actions">
                  <button type="submit" className="kl-btn-primary">
                    Jetzt als Lieferanten-Partner registrieren
                  </button>
                </div>
              </form>
            )}
          </div>
        </section>
      </main>

      {/* Lieferschein-Modal */}
      <VendorDeliverySlipModal
        slip={activeSlip}
        onClose={() => setActiveSlip(null)}
      />
    </div>
  );
}
