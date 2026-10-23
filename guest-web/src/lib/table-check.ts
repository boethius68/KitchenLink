/**
 * KL-WEB-007: Gemeinsame Tischrechnung & Self-Checkout im Gast-Web (Blueprint §6.1, §8.1).
 *
 * Verbindet die gemeinsame Tisch-Session (`table_sessions`, `payments`, `payment_items`)
 * mit dem Gast-Browser:
 * - Gäste sehen sämtliche offenen und bereits bezahlten Positionen ihres Tisches
 *   (unabhängig davon, ob per Tisch-QR oder mündlich beim Kellner bestellt).
 * - Drei Aufteilungsmodi („Sunday-Prinzip"):
 *   1. `items`: Eigene Positionen antippen („Getrennt nach Artikeln")
 *   2. `full`: Gesamten offenen Restbetrag übernehmen („Alles Offene")
 *   3. `equal`: Offenen Betrag gleichmäßig durch N Personen teilen („Durch X teilen")
 * - Unterstützt zowel echte Supabase-RPCs (`guest_web_get_table_check`,
 *   `guest_web_pay_table_check`) als auch einen deterministischen Sandbox-Demo-Fallback,
 *   damit der Flow jederzeit ohne Backend-Abhängigkeit vorgeführt werden kann.
 */

import type { SupabaseClient } from "@supabase/supabase-js";
import type { GuestVenue } from "./venue-data";

export type GuestCheckItemSource = "guest_qr" | "service";

export interface GuestTableCheckItem {
  orderItemId: string;
  orderId: string;
  name: string;
  quantity: number;
  unitPriceCents: number;
  lineTotalCents: number;
  paid: boolean;
  paymentId: string | null;
  source: GuestCheckItemSource;
}

export interface GuestTableCheck {
  tableSessionId: string | null;
  tableLabel: string;
  tableArea: string;
  totalCents: number;
  paidCents: number;
  tipCents: number;
  openCents: number;
  items: GuestTableCheckItem[];
}

export interface GuestTablePaymentReceipt {
  paymentId: string;
  amountCents: number;
  tipCents: number;
  method: string;
  providerReference: string;
  tseSignature: string;
  openCents: number;
  sessionClosed: boolean;
  replayed: boolean;
}

export type GuestSplitMode = "items" | "full" | "equal";
export type GuestTipPercent = 0 | 5 | 10 | 15;

/**
 * Dekodiert die Antwort von `guest_web_get_table_check` defensiv.
 * Ungültige Einzelzeilen werden verworfen statt geraten.
 */
export function decodeGuestTableCheck(raw: unknown): GuestTableCheck | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const obj = raw as Record<string, unknown>;
  const rawItems = Array.isArray(obj.items) ? obj.items : [];
  const items: GuestTableCheckItem[] = [];

  for (const entry of rawItems) {
    if (!entry || typeof entry !== "object") continue;
    const row = entry as Record<string, unknown>;
    const orderItemId = typeof row.order_item_id === "string" ? row.order_item_id : null;
    const orderId = typeof row.order_id === "string" ? row.order_id : "order-unknown";
    const name = typeof row.name === "string" ? row.name : null;
    const quantity = typeof row.quantity === "number" ? row.quantity : null;
    const unitPriceCents = typeof row.unit_price_cents === "number" ? row.unit_price_cents : null;
    const lineTotalCents =
      typeof row.line_total_cents === "number"
        ? row.line_total_cents
        : quantity !== null && unitPriceCents !== null
          ? quantity * unitPriceCents
          : null;

    if (!orderItemId || !name || quantity === null || unitPriceCents === null || lineTotalCents === null) {
      continue;
    }

    items.push({
      orderItemId,
      orderId,
      name,
      quantity,
      unitPriceCents,
      lineTotalCents,
      paid: Boolean(row.paid),
      paymentId: typeof row.payment_id === "string" ? row.payment_id : null,
      source: row.source === "service" ? "service" : "guest_qr",
    });
  }

  return {
    tableSessionId: typeof obj.table_session_id === "string" ? obj.table_session_id : null,
    tableLabel: typeof obj.table_label === "string" ? obj.table_label : "1",
    tableArea: typeof obj.table_area === "string" ? obj.table_area : "Gastraum",
    totalCents: typeof obj.total_cents === "number" ? obj.total_cents : 0,
    paidCents: typeof obj.paid_cents === "number" ? obj.paid_cents : 0,
    tipCents: typeof obj.tip_cents === "number" ? obj.tip_cents : 0,
    openCents: typeof obj.open_cents === "number" ? obj.open_cents : 0,
    items,
  };
}

/**
 * Dekodiert den Zahlungsbeleg aus `guest_web_pay_table_check`.
 */
