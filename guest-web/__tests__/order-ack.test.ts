import { describe, expect, it } from "vitest";
import {
  acceptedState,
  errorState,
  initialSubmitUiState,
  submittingState,
  toOrderAck,
  type OrderRpcRowLike,
} from "@/lib/order-ack";

function rpcRow(overrides: Partial<OrderRpcRowLike> = {}): OrderRpcRowLike {
  return {
    order_id: "11111111-1111-1111-1111-111111111111",
    status: "pending",
    total_cents: 2180,
    currency: "EUR",
    idempotent_replay: false,
    accepted: true,
    ...overrides,
  };
}

describe("toOrderAck", () => {
  it("übersetzt eine gültige Serverantwort in einen typisierten ACK", () => {
    const ack = toOrderAck(rpcRow());
    expect(ack).toEqual({
      orderId: "11111111-1111-1111-1111-111111111111",
      status: "pending",
      totalCents: 2180,
      currency: "EUR",
      idempotentReplay: false,
    });
  });

  it("markiert idempotente Wiederholungen aus der Serverantwort", () => {
    const ack = toOrderAck(rpcRow({ idempotent_replay: true }));
    expect(ack.idempotentReplay).toBe(true);
  });

  it("lehnt eine Serverantwort ohne order_id ab (kein falsches ACK)", () => {
    expect(() => toOrderAck(rpcRow({ order_id: null }))).toThrow(
      /order_id/,
    );
  });

  it("lehnt eine Serverantwort mit accepted=false ab", () => {
    expect(() => toOrderAck(rpcRow({ accepted: false }))).toThrow(
      /nicht angenommen/,
    );
  });

  it("fällt für unbekannten Status auf pending zurück, behält aber die Serverantwort", () => {
    const ack = toOrderAck(rpcRow({ status: "komisch" }));
    expect(ack.status).toBe("pending");
  });

  it("lehnt negative/nicht-ganzzahlige Summen aus der Serverantwort ab", () => {
    expect(() => toOrderAck(rpcRow({ total_cents: -1 }))).toThrow();
    expect(() => toOrderAck(rpcRow({ total_cents: 12.5 }))).toThrow();
  });
});

describe("SubmitUiState (Status nur aus Serverantwort)", () => {
  it("startet idle und kennt keinen optimistisch-akzeptierten Zustand", () => {
    expect(initialSubmitUiState().kind).toBe("idle");
  });

  it("submitting ist ein eigener, eindeutig noch-nicht-bestätigter Zustand", () => {
    expect(submittingState().kind).toBe("submitting");
  });

  it("accepted entsteht nur aus einem ACK", () => {
    const state = acceptedState(toOrderAck(rpcRow()));
    expect(state.kind).toBe("accepted");
    if (state.kind === "accepted") {
      expect(state.ack.status).toBe("pending");
    }
  });

  it("error trägt nur die Server-/Backend-Fehlermeldung, kein ACK", () => {
    const state = errorState("idempotency_conflict");
    expect(state.kind).toBe("error");
    if (state.kind === "error") {
      expect(state.message).toBe("idempotency_conflict");
    }
  });
});
