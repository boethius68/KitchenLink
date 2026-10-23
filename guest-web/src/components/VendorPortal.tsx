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

  const openCount = orders.filter((o) => o.status === "sent").length;
  const inProgressCount = orders.filter(
    (o) => o.status === "confirmed" || o.status === "in_transit",
  ).length;
  const completedCount = orders.filter((o) => o.status === "received").length;
  const totalVolumeCents = orders
    .filter((o) => o.status !== "cancelled")
    .reduce((sum, o) => sum + o.totalCents, 0);

  return (
    <div className="kl-brand-home">
      {/* 1. Header */}
      <header className="kl-brand-header">
        <div className="kl-brand-header-inner">
          <div className="kl-brand-logo-group">
            <Link href="/" className="kl-brand-wordmark">
              KitchenLink
            </Link>
            <span className="kl-brand-env-tag">B2B Lieferanten</span>
          </div>

          <div className="kl-brand-header-actions">
            <Link href="/" className="kl-action-link">
              ← Zur Startseite
            </Link>
            <Link href="/alte-muehle/menu" className="kl-action-link">
              Gast-Speisekarte
            </Link>
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main className="kl-vendor-main-clean">
        {/* 2. Titel & Statusleiste */}
        <div className="kl-vendor-title-bar">
          <div>
            <div className="kl-surface-kicker">Warenwirtschaft & Einkauf · Blueprint §11</div>
            <h1 className="kl-editorial-subtitle">B2B Lieferanten-Portal</h1>
            <p className="kl-type-secondary">
              Eingehende Bestellungen aus der Restaurantküche bestätigen, Liefertermine
              avisieren und digitale Lieferscheine für Fahrer und Wareneingang drucken.
            </p>
          </div>

          <div className="kl-vendor-metrics-summary">
            <div className="kl-metric-cell">
              <span className="kl-type-meta kl-text-muted">Offen</span>
              <span className="kl-type-section kl-tabular">{openCount}</span>
            </div>
            <div className="kl-metric-cell">
              <span className="kl-type-meta kl-text-muted">In Zustellung</span>
              <span className="kl-type-section kl-tabular">{inProgressCount}</span>
            </div>
            <div className="kl-metric-cell">
              <span className="kl-type-meta kl-text-muted">Geliefert</span>
              <span className="kl-type-section kl-tabular">{completedCount}</span>
            </div>
            <div className="kl-metric-cell">
              <span className="kl-type-meta kl-text-muted">Auftragsvolumen</span>
              <span className="kl-type-section kl-tabular">{formatCents(totalVolumeCents)}</span>
            </div>
          </div>
        </div>

        {/* 3. Filter- und Auswahlschaltflächen */}
        <div className="kl-vendor-nav-tabs">
          <div className="kl-tab-row">
            <span className="kl-type-meta kl-tab-label">Lieferant:</span>
            <button
              type="button"
              className={`kl-tab-item ${selectedSupplierId === "all" ? "kl-tab-item-active" : ""}`}
              onClick={() => setSelectedSupplierId("all")}
            >
              Alle ({orders.length})
            </button>
            {sandboxSuppliers.map((supplier) => (
              <button
                key={supplier.id}
                type="button"
                className={`kl-tab-item ${selectedSupplierId === supplier.id ? "kl-tab-item-active" : ""}`}
                onClick={() => setSelectedSupplierId(supplier.id)}
              >
                {supplier.name}
              </button>
            ))}
          </div>

          <div className="kl-tab-row">
            <span className="kl-type-meta kl-tab-label">Status:</span>
            <button
              type="button"
              className={`kl-tab-item ${statusFilter === "all" ? "kl-tab-item-active" : ""}`}
              onClick={() => setStatusFilter("all")}
            >
              Alle
            </button>
            <button
              type="button"
              className={`kl-tab-item ${statusFilter === "open" ? "kl-tab-item-active" : ""}`}
              onClick={() => setStatusFilter("open")}
            >
              Neu ({openCount})
            </button>
            <button
              type="button"
              className={`kl-tab-item ${statusFilter === "active" ? "kl-tab-item-active" : ""}`}
              onClick={() => setStatusFilter("active")}
            >
              Aktiv ({inProgressCount})
            </button>
            <button
              type="button"
              className={`kl-tab-item ${statusFilter === "completed" ? "kl-tab-item-active" : ""}`}
              onClick={() => setStatusFilter("completed")}
            >
              Erledigt ({completedCount})
            </button>
          </div>
        </div>

        {/* 4. Bestellungsliste */}
        <div className="kl-vendor-list-container">
          {filteredOrders.length === 0 ? (
            <div className="kl-empty-state">
              <p className="kl-type-secondary">Keine Bestellungen für diese Auswahl.</p>
              <button
                type="button"
                className="kl-action-link"
                onClick={() => {
                  setSelectedSupplierId("all");
                  setStatusFilter("all");
                }}
              >
                Filter zurücksetzen
              </button>
            </div>
          ) : (
            filteredOrders.map((po) => {
              const badge = getStatusBadgeInfo(po.status);
              const isExpanded = !!expandedOrders[po.id];
              const isConfirming = confirmingOrderId === po.id;

              return (
                <article key={po.id} className="kl-po-item-card">
                  {/* Kartenkopf */}
                  <div className="kl-po-item-header">
                    <div className="kl-po-header-left">
                      <div className="kl-po-title-line">
                        <span className="kl-tabular-code">{po.orderNumber}</span>
                        <span className={`kl-status-pill ${badge.cssModifier}`}>
                          {badge.label}
                        </span>
                      </div>
                      <div className="kl-type-primary kl-po-venue-title">
                        {po.venueName}
                      </div>
                      <div className="kl-type-meta kl-text-muted">
                        Lieferant: <strong>{po.supplierName}</strong> ({po.supplierContact})
                      </div>
                    </div>

                    <div className="kl-po-header-right">
                      <div className="kl-type-section kl-tabular">
                        {formatCents(po.totalCents)}
                      </div>
                      <div className="kl-type-meta kl-text-muted">
                        Wunschtermin: {new Date(po.expectedDeliveryDate).toLocaleDateString("de-DE")}
                      </div>
                      {po.confirmedDeliveryDate && (
                        <div className="kl-type-meta kl-urgency-fresh-text">
                          Bestätigt: {new Date(po.confirmedDeliveryDate).toLocaleDateString("de-DE")}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Küchen-Notiz */}
                  {po.notes && (
                    <div className="kl-po-kitchen-note">
                      <span className="kl-type-meta">Anmerkung der Küche:</span>
                      <p className="kl-type-secondary">{po.notes}</p>
                    </div>
                  )}

                  {/* Positionen ausklappen */}
                  <div className="kl-po-items-toggle-strip">
                    <button
                      type="button"
                      className="kl-text-link"
                      onClick={() => handleToggleExpand(po.id)}
                      aria-expanded={isExpanded}
                    >
                      {isExpanded
                        ? `Positionen schließen (${po.lines.length} Artikel)`
                        : `Positionen anzeigen (${po.lines.length} Artikel)`}
                    </button>
                  </div>

                  {isExpanded && (
                    <div className="kl-po-table-wrap">
                      <table className="kl-po-lines-table">
                        <thead>
                          <tr>
                            <th>Artikelbezeichnung</th>
                            <th style={{ textAlign: "right" }}>Menge</th>
                            <th style={{ textAlign: "right" }}>Einzelpreis</th>
                            <th style={{ textAlign: "right" }}>Gesamt</th>
                          </tr>
                        </thead>
                        <tbody>
                          {po.lines.map((line) => (
                            <tr key={line.id}>
                              <td>{line.ingredientName}</td>
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

                  {/* Terminbestätigung */}
                  {isConfirming && (
                    <div className="kl-confirm-dialog-wrap">
                      <div className="kl-type-primary">Liefertermin verbindlich avisieren</div>
                      <div className="kl-confirm-grid">
                        <div>
                          <label htmlFor={`date-${po.id}`} className="kl-type-meta">
                            Lieferdatum:
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
                          <label htmlFor={`note-${po.id}`} className="kl-type-meta">
                            Hinweis an Küche:
                          </label>
                          <input
                            id={`note-${po.id}`}
                            type="text"
                            className="kl-text-input"
                            placeholder="z. B. Zustellung vor 10:00 Uhr"
                            value={supplierNote}
                            onChange={(e) => setSupplierNote(e.target.value)}
                          />
                        </div>
                      </div>
                      <div className="kl-confirm-actions-row">
                        <button
                          type="button"
                          className="kl-primary-button"
                          style={{ minHeight: "2.5rem", width: "auto", padding: "0 1.25rem" }}
                          onClick={() => handleExecuteConfirm(po.id)}
                        >
                          Termin bestätigen
                        </button>
                        <button
                          type="button"
                          className="kl-secondary-button"
                          style={{ minHeight: "2.5rem", width: "auto", padding: "0 1.25rem" }}
                          onClick={() => setConfirmingOrderId(null)}
                        >
                          Abbrechen
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Aktionen */}
                  <div className="kl-po-item-footer">
                    <button
                      type="button"
                      className="kl-secondary-button"
                      style={{ minHeight: "2.5rem", width: "auto", padding: "0 1rem" }}
                      onClick={() => handleViewSlip(po.id)}
                    >
                      Lieferschein drucken (PDF)
                    </button>

                    <div className="kl-po-footer-actions-right">
                      {po.status === "sent" && !isConfirming && (
                        <button
                          type="button"
                          className="kl-primary-button"
                          style={{ minHeight: "2.5rem", width: "auto", padding: "0 1.25rem" }}
                          onClick={() => handleStartConfirm(po)}
                        >
                          Auftrag annehmen & terminieren
                        </button>
                      )}

                      {po.status === "confirmed" && (
                        <button
                          type="button"
                          className="kl-primary-button"
                          style={{ minHeight: "2.5rem", width: "auto", padding: "0 1.25rem" }}
                          onClick={() => handleTransit(po.id)}
                        >
                          Als in Zustellung markieren
                        </button>
                      )}

                      {po.status === "in_transit" && (
                        <button
                          type="button"
                          className="kl-primary-button"
                          style={{ minHeight: "2.5rem", width: "auto", padding: "0 1.25rem" }}
                          onClick={() => handleDelivered(po.id)}
                        >
                          Warenanlieferung melden
                        </button>
                      )}

                      {po.status === "received" && (
                        <span className="kl-type-meta kl-urgency-fresh-text">
                          ✓ Ware im Restaurant übernommen & verbucht
                        </span>
                      )}
                    </div>
                  </div>
                </article>
              );
            })
          )}
        </div>

        {/* 5. Lieferanten-Registrierung / Partner */}
        <section className="kl-vendor-registration-clean">
          <div className="kl-surface-meta">
            <span className="kl-surface-kicker">Partnernetzwerk</span>
            <h2 className="kl-surface-heading">Neuen Lieferanten anbinden</h2>
            <p className="kl-type-secondary">
              Sie beliefern Restaurants und möchten Bestellungen digital empfangen?
              Registrieren Sie Ihren Großhandel oder Erzeugerbetrieb.
            </p>
          </div>

          {partnerSubmitted ? (
            <div className="kl-partner-success-clean" role="status">
              <strong>Anfrage für {partnerForm.companyName} erfasst.</strong>
              <p className="kl-type-secondary">
                Wir melden uns zur Bereitstellung der B2B-Schnittstelle.
              </p>
            </div>
          ) : (
            <form onSubmit={handlePartnerSubmit} className="kl-partner-form-clean">
              <div className="kl-partner-fields-row">
                <input
                  type="text"
                  required
                  placeholder="Großhandel / Firmenname"
                  className="kl-text-input"
                  value={partnerForm.companyName}
                  onChange={(e) =>
                    setPartnerForm({ ...partnerForm, companyName: e.target.value })
                  }
                />
                <input
                  type="email"
                  required
                  placeholder="E-Mail für Bestellungen"
                  className="kl-text-input"
                  value={partnerForm.email}
                  onChange={(e) =>
                    setPartnerForm({ ...partnerForm, email: e.target.value })
                  }
                />
                <select
                  className="kl-select"
                  value={partnerForm.category}
                  onChange={(e) =>
                    setPartnerForm({ ...partnerForm, category: e.target.value })
                  }
                >
                  <option value="Frische & Molkerei">Frische & Molkerei</option>
                  <option value="Obst & Gemüse">Obst & Gemüse</option>
                  <option value="Getränke & Wein">Getränke & Wein</option>
                  <option value="Trockensortiment">Trockensortiment</option>
                </select>
                <button
                  type="submit"
                  className="kl-secondary-button"
                  style={{ minHeight: "2.75rem", width: "auto", padding: "0 1.25rem", whiteSpace: "nowrap" }}
                >
                  Registrieren
                </button>
              </div>
            </form>
          )}

          <div className="kl-reset-bar-clean">
            <button
              type="button"
              className="kl-text-link"
              onClick={handleResetDemo}
            >
              Demo-Bestellungen auf Ausgangszustand zurücksetzen
            </button>
          </div>
        </section>
      </main>

      {/* Lieferschein-Druck-Modal */}
      <VendorDeliverySlipModal
        slip={activeSlip}
        onClose={() => setActiveSlip(null)}
      />
    </div>
  );
}
