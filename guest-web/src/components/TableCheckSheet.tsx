"use client";

import { useMemo, useState } from "react";
import { formatEuro } from "@/lib/cart";
import {
  applyLocalDemoPayment,
  computeEqualSplitShare,
  computePayableCents,
  computeRoundUpTipCents,
  computeSelectedItemsTotal,
  computeTipCents,
  fetchGuestTableCheck,
  submitGuestTablePayment,
  type BewirtungsbelegData,
  type GuestSplitMode,
  type GuestTableCheck,
  type GuestTablePaymentReceipt,
  type GuestTipPercent,
} from "@/lib/table-check";
import { tableHeadline } from "@/lib/table-context";
import { getSupabase } from "@/lib/supabase-client";
import { HospitalityReceiptModal } from "./HospitalityReceiptModal";
import { WalletPayButton, WalletPaymentSheet } from "./WalletPaymentSheet";

type TipSelectionMode = GuestTipPercent | "round_up";

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
  const [selectedQuantities, setSelectedQuantities] = useState<Record<string, number>>({});
  const [equalSplitCount, setEqualSplitCount] = useState<number>(2);
  const [tipSelection, setTipSelection] = useState<TipSelectionMode>(10);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isWalletOpen, setWalletOpen] = useState(false);
  const [isReceiptModalOpen, setReceiptModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [lastReceipt, setLastReceipt] = useState<GuestTablePaymentReceipt | null>(null);

  // Bewirtungsbeleg (§ 4 Abs. 5 Nr. 2 EStG)
  const [bewirtung, setBewirtung] = useState<BewirtungsbelegData>({
    enabled: false,
    hostName: "",
    guests: "",
    purpose: "",
  });

  const openItems = useMemo(
    () => check.items.filter((item) => !item.paid),
    [check.items],
  );

  const baseAmountCents = useMemo(() => {
    if (check.openCents <= 0) return 0;
    switch (splitMode) {
      case "items":
        return computeSelectedItemsTotal(check, selectedItemIds, selectedQuantities);
      case "full":
        return check.openCents;
      case "equal":
        return computeEqualSplitShare(check.openCents, equalSplitCount);
    }
  }, [check, splitMode, selectedItemIds, selectedQuantities, equalSplitCount]);

  const tipCents = useMemo(() => {
    if (baseAmountCents <= 0) return 0;
    if (tipSelection === "round_up") {
      return computeRoundUpTipCents(baseAmountCents);
    }
    return computeTipCents(baseAmountCents, tipSelection);
  }, [baseAmountCents, tipSelection]);

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
        // Default to full quantity when toggled on
        const target = check.items.find((i) => i.orderItemId === orderItemId);
        if (target) {
          setSelectedQuantities((q) => ({
            ...q,
            [orderItemId]: target.quantity,
          }));
        }
      }
      return next;
    });
  };

  const setItemQuantity = (orderItemId: string, nextQty: number, maxQty: number) => {
    setErrorMessage(null);
    const clamped = Math.max(1, Math.min(maxQty, nextQty));
    setSelectedQuantities((prev) => ({
      ...prev,
      [orderItemId]: clamped,
    }));
    // Auto-select the item if quantity adjusted
    setSelectedItemIds((prev) => {
      const next = new Set(prev);
      next.add(orderItemId);
      return next;
    });
  };

  const selectAllOpen = () => {
    setErrorMessage(null);
    if (selectedItemIds.size === openItems.length) {
      setSelectedItemIds(new Set());
    } else {
      const nextIds = new Set(openItems.map((i) => i.orderItemId));
      setSelectedItemIds(nextIds);
      const nextQtys: Record<string, number> = {};
      openItems.forEach((item) => {
        nextQtys[item.orderItemId] = item.quantity;
      });
      setSelectedQuantities(nextQtys);
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
        const enrichedReceipt: GuestTablePaymentReceipt = {
          ...remoteResult.receipt,
          bewirtungsbeleg: bewirtung.enabled ? bewirtung : undefined,
          venueName,
          tableLabel: check.tableLabel,
          tableArea: check.tableArea,
        };
        setLastReceipt(enrichedReceipt);
        const refreshed = await fetchGuestTableCheck(venueSlug, tableToken, supabase);
        if (refreshed) {
          onCheckUpdated(refreshed);
          const remainingOpen = refreshed.items.filter((i) => !i.paid);
          setSelectedItemIds(
            remainingOpen.length > 0 ? new Set([remainingOpen[0].orderItemId]) : new Set(),
          );
        } else {
          const fallback = applyLocalDemoPayment(check, {
            orderItemIds,
            selectedQuantities: splitMode === "items" ? selectedQuantities : undefined,
            amountCents: baseAmountCents,
            tipCents,
            idempotencyKey,
            bewirtungsbeleg: bewirtung.enabled ? bewirtung : undefined,
            venueName,
          });
          if (fallback.ok) {
            onCheckUpdated(fallback.check);
          }
        }
        setIsSubmitting(false);
        return;
      }

      if (!check.tableSessionId?.startsWith("demo-")) {
        setErrorMessage(remoteResult.message);
        setIsSubmitting(false);
        return;
      }
    }

    const localResult = applyLocalDemoPayment(check, {
      orderItemIds,
      selectedQuantities: splitMode === "items" ? selectedQuantities : undefined,
      amountCents: baseAmountCents,
      tipCents,
      idempotencyKey,
      bewirtungsbeleg: bewirtung.enabled ? bewirtung : undefined,
      venueName,
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
    <>
      <div
        className="fixed inset-0 z-40 bg-kl-dark/60 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto"
        onClick={onClose}
      >
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="kl-table-check-title"
          className="bg-kl-canvas text-kl-charcoal w-full max-w-xl max-h-[92vh] overflow-y-auto rounded-t-2xl sm:rounded-2xl border border-kl-border shadow-2xl flex flex-col p-4 sm:p-6"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-start justify-between gap-3 mb-4">
            <div>
              <h2
                id="kl-table-check-title"
                className="font-serif text-2xl font-bold tracking-tight text-kl-charcoal"
              >
                Tischrechnung & Teilen
              </h2>
              <p className="font-mono text-xs text-kl-muted mt-0.5">
                {displayTable} · Gemeinsame Tisch-Session
              </p>
            </div>
            <button
              type="button"
              className="w-8 h-8 rounded-full bg-kl-subtle hover:bg-kl-border/70 text-kl-charcoal flex items-center justify-center font-bold text-lg transition-colors cursor-pointer"
              onClick={onClose}
              aria-label="Tischrechnung schließen"
            >
              ×
            </button>
          </div>

          {/* Übersichtskarte: Gesamt / Bezahlt / Offen */}
          <div className="grid grid-cols-3 gap-2 p-3.5 bg-kl-surface rounded-xl border border-kl-border mb-4">
            <div>
              <span className="block font-mono text-[11px] uppercase tracking-wider text-kl-muted">
                Gesamt
              </span>
              <span className="font-mono tabular-nums text-sm sm:text-base font-semibold text-kl-charcoal">
                {formatEuro(check.totalCents)}
              </span>
            </div>
            <div>
              <span className="block font-mono text-[11px] uppercase tracking-wider text-kl-muted">
                Bereits bezahlt
              </span>
              <span className="font-mono tabular-nums text-sm sm:text-base text-neutral-500">
                {formatEuro(check.paidCents)}
              </span>
            </div>
            <div className="text-right">
              <span className="block font-mono text-[11px] uppercase tracking-wider text-kl-muted">
                Noch offen
              </span>
              <span
                className={`font-mono tabular-nums text-sm sm:text-base font-bold ${
                  isSettled ? "text-kl-sage" : "text-kl-terracotta"
                }`}
              >
                {formatEuro(check.openCents)}
              </span>
            </div>
          </div>

          {/* Aufteilungs-Modus (Gesamter Tisch vs. Artikel aufteilen vs. Gleichmäßig) */}
          {!isSettled && (
            <div
              role="tablist"
              aria-label="Aufteilungsart wählen"
              className="grid grid-cols-3 gap-1.5 p-1 bg-kl-subtle rounded-xl mb-4 border border-kl-border/60"
            >
              <button
                type="button"
                role="tab"
                aria-selected={splitMode === "full"}
                className={`font-sans text-xs sm:text-sm font-medium py-2 px-2 rounded-lg text-center transition-all cursor-pointer ${
                  splitMode === "full"
                    ? "bg-kl-dark text-kl-canvas shadow-sm font-semibold"
                    : "text-kl-charcoal hover:bg-kl-border/40"
                }`}
                onClick={() => setSplitMode("full")}
              >
                Gesamter Tisch
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={splitMode === "items"}
                className={`font-sans text-xs sm:text-sm font-medium py-2 px-2 rounded-lg text-center transition-all cursor-pointer ${
                  splitMode === "items"
                    ? "bg-kl-dark text-kl-canvas shadow-sm font-semibold"
                    : "text-kl-charcoal hover:bg-kl-border/40"
                }`}
                onClick={() => setSplitMode("items")}
              >
                Artikel aufteilen
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={splitMode === "equal"}
                className={`font-sans text-xs sm:text-sm font-medium py-2 px-2 rounded-lg text-center transition-all cursor-pointer ${
                  splitMode === "equal"
                    ? "bg-kl-dark text-kl-canvas shadow-sm font-semibold"
                    : "text-kl-charcoal hover:bg-kl-border/40"
                }`}
                onClick={() => setSplitMode("equal")}
              >
                Gleichmäßig ({equalSplitCount})
              </button>
            </div>
          )}

          {/* Stepper für gleichmäßige Aufteilung */}
          {!isSettled && splitMode === "equal" && (
            <div className="flex items-center justify-between p-3.5 bg-kl-surface rounded-xl border border-kl-border mb-4">
              <div>
                <p className="font-sans font-medium text-sm text-kl-charcoal">
                  Gleichmäßig durch Personen teilen
                </p>
                <p className="font-mono text-xs text-kl-muted mt-0.5">
                  1/{equalSplitCount} des offenen Betrags:{" "}
                  <span className="font-semibold text-kl-charcoal tabular-nums">
                    {formatEuro(baseAmountCents)}
                  </span>
                </p>
              </div>
              <div
                className="flex items-center gap-2 bg-kl-subtle rounded-lg p-1 border border-kl-border"
                role="group"
                aria-label="Anzahl Personen"
              >
                <button
                  type="button"
                  className="w-7 h-7 rounded bg-kl-surface text-kl-charcoal font-bold flex items-center justify-center hover:bg-kl-border/70 disabled:opacity-40 cursor-pointer"
                  onClick={() => setEqualSplitCount((c) => Math.max(2, c - 1))}
                  disabled={equalSplitCount <= 2}
                  aria-label="Personenanzahl verringern"
                >
                  −
                </button>
                <span className="font-mono tabular-nums font-semibold text-sm w-5 text-center">
                  {equalSplitCount}
                </span>
                <button
                  type="button"
                  className="w-7 h-7 rounded bg-kl-surface text-kl-charcoal font-bold flex items-center justify-center hover:bg-kl-border/70 disabled:opacity-40 cursor-pointer"
                  onClick={() => setEqualSplitCount((c) => Math.min(12, c + 1))}
                  disabled={equalSplitCount >= 12}
                  aria-label="Personenanzahl erhöhen"
                >
                  +
                </button>
              </div>
            </div>
          )}

          {/* Positionsliste */}
          <div className="mb-4">
            <div className="flex justify-between items-center mb-2 px-1">
              <span className="font-mono text-xs uppercase tracking-wider text-kl-muted font-semibold">
                Positionen am Tisch ({check.items.length})
              </span>
              {!isSettled && splitMode === "items" && openItems.length > 0 && (
                <button
                  type="button"
                  onClick={selectAllOpen}
                  className="font-sans text-xs text-kl-terracotta hover:underline font-medium cursor-pointer"
                >
                  {selectedItemIds.size === openItems.length
                    ? "Auswahl aufheben"
                    : "Alle offenen wählen"}
                </button>
              )}
            </div>

            <ul className="space-y-2" aria-label="Rechnungspositionen">
              {check.items.map((item) => {
                const isSelected =
                  splitMode === "items" && !item.paid && selectedItemIds.has(item.orderItemId);
                const isInteractive = !isSettled && splitMode === "items" && !item.paid;
                const chosenQty = selectedQuantities[item.orderItemId] ?? item.quantity;
                const activeLineTotal = isSelected
                  ? chosenQty * item.unitPriceCents
                  : item.lineTotalCents;

                return (
                  <li
                    key={item.orderItemId}
                    className={`p-3 rounded-xl border transition-all ${
                      item.paid
                        ? "bg-kl-subtle/50 border-kl-border/60 opacity-60"
                        : isSelected
                          ? "bg-kl-surface border-kl-terracotta/80 shadow-sm"
                          : "bg-kl-surface border-kl-border hover:border-neutral-400"
                    } ${isInteractive ? "cursor-pointer" : ""}`}
                    onClick={() => {
                      if (isInteractive) toggleItem(item.orderItemId);
                    }}
                  >
                    <div className="flex items-center justify-between gap-3">
                      <div className="flex items-center gap-3 min-w-0">
                        {/* Status / Checkbox */}
                        <div
                          className={`w-5 h-5 rounded-md flex items-center justify-center font-mono text-xs font-bold shrink-0 transition-colors ${
                            item.paid
                              ? "bg-kl-sage/20 text-kl-sage border border-kl-sage/30"
                              : isSelected
                                ? "bg-kl-terracotta text-white"
                                : "border border-neutral-300 bg-white"
                          }`}
                          aria-hidden="true"
                        >
                          {item.paid ? "✓" : isSelected ? "✓" : ""}
                        </div>

                        <div className="min-w-0">
                          <p className="font-sans font-semibold text-sm text-kl-charcoal truncate">
                            <span className="font-mono tabular-nums text-neutral-600 mr-1.5 font-normal">
                              {item.quantity}×
                            </span>
                            {item.name}
                          </p>
                          <p className="font-mono text-[11px] text-kl-muted mt-0.5">
                            {item.paid
                              ? "Bereits bezahlt"
                              : item.source === "service"
                                ? "Service-Bestellung"
                                : "Tisch-QR"}
                            {" · "}
                            {formatEuro(item.unitPriceCents)} / Stk.
                          </p>
                        </div>
                      </div>

                      <div className="text-right shrink-0">
                        <span className="font-mono tabular-nums font-semibold text-sm text-kl-charcoal">
                          {formatEuro(activeLineTotal)}
                        </span>
                      </div>
                    </div>

                    {/* Mengen-Stepper bei Artikeln mit Menge > 1 im Modus "Artikel aufteilen" */}
                    {isInteractive && isSelected && item.quantity > 1 && (
                      <div
                        className="mt-2.5 pt-2 border-t border-kl-border/60 flex items-center justify-between"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <span className="font-mono text-xs text-kl-muted">
                          Zu zahlende Menge:
                        </span>
                        <div className="flex items-center gap-2 bg-kl-subtle rounded-lg p-0.5 border border-kl-border">
                          <button
                            type="button"
                            className="w-6 h-6 rounded bg-white text-kl-charcoal font-bold flex items-center justify-center hover:bg-neutral-100 disabled:opacity-40 cursor-pointer text-xs"
                            onClick={() =>
                              setItemQuantity(item.orderItemId, chosenQty - 1, item.quantity)
                            }
                            disabled={chosenQty <= 1}
                            aria-label="Zu zahlende Menge verringern"
                          >
                            −
                          </button>
                          <span className="font-mono tabular-nums font-semibold text-xs px-1">
                            {chosenQty} von {item.quantity}
                          </span>
                          <button
                            type="button"
                            className="w-6 h-6 rounded bg-white text-kl-charcoal font-bold flex items-center justify-center hover:bg-neutral-100 disabled:opacity-40 cursor-pointer text-xs"
                            onClick={() =>
                              setItemQuantity(item.orderItemId, chosenQty + 1, item.quantity)
                            }
                            disabled={chosenQty >= item.quantity}
                            aria-label="Zu zahlende Menge erhöhen"
                          >
                            +
                          </button>
                        </div>
                      </div>
                    )}
                  </li>
                );
              })}
            </ul>
          </div>

          {/* Trinkgeld-Wahl */}
          {!isSettled && (
            <div className="mb-4 bg-kl-surface p-3.5 rounded-xl border border-kl-border">
              <div className="flex justify-between items-center mb-2">
                <span className="font-mono text-xs uppercase tracking-wider text-kl-muted font-semibold">
                  Trinkgeld für den Service
                </span>
                <span className="font-mono tabular-nums font-semibold text-sm text-kl-charcoal">
                  +{formatEuro(tipCents)}
                </span>
              </div>
              <div className="grid grid-cols-5 gap-1.5">
                {([0, 5, 10, 15] as GuestTipPercent[]).map((pct) => {
                  const tipVal = computeTipCents(baseAmountCents, pct);
                  const isSelected = tipSelection === pct;
                  return (
                    <button
                      key={pct}
                      type="button"
                      className={`py-2 px-1 rounded-lg text-center transition-all cursor-pointer border ${
                        isSelected
                          ? "bg-kl-dark text-kl-canvas border-kl-dark font-semibold shadow-sm"
                          : "bg-kl-subtle text-kl-charcoal border-transparent hover:bg-kl-border/60"
                      }`}
                      onClick={() => setTipSelection(pct)}
                    >
                      <span className="block font-sans text-xs">
                        {pct === 0 ? "Kein" : `${pct} %`}
                      </span>
                      <span className="block font-mono tabular-nums text-[10px] text-neutral-400 mt-0.5">
                        {pct === 0 ? "0 €" : `+${formatEuro(tipVal)}`}
                      </span>
                    </button>
                  );
                })}

                {/* Aufrunden-Option */}
                <button
                  type="button"
                  className={`py-2 px-1 rounded-lg text-center transition-all cursor-pointer border ${
                    tipSelection === "round_up"
                      ? "bg-kl-dark text-kl-canvas border-kl-dark font-semibold shadow-sm"
                      : "bg-kl-subtle text-kl-charcoal border-transparent hover:bg-kl-border/60"
                  }`}
                  onClick={() => setTipSelection("round_up")}
                >
                  <span className="block font-sans text-xs">Aufrunden</span>
                  <span className="block font-mono tabular-nums text-[10px] text-neutral-400 mt-0.5">
                    +{formatEuro(computeRoundUpTipCents(baseAmountCents))}
                  </span>
                </button>
              </div>
            </div>
          )}

          {/* Bewirtungsbeleg Toggle & Formular (§ 4 Abs. 5 Nr. 2 EStG) */}
          {!isSettled && (
            <div className="mb-4 bg-kl-surface p-4 rounded-xl border border-kl-border">
              <label className="flex items-center gap-3 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={bewirtung.enabled}
                  onChange={(e) =>
                    setBewirtung((prev) => ({ ...prev, enabled: e.target.checked }))
                  }
                  className="w-4 h-4 rounded text-kl-terracotta border-neutral-300 focus:ring-kl-terracotta cursor-pointer"
                />
                <span className="font-sans font-medium text-sm text-kl-charcoal">
                  Bewirtungsbeleg benötigen? (Für das Finanzamt)
                </span>
              </label>

              {bewirtung.enabled && (
                <div className="mt-3 pt-3 border-t border-kl-border/70 space-y-3 font-sans text-xs sm:text-sm">
                  <p className="font-sans text-xs text-kl-muted leading-relaxed">
                    Für den Betriebsausgabenabzug gem. § 4 Abs. 5 Nr. 2 EStG sind Angaben zum
                    Gastgeber, allen Teilnehmern und dem geschäftlichen Anlass erforderlich.
                  </p>

                  <div>
                    <label className="block font-semibold text-xs text-neutral-700 mb-1">
                      Bewirtende Person / Firma:
                    </label>
                    <input
                      type="text"
                      placeholder="z. B. Max Mustermann, Acme Technologies GmbH"
                      value={bewirtung.hostName}
                      onChange={(e) =>
                        setBewirtung((prev) => ({ ...prev, hostName: e.target.value }))
                      }
                      className="w-full bg-kl-canvas border border-kl-border text-kl-charcoal rounded-lg px-3 py-2 text-xs sm:text-sm focus:border-kl-terracotta focus:outline-none"
                    />
                  </div>

                  <div>
                    <label className="block font-semibold text-xs text-neutral-700 mb-1">
                      Bewirtete Personen (Teilnehmer):
                    </label>
                    <input
                      type="text"
                      placeholder="z. B. Dr. Peter Müller (TechCorp), Sandra Weber"
                      value={bewirtung.guests}
                      onChange={(e) =>
                        setBewirtung((prev) => ({ ...prev, guests: e.target.value }))
                      }
                      className="w-full bg-kl-canvas border border-kl-border text-kl-charcoal rounded-lg px-3 py-2 text-xs sm:text-sm focus:border-kl-terracotta focus:outline-none"
                    />
                  </div>

                  <div>
                    <label className="block font-semibold text-xs text-neutral-700 mb-1">
                      Konkreter Anlass der Bewirtung:
                    </label>
                    <input
                      type="text"
                      placeholder="z. B. Projektbesprechung Mandant Q4 Roadmap"
                      value={bewirtung.purpose}
                      onChange={(e) =>
                        setBewirtung((prev) => ({ ...prev, purpose: e.target.value }))
                      }
                      className="w-full bg-kl-canvas border border-kl-border text-kl-charcoal rounded-lg px-3 py-2 text-xs sm:text-sm focus:border-kl-terracotta focus:outline-none"
                    />
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Zahlungs-Zusammenfassung */}
          {!isSettled && (
            <div className="flex justify-between items-baseline p-3.5 bg-kl-surface rounded-xl border border-kl-border mb-4 font-sans">
              <span className="font-medium text-sm text-kl-charcoal">
                Dein Zahlbetrag{tipCents > 0 ? " (inkl. Trinkgeld)" : ""}
              </span>
              <span className="font-mono tabular-nums text-lg font-bold text-kl-charcoal">
                {formatEuro(payableCents)}
              </span>
            </div>
          )}

          {errorMessage && (
            <p className="p-3 bg-red-50 text-red-700 rounded-xl font-sans text-xs mb-4 border border-red-200" role="alert">
              {errorMessage}
            </p>
          )}

          {/* Bestätigung & Beleg-Download nach Zahlung */}
          {lastReceipt && (
            <div
              className="p-4 bg-emerald-50/70 border border-emerald-200 rounded-xl mb-4 font-sans"
              role="status"
              aria-live="polite"
            >
              <div className="flex items-start gap-3">
                <span className="w-5 h-5 rounded-full bg-kl-emerald text-white font-bold text-xs flex items-center justify-center shrink-0 mt-0.5" aria-hidden="true">
                  ✓
                </span>
                <div className="flex-1">
                  <p className="font-serif font-bold text-base text-emerald-950">
                    {lastReceipt.sessionClosed
                      ? "Tischrechnung vollständig beglichen"
                      : "Dein Anteil wurde bezahlt"}
                  </p>
                  <p className="font-mono tabular-nums text-xs text-emerald-900 mt-0.5">
                    Gezahlt: {formatEuro(lastReceipt.amountCents)}
                    {lastReceipt.tipCents > 0 ? ` + ${formatEuro(lastReceipt.tipCents)} Trinkgeld` : ""}
                    {" · "}
                    {lastReceipt.sessionClosed
                      ? "Offen: 0,00 €"
                      : `Rest am Tisch: ${formatEuro(lastReceipt.openCents)}`}
                  </p>
                  <p className="font-mono text-[11px] text-emerald-800 mt-1">
                    Signatur: {lastReceipt.tseSignature.slice(0, 18)}… · Ref: {lastReceipt.providerReference.slice(0, 16)}
                  </p>

                  <div className="mt-3">
                    <button
                      type="button"
                      onClick={() => setReceiptModalOpen(true)}
                      className="bg-kl-dark hover:bg-neutral-800 text-kl-canvas font-sans text-xs font-semibold px-4 py-2 rounded-lg inline-flex items-center gap-1.5 shadow-sm transition-colors cursor-pointer"
                    >
                      <span>
                        {lastReceipt.bewirtungsbeleg?.enabled
                          ? "Bewirtungsbeleg anzeigen & drucken (PDF)"
                          : "Kassenbeleg anzeigen & drucken (PDF)"}
                      </span>
                      <span aria-hidden="true">📄</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Aktionsleiste */}
          <div className="space-y-2 mt-auto">
            {!isSettled && (
              <>
                <WalletPayButton
                  onClick={() => setWalletOpen(true)}
                  disabled={!canPay}
                />
                <button
                  type="button"
                  className="bg-kl-terracotta hover:opacity-95 text-white font-sans font-medium text-sm sm:text-base py-3.5 px-4 rounded-xl flex items-center justify-between w-full shadow-sm transition-opacity disabled:opacity-50 cursor-pointer"
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
                          : "Gesamten Tisch bezahlen"}
                  </span>
                  <span className="font-mono tabular-nums font-semibold">
                    {formatEuro(payableCents)}
                  </span>
                </button>
              </>
            )}
            <button
              type="button"
              className="bg-kl-subtle hover:bg-kl-border text-kl-charcoal font-sans text-xs sm:text-sm font-medium py-3 px-4 rounded-xl w-full transition-colors cursor-pointer"
              onClick={onClose}
              disabled={isSubmitting}
            >
              {isSettled ? "Schließen" : "Zurück zur Karte"}
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

      <HospitalityReceiptModal
        receipt={lastReceipt}
        venueSlug={venueSlug}
        venueName={venueName}
        isOpen={isReceiptModalOpen}
        onClose={() => setReceiptModalOpen(false)}
      />
    </>
  );
}