export function decodeGuestTablePaymentReceipt(raw: unknown): GuestTablePaymentReceipt | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const obj = raw as Record<string, unknown>;
  const paymentId = typeof obj.payment_id === "string" ? obj.payment_id : null;
  if (!paymentId) {
    return null;
  }
  return {
    paymentId,
    amountCents: typeof obj.amount_cents === "number" ? obj.amount_cents : 0,
    tipCents: typeof obj.tip_cents === "number" ? obj.tip_cents : 0,
    method: typeof obj.method === "string" ? obj.method : "online",
    providerReference:
      typeof obj.provider_reference === "string" ? obj.provider_reference : "sandbox-wallet",
    tseSignature:
      typeof obj.tse_signature === "string"
        ? obj.tse_signature
        : `TSE-SIM-${paymentId.replace(/-/g, "").slice(0, 12).toUpperCase()}`,
    openCents: typeof obj.open_cents === "number" ? obj.open_cents : 0,
    sessionClosed: Boolean(obj.session_closed),
    replayed: Boolean(obj.replayed),
  };
}

/**
 * Berechnet die Zwischensumme der vom Gast ausgewählten offenen Positionen,
 * gedeckelt auf den tatsächlich noch offenen Rechnungsbetrag.
 */
export function computeSelectedItemsTotal(
  check: GuestTableCheck,
  selectedItemIds: ReadonlySet<string>,
): number {
  let sum = 0;
  for (const item of check.items) {
    if (!item.paid && selectedItemIds.has(item.orderItemId)) {
      sum += item.lineTotalCents;
    }
  }
  return Math.min(sum, check.openCents);
}

/**
 * Berechnet den Pro-Kopf-Anteil bei gleichmäßiger Aufteilung („Durch N Personen teilen").
 * Rundet kaufmännisch auf volle Cent, überschreitet nie `openCents`.
 */
export function computeEqualSplitShare(openCents: number, splitCount: number): number {
  if (openCents <= 0) return 0;
  const safeCount = Math.max(2, Math.min(12, Math.floor(splitCount)));
  const share = Math.ceil(openCents / safeCount);
  return Math.min(share, openCents);
}

/**
 * Berechnet das Trinkgeld in Cent auf Basis des gewählten Prozentsatzes.
 */
export function computeTipCents(baseAmountCents: number, tipPercent: GuestTipPercent): number {
  if (baseAmountCents <= 0 || tipPercent <= 0) {
    return 0;
  }
  return Math.round((baseAmountCents * tipPercent) / 100);
}

/**
 * Berechnet den zu zahlenden Gesamtbetrag inkl. Trinkgeld.
 */
export function computePayableCents(baseAmountCents: number, tipCents: number): number {
  return Math.max(0, baseAmountCents) + Math.max(0, tipCents);
}

/**
 * Erzeugt eine realistische Demo-Tischrechnung für die Sandbox, falls noch keine
 * Cloud-Session geladen wurde — enthält sowohl QR-Bestellungen als auch eine
 * durch den Service (Kellner) gebuchte Position, um die gemeinsame Tisch-Session
 * sofort vorführbar zu machen.
 */
export function buildDemoTableCheck(
  venue: GuestVenue,
  tableLabel = "3",
  tableArea = "Gastraum",
  extraItems: Array<{ name: string; quantity: number; unitPriceCents: number }> = [],
): GuestTableCheck {
  const firstFood = venue.menu.find((i) => i.kind === "food") ?? venue.menu[0];
  const secondFood = venue.menu.filter((i) => i.kind === "food")[1] ?? venue.menu[1] ?? firstFood;
  const firstDrink = venue.menu.find((i) => i.kind === "drink") ?? venue.menu[venue.menu.length - 1];

  const baseItems: GuestTableCheckItem[] = [];

  if (firstFood) {
    baseItems.push({
      orderItemId: "demo-item-1",
      orderId: "demo-order-qr-1",
      name: firstFood.name,
      quantity: 1,
      unitPriceCents: firstFood.priceCents,
      lineTotalCents: firstFood.priceCents,
      paid: false,
      paymentId: null,
      source: "guest_qr",
    });
  }

  if (secondFood && secondFood.id !== firstFood?.id) {
    baseItems.push({
      orderItemId: "demo-item-2",
      orderId: "demo-order-waiter-1",
      name: secondFood.name,
      quantity: 1,
      unitPriceCents: secondFood.priceCents,
      lineTotalCents: secondFood.priceCents,
      paid: false,
      paymentId: null,
      source: "service",
    });
  }

  if (firstDrink) {
    baseItems.push({
      orderItemId: "demo-item-3",
      orderId: "demo-order-waiter-1",
      name: firstDrink.name,
      quantity: 2,
      unitPriceCents: firstDrink.priceCents,
      lineTotalCents: firstDrink.priceCents * 2,
      paid: false,
      paymentId: null,
      source: "service",
    });
  }

  extraItems.forEach((extra, index) => {
    baseItems.push({
      orderItemId: `demo-extra-${index + 1}`,
      orderId: "demo-order-qr-session",
      name: extra.name,
      quantity: extra.quantity,
      unitPriceCents: extra.unitPriceCents,
      lineTotalCents: extra.quantity * extra.unitPriceCents,
      paid: false,
      paymentId: null,
      source: "guest_qr",
    });
  });

  const totalCents = baseItems.reduce((sum, item) => sum + item.lineTotalCents, 0);

  return {
    tableSessionId: "demo-session-alte-muehle-t3",
    tableLabel,
    tableArea,
    totalCents,
    paidCents: 0,
    tipCents: 0,
    openCents: totalCents,
    items: baseItems,
  };
}

