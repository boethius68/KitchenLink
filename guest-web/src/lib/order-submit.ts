/**
 * Bestellübermittlung an die autoritative Grenze (ADR-001 §6, §7).
 *
 * Der Browser ruft ausschließlich die RPC `guest_web_submit_order_v2` auf und
 * schreibt nie direkt in Bestelltabellen. Vor der Bestellung erfolgt Supabase
 * Anonymous Sign-in (DECISIONS.md Guest Web, ADR-001 §6.3): nur ein anonym
 * eingelogter User (`authenticated` + `is_anonymous`) darf eine Bestellung
 * aufgeben; die bloße anon-Rolle hat keinen `auth.uid()` und scheitert in der
 * RPC.
 *
 * Die Preise werden nur clientseitig zur Anzeige gebildet (cart.ts). Die
 * autoritative Neubepreisung läuft serverseitig in der RPC aus
 * `menu_items.price_cents` plus den gespeicherten Auswahlregeln (ADR-001 §6.1)
 * und wird dem Client nicht vertraut.
 *
 * Auth- und RPC-Aufrufe laufen über die injizierbare `OrderBackend`-Schnitt-
 * stelle, sodass die hier geprüfte Logik (Idempotenz-Key, Inhaltskonflikt,
 * Fehler-→Ergebnis-Mapping) in Vitest ohne echte Supabase-Instanz getestet
 * werden kann. Der Produktions-Backend (`createSupabaseOrderBackend`) macht
 * die echten Aufrufe und schlägt ohne laufende Instanz fehl.
 */

import { cartLines, type Cart } from "./cart";
import type { GuestVenue } from "./venue-data";
import type { OrderAck } from "./order-ack";
import { toOrderAck } from "./order-ack";

/** Eine normierte Position, die an die RPC gesendet wird. */
export interface SubmitItem {
  slug: string;
  quantity: number;
  option_ids: string[];
}

/** Rohe Rückgabe der RPC (Spaltennamen wie in der Migration). */
export interface OrderRpcRow {
  order_id: string | null;
  status: string | null;
  total_cents: number | null;
  currency: string | null;
  idempotent_replay: boolean | null;
  accepted: boolean | null;
}

/**
 * Backend-Schnittstelle. Produktiv über Supabase, in Tests durch einen Mock
 * ersetzt. `signInAnonymously` MUSS vor `submitOrderRpc` erfolgreich gewesen
 * sein, damit die RPC einen auth.uid() vorfindet.
 */
export interface OrderBackend {
  signInAnonymously(): Promise<void>;
  submitOrderRpc(args: {
    venueSlug: string;
    idempotencyKey: string;
    items: SubmitItem[];
    serviceMode: ServiceMode;
    customerNote: string;
  }): Promise<OrderRpcRow>;
}

export type ServiceMode = "dine_in" | "bar" | "pickup";

/** Ergebnis einer Übermittlung: entweder ein ACK aus der Serverantwort oder
 *  ein strukturierter Fehler. Es gibt keinen „optimistisch akzeptiert“-Fall. */
export type SubmitResult =
  | { ok: true; ack: OrderAck }
  | { ok: false; code: SubmitErrorCode; message: string };

export type SubmitErrorCode =
  | "no_backend"
  | "anonymous_sign_in_failed"
  | "idempotency_conflict"
  | "unknown_item"
  | "unknown_option"
  | "invalid_selection"
  | "unavailable_item"
  | "unknown_venue"
  | "unauthenticated"
  | "rpc_error"
  | "invalid_response";

/** Neue, zufällige Kennung für genau einen Checkout-Versuch. Der Aufrufer hält
 *  sie über Netzwerk-Retries stabil und verwirft sie nach einer Bestätigung. */
export function createOrderAttemptID(): string {
  return globalThis.crypto.randomUUID();
}

/** Der zufällige Versuch verhindert Kollisionen zwischen Gästen und echten
 *  Nachbestellungen. Der kanonische Inhalt schützt zusätzlich vor mehrdeutigen
 *  Trennzeichen und erzeugt einen kurzen Key unterhalb des Serverlimits. */
