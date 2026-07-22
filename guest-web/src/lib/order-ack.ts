/**
 * ACK-Logik für die autoritative Bestellgrenze (ADR-001 §6, §7).
 *
 * Status entsteht ausschließlich aus der Serverantwort, nie optimistisch. Der
 * Gast sieht „Eingegangen“ erst, wenn der autoritative Knoten (hier die RPC
 * `guest_web_submit_order_v2`) die Bestellung dauerhaft gespeichert und per ACK
 * bestätigt hat. Vorher gilt ein eindeutiger „übermitteln“/„warten“-Zustand
 * ohne falsche Bestätigung (ADR-001 §5.3, Blueprint §16.2).
 *
 * Diese Datei ist rein und frei von Nebenwirkungen, damit sie sich mit Vitest
 * ohne echte Supabase-Instanz prüfen lässt.
 */

/** Bestellstatus, wie er aus der Serverantwort stammt. */
export type OrderStatus =
  | "pending"
  | "accepted"
  | "preparing"
  | "ready"
  | "served"
  | "canceled";

/** ACK-Record, deckungsgleich mit der Rückgabe von guest_web_submit_order_v2. */
export interface OrderAck {
  orderId: string;
  status: OrderStatus;
  totalCents: number;
  currency: string;
  /** true, wenn ein vorhandener Idempotenz-Treffer zurückgegeben wurde. */
  idempotentReplay: boolean;
}

/** Rohe Rückgabe der RPC guest_web_submit_order_v2 (Spaltennamen wie in der
 *  Migration). Wird von order-submit und order-ack geteilt. */
export interface OrderRpcRowLike {
  order_id: string | null;
  status: string | null;
  total_cents: number | null;
  currency: string | null;
  idempotent_replay: boolean | null;
  accepted: boolean | null;
}

/** Übersetzung des nackten RPC-Ergebnisses in den typisierten ACK. */
export function toOrderAck(row: OrderRpcRowLike): OrderAck {
  if (!row.order_id) {
    throw new Error("ACK ohne order_id erhalten");
  }
  if (row.accepted === false) {
    throw new Error("Server hat die Bestellung nicht angenommen");
  }
  return {
    orderId: row.order_id,
    status: normalizeStatus(row.status),
    totalCents: nonNegativeCents(row.total_cents),
    currency: row.currency ?? "EUR",
    idempotentReplay: row.idempotent_replay === true,
  };
}

function normalizeStatus(value: string | null): OrderStatus {
  const known: OrderStatus[] = [
    "pending",
    "accepted",
    "preparing",
    "ready",
    "served",
    "canceled",
  ];
  const next = (value ?? "pending") as OrderStatus;
  return known.includes(next) ? next : "pending";
}

function nonNegativeCents(value: number | null): number {
  const cents = value ?? 0;
  if (!Number.isInteger(cents) || cents < 0) {
    throw new Error(`ungültiger total_cents-Wert: ${value}`);
  }
  return cents;
}

/**
 * Sichtbarer UI-Zustand, der nur aus einem ACK (oder einem Fehler/Wait)
 * abgeleitet wird. Es gibt keinen „optimistically accepted“-Zustand.
 */
export type SubmitUiState =
  | { kind: "idle" }
  | { kind: "submitting" }
  | { kind: "accepted"; ack: OrderAck }
  | { kind: "error"; message: string };

export function initialSubmitUiState(): SubmitUiState {
  return { kind: "idle" };
}

export function submittingState(): SubmitUiState {
  return { kind: "submitting" };
}

export function acceptedState(ack: OrderAck): SubmitUiState {
  return { kind: "accepted", ack };
}

export function errorState(message: string): SubmitUiState {
  return { kind: "error", message };
}
