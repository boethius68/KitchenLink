"use client";

import { useMemo, useState } from "react";
import {
  type Cart,
  decrement,
  emptyCart,
  formatEuro,
  increment,
  itemCount,
  totalCents,
} from "@/lib/cart";
import type { GuestMenuItem, GuestVenue } from "@/lib/venue-data";

interface GuestMenuCardProps {
  venue: GuestVenue;
}

export function GuestMenuCard({ venue }: GuestMenuCardProps) {
  const [cart, setCart] = useState<Cart>(emptyCart);
  const [isSummaryOpen, setSummaryOpen] = useState(false);

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
            (§5, §9) und ein einzelnes, durchgehendes Aktionsziel. */}
        <button
          type="button"
          className="kl-order-bar-button"
          disabled={count === 0}
          onClick={() => setSummaryOpen(true)}
        >
          <span className="kl-type-button kl-tabular">
            {count === 1 ? "1 Artikel" : `${count} Artikel`} · bestellen
          </span>
          <span className="kl-type-button kl-tabular">{formatEuro(total)}</span>
        </button>
      </div>

      {isSummaryOpen && (
        <OrderSummarySheet
          venue={venue}
          cart={cart}
          totalCents={total}
          onClose={() => setSummaryOpen(false)}
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
  onClose: () => void;
}

function OrderSummarySheet({
  venue,
  cart,
  totalCents,
  onClose,
}: OrderSummarySheetProps) {
  const lines = venue.menu.filter((item) => (cart[item.id] ?? 0) > 0);

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
        <p className="kl-sheet-note kl-type-secondary">
          Sandbox: Die verbindliche Übermittlung folgt mit der autoritativen
          Bestellgrenze. Es wird nichts bestellt und nichts bezahlt.
        </p>
        <button
          type="button"
          className="kl-secondary-button kl-type-button"
          onClick={onClose}
          autoFocus
        >
          Zurück zur Karte
        </button>
      </div>
    </div>
  );
}
