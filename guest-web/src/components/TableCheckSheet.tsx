"use client";

import { useMemo, useState } from "react";
import { formatEuro } from "@/lib/cart";
import {
  applyLocalDemoPayment,
  computeEqualSplitShare,
  computePayableCents,
  computeSelectedItemsTotal,
  computeTipCents,
  fetchGuestTableCheck,
  submitGuestTablePayment,
  type GuestSplitMode,
  type GuestTableCheck,
  type GuestTablePaymentReceipt,
  type GuestTipPercent,
} from "@/lib/table-check";
import { tableHeadline } from "@/lib/table-context";
import { getSupabase } from "@/lib/supabase-client";
import { WalletPayButton, WalletPaymentSheet } from "./WalletPaymentSheet";

interface TableCheckSheetProps {
  venueSlug: string;
  venueName: string;
  tableToken: string | null;
  check: GuestTableCheck;
  isOpen: boolean;
  onCheckUpdated: (nextCheck: GuestTableCheck) => void;
  onClose: () => void;
}

export function TableCheckSheet({
  venueSlug,
  venueName,
  tableToken,
  check,
  isOpen,
  onCheckUpdated,
  onClose,
}: TableCheckSheetProps) {
  const [splitMode, setSplitMode] = useState<GuestSplitMode>("items");
  const [selectedItemIds, setSelectedItemIds] = useState<Set<string>>(() => {
    const firstOpen = check.items.find((item) => !item.paid);
    return firstOpen ? new Set([firstOpen.orderItemId]) : new Set();
  });
  const [equalSplitCount, setEqualSplitCount] = useState<number>(2);
  const [tipPercent, setTipPercent] = useState<GuestTipPercent>(10);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isWalletOpen, setWalletOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [lastReceipt, setLastReceipt] = useState<GuestTablePaymentReceipt | null>(null);

  const openItems = useMemo(
    () => check.items.filter((item) => !item.paid),
    [check.items],
  );

  const baseAmountCents = useMemo(() => {
    if (check.openCents <= 0) return 0;
    switch (splitMode) {
      case "items":
        return computeSelectedItemsTotal(check, selectedItemIds);
      case "full":
        return check.openCents;
      case "equal":
        return computeEqualSplitShare(check.openCents, equalSplitCount);
    }
  }, [check, splitMode, selectedItemIds, equalSplitCount]);

  const tipCents = useMemo(
    () => computeTipCents(baseAmountCents, tipPercent),
    [baseAmountCents, tipPercent],
  );

  const payableCents = useMemo(
    () => computePayableCents(baseAmountCents, tipCents),
    [baseAmountCents, tipCents],
  );

  if (!isOpen) return null;

  const displayTable = `${tableHeadline(check.tableLabel)}${check.tableArea.trim() ? ` · ${check.tableArea.trim()}` : ""}`;
  const isSettled = check.openCents <= 0;
  const canPay = !isSettled && baseAmountCents > 0 && !isSubmitting;

  const toggleItem = (orderItemId: string) => {
    setErrorMessage(null);
    setSelectedItemIds((prev) => {
      const next = new Set(prev);
      if (next.has(orderItemId)) {
        next.delete(orderItemId);
      } else {
        next.add(orderItemId);
      }
      return next;
    });
  };

  const selectAllOpen = () => {
    setErrorMessage(null);
    if (selectedItemIds.size === openItems.length) {
      setSelectedItemIds(new Set());
    } else {
      setSelectedItemIds(new Set(openItems.map((i) => i.orderItemId)));
    }
  };

  const executePayment = async () => {
    if (!canPay) return;
    setIsSubmitting(true);
    setErrorMessage(null);

    const idempotencyKey = `guest-check-${venueSlug}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const orderItemIds =
      splitMode === "items"
        ? [...selectedItemIds].filter((id) => openItems.some((item) => item.orderItemId === id))
        : undefined;

    const supabase = getSupabase();
    if (supabase && tableToken) {
      const remoteResult = await submitGuestTablePayment(
        {
          venueSlug,
          tableToken,
          idempotencyKey,
          orderItemIds,
          amountCents: baseAmountCents,
          tipCents,
        },
        supabase,
      );

      if (remoteResult.ok) {
        setLastReceipt(remoteResult.receipt);
        const refreshed = await fetchGuestTableCheck(venueSlug, tableToken, supabase);
        if (refreshed) {
          onCheckUpdated(refreshed);
          const remainingOpen = refreshed.items.filter((i) => !i.paid);
          setSelectedItemIds(
            remainingOpen.length > 0 ? new Set([remainingOpen[0].orderItemId]) : new Set(),
          );
        } else {
          // Falls kein Re-Fetch möglich, lokal fortschreiben
          const fallback = applyLocalDemoPayment(check, {
            orderItemIds,
            amountCents: baseAmountCents,
            tipCents,
            idempotencyKey,
          });
          if (fallback.ok) {
            onCheckUpdated(fallback.check);
          }
        }
        setIsSubmitting(false);
        return;
      }

      // Falls Tisch-Session nur im lokalen Sandbox-Demo-Zustand existiert, lokal ausführen
      if (!check.tableSessionId?.startsWith("demo-")) {
        setErrorMessage(remoteResult.message);
        setIsSubmitting(false);
        return;
      }
    }

    const localResult = applyLocalDemoPayment(check, {
      orderItemIds,
      amountCents: baseAmountCents,
      tipCents,
      idempotencyKey,
    });

    if (localResult.ok) {
      onCheckUpdated(localResult.check);
      setLastReceipt(localResult.receipt);
      const remainingOpen = localResult.check.items.filter((i) => !i.paid);
      setSelectedItemIds(
        remainingOpen.length > 0 ? new Set([remainingOpen[0].orderItemId]) : new Set(),
      );
    } else {
      setErrorMessage(localResult.message);
    }
    setIsSubmitting(false);
  };

  return (
    <div className="kl-sheet-backdrop" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="kl-table-check-title"
        className="kl-sheet"
        onClick={(e) => e.stopPropagation()}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-start",
            gap: "var(--kl-space-3)",
            marginBottom: "var(--kl-space-2)",
          }}
        >
          <div>
            <h2 id="kl-table-check-title" className="kl-type-section">
              Tischrechnung & Teilen
            </h2>
            <p className="kl-type-meta" style={{ marginTop: "0.125rem" }}>
              {displayTable} · Gemeinsame Tisch-Session
            </p>
          </div>
          <button
            type="button"
            className="kl-icon-close kl-type-button"
            onClick={onClose}
            aria-label="Tischrechnung schließen"
          >
            ×
          </button>
        </div>

        {/* Übersichtskarte: Gesamt / Bezahlt / Offen */}
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr 1fr",
            gap: "var(--kl-space-2)",
            padding: "var(--kl-space-3)",
            background: "var(--kl-surface-control)",
            borderRadius: "var(--kl-radius-control)",
            marginBottom: "var(--kl-space-3)",
          }}
        >
          <div>
            <span className="kl-type-meta" style={{ display: "block" }}>
              Gesamt
            </span>
            <span className="kl-type-primary kl-tabular">
              {formatEuro(check.totalCents)}
            </span>
          </div>
          <div>
            <span className="kl-type-meta" style={{ display: "block" }}>
              Bereits bezahlt
            </span>
            <span className="kl-type-secondary kl-tabular">
              {formatEuro(check.paidCents)}
            </span>
          </div>
          <div style={{ textAlign: "right" }}>
            <span className="kl-type-meta" style={{ display: "block" }}>
              Noch offen
            </span>
            <span
              className="kl-type-primary kl-tabular"
              style={{
                fontWeight: 700,
                color: isSettled
                  ? "var(--kl-urgency-fresh-text)"
                  : "var(--kl-content-primary)",
              }}
            >
              {formatEuro(check.openCents)}
            </span>
          </div>
        </div>

        {/* Split-Modus-Auswahl */}
        {!isSettled && (
          <div
            role="tablist"
            aria-label="Aufteilungsart wählen"
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 1fr 1fr",
              gap: "var(--kl-space-2)",
              marginBottom: "var(--kl-space-3)",
            }}
          >
            <button
              type="button"
              role="tab"
              aria-selected={splitMode === "items"}
              className={`kl-chip ${splitMode === "items" ? "kl-chip-selected" : ""}`}
              style={{ fontSize: "0.8125rem", minHeight: "2.25rem", justifyContent: "center" }}
              onClick={() => setSplitMode("items")}
            >
              Meine Artikel
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={splitMode === "full"}
              className={`kl-chip ${splitMode === "full" ? "kl-chip-selected" : ""}`}
              style={{ fontSize: "0.8125rem", minHeight: "2.25rem", justifyContent: "center" }}
              onClick={() => setSplitMode("full")}
            >
              Alles Offene
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={splitMode === "equal"}
              className={`kl-chip ${splitMode === "equal" ? "kl-chip-selected" : ""}`}
              style={{ fontSize: "0.8125rem", minHeight: "2.25rem", justifyContent: "center" }}
              onClick={() => setSplitMode("equal")}
            >
              Durch {equalSplitCount} teilen
            </button>
          </div>
        )}

        {/* Modus 3: Gleichmäßig durch N Personen teilen */}
        {!isSettled && splitMode === "equal" && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "var(--kl-space-3)",
              background: "var(--kl-surface-control)",
              borderRadius: "var(--kl-radius-control)",
              marginBottom: "var(--kl-space-3)",
            }}
          >
            <div>
              <p className="kl-type-primary">Gleichmäßig aufteilen</p>
              <p className="kl-type-meta">
                Jede Person übernimmt 1/{equalSplitCount} des offenen Betrags ({formatEuro(baseAmountCents)})
              </p>
            </div>
            <div className="kl-stepper" role="group" aria-label="Anzahl Personen">
              <button
                type="button"
                className="kl-stepper-button kl-type-button"
                onClick={() => setEqualSplitCount((c) => Math.max(2, c - 1))}
                disabled={equalSplitCount <= 2}
                aria-label="Personenanzahl verringern"
              >
                −
              </button>
              <span className="kl-stepper-quantity kl-type-primary kl-tabular">
                {equalSplitCount}
              </span>
              <button
                type="button"
                className="kl-stepper-button kl-type-button"
                onClick={() => setEqualSplitCount((c) => Math.min(12, c + 1))}
                disabled={equalSplitCount >= 12}
                aria-label="Personenanzahl erhöhen"
              >
                +
              </button>
            </div>
          </div>
        )}

        {/* Positionsliste der gemeinsamen Tisch-Session */}
        <div style={{ marginBottom: "var(--kl-space-3)" }}>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              marginBottom: "var(--kl-space-1)",
            }}
          >
            <span className="kl-type-meta" style={{ textTransform: "uppercase", letterSpacing: "0.05em" }}>
              Positionen am Tisch ({check.items.length})
            </span>
            {!isSettled && splitMode === "items" && openItems.length > 0 && (
              <button
                type="button"
                onClick={selectAllOpen}
                className="kl-type-meta"
                style={{
                  background: "none",
                  border: "none",
                  color: "var(--kl-content-primary)",
                  textDecoration: "underline",
                  cursor: "pointer",
                  padding: "0.25rem 0",
                }}
              >
                {selectedItemIds.size === openItems.length ? "Auswahl aufheben" : "Alle offenen wählen"}
              </button>
            )}
          </div>

          <ul className="kl-sheet-lines" aria-label="Rechnungspositionen">
            {check.items.map((item) => {
              const isSelected = splitMode === "items" && !item.paid && selectedItemIds.has(item.orderItemId);
              const isInteractive = !isSettled && splitMode === "items" && !item.paid;

              return (
                <li
                  key={item.orderItemId}
                  className="kl-sheet-line"
                  style={{
                    opacity: item.paid ? 0.6 : 1,
                    cursor: isInteractive ? "pointer" : "default",
                  }}
                  onClick={() => {
                    if (isInteractive) toggleItem(item.orderItemId);
                  }}
                >
                  <span
                    className="kl-sheet-line-copy kl-type-secondary"
                    style={{ display: "flex", alignItems: "center", gap: "var(--kl-space-2)" }}
                  >
                    <span
                      aria-hidden="true"
                      style={{
                        fontSize: "1.05rem",
                        color: item.paid
                          ? "var(--kl-urgency-fresh-text)"
                          : isSelected
                            ? "var(--kl-content-primary)"
                            : "var(--kl-content-muted)",
                      }}
                    >
                      {item.paid ? "✓" : splitMode === "items" ? (isSelected ? "☑" : "☐") : "•"}
                    </span>
                    <span>
                      <span style={{ display: "block", color: "var(--kl-content-primary)" }}>
                        <span className="kl-tabular">{item.quantity}×</span> {item.name}
                      </span>
                      <span className="kl-type-meta">
                        {item.paid
                          ? "Bereits bezahlt"
                          : item.source === "service"
                            ? "Beim Service bestellt"
                            : "Per Tisch-QR bestellt"}
                      </span>
                    </span>
                  </span>
                  <span className="kl-sheet-line-trailing">
                    <span className="kl-type-primary kl-tabular">
                      {formatEuro(item.lineTotalCents)}
                    </span>
                  </span>
                </li>
              );
            })}
          </ul>
        </div>

        {/* Trinkgeld-Wahl */}
        {!isSettled && (
          <div style={{ marginBottom: "var(--kl-space-3)" }}>
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                marginBottom: "var(--kl-space-1)",
              }}
            >
              <span className="kl-type-meta" style={{ textTransform: "uppercase", letterSpacing: "0.05em" }}>
                Trinkgeld für das Team
              </span>
              <span className="kl-type-primary kl-tabular">{formatEuro(tipCents)}</span>
            </div>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(4, 1fr)",
                gap: "var(--kl-space-2)",
              }}
            >
              {([0, 5, 10, 15] as GuestTipPercent[]).map((pct) => (
                <button
                  key={pct}
                  type="button"
                  className={`kl-chip ${tipPercent === pct ? "kl-chip-selected" : ""}`}
                  style={{ minHeight: "2.25rem", justifyContent: "center", fontSize: "0.8125rem" }}
                  onClick={() => setTipPercent(pct)}
                >
                  {pct === 0 ? "Kein" : `${pct} %`}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Zahlungs-Zusammenfassung */}
        {!isSettled && (
          <div className="kl-sheet-total" style={{ marginBottom: "var(--kl-space-3)" }}>
            <span className="kl-type-primary">
              Dein Zahlbetrag{tipCents > 0 ? " (inkl. Trinkgeld)" : ""}
            </span>
            <span className="kl-type-primary kl-tabular">{formatEuro(payableCents)}</span>
          </div>
        )}

        {errorMessage && (
          <p className="kl-sheet-note kl-type-secondary" role="alert" style={{ color: "var(--kl-urgency-waiting-text)" }}>
            {errorMessage}
          </p>
        )}

        {/* Digitaler KassenSichV- / Sandbox-Beleg nach Zahlung */}
        {lastReceipt && (
          <div className="kl-confirmation" role="status" aria-live="polite" style={{ marginBottom: "var(--kl-space-3)" }}>
            <div className="kl-confirmation-check" aria-hidden="true">
              ✓
            </div>
            <div className="kl-confirmation-body">
              <p className="kl-confirmation-title kl-type-section">
                {lastReceipt.sessionClosed
                  ? "Tischrechnung vollständig beglichen"
                  : "Dein Anteil wurde bezahlt"}
              </p>
              <p className="kl-confirmation-meta kl-type-secondary">
                Gezahlt: {formatEuro(lastReceipt.amountCents)}
                {lastReceipt.tipCents > 0 ? ` + ${formatEuro(lastReceipt.tipCents)} Trinkgeld` : ""}
                {" · "}
                {lastReceipt.sessionClosed
                  ? "Offen am Tisch: 0,00 €"
                  : `Noch offen am Tisch: ${formatEuro(lastReceipt.openCents)}`}
              </p>
              <p className="kl-confirmation-status kl-type-meta">
                Digitaler E-Bon · {lastReceipt.tseSignature} · Ref: {lastReceipt.providerReference.slice(0, 18)} · Sandbox
              </p>
            </div>
          </div>
        )}

        <div className="kl-sheet-actions">
          {!isSettled && (
            <>
              <WalletPayButton
                onClick={() => setWalletOpen(true)}
                disabled={!canPay}
              />
              <button
                type="button"
                className="kl-primary-button kl-type-button"
                onClick={() => void executePayment()}
                disabled={!canPay}
              >
                <span>
                  {isSubmitting
                    ? "Wird gebucht …"
                    : splitMode === "items"
                      ? "Auswahl direkt bezahlen"
                      : splitMode === "equal"
                        ? `Anteil (1/${equalSplitCount}) bezahlen`
                        : "Offenen Restbetrag bezahlen"}
                </span>
                <span className="kl-tabular">{formatEuro(payableCents)}</span>
              </button>
            </>
          )}
          <button
            type="button"
            className="kl-secondary-button kl-type-button"
            onClick={onClose}
            disabled={isSubmitting}
          >
            {isSettled ? "Fertig" : "Zurück zur Karte"}
          </button>
        </div>
      </div>

      <WalletPaymentSheet
        venueName={venueName}
        tableLabel={displayTable}
        totalCents={payableCents}
        isOpen={isWalletOpen}
        isSubmitting={isSubmitting}
        onClose={() => setWalletOpen(false)}
        onConfirm={async () => {
          setWalletOpen(false);
          await executePayment();
        }}
      />
    </div>
  );
}
