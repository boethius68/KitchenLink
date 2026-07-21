"use client";

import { useEffect, useMemo, useState } from "react";
import {
  type Cart,
  decrement,
  emptyCart,
  formatEuro,
  increment,
  itemCount,
  totalCents,
} from "@/lib/cart";
import {
  createSupabaseOrderBackend,
} from "@/lib/order-backend-supabase";
import { submitOrder } from "@/lib/order-submit";
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
import { getSupabase } from "@/lib/supabase-client";
import type { GuestMenuItem, GuestVenue } from "@/lib/venue-data";

interface GuestMenuCardProps {
  venue: GuestVenue;
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
  // Ist das Service-Geraet des Restaurants online? Ohne Presence-Daten bleibt
  // es bei "unknown" und die Cloud-Bestellung verhaelt sich wie bisher.
  const [hubAvailability, setHubAvailability] = useState<HubAvailability>({
    kind: "unknown",
  });

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
          sichere Fallback (§2, §9). Tisch-/Kanalkontext ist ein Platzhalter,
          solange es noch keine echte QR-/Tisch-Session gibt. */}
      <header className="kl-venue-header">
        <div className="kl-venue-header-top">
          <h1 className="kl-type-display">{venue.name}</h1>
          <span className="kl-badge kl-badge-on-dark kl-type-meta">
            {venue.isOpen ? "geöffnet" : "geschlossen"}
          </span>
        </div>
        <p className="kl-venue-header-context kl-type-secondary">Speisekarte</p>
      </header>

      <main className="kl-page">
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
                  quantity={cart[item.id] ?? 0}
                  onIncrement={() => setCart((c) => increment(c, item.id))}
                  onDecrement={() => setCart((c) => decrement(c, item.id))}
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
          localFallbackUrl={localFallback?.localGuestUrl ?? null}
          submitState={submitState}
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
            setSubmitState(submittingState());
            const result = await submitOrder({
              venue,
              cart,
              backend: createSupabaseOrderBackend(),
            });
            if (result.ok) {
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
  onIncrement: () => void;
  onDecrement: () => void;
}

function variantKindLabel(kind: "portion" | "extra" | "variant"): string {
  switch (kind) {
    case "portion":
      return "Portion";
    case "extra":
      return "Extra";
    default:
      return "Variante";
  }
}

function MenuRow({ item, quantity, onIncrement, onDecrement }: MenuRowProps) {
  return (
    <li className="kl-menu-row">
      <div className="kl-menu-row-info">
        <div className="kl-menu-row-name">
          <span className="kl-type-primary">{item.name}</span>
          {item.tag && (
            <span className="kl-badge kl-badge-on-light kl-type-meta">
              {item.tag}
            </span>
          )}
        </div>
        <p className="kl-type-secondary">{item.description}</p>
        {item.allergens && item.allergens.length > 0 && (
          <ul className="kl-allergen-row" aria-label="Allergene und Zusatzstoffe">
            {item.allergens.map((allergen) => (
              <li
                key={allergen.code}
                className="kl-allergen-badge"
                title={allergen.label}
              >
                <span className="kl-allergen-code kl-type-meta" aria-hidden="true">
                  {allergen.code.toUpperCase()}
                </span>
                <span className="kl-allergen-label kl-type-meta">
                  {allergen.label}
                </span>
              </li>
            ))}
          </ul>
        )}
        {item.variants && item.variants.length > 0 && (
          <ul className="kl-variant-list">
            {item.variants.map((variant, index) => (
              <li
                key={`${variant.kind}-${index}`}
                className="kl-variant-row kl-type-meta"
              >
                <span className="kl-variant-name">
                  {variantKindLabel(variant.kind)}: {variant.name}
                </span>
                <span className="kl-tabular">
                  {variant.kind === "extra" ? "+" : ""}
                  {formatEuro(variant.priceCents)}
                </span>
              </li>
            ))}
          </ul>
        )}
        <div className="kl-menu-row-price kl-type-primary kl-tabular">
          {formatEuro(item.priceCents)}
        </div>
      </div>
      {/* Umrandete Mengensteuerung, traubenbasiert, nie Zitrone (§5). */}
      {quantity === 0 ? (
        <button
          type="button"
          className="kl-add-button kl-type-button"
          onClick={onIncrement}
          aria-label={`${item.name} hinzufügen`}
        >
          +
        </button>
      ) : (
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
            onClick={onIncrement}
            aria-label={`${item.name} erhöhen`}
          >
            +
          </button>
        </div>
      )}
    </li>
  );
}

interface OrderSummarySheetProps {
  venue: GuestVenue;
  cart: Cart;
  totalCents: number;
  localFallbackUrl: string | null;
  submitState: SubmitUiState;
  onClose: () => void;
  onSubmit: () => void | Promise<void>;
}

function OrderSummarySheet({
  venue,
  cart,
  totalCents,
  localFallbackUrl,
  submitState,
  onClose,
  onSubmit,
}: OrderSummarySheetProps) {
  const lines = venue.menu.filter((item) => (cart[item.id] ?? 0) > 0);
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
      onKeyDown={(event) => {
        if (event.key === "Escape") {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="kl-order-summary-title"
        className="kl-sheet"
        onClick={(event) => event.stopPropagation()}
      >
        <h2 id="kl-order-summary-title" className="kl-type-section">
          Deine Auswahl
        </h2>
        <ul className="kl-sheet-lines">
          {lines.map((item) => {
            const quantity = cart[item.id] ?? 0;
            return (
              <li key={item.id} className="kl-sheet-line">
                <span className="kl-type-secondary">
                  <span className="kl-tabular">{quantity}×</span> {item.name}
                </span>
                <span className="kl-type-primary kl-tabular">
                  {formatEuro(quantity * item.priceCents)}
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
