import type { GuestMenuItem } from "./venue-data";

/**
 * Reiner, testbarer Warenkorbzustand: Artikel-ID -> Menge.
 * Preise werden nie im Warenkorb gespeichert; die Summe entsteht
 * ausschließlich aus den Menüdaten. Die spätere autoritative
 * Bestellgrenze rechnet serverseitig ohnehin neu (ADR-001 §6).
 */
export type Cart = Readonly<Record<string, number>>;

export const emptyCart: Cart = {};

export const MAX_QUANTITY = 99;

export function setQuantity(cart: Cart, itemID: string, quantity: number): Cart {
  const clamped = Math.min(MAX_QUANTITY, Math.max(0, Math.trunc(quantity)));
  if (clamped === 0) {
    if (!(itemID in cart)) {
      return cart;
    }
    const next = { ...cart };
    delete next[itemID];
    return next;
  }
  return { ...cart, [itemID]: clamped };
}

export function increment(cart: Cart, itemID: string): Cart {
  return setQuantity(cart, itemID, (cart[itemID] ?? 0) + 1);
}

export function decrement(cart: Cart, itemID: string): Cart {
  return setQuantity(cart, itemID, (cart[itemID] ?? 0) - 1);
}

export function itemCount(cart: Cart): number {
  return Object.values(cart).reduce((sum, quantity) => sum + quantity, 0);
}

export function totalCents(cart: Cart, items: readonly GuestMenuItem[]): number {
  return items.reduce((sum, item) => {
    const quantity = cart[item.id] ?? 0;
    return sum + quantity * item.priceCents;
  }, 0);
}

const euroFormatter = new Intl.NumberFormat("de-DE", {
  style: "currency",
  currency: "EUR",
});

export function formatEuro(cents: number): string {
  return euroFormatter.format(cents / 100);
}