/**
 * Führt eine Zahlung im lokalen Sandbox-Demo-Zustand aus (identische Fachregeln
 * wie die PostgreSQL-RPC `guest_web_pay_table_check`).
 */
export function applyLocalDemoPayment(
  check: GuestTableCheck,
  params: {
    orderItemIds?: string[];
    amountCents?: number;
    tipCents: number;
    idempotencyKey: string;
  },
): { ok: true; check: GuestTableCheck; receipt: GuestTablePaymentReceipt } | { ok: false; message: string } {
  if (check.openCents <= 0) {
    return { ok: false, message: "Die Tischrechnung ist bereits vollständig beglichen." };
  }

  const selectedIds = new Set(params.orderItemIds ?? []);
  let amountCents = 0;

  if (selectedIds.size > 0) {
    for (const id of selectedIds) {
      const item = check.items.find((i) => i.orderItemId === id);
      if (!item || item.paid) {
        return {
          ok: false,
          message: "Eine ausgewählte Position wurde bereits bezahlt oder gehört nicht zu diesem Tisch.",
        };
      }
      amountCents += item.lineTotalCents;
    }
    amountCents = Math.min(amountCents, check.openCents);
  } else {
    if (!params.amountCents || params.amountCents <= 0) {
      return { ok: false, message: "Bitte wähle mindestens eine Position oder einen gültigen Betrag." };
    }
    if (params.amountCents > check.openCents) {
      return { ok: false, message: "Der Betrag übersteigt den offenen Rechnungsbetrag." };
    }
    amountCents = params.amountCents;
  }

  const paymentId = `pay-${params.idempotencyKey.slice(0, 12)}`;
  const newPaidCents = check.paidCents + amountCents;
  const newOpenCents = Math.max(0, check.totalCents - newPaidCents);
  const sessionClosed = newOpenCents === 0;

  const updatedItems = check.items.map((item) => {
    if (selectedIds.has(item.orderItemId) || (selectedIds.size === 0 && sessionClosed && !item.paid)) {
      return {
        ...item,
        paid: true,
        paymentId,
      };
    }
    return item;
  });

  const receipt: GuestTablePaymentReceipt = {
    paymentId,
    amountCents,
    tipCents: Math.max(0, params.tipCents),
    method: "online",
    providerReference: `sandbox-wallet-${params.idempotencyKey.slice(0, 8)}`,
    tseSignature: `TSE-SIM-${params.idempotencyKey.replace(/[^a-zA-Z0-9]/g, "").slice(0, 12).toUpperCase()}`,
    openCents: newOpenCents,
    sessionClosed,
    replayed: false,
  };

  return {
    ok: true,
    check: {
      ...check,
      paidCents: newPaidCents,
      tipCents: check.tipCents + Math.max(0, params.tipCents),
      openCents: newOpenCents,
      items: updatedItems,
    },
    receipt,
  };
}

/**
 * Lädt die aktuelle Tischrechnung über die Supabase-RPC `guest_web_get_table_check`.
 */
export async function fetchGuestTableCheck(
  venueSlug: string,
  tableToken: string,
  supabase: SupabaseClient,
): Promise<GuestTableCheck | null> {
  try {
    const { data, error } = await supabase.rpc("guest_web_get_table_check", {
      p_venue_slug: venueSlug,
      p_table_token: tableToken,
    });
    if (error || !data) {
      return null;
    }
    return decodeGuestTableCheck(data);
  } catch {
    return null;
  }
}

/**
 * Übermittelt eine Gast-Zahlung am Tisch über `guest_web_pay_table_check`.
 */
export async function submitGuestTablePayment(
  params: {
    venueSlug: string;
    tableToken: string;
    idempotencyKey: string;
    orderItemIds?: string[];
    amountCents?: number;
    tipCents: number;
    providerReference?: string;
  },
  supabase: SupabaseClient,
): Promise<{ ok: true; receipt: GuestTablePaymentReceipt } | { ok: false; message: string }> {
  try {
    const { data, error } = await supabase.rpc("guest_web_pay_table_check", {
      p_venue_slug: params.venueSlug,
      p_table_token: params.tableToken,
      p_idempotency_key: params.idempotencyKey,
      p_order_item_ids:
        params.orderItemIds && params.orderItemIds.length > 0 ? params.orderItemIds : null,
      p_amount_cents: params.amountCents ?? null,
      p_tip_cents: params.tipCents,
      p_provider_reference: params.providerReference ?? null,
    });

    if (error) {
      return {
        ok: false,
        message: error.message || "Zahlung konnte nicht verbucht werden.",
      };
    }

    const receipt = decodeGuestTablePaymentReceipt(data);
    if (!receipt) {
      return {
        ok: false,
        message: "Unerwartete Server-Antwort bei der Rechnungszahlung.",
      };
    }

    return { ok: true, receipt };
  } catch (err) {
    return {
      ok: false,
      message: err instanceof Error ? err.message : "Netzwerkfehler bei der Zahlung.",
    };
  }
}
