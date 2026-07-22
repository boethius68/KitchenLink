import { configuredUnitPrice, isValidConfiguration } from "./menu-options";
import type { GuestMenuItem } from "./venue-data";

/** Eine Warenkorbzeile entspricht genau einer konfigurierten Ausführung. */
export interface CartLine {
  id: string;
  itemID: string;
  optionIDs: readonly string[];
  quantity: number;
}

export type Cart = Readonly<Record<string, CartLine>>;

export const emptyCart: Cart = {};

export const MAX_QUANTITY = 99;

export function cartLineID(itemID: string, optionIDs: readonly string[] = []): string {
  return [itemID, ...[...optionIDs].sort()]
    .map((part) => encodeURIComponent(part))
    .join("::");
}

export function setQuantity(
  cart: Cart,
  itemID: string,
  quantity: number,
  optionIDs: readonly string[] = [],
): Cart {
  const normalizedOptions = [...optionIDs].sort();
  const id = cartLineID(itemID, normalizedOptions);
  const clamped = Math.min(MAX_QUANTITY, Math.max(0, Math.trunc(quantity)));
  if (clamped === 0) {
    if (!(id in cart)) {
      return cart;
    }
    const next = { ...cart };
    delete next[id];
    return next;
  }
  const next = { ...cart };
  // Neu gesetzte/erhöhte Zeilen ans Ende verschieben. So bezeichnet das
  // kompakte Minus in der Menüzeile tatsächlich die zuletzt berührte Auswahl.
  delete next[id];
  return {
    ...next,
    [id]: { id, itemID, optionIDs: normalizedOptions, quantity: clamped },
  };
}

export function increment(
  cart: Cart,
  itemID: string,
  optionIDs: readonly string[] = [],
): Cart {
  const id = cartLineID(itemID, optionIDs);
  return setQuantity(cart, itemID, (cart[id]?.quantity ?? 0) + 1, optionIDs);
}

export function decrement(
  cart: Cart,
  itemID: string,
  optionIDs: readonly string[] = [],
): Cart {
  const id = cartLineID(itemID, optionIDs);
  return setQuantity(cart, itemID, (cart[id]?.quantity ?? 0) - 1, optionIDs);
}

/** Entfernt eine Einheit der zuletzt hinzugefügten Konfiguration des Artikels. */
export function decrementLastConfiguration(cart: Cart, itemID: string): Cart {
  const line = Object.values(cart).findLast((candidate) => candidate.itemID === itemID);
  return line ? decrement(cart, line.itemID, line.optionIDs) : cart;
}

export function cartLines(cart: Cart): CartLine[] {
  return Object.values(cart).filter((line) => line.quantity > 0);
}

export function quantityForItem(cart: Cart, itemID: string): number {
  return cartLines(cart).reduce(
    (sum, line) => sum + (line.itemID === itemID ? line.quantity : 0),
    0,
  );
}

export function itemCount(cart: Cart): number {
  return cartLines(cart).reduce((sum, line) => sum + line.quantity, 0);
}

export function totalCents(cart: Cart, items: readonly GuestMenuItem[]): number {
  const byID = new Map(items.map((item) => [item.id, item]));
  return cartLines(cart).reduce((sum, line) => {
    const item = byID.get(line.itemID);
    if (!item || !isValidConfiguration(item, line.optionIDs)) {
      return sum;
    }
    return sum + line.quantity * configuredUnitPrice(item, line.optionIDs);
  }, 0);
}

const euroFormatter = new Intl.NumberFormat("de-DE", {
  style: "currency",
  currency: "EUR",
});

export function formatEuro(cents: number): string {
  return euroFormatter.format(cents / 100);
}