export async function buildIdempotencyKey(parts: {
  attemptID: string;
  venueSlug: string;
  items: SubmitItem[];
  serviceMode: ServiceMode;
  customerNote: string;
}): Promise<string> {
  const items = [...parts.items]
    .sort((a, b) => {
      const left = JSON.stringify([a.slug, [...a.option_ids].sort()]);
      const right = JSON.stringify([b.slug, [...b.option_ids].sort()]);
      return left.localeCompare(right);
    })
    .map((item) => ({
      slug: item.slug,
      quantity: item.quantity,
      option_ids: [...item.option_ids].sort(),
    }));
  const canonical = JSON.stringify({
    attemptID: parts.attemptID,
    venueSlug: parts.venueSlug,
    serviceMode: parts.serviceMode,
    customerNote: parts.customerNote,
    items,
  });
  const digest = await globalThis.crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );
  const hex = Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
  return `gw2-${hex}`;
}

/** Normiert den Warenkorb + Venue in die RPC-Positionen (slug aus venue-data). */
export function cartToSubmitItems(
  cart: Cart,
  venue: GuestVenue,
): SubmitItem[] {
  const knownItems = new Set(venue.menu.map(({ id }) => id));
  return cartLines(cart)
    .filter((line) => knownItems.has(line.itemID))
    .map((line) => ({
      slug: line.itemID,
      quantity: line.quantity,
      option_ids: [...line.optionIDs].sort(),
    }));
}

const ERROR_CODE_PATTERNS: ReadonlyArray<{ match: RegExp; code: SubmitErrorCode }> = [
  { match: /idempotency_conflict/i, code: "idempotency_conflict" },
  { match: /unknown_item/i, code: "unknown_item" },
  { match: /unknown_option/i, code: "unknown_option" },
  { match: /invalid_selection|selection_required|selection_limit/i, code: "invalid_selection" },
  { match: /unavailable_item/i, code: "unavailable_item" },
  { match: /unknown_venue/i, code: "unknown_venue" },
  { match: /unauthenticated/i, code: "unauthenticated" },
];

/** Wandelt eine RPC-/Backend-Ausnahme in ein strukturiertes Ergebnis um. */
export function backendErrorToResult(error: unknown): SubmitResult {
  const message = errorMessage(error);
  for (const pattern of ERROR_CODE_PATTERNS) {
    if (pattern.match.test(message)) {
      return { ok: false, code: pattern.code, message };
    }
  }
  return { ok: false, code: "rpc_error", message };
}

function errorMessage(error: unknown): string {
  if (typeof error === "string") {
    return error;
  }
  if (error && typeof error === "object" && "message" in error) {
    const msg = (error as { message: unknown }).message;
    if (typeof msg === "string") {
      return msg;
    }
  }
  return "unbekannter Fehler";
}

export interface SubmitOrderArgs {
  venue: GuestVenue;
  cart: Cart;
  attemptID: string;
  serviceMode?: ServiceMode;
  customerNote?: string;
  backend: OrderBackend | null;
}

/**
 * Führt die Übermittlung durch: Anonymous Sign-in, dann RPC. Das ACK stammt
 * ausschließlich aus der Serverantwort (order-ack.ts). Gibt es keinen Backend
 * (z. B. Supabase nicht konfiguriert), wird ein strukturierter Fehler ohne
 * Bestätigung zurückgegeben — nie ein falsches ACK.
 */
export async function submitOrder(
  args: SubmitOrderArgs,
): Promise<SubmitResult> {
  const { venue, cart, backend } = args;
  const serviceMode = args.serviceMode ?? "dine_in";
  const customerNote = args.customerNote ?? "";

  if (!backend) {
    return {
      ok: false,
      code: "no_backend",
      message:
        "Supabase ist nicht konfiguriert (NEXT_PUBLIC_SUPABASE_URL/ANON_KEY).",
    };
  }

  const items = cartToSubmitItems(cart, venue);
  if (items.length === 0) {
    return { ok: false, code: "rpc_error", message: "leerer Warenkorb" };
  }

  try {
    await backend.signInAnonymously();
  } catch (error) {
    return {
      ok: false,
      code: "anonymous_sign_in_failed",
      message: errorMessage(error),
    };
  }

  let idempotencyKey: string;
  try {
    idempotencyKey = await buildIdempotencyKey({
      attemptID: args.attemptID,
      venueSlug: venue.slug,
      items,
      serviceMode,
      customerNote,
    });
  } catch (error) {
    return { ok: false, code: "rpc_error", message: errorMessage(error) };
  }

  let row: OrderRpcRow;
  try {
    row = await backend.submitOrderRpc({
      venueSlug: venue.slug,
      idempotencyKey,
      items,
      serviceMode,
      customerNote,
    });
  } catch (error) {
    return backendErrorToResult(error);
  }

  try {
    return { ok: true, ack: toOrderAck(row) };
  } catch (error) {
    return {
      ok: false,
      code: "invalid_response",
      message: errorMessage(error),
    };
  }
}
