"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  cartLines,
  type Cart,
  type CartLine,
  decrement,
  decrementLastConfiguration,
  emptyCart,
  formatEuro,
  increment,
  itemCount,
  quantityForItem,
  totalCents,
} from "@/lib/cart";
import {
  configuredUnitPrice,
  isValidConfiguration,
  optionGroups,
  selectedOptions,
  type GuestOptionGroup,
} from "@/lib/menu-options";
import {
  createSupabaseOrderBackend,
} from "@/lib/order-backend-supabase";
import { createOrderAttemptID, submitOrder } from "@/lib/order-submit";
import {
  acceptedState,
  errorState,
  initialSubmitUiState,
  submittingState,
  type SubmitUiState,
} from "@/lib/order-ack";
import {
  evaluateHubPresence,
  fetchHubPresence,
  HUB_POLL_INTERVAL_MS,
  type HubAvailability,
} from "@/lib/hub-presence";
import {
  fetchTable,
  readTableToken,
  tableContextLabel,
  type TableContext,
} from "@/lib/table-context";
import { getSupabase } from "@/lib/supabase-client";
import type { GuestAllergen, GuestMenuItem, GuestVenue } from "@/lib/venue-data";
import { ThemeToggle } from "./ThemeToggle";

interface GuestMenuCardProps {
  venue: GuestVenue;
}

function useModalDialog<ElementType extends HTMLElement>(onClose: () => void) {
  const dialogRef = useRef<ElementType>(null);
  const closeRef = useRef(onClose);

  useEffect(() => {
    closeRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    const previousFocus = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null;
    const focusable = () => [...dialog.querySelectorAll<HTMLElement>(
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    )];
    (focusable()[0] ?? dialog).focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        closeRef.current();
        return;
      }
      if (event.key !== "Tab") return;
      const targets = focusable();
      if (targets.length === 0) {
        event.preventDefault();
        dialog.focus();
        return;
      }
      const first = targets[0];
      const last = targets[targets.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    dialog.addEventListener("keydown", handleKeyDown);
    return () => {
      dialog.removeEventListener("keydown", handleKeyDown);
      previousFocus?.focus();
    };
  }, []);

  return dialogRef;
}

