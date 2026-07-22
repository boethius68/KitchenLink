import type { GuestMenuItem, GuestVariantOption } from "./venue-data";

export interface GuestOptionGroup {
  id: string;
  title?: string;
  minimumSelections: number;
  maximumSelections: number;
  selectionMode: "single" | "multiple" | "quantity";
  freeSelectionCount: number;
  allowsRepeats: boolean;
  options: GuestVariantOption[];
}

const GENERIC_GROUP_WORDS = new Set([
  "variante",
  "varianten",
  "option",
  "optionen",
  "extra",
  "extras",
  "portion",
  "portionen",
]);

/**
 * Baut die bestellbaren Gruppen aus den publizierten Metadaten. Alte Menüs
 * ohne Gruppen bleiben kompatibel: Portionen/Varianten sind eine optionale
 * Einfachauswahl, Extras eine optionale Mehrfachauswahl.
 */
export function optionGroups(item: GuestMenuItem): GuestOptionGroup[] {
  const groups: GuestOptionGroup[] = [];
  const variants = item.variants ?? [];

  for (const option of variants) {
    const id = option.groupID ??
      (option.kind === "extra" ? "legacy-extra" : "legacy-choice");
    const existing = groups.find((group) => group.id === id);
    if (existing) {
      existing.options.push(option);
      continue;
    }

    const selectionMode = normalizedSelectionMode(option.selectionMode, option.kind);
    const groupOptionCount = variants.filter((candidate) => {
      const candidateID = candidate.groupID ??
        (candidate.kind === "extra" ? "legacy-extra" : "legacy-choice");
      return candidateID === id;
    }).length;
    const fallbackMaximum = selectionMode === "single" ? 1 : Math.max(1, groupOptionCount);
    groups.push({
      id,
      title: guestFacingGroupTitle(option.groupTitle),
      minimumSelections: Math.max(0, option.minimumSelections ?? 0),
      maximumSelections: Math.max(1, option.maximumSelections ?? fallbackMaximum),
      selectionMode,
      freeSelectionCount: Math.max(0, option.freeSelectionCount ?? 0),
      allowsRepeats: option.allowsRepeats ?? false,
      options: [option],
    });
  }

  return groups;
}

export function selectedOptions(
  item: GuestMenuItem,
  optionIDs: readonly string[],
): GuestVariantOption[] {
  const optionsByID = new Map((item.variants ?? []).map((option) => [option.id, option]));
  return optionIDs.flatMap((id) => {
    const option = optionsByID.get(id);
    return option ? [option] : [];
  });
}

/** Anzeigeformel; die Datenbank validiert und berechnet bei der Bestellung neu. */
export function configuredUnitPrice(
  item: GuestMenuItem,
  optionIDs: readonly string[],
): number {
  const selected = selectedOptions(item, optionIDs);
  const fixed = (item.variants ?? []).find(
    (option) => option.priceKind === "fixed" && selected.some(({ id }) => id === option.id),
  );
  const deltas = optionGroups(item).reduce((sum, group) => {
    const groupOptionIDs = new Set(group.options.map(({ id }) => id));
    const selectedInGroup = selected.filter(({ id }) => groupOptionIDs.has(id));
    const deltaPrices = selectedInGroup
      .filter(({ priceKind }) => priceKind === "delta")
      .map(({ priceCents }) => priceCents)
      .sort((a, b) => a - b);
    const includedCount = selectedInGroup.filter(
      ({ priceKind }) => priceKind === "included" || priceKind === "free",
    ).length;
    const waivedDeltaCount = group.selectionMode === "single"
      ? 0
      : Math.max(0, group.freeSelectionCount - includedCount);
    return sum + deltaPrices
      .slice(Math.min(waivedDeltaCount, deltaPrices.length))
      .reduce((groupSum, price) => groupSum + price, 0);
  }, 0);
  return Math.max(0, (fixed?.priceCents ?? item.priceCents) + deltas);
}

export function isValidConfiguration(
  item: GuestMenuItem,
  optionIDs: readonly string[],
): boolean {
  const variants = item.variants ?? [];
  const knownIDs = new Set(variants.map(({ id }) => id));
  if (optionIDs.some((id) => !knownIDs.has(id))) {
    return false;
  }

  for (const group of optionGroups(item)) {
    const groupIDs = new Set(group.options.map(({ id }) => id));
    const selectedInGroup = optionIDs.filter((id) => groupIDs.has(id));
    const count = selectedInGroup.length;
    if (count < group.minimumSelections || count > group.maximumSelections) {
      return false;
    }
    if (group.selectionMode === "single" && count > 1) {
      return false;
    }
    if (!group.allowsRepeats && new Set(selectedInGroup).size !== selectedInGroup.length) {
      return false;
    }
  }

  return selectedOptions(item, optionIDs).filter(({ priceKind }) => priceKind === "fixed").length <= 1;
}

function guestFacingGroupTitle(rawTitle?: string): string | undefined {
  const title = rawTitle?.trim();
  if (!title) {
    return undefined;
  }
  const words = title
    .toLocaleLowerCase("de-DE")
    .split(/[^\p{L}]+/u)
    .filter(Boolean);
  if (words.length > 0 && words.every((word) => GENERIC_GROUP_WORDS.has(word))) {
    return undefined;
  }
  return title;
}

function normalizedSelectionMode(
  rawMode: string | undefined,
  kind: GuestVariantOption["kind"],
): "single" | "multiple" | "quantity" {
  switch (rawMode?.toLocaleLowerCase("de-DE")) {
    case "single":
      return "single";
    case "multiple":
      return "multiple";
    case "quantity":
      return "quantity";
    default:
      return kind === "extra" ? "multiple" : "single";
  }
}
