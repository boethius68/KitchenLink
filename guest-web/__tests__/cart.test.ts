import { describe, expect, it } from "vitest";
import {
  MAX_QUANTITY,
  cartLineID,
  decrement,
  decrementLastConfiguration,
  emptyCart,
  formatEuro,
  increment,
  itemCount,
  quantityForItem,
  setQuantity,
  totalCents,
} from "@/lib/cart";
import { sandboxVenues } from "@/lib/venue-data";

const menu = sandboxVenues[0].menu;

describe("configured cart lines", () => {
  it("stores clamped integer quantities without mutating the previous cart", () => {
    const id = cartLineID("a");
    const cart = setQuantity(emptyCart, "a", 2.9);
    expect(cart).toEqual({
      [id]: { id, itemID: "a", optionIDs: [], quantity: 2 },
    });
    increment(cart, "a");
    expect(cart[id].quantity).toBe(2);
    expect(setQuantity(emptyCart, "a", MAX_QUANTITY + 10)[id].quantity).toBe(
      MAX_QUANTITY,
    );
  });

  it("removes entries at zero and leaves an absent line untouched", () => {
    const cart = setQuantity(emptyCart, "a", 2);
    expect(setQuantity(cart, "a", 0)).toEqual({});
    expect(setQuantity(emptyCart, "missing", 0)).toBe(emptyCart);
  });

  it("decrements across the full 2 → 1 → removed lifecycle", () => {
    const cart = setQuantity(emptyCart, "a", 2);
    const once = decrement(cart, "a");
    expect(once[cartLineID("a")].quantity).toBe(1);
    expect(decrement(once, "a")).toEqual({});
    expect(decrement(emptyCart, "a")).toBe(emptyCart);
  });

  it("keeps two configurations of the same article separate", () => {
    let cart = increment(emptyCart, "kuerbissuppe", []);
    cart = increment(cart, "kuerbissuppe", ["suppe-gross"]);
    cart = increment(cart, "kuerbissuppe", ["suppe-gross"]);

    expect(Object.values(cart)).toHaveLength(2);
    expect(quantityForItem(cart, "kuerbissuppe")).toBe(3);
    expect(itemCount(cart)).toBe(3);

    cart = decrementLastConfiguration(cart, "kuerbissuppe");
    expect(quantityForItem(cart, "kuerbissuppe")).toBe(2);
    cart = decrement(cart, "kuerbissuppe", []);
    expect(quantityForItem(cart, "kuerbissuppe")).toBe(1);
  });

  it("decrements the configuration that was touched most recently", () => {
    let cart = increment(emptyCart, "kuerbissuppe", []);
    cart = increment(cart, "kuerbissuppe", ["suppe-gross"]);
    cart = increment(cart, "kuerbissuppe", []);

    cart = decrementLastConfiguration(cart, "kuerbissuppe");
    expect(cart[cartLineID("kuerbissuppe", [])].quantity).toBe(1);
    expect(cart[cartLineID("kuerbissuppe", ["suppe-gross"])].quantity).toBe(1);
  });

  it("preserves repeated option IDs for repeatable quantities", () => {
    const cart = setQuantity(emptyCart, "a", 1, ["sauce", "sauce"]);
    const line = cart[cartLineID("a", ["sauce", "sauce"])];
    expect(line.optionIDs).toEqual(["sauce", "sauce"]);
  });
});

describe("totals", () => {
  it("uses a fixed portion price instead of the base price", () => {
    const cart = setQuantity(
      emptyCart,
      "kuerbissuppe",
      2,
      ["suppe-gross"],
    );
    expect(totalCents(cart, menu)).toBe(2 * 890);
  });

  it("adds a selected price delta", () => {
    const cart = setQuantity(
      emptyCart,
      "wiener-schnitzel",
      1,
      ["schnitzel-pommes"],
    );
    expect(totalCents(cart, menu)).toBe(2180 + 150);
  });

  it("ignores unknown items and is zero for an empty cart", () => {
    const cart = setQuantity(emptyCart, "unknown-item", 5);
    expect(totalCents(cart, menu)).toBe(0);
    expect(totalCents(emptyCart, menu)).toBe(0);
  });
});

describe("formatEuro", () => {
  it("formats German euro amounts from cents", () => {
    expect(formatEuro(1150).replace(/ /g, " ")).toBe("11,50 €");
    expect(formatEuro(0).replace(/ /g, " ")).toBe("0,00 €");
  });
});