export function GuestMenuCard({ venue }: GuestMenuCardProps) {
  const [cart, setCart] = useState<Cart>(emptyCart);
  const [isSummaryOpen, setSummaryOpen] = useState(false);
  const [submitState, setSubmitState] = useState<SubmitUiState>(
    initialSubmitUiState(),
  );
  // Schnappschuss des Warenkorbs im Moment der Bestaetigung: der Warenkorb
  // wird bei Erfolg sofort geleert, das Sheet soll aber weiterhin zeigen, was
  // bestaetigt wurde, statt auf 0,00 EUR zurueckzufallen.
  const [confirmedCart, setConfirmedCart] = useState<Cart | null>(null);
  const orderAttemptRef = useRef<{ fingerprint: string; id: string } | null>(null);
  // Ist das Service-Geraet des Restaurants online? Ohne Presence-Daten bleibt
  // es bei "unknown" und die Cloud-Bestellung verhaelt sich wie bisher.
  const [hubAvailability, setHubAvailability] = useState<HubAvailability>({
    kind: "unknown",
  });
  // Tisch aus dem QR-Code. Bewusst erst nach der Hydration aus der URL gelesen,
  // damit die Karte prerendert bleibt (Begruendung in table-context.ts).
  const [tableContext, setTableContext] = useState<TableContext>({
    kind: "none",
  });

  useEffect(() => {
    const token = readTableToken(window.location.search);
    if (!token) {
      return;
    }
    let cancelled = false;
    const resolve = async () => {
      const supabase = getSupabase();
      if (!supabase) {
        // Ohne Backend laesst sich der Tisch nicht pruefen — und die
        // Bestellung ginge ohnehin nirgendwohin.
        setTableContext({ kind: "unknown", token });
        return;
      }
      setTableContext({ kind: "resolving", token });
      const table = await fetchTable(venue.slug, token, supabase);
      if (cancelled) {
        return;
      }
      setTableContext(
        table
          ? { kind: "resolved", token, label: table.label, area: table.area }
          : { kind: "unknown", token },
      );
    };
    void resolve();
    return () => {
      cancelled = true;
    };
  }, [venue.slug]);

  useEffect(() => {
    const supabase = getSupabase();
    if (!supabase) {
      return;
    }
    let cancelled = false;
    const check = async () => {
      const row = await fetchHubPresence(venue.slug, supabase);
      if (!cancelled) {
        setHubAvailability(evaluateHubPresence(row, Date.now()));
      }
    };
    void check();
    const timer = setInterval(() => void check(), HUB_POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [venue.slug]);

  const localFallback =
    hubAvailability.kind === "local_fallback" ? hubAvailability : null;
  // Ein QR-Code, den diese Venue nicht (mehr) kennt: die Bestellung wuerde
  // serverseitig abgewiesen. Sie hier zu blockieren ist die ehrlichere
  // Variante — eine Bestellung ohne zuordenbaren Tisch waere im Betrieb
  // teurer als eine, die gar nicht erst abgeschickt wird.
  const tableUnknown = tableContext.kind === "unknown";
  const tableToken =
    tableContext.kind === "resolved" ? tableContext.token : null;
  const tableLabel = tableContextLabel(tableContext);

  const sections = useMemo(
    () =>
      [
        { title: "Küche", items: venue.menu.filter((i) => i.kind === "food") },
        {
          title: "Getränke",
          items: venue.menu.filter((i) => i.kind === "drink"),
        },
      ].filter((section) => section.items.length > 0),
    [venue.menu],
  );

  const count = itemCount(cart);
  const total = totalCents(cart, venue.menu);

  return (
    <>
      {/* Randloser Venue-Kopf: das Restaurant fuehrt, Traube ist der
          sichere Fallback (§2, §9). Die Kontextzeile traegt den Tisch aus dem
          QR-Code, sonst wie bisher „Speisekarte". */}
      <header className="kl-venue-header">
        <div className="kl-venue-header-top">
          <h1 className="kl-type-display">{venue.name}</h1>
          <div className="kl-venue-header-actions">
            <ThemeToggle />
            <span className="kl-badge kl-badge-on-dark kl-type-meta">
              {venue.isOpen ? "geöffnet" : "geschlossen"}
            </span>
          </div>
        </div>
        <p className="kl-venue-header-context kl-type-secondary">
          {tableLabel ?? "Speisekarte"}
        </p>
      </header>

      <main className="kl-page">
        {tableUnknown && !localFallback && (
          <aside className="kl-hub-notice" role="status">
            <p className="kl-hub-notice-title kl-type-primary">
              Dieser QR-Code gilt nicht mehr
            </p>
            <p className="kl-hub-notice-text kl-type-secondary">
              Der Code auf dem Tisch ist abgelaufen oder gehört zu einem Tisch,
              den es nicht mehr gibt. Bitte scanne den aktuellen Code oder sag
              dem Personal Bescheid — sonst wüsste die Küche nicht, wohin die
              Bestellung soll.
            </p>
          </aside>
        )}

        {localFallback && (
          <aside className="kl-hub-notice" role="status">
            <p className="kl-hub-notice-title kl-type-primary">
              Online-Bestellung gerade nicht möglich
            </p>
            <p className="kl-hub-notice-text kl-type-secondary">
              Das Restaurant ist gerade nicht mit dem Internet verbunden. Du
              bist vor Ort? Verbinde dich mit dem WLAN des Restaurants und
              bestelle direkt lokal weiter.
            </p>
            <a
              className="kl-hub-notice-link kl-type-button"
              href={localFallback.localGuestUrl}
            >
              Lokal bestellen (nur im Restaurant-WLAN)
            </a>
          </aside>
        )}

        {sections.map((section) => (
          <section key={section.title} aria-label={section.title}>
            <h2 className="kl-type-section kl-menu-section-title">
              {section.title}
            </h2>
            <ul className="kl-menu-list">
              {section.items.map((item) => (
                <MenuRow
                  key={item.id}
                  item={item}
                  quantity={quantityForItem(cart, item.id)}
                  onAdd={(optionIDs) =>
                    setCart((current) => increment(current, item.id, optionIDs))
                  }
                  onDecrement={() =>
                    setCart((current) => decrementLastConfiguration(current, item.id))
                  }
                />
              ))}
            </ul>
          </section>
        ))}

        <p className="kl-trust-signature kl-type-meta">
          Bereitgestellt mit KitchenLink
        </p>
      </main>

      <div className="kl-order-bar">
        {/* Die gesamte Leiste ist die einzige dauerhafte Zitronenflaeche
            (§5, §9) und ein einzelnes, durchgehendes Aktionsziel. Ist das
            Service-Geraet offline, wird die Primaeraktion selbst zum
            Verweis auf die lokale Bestellseite im Restaurant-WLAN. */}
        {localFallback ? (
          <a
            className="kl-order-bar-button kl-order-bar-link"
            href={localFallback.localGuestUrl}
          >
            <span className="kl-type-button">
              Im Restaurant-WLAN lokal bestellen
            </span>
            <span className="kl-type-button" aria-hidden="true">
              →
            </span>
          </a>
        ) : tableUnknown ? (
          <button type="button" className="kl-order-bar-button" disabled>
            <span className="kl-type-button">Tisch nicht erkannt</span>
            <span className="kl-type-button" aria-hidden="true">
              ⚠
            </span>
          </button>
        ) : (
          <button
            type="button"
            className="kl-order-bar-button"
            disabled={count === 0 || submitState.kind === "submitting"}
            onClick={() => setSummaryOpen(true)}
          >
            <span className="kl-type-button kl-tabular">
              {count === 1 ? "1 Artikel" : `${count} Artikel`} · bestellen
            </span>
            <span className="kl-type-button kl-tabular">{formatEuro(total)}</span>
          </button>
        )}
      </div>

      {isSummaryOpen && (
        <OrderSummarySheet
          venue={venue}
          cart={submitState.kind === "accepted" && confirmedCart ? confirmedCart : cart}
          totalCents={submitState.kind === "accepted" ? submitState.ack.totalCents : total}
          tableLabel={tableContext.kind === "resolved" ? tableLabel : null}
          localFallbackUrl={localFallback?.localGuestUrl ?? null}
          submitState={submitState}
          onDecrementLine={(line) =>
            setCart((current) => decrement(current, line.itemID, line.optionIDs))
          }
          onIncrementLine={(line) =>
            setCart((current) => increment(current, line.itemID, line.optionIDs))
          }
          onClose={() => {
            // Nach bestätigter Bestellung schließt das Sheet in den Ausgangs-
            // zustand; ein Fehler bleibt sichtbar, bis der Nutzer das Sheet
            // schließt oder erneut sendet.
            setSubmitState((current: SubmitUiState) =>
              current.kind === "submitting" ? current : initialSubmitUiState(),
            );
            setConfirmedCart(null);
            setSummaryOpen(false);
          }}
          onSubmit={async () => {
            const cartAtSubmission = cart;
            const fingerprint = JSON.stringify(
              cartLines(cart)
                .map((line) => ({
                  id: line.id,
                  quantity: line.quantity,
                  optionIDs: [...line.optionIDs],
                }))
                .sort((left, right) => left.id.localeCompare(right.id)),
            );
            if (orderAttemptRef.current?.fingerprint !== fingerprint) {
              orderAttemptRef.current = {
                fingerprint,
                id: createOrderAttemptID(),
              };
            }
            setSubmitState(submittingState());
            const result = await submitOrder({
              venue,
              cart,
              attemptID: orderAttemptRef.current.id,
              tableToken,
              backend: createSupabaseOrderBackend(),
            });
            if (result.ok) {
              orderAttemptRef.current = null;
              setSubmitState(acceptedState(result.ack));
              setConfirmedCart(cartAtSubmission);
              setCart(emptyCart);
            } else {
              setSubmitState(errorState(result.message));
            }
          }}
        />
      )}
    </>
  );
}

interface MenuRowProps {
  item: GuestMenuItem;
  quantity: number;
  onAdd: (optionIDs: string[]) => void;
  onDecrement: () => void;
}

function MenuRow({ item, quantity, onAdd, onDecrement }: MenuRowProps) {
  const [selectedDeclaration, setSelectedDeclaration] = useState<GuestAllergen | null>(null);
  const [isDeclarationListOpen, setDeclarationListOpen] = useState(false);
  const [isConfigurationOpen, setConfigurationOpen] = useState(false);
  // Pflichtkennzeichnungen werden vollständig gezeigt; bei Platzmangel bricht
  // die Zeile um, statt Angaben hinter einem "+N" zu verbergen. Die Zeile ist
  // bewusst monochrom und ruhig — Fußnote, nicht Bedienelement; die gesamte
  // Zeile öffnet als ein Tap-Ziel die Klartextliste.
  const declarations = item.allergens ?? [];
  const hasChoices = (item.variants?.length ?? 0) > 0;
  const usesInlineAdd = quantity === 0;

  return (
    <li className="kl-menu-row">
      <div className="kl-menu-row-info">
        <div className="kl-menu-row-heading">
          <div className="kl-menu-row-name">
            <span className="kl-menu-item-title">{item.name}</span>
            {item.tag && (
              <span className="kl-badge kl-badge-on-light kl-type-meta">
                {item.tag}
              </span>
            )}
          </div>
          <div className="kl-menu-row-trailing">
            <div className="kl-menu-row-price kl-tabular">
              {formatEuro(item.priceCents)}
            </div>
            {usesInlineAdd && (
              <button
                type="button"
                className="kl-add-button kl-inline-add-button kl-type-button"
                onClick={() => hasChoices ? setConfigurationOpen(true) : onAdd([])}
                aria-label={`${item.name}: ${hasChoices ? "Auswahl öffnen" : "hinzufügen"}`}
                aria-haspopup={hasChoices ? "dialog" : undefined}
                aria-expanded={hasChoices ? isConfigurationOpen : undefined}
              >
                <span aria-hidden="true">+</span>
              </button>
            )}
          </div>
        </div>
        {(item.description || declarations.length > 0) && (
          <p className="kl-type-secondary kl-menu-row-description">
            {item.description}
            {declarations.length > 0 && (
              <button
                type="button"
                className="kl-declaration-inline"
                onClick={() => setDeclarationListOpen(true)}
                aria-haspopup="dialog"
                aria-expanded={isDeclarationListOpen}
                aria-label={`Kennzeichnungen: ${declarations
                  .map((allergen) => allergen.label)
                  .join(", ")}. Alle im Klartext anzeigen`}
              >
                {declarations.map((allergen) => (
                  <span key={allergen.code} className="kl-declaration-inline-glyph" aria-hidden="true">
                    <FoodDeclarationIcon declaration={allergen} />
                  </span>
                ))}
              </button>
            )}
          </p>
        )}
        {quantity > 0 && (
          <div className="kl-menu-row-stepper">
            <div className="kl-stepper" role="group" aria-label={`Menge: ${item.name}`}>
              <button
                type="button"
                className="kl-stepper-button kl-type-button"
                onClick={onDecrement}
                aria-label={`${item.name} verringern`}
              >
                −
              </button>
              <span
                className="kl-stepper-quantity kl-type-primary kl-tabular"
                aria-live="polite"
              >
                {quantity}
              </span>
              <button
                type="button"
                className="kl-stepper-button kl-type-button"
                onClick={() => hasChoices ? setConfigurationOpen(true) : onAdd([])}
                aria-label={`${item.name} ${hasChoices ? "erneut auswählen" : "erhöhen"}`}
              >
                +
              </button>
            </div>
          </div>
        )}
      </div>
      {isDeclarationListOpen && (
        <FoodDeclarationListDialog
          declarations={declarations}
          onSelect={(declaration) => {
            setDeclarationListOpen(false);
            setSelectedDeclaration(declaration);
          }}
          onClose={() => setDeclarationListOpen(false)}
        />
      )}
      {selectedDeclaration && (
        <FoodDeclarationDialog
          declaration={selectedDeclaration}
          onClose={() => setSelectedDeclaration(null)}
        />
      )}
      {isConfigurationOpen && (
        <MenuConfigurationDialog
          item={item}
          onAdd={(optionIDs) => {
            onAdd(optionIDs);
            setConfigurationOpen(false);
          }}
          onClose={() => setConfigurationOpen(false)}
        />
      )}
    </li>
  );
}

function MenuConfigurationDialog({
  item,
  onAdd,
  onClose,
}: {
  item: GuestMenuItem;
  onAdd: (optionIDs: string[]) => void;
  onClose: () => void;
}) {
  const dialogRef = useModalDialog<HTMLElement>(onClose);
  const groups = useMemo(() => optionGroups(item), [item]);
  const [selectedIDs, setSelectedIDs] = useState<string[]>([]);
  const optionIDs = selectedIDs;
  const canAdd = isValidConfiguration(item, optionIDs);
  const price = configuredUnitPrice(item, optionIDs);

  const toggle = (optionID: string, group: GuestOptionGroup) => {
    setSelectedIDs((current) => {
      let next = [...current];
      if (next.includes(optionID)) {
        if (group.selectionMode !== "single" || group.minimumSelections === 0) {
          next = next.filter((id) => id !== optionID);
        }
        return next;
      }
      const selectedOption = (item.variants ?? []).find(({ id }) => id === optionID);
      if (selectedOption?.priceKind === "fixed") {
        const fixedIDs = new Set(
          (item.variants ?? [])
            .filter(({ priceKind }) => priceKind === "fixed")
            .map(({ id }) => id),
        );
        next = next.filter((id) => id === optionID || !fixedIDs.has(id));
      }
      if (group.maximumSelections === 1) {
        const siblingIDs = new Set(group.options.map(({ id }) => id));
        next = next.filter((id) => !siblingIDs.has(id));
        next.push(optionID);
      } else {
        const siblingIDs = new Set(group.options.map(({ id }) => id));
        const selectedInGroup = next.filter((id) => siblingIDs.has(id)).length;
        if (selectedInGroup < group.maximumSelections) {
          next.push(optionID);
        }
      }
      return next;
    });
  };

  const changeRepeatCount = (
    optionID: string,
    group: GuestOptionGroup,
    delta: -1 | 1,
  ) => {
    setSelectedIDs((current) => {
      const index = current.lastIndexOf(optionID);
      if (delta < 0) {
        if (index < 0) return current;
        const next = [...current];
        next.splice(index, 1);
        return next;
      }

      const selectedOption = (item.variants ?? []).find(({ id }) => id === optionID);
      if (selectedOption?.priceKind === "fixed") return current;
      const siblingIDs = new Set(group.options.map(({ id }) => id));
      const selectedInGroup = current.filter((id) => siblingIDs.has(id)).length;
      if (selectedInGroup >= group.maximumSelections) return current;
      return [...current, optionID];
    });
  };

  return (
    <div
      className="kl-sheet-backdrop"
      onClick={onClose}
    >
      <section
        ref={dialogRef}
        tabIndex={-1}
        className="kl-sheet kl-configuration-sheet"
        role="dialog"
        aria-modal="true"
        aria-labelledby={`kl-config-title-${item.id}`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="kl-configuration-heading">
          <div>
            <h2 id={`kl-config-title-${item.id}`} className="kl-type-section">
              {item.name}
            </h2>
            {item.description && (
              <p className="kl-type-secondary">{item.description}</p>
            )}
          </div>
          <button
            type="button"
            className="kl-icon-close kl-type-button"
            onClick={onClose}
            aria-label="Schließen"
          >
            ×
          </button>
        </div>

        <div className="kl-configuration-groups">
          {groups.map((group) => {
            const groupIDs = new Set(group.options.map(({ id }) => id));
            const selectedCount = selectedIDs.filter((id) => groupIDs.has(id)).length;
            return (
              <div className="kl-configuration-group" key={group.id}>
                {group.title && (
                  <p className="kl-configuration-group-title kl-type-meta">
                    {group.title}
                  </p>
                )}
                {group.selectionMode !== "single" && group.freeSelectionCount > 0 && (
                  <p className="kl-choice-free kl-type-meta">
                    {group.freeSelectionCount === 1
                      ? "1 Auswahl inklusive, danach Aufpreis"
                      : `${group.freeSelectionCount} Auswahlen inklusive, danach Aufpreis`}
                  </p>
                )}
                {group.options.map((option) => {
                  const optionCount = selectedIDs.filter((id) => id === option.id).length;
                  const isSelected = optionCount > 0;
                  const usesCounter = group.allowsRepeats && option.priceKind !== "fixed";
                  if (usesCounter) {
                    return (
                      <div
                        key={option.id}
                        className={`kl-choice-row kl-choice-counter${isSelected ? " kl-choice-row-selected" : ""}`}
                      >
                        <span className="kl-choice-counter-info">
                          <span className="kl-type-primary">{option.name}</span>
                          <span className="kl-choice-price kl-type-secondary kl-tabular">
                            {optionPriceLabel(option, group)}
                          </span>
                        </span>
                        <div className="kl-choice-quantity" role="group" aria-label={`Menge ${option.name}`}>
                          <button
                            type="button"
                            onClick={() => changeRepeatCount(option.id, group, -1)}
                            disabled={optionCount === 0}
                            aria-label={`${option.name} entfernen`}
                          >
                            −
                          </button>
                          <span className="kl-tabular" aria-live="polite">{optionCount}</span>
                          <button
                            type="button"
                            onClick={() => changeRepeatCount(option.id, group, 1)}
                            disabled={selectedCount >= group.maximumSelections}
                            aria-label={`${option.name} hinzufügen`}
                          >
                            +
                          </button>
                        </div>
                      </div>
                    );
                  }
                  return (
                    <button
                      type="button"
                      key={option.id}
                      className={`kl-choice-row${isSelected ? " kl-choice-row-selected" : ""}`}
                      onClick={() => toggle(option.id, group)}
                      aria-pressed={isSelected}
                    >
                      <span className="kl-choice-mark" aria-hidden="true">
                        {group.selectionMode === "single"
                          ? isSelected ? "◉" : "○"
                          : isSelected ? "☑" : "☐"}
                      </span>
                      <span className="kl-type-primary">{option.name}</span>
                      <span className="kl-choice-price kl-type-secondary kl-tabular">
                        {optionPriceLabel(option, group)}
                      </span>
                    </button>
                  );
                })}
                {selectedCount < group.minimumSelections && (
                  <p className="kl-choice-required kl-type-meta">Bitte noch auswählen</p>
                )}
              </div>
            );
          })}
        </div>

        <button
          type="button"
          className="kl-primary-button kl-configuration-add kl-type-button"
          disabled={!canAdd}
          onClick={() => onAdd([...selectedIDs].sort())}
        >
          <span>Hinzufügen</span>
          <span className="kl-tabular">{formatEuro(price)}</span>
        </button>
      </section>
    </div>
  );
}

function optionPriceLabel(
  option: NonNullable<GuestMenuItem["variants"]>[number],
  group: GuestOptionGroup,
): string {
  switch (option.priceKind) {
    case "fixed":
      return formatEuro(option.priceCents);
    case "delta":
      return `${group.selectionMode !== "single" && group.freeSelectionCount > 0 ? "danach " : ""}+${formatEuro(option.priceCents)}`;
    default:
      return "inklusive";
  }
}

function FoodDeclarationListDialog({
  declarations,
  onSelect,
  onClose,
}: {
  declarations: GuestAllergen[];
  onSelect: (declaration: GuestAllergen) => void;
  onClose: () => void;
}) {
  const dialogRef = useModalDialog<HTMLElement>(onClose);
  return (
    <div className="kl-declaration-backdrop" onClick={onClose}>
      <section
        ref={dialogRef}
        tabIndex={-1}
        className="kl-declaration-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="kl-declaration-list-title"
        onClick={(event) => event.stopPropagation()}
      >
        <h2 id="kl-declaration-list-title" className="kl-type-section">
          Kennzeichnungen
        </h2>
        <div className="kl-declaration-list">
          {declarations.map((declaration) => (
            <button
              type="button"
              key={declaration.code}
              className="kl-declaration-list-row"
              onClick={() => onSelect(declaration)}
            >
              <span className={`kl-declaration-list-icon kl-allergen-badge-${declaration.group}`}>
                <FoodDeclarationIcon declaration={declaration} />
              </span>
              <span>
                <span className="kl-type-primary">{declaration.label}</span>
                <span className="kl-declaration-list-meta kl-type-meta">
                  {declaration.groupLabel}
                </span>
              </span>
            </button>
          ))}
        </div>
        <p className="kl-declaration-note kl-type-meta">
          Die Symbole ergänzen die schriftliche Kennzeichnung. Bei Allergien
          oder Unverträglichkeiten bitte das Restaurantpersonal ansprechen.
        </p>
        <button type="button" className="kl-secondary-button kl-type-button" onClick={onClose}>
          Fertig
        </button>
      </section>
    </div>
  );
}

function FoodDeclarationDialog({
  declaration,
  onClose,
}: {
  declaration: GuestAllergen;
  onClose: () => void;
}) {
  const dialogRef = useModalDialog<HTMLElement>(onClose);
  return (
    <div
      className="kl-declaration-backdrop"
      onClick={onClose}
    >
      <section
        ref={dialogRef}
        tabIndex={-1}
        className="kl-declaration-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby={`kl-declaration-title-${declaration.code}`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className={`kl-declaration-hero kl-allergen-badge-${declaration.group}`}>
          <FoodDeclarationIcon declaration={declaration} />
        </div>
        <p className="kl-declaration-group kl-type-meta">{declaration.groupLabel}</p>
        <h2 id={`kl-declaration-title-${declaration.code}`} className="kl-type-section">
          {declaration.label}
        </h2>
        <p className="kl-declaration-detail kl-type-secondary">{declaration.detail}</p>
        <p className="kl-declaration-note kl-type-meta">
          Das Symbol ergänzt die schriftliche Kennzeichnung. Bei Allergien oder
          Unverträglichkeiten bitte das Restaurantpersonal ansprechen.
        </p>
        <button
          type="button"
          className="kl-secondary-button kl-type-button"
          onClick={onClose}
        >
          Fertig
        </button>
      </section>
    </div>
  );
}

function FoodDeclarationIcon({ declaration }: { declaration: GuestAllergen }) {
  const common = {
    viewBox: "0 0 24 24",
    className: "kl-declaration-icon",
    "aria-hidden": true,
  } as const;
  const strokeProps = {
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };

  switch (declaration.glyph) {
    case "wheat":
      return <svg {...common} {...strokeProps}><path d="M12 21V4M12 7 8 5.5M12 10l4-2M12 13l-4-2M12 16l4-2M8 5.5c0 2 1.7 3 4 3M16 8c0 2-1.7 3-4 3M8 11c0 2 1.7 3 4 3M16 14c0 2-1.7 3-4 3" /></svg>;
    case "crustacean":
      return <svg {...common} {...strokeProps}><path d="M19 7c-3-5-10-4-12-1-4 5 0 12 5 12 4 0 6-2 6-5M8 7l7 8m-3-10 6 6m0-5 4-3m-4 4 4 1" /><circle cx="17" cy="6" r="1" fill="currentColor" stroke="none" /></svg>;
    case "egg":
      return <svg {...common} {...strokeProps}><path d="M12 2.5C8 5 5 10 5 15a7 7 0 0 0 14 0c0-5-3-10-7-12.5Z" /><circle cx="12" cy="14.5" r="3" fill="currentColor" stroke="none" /></svg>;
    case "fish":
      return <svg {...common} {...strokeProps}><path d="M3 12c4-7 10-6 14-4l4-3-1 7 1 7-4-3c-4 2-10 3-14-4Z" /><circle cx="8.5" cy="10" r="1" fill="currentColor" stroke="none" /></svg>;
    case "peanut":
      return <svg {...common} {...strokeProps}><path d="M7 4c-4 3-1 7 3 8-2 4 2 10 6 8s1-7-2-9c2-4-3-10-7-7Zm0 3 10 10m-6-12-4 5m10 3-4 6" /></svg>;
    case "soy":
      return <svg {...common} {...strokeProps}><path d="M4 17C7 7 15 3 20 6c-2 10-10 15-16 11Z" /><circle cx="8.5" cy="14" r="1.5" fill="currentColor" stroke="none" /><circle cx="13" cy="10.5" r="1.5" fill="currentColor" stroke="none" /><circle cx="17" cy="8" r="1.4" fill="currentColor" stroke="none" /></svg>;
    case "milk":
      return <svg {...common} {...strokeProps}><path d="m6 7 4-4 8 3v15H6V7Zm0 0 8 2 4-3M14 9v12M10 3v5" /></svg>;
    case "treeNut":
      return <svg {...common} {...strokeProps}><path d="M12 6c-5 1-7 4-7 7a7 7 0 0 0 14 0c0-3-2-6-7-7ZM7 8h10m-5-2 2-4" /></svg>;
    case "celery":
      return <svg {...common} {...strokeProps}><path d="m8 21 2-13m2 13V6m4 15-2-13M6 21h12" /><path d="M10 8C5 9 4 4 8 3c3-1 4 2 4 4 0-4 5-7 7-3 2 4-3 5-5 4" fill="currentColor" stroke="none" /></svg>;
    case "mustard":
      return <svg {...common} {...strokeProps}><path d="M7 4h10l1 3H6l1-3Zm-1 3h12v14H6V7Z" /><circle cx="12" cy="14" r="3" fill="currentColor" stroke="none" /></svg>;
    case "sesame":
      return <svg {...common} {...strokeProps}><ellipse cx="8" cy="12" rx="2.5" ry="4.5" /><ellipse cx="13" cy="8" rx="2.5" ry="4.5" /><ellipse cx="16" cy="16" rx="2.5" ry="4.5" /></svg>;
    case "sulfite":
      return <FormulaIcon text="SO₂" />;
    case "lupin":
      return <svg {...common} {...strokeProps}><path d="M12 21V7" /><circle cx="12" cy="5" r="3" fill="currentColor" stroke="none" /><circle cx="8.5" cy="9" r="2.5" fill="currentColor" stroke="none" /><circle cx="15.5" cy="10" r="2.5" fill="currentColor" stroke="none" /><circle cx="9.5" cy="14" r="2" fill="currentColor" stroke="none" /><circle cx="14.5" cy="15" r="2" fill="currentColor" stroke="none" /></svg>;
    case "mollusc":
      return <svg {...common} {...strokeProps}><path d="M4 19C3 10 7 4 12 4s9 6 8 15H4Zm8-14v14M8 6l1 13m7-13-1 13M5 19h14" /></svg>;
    case "nitrite": return <FormulaIcon text="NO₂" />;
    case "nitrate": return <FormulaIcon text="NO₃" />;
    case "curingSalts": return <FormulaIcon text="N₂" />;
    case "phosphate": return <FormulaIcon text="PO₄" />;
    case "phenylalanine": return <FormulaIcon text="Phe" small />;
    case "polyols": return <FormulaIcon text="10%" small />;
    case "quinine": return <FormulaIcon text="Q" />;
    case "genericAdditive": return <FormulaIcon text="E" />;
    case "colorant":
      return <svg {...common} {...strokeProps}><path d="M12 3a9 9 0 1 0 0 18h2a2 2 0 0 0 0-4h-1a2 2 0 0 1 0-4h8" /><circle cx="8" cy="9" r="1.3" fill="currentColor" stroke="none" /><circle cx="12" cy="7" r="1.3" fill="currentColor" stroke="none" /><circle cx="16" cy="9" r="1.3" fill="currentColor" stroke="none" /></svg>;
    case "preservative":
      return <svg {...common} {...strokeProps}><path d="M7 4h10v3l2 2v12H5V9l2-2V4Zm0 3h10" /></svg>;
    case "antioxidant":
      return <svg {...common} {...strokeProps}><path d="m12 3 8 3v6c0 5-3 8-8 10-5-2-8-5-8-10V6l8-3Zm0 4v10m-4-5h8" /></svg>;
    case "flavorEnhancer":
      return <svg {...common} {...strokeProps}><path d="M4 16c4-4 12-4 16 0M6 12c3-3 9-3 12 0M9 8c2-2 4-2 6 0" /></svg>;
    case "blackened":
      return <svg {...common}><circle cx="12" cy="12" r="8" fill="currentColor" /><path d="M12 4a8 8 0 0 0 0 16Z" fill="var(--kl-surface-card)" /></svg>;
    case "waxed":
      return <svg {...common} {...strokeProps}><path d="m12 3 1.5 4.5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1.5L12 3Zm6 10 .8 2.2L21 16l-2.2.8L18 19l-.8-2.2L15 16l2.2-.8L18 13Z" /></svg>;
    case "sweetener":
      return <svg {...common} {...strokeProps}><path d="m5 8 7-4 7 4v8l-7 4-7-4V8Zm0 0 7 4 7-4m-7 4v8" /></svg>;
    case "tableSweetener":
      return <svg {...common} {...strokeProps}><path d="M4 15c4 4 12 4 16 0-4-2-12-2-16 0Zm8-2V4m-3 3h6" /></svg>;
    case "caffeine":
      return <svg {...common} {...strokeProps}><path d="M5 8h12v6a6 6 0 0 1-12 0V8Zm12 2h2a3 3 0 0 1 0 6h-2M7 21h10M8 4c1 1 1 2 0 3m4-3c1 1 1 2 0 3" /></svg>;
    case "liquorice":
      return <svg {...common} {...strokeProps}><path d="M12 4a8 8 0 1 1-8 8c0-4 3-6 6-6 4 0 6 3 6 6 0 2-2 4-4 4s-4-2-4-4 2-3 4-3c2 0 3 1 3 3" /></svg>;
    case "alcohol":
      return <svg {...common} {...strokeProps}><path d="M7 3h10l-1 7a4 4 0 0 1-8 0L7 3Z" /><path d="M8 8h8M12 14v7M8 21h8" /></svg>;
    case "notice":
      return <svg {...common} {...strokeProps}><path d="M4 5h16v12H9l-5 4V5Zm4 4h8m-8 4h5" /></svg>;
    default:
      return <FormulaIcon text="?" />;
  }
}

function FormulaIcon({ text, small = false }: { text: string; small?: boolean }) {
  return (
    <svg viewBox="0 0 24 24" className="kl-declaration-icon" aria-hidden="true">
      <text x="12" y="13" textAnchor="middle" dominantBaseline="middle" className={small ? "kl-icon-formula-small" : "kl-icon-formula"}>
        {text}
      </text>
    </svg>
  );
}

interface OrderSummarySheetProps {
  venue: GuestVenue;
  cart: Cart;
  totalCents: number;
  /** Sichtbare Tischangabe, sofern die Karte ueber einen Tisch-QR kam. */
  tableLabel: string | null;
  localFallbackUrl: string | null;
  submitState: SubmitUiState;
  onDecrementLine: (line: CartLine) => void;
  onIncrementLine: (line: CartLine) => void;
  onClose: () => void;
  onSubmit: () => void | Promise<void>;
}

function OrderSummarySheet({
  venue,
  cart,
  totalCents,
  tableLabel,
  localFallbackUrl,
  submitState,
  onDecrementLine,
  onIncrementLine,
  onClose,
  onSubmit,
}: OrderSummarySheetProps) {
  const dialogRef = useModalDialog<HTMLDivElement>(onClose);
  const itemsByID = new Map(venue.menu.map((item) => [item.id, item]));
  const lines = cartLines(cart).flatMap((line) => {
    const item = itemsByID.get(line.itemID);
    return item ? [{ line, item }] : [];
  });
  const isSubmitting = submitState.kind === "submitting";
  // Nach einer bestätigten Bestellung ist der Warenkorb geleert; ein erneuter
  // Klick würde "leerer Warenkorb" melden. Die Bestellung ist bereits raus —
  // der Submit-Button hat nichts mehr zu tun und wird deaktiviert.
  const isAccepted = submitState.kind === "accepted";
  // Service-Geraet offline: eine Cloud-Bestellung wuerde niemand sehen. Der
  // Submit wird gesperrt und der lokale Weg angeboten (eine bereits
  // bestaetigte Bestellung bleibt unveraendert sichtbar).
  const isLocalFallback = localFallbackUrl !== null && !isAccepted;

  return (
    <div
      className="kl-sheet-backdrop"
      onClick={onClose}
    >
      <div
        ref={dialogRef}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby="kl-order-summary-title"
        className="kl-sheet"
        onClick={(event) => event.stopPropagation()}
      >
        <h2 id="kl-order-summary-title" className="kl-type-section">
          Deine Auswahl
        </h2>
        {tableLabel && (
          <p className="kl-sheet-table kl-type-meta">Für {tableLabel}</p>
        )}
        <ul className="kl-sheet-lines">
          {lines.map(({ line, item }) => {
            const choices = selectedOptions(item, line.optionIDs);
            const unitPrice = configuredUnitPrice(item, line.optionIDs);
            return (
              <li key={line.id} className="kl-sheet-line">
                <span className="kl-sheet-line-copy kl-type-secondary">
                  <span>
                    <span className="kl-tabular">{line.quantity}×</span> {item.name}
                  </span>
                  {choices.length > 0 && (
                    <span className="kl-sheet-line-options kl-type-meta">
                      {choices.map(({ name }) => name).join(" · ")}
                    </span>
                  )}
                </span>
                <span className="kl-sheet-line-trailing">
                  <span className="kl-type-primary kl-tabular">
                    {formatEuro(line.quantity * unitPrice)}
                  </span>
                  {!isAccepted && (
                    <span
                      className="kl-stepper kl-sheet-line-stepper"
                      role="group"
                      aria-label={`Menge: ${item.name}${choices.length > 0 ? `, ${choices.map(({ name }) => name).join(", ")}` : ""}`}
                    >
                      <button
                        type="button"
                        className="kl-stepper-button kl-type-button"
                        onClick={() => onDecrementLine(line)}
                        disabled={isSubmitting}
                        aria-label="Diese Auswahl verringern"
                      >
                        −
                      </button>
                      <span className="kl-stepper-quantity kl-type-primary kl-tabular">
                        {line.quantity}
                      </span>
                      <button
                        type="button"
                        className="kl-stepper-button kl-type-button"
                        onClick={() => onIncrementLine(line)}
                        disabled={isSubmitting}
                        aria-label="Diese Auswahl erhöhen"
                      >
                        +
                      </button>
                    </span>
                  )}
                </span>
              </li>
            );
          })}
        </ul>
        <div className="kl-sheet-total">
          <span className="kl-type-primary">Summe</span>
          <span className="kl-type-primary kl-tabular">
            {formatEuro(totalCents)}
          </span>
        </div>

        {isLocalFallback && (
          <p className="kl-sheet-note kl-type-secondary" role="alert">
            Das Restaurant ist gerade nicht online erreichbar. Verbinde dich
            mit dem Restaurant-WLAN und{" "}
            <a className="kl-hub-inline-link" href={localFallbackUrl}>
              bestelle lokal weiter
            </a>
            .
          </p>
        )}

        <SubmitStatusRow submitState={submitState} />

        <div className="kl-sheet-actions">
          <button
            type="button"
            className="kl-primary-button kl-type-button"
            onClick={onSubmit}
            disabled={
              isSubmitting || isAccepted || isLocalFallback || lines.length === 0
            }
          >
            {isSubmitting
              ? "Übermitteln…"
              : isAccepted
                ? "Bestellung eingegangen ✓"
                : isLocalFallback
                  ? "Online-Bestellung nicht möglich"
                  : "Sandbox-Bestellung senden"}
          </button>
          <button
            type="button"
            className="kl-secondary-button kl-type-button"
            onClick={onClose}
            disabled={isSubmitting}
            autoFocus={isAccepted}
          >
            {isAccepted ? "Fertig" : "Zurück zur Karte"}
          </button>
        </div>
      </div>
    </div>
  );
}

function SubmitStatusRow({ submitState }: { submitState: SubmitUiState }) {
  if (submitState.kind === "accepted") {
    const ack = submitState.ack;
    return (
      // Prominente Erfolgsbestaetigung (eigene Flaeche, nicht die graue Notiz).
      // Bewusst KEINE Zitrone (die bleibt dem CTA vorbehalten, §5/§9): die
      // Bestaetigung ist eine ruhige Erfolgsflaeche mit großem Status-Symbol.
      <div className="kl-confirmation" role="status" aria-live="polite">
        <div className="kl-confirmation-check" aria-hidden="true">✓</div>
        <div className="kl-confirmation-body">
          <p className="kl-confirmation-title kl-type-section">Bestellung eingegangen</p>
          <p className="kl-confirmation-meta kl-type-secondary">
            Bestellnummer: <span className="kl-tabular">{ack.orderId.slice(0, 8)}</span>
            {ack.idempotentReplay ? " · idempotente Wiederholung" : ""}
          </p>
          <p className="kl-confirmation-status kl-type-meta">
            Status: {ack.status} · {formatEuro(ack.totalCents)} · Sandbox, kein Echtgeld
          </p>
        </div>
      </div>
    );
  }
  if (submitState.kind === "error") {
    return (
      <p className="kl-sheet-note kl-type-secondary" role="alert">
        Übermittlung fehlgeschlagen: {submitState.message}. Keine Bestellung
        gespeichert.
      </p>
    );
  }
  if (submitState.kind === "submitting") {
    return (
      <p className="kl-sheet-note kl-type-secondary" aria-live="polite">
        Übermitteln … noch nicht bestätigt.
      </p>
    );
  }
  return (
    <p className="kl-sheet-note kl-type-secondary">
      Sandbox: Nach dem Senden wird die autoritative Bestellgrenze
      (Supabase-Anonymous-Sign-in + RPC) aufgerufen. Es wird nichts bezahlt.
      Ohne laufende Supabase-Instanz schlägt das Senden fehl.
    </p>
  );
}
