import { describe, expect, it } from "vitest";
import {
  MAX_QUANTITY,
  decrement,
  emptyCart,
  formatEuro,
  increment,
  itemCount,
  setQuantity,
  totalCents,
} from "@/lib/cart";
import { sandboxVenues } from "@/lib/venue-data";

const menu = sandboxVenues[0].menu;

describe("setQuantity", () => {
  it("stores clamped integer quantities", () => {
    expect(setQuantity(emptyCart, "a", 3)).toEqual({ a: 3 });
    expect(setQuantity(emptyCart, "a", 2.9)).toEqual({ a: 2 });
    expect(setQuantity(emptyCart, "a", MAX_QUANTITY + 10)).toEqual({
      a: MAX_QUANTITY,
    });
  });

  it("removes entries at zero and below", () => {
    const cart = setQuantity(emptyCart, "a", 2);
    expect(setQuantity(cart, "a", 0)).toEqual({});
    expect(setQuantity(cart, "a", -5)).toEqual({});
  });

  it("returns the same cart when removing an absent item", () => {
    expect(setQuantity(emptyCart, "missing", 0)).toBe(emptyCart);
  });

  it("does not mutate the previous cart", () => {
    const cart = setQuantity(emptyCart, "a", 1);
    increment(cart, "a");
    expect(cart).toEqual({ a: 1 });
  });
});

describe("increment/decrement", () => {
  it("walks quantities up and down", () => {
    let cart = increment(emptyCart, "a");
    cart = increment(cart, "a");
    expect(cart).toEqual({ a: 2 });
    cart = decrement(cart, "a");
    expect(cart).toEqual({ a: 1 });
    cart = decrement(cart, "a");
    expect(cart).toEqual({});
  });

  it("keeps the cart empty when decrementing an absent item", () => {
    expect(decrement(emptyCart, "a")).toEqual({});
  });

  it("caps increments at MAX_QUANTITY", () => {
    const cart = setQuantity(emptyCart, "a", MAX_QUANTITY);
    expect(increment(cart, "a")).toEqual({ a: MAX_QUANTITY });
  });
});

describe("totals", () => {
  it("counts items across lines", () => {
    let cart = setQuantity(emptyCart, menu[0].id, 2);
    cart = setQuantity(cart, menu[1].id, 1);
    expect(itemCount(cart)).toBe(3);
  });

  it("sums cents from menu prices only", () => {
    let cart = setQuantity(emptyCart, menu[0].id, 2);
    cart = setQuantity(cart, "unknown-item", 5);
    expect(totalCents(cart, menu)).toBe(2 * menu[0].priceCents);
  });

  it("is zero for the empty cart", () => {
    expect(totalCents(emptyCart, menu)).toBe(0);
  });
});

describe("formatEuro", () => {
  it("formats German euro amounts from cents", () => {
    // Intl nutzt geschütztes Leerzeichen zwischen Betrag und Symbol.
    expect(formatEuro(1150).replace(/ /g, " ")).toBe("11,50 €");
    expect(formatEuro(0).replace(/ /g, " ")).toBe("0,00 €");
  });
});
