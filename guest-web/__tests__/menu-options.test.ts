import { describe, expect, it } from "vitest";
import {
  configuredUnitPrice,
  isValidConfiguration,
  optionGroups,
} from "@/lib/menu-options";
import type { GuestMenuItem } from "@/lib/venue-data";

const item: GuestMenuItem = {
  id: "test",
  name: "Testgericht",
  description: "",
  priceCents: 1000,
  kind: "food",
  variants: [
    {
      id: "small",
      name: "Klein",
      priceCents: 900,
      kind: "portion",
      priceKind: "fixed",
      groupID: "size",
      groupTitle: "Größe",
      minimumSelections: 1,
      maximumSelections: 1,
    },
    {
      id: "large",
      name: "Groß",
      priceCents: 1200,
      kind: "portion",
      priceKind: "fixed",
      groupID: "size",
      groupTitle: "Größe",
      minimumSelections: 1,
      maximumSelections: 1,
    },
    {
      id: "cheese",
      name: "Käse",
      priceCents: 150,
      kind: "extra",
      priceKind: "delta",
      groupID: "toppings",
      groupTitle: "Dazu",
      minimumSelections: 0,
      maximumSelections: 2,
    },
  ],
};

describe("menu configurations", () => {
  it("preserves meaningful group names without generic prefixes", () => {
    expect(optionGroups(item).map(({ title }) => title)).toEqual(["Größe", "Dazu"]);
  });

  it("suppresses compound generic headings", () => {
    const genericTitleItem: GuestMenuItem = {
      ...item,
      variants: item.variants?.map((option) => ({
        ...option,
        groupTitle: option.groupID === "size" ? "Varianten / Optionen" : "Extras & Optionen",
      })),
    };
    expect(optionGroups(genericTitleItem).map(({ title }) => title)).toEqual([
      undefined,
      undefined,
    ]);
  });

  it("requires a mandatory choice and enforces single selection", () => {
    expect(isValidConfiguration(item, [])).toBe(false);
    expect(isValidConfiguration(item, ["small"])).toBe(true);
    expect(isValidConfiguration(item, ["small", "large"])).toBe(false);
  });

  it("replaces the base with a fixed price and adds deltas", () => {
    expect(configuredUnitPrice(item, ["large"])).toBe(1200);
    expect(configuredUnitPrice(item, ["large", "cheese"])).toBe(1350);
  });

  it("rejects unknown and duplicate IDs", () => {
    expect(isValidConfiguration(item, ["small", "missing"])).toBe(false);
    expect(isValidConfiguration(item, ["small", "small"])).toBe(false);
  });

  it("rejects more than one absolute price across groups", () => {
    const secondFixed: GuestMenuItem = {
      ...item,
      variants: [
        ...(item.variants ?? []),
        {
          id: "menu-price",
          name: "Menüpreis",
          priceCents: 1500,
          kind: "variant",
          priceKind: "fixed",
          groupID: "menu",
          minimumSelections: 0,
          maximumSelections: 1,
        },
      ],
    };
    expect(isValidConfiguration(secondFixed, ["small", "menu-price"])).toBe(false);
  });

  it("prices the first choice in a free multi-select allowance at zero", () => {
    const sides: GuestMenuItem = {
      ...item,
      variants: [
        {
          id: "fries",
          name: "Pommes",
          priceCents: 250,
          kind: "extra",
          priceKind: "delta",
          groupID: "sides",
          selectionMode: "multiple",
          freeSelectionCount: 1,
          minimumSelections: 0,
          maximumSelections: 2,
        },
        {
          id: "salad",
          name: "Salat",
          priceCents: 300,
          kind: "extra",
          priceKind: "delta",
          groupID: "sides",
          selectionMode: "multiple",
          freeSelectionCount: 1,
          minimumSelections: 0,
          maximumSelections: 2,
        },
      ],
    };
    expect(configuredUnitPrice(sides, ["fries"])).toBe(1000);
    expect(configuredUnitPrice(sides, ["fries", "salad"])).toBe(1300);
  });

  it("supports repeated quantities only for explicitly repeatable groups", () => {
    const sauces: GuestMenuItem = {
      ...item,
      variants: [{
        id: "sauce",
        name: "Sauce",
        priceCents: 100,
        kind: "extra",
        priceKind: "delta",
        groupID: "sauces",
        selectionMode: "quantity",
        freeSelectionCount: 1,
        allowsRepeats: true,
        minimumSelections: 0,
        maximumSelections: 3,
      }],
    };
    expect(isValidConfiguration(sauces, ["sauce", "sauce"])).toBe(true);
    expect(configuredUnitPrice(sauces, ["sauce", "sauce"])).toBe(1100);

    const nonRepeatable: GuestMenuItem = {
      ...sauces,
      variants: sauces.variants?.map((option) => ({ ...option, allowsRepeats: false })),
    };
    expect(isValidConfiguration(nonRepeatable, ["sauce", "sauce"])).toBe(false);
  });
});
