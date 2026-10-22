import { describe, expect, it, vi } from "vitest";
import {
  backendErrorToResult,
  buildIdempotencyKey,
  cartToSubmitItems,
  submitOrder,
  type OrderBackend,
  type OrderRpcRow,
} from "@/lib/order-submit";
import { emptyCart, setQuantity, type Cart } from "@/lib/cart";
import { sandboxVenues } from "@/lib/venue-data";

const venue = sandboxVenues[0];

function cartWith(...entries: Array<[string, number, string[]?]>): Cart {
  return entries.reduce(
    (cart, [itemID, quantity, optionIDs]) =>
      setQuantity(cart, itemID, quantity, optionIDs),
    emptyCart,
  );
}

function okRow(overrides: Partial<OrderRpcRow> = {}): OrderRpcRow {
  return {
    order_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    status: "pending",
    total_cents: 2180,
    currency: "EUR",
    idempotent_replay: false,
    accepted: true,
    ...overrides,
  };
}

/** Mock-Backend:SignIn + RPC. Die reine Submit-Logik läuft hier ohne echte
 *  Supabase-Instanz. Was diese Tests NICHT beweisen: die echte RPC-Ausführung
 *  und RLS-Durchsetzung (siehe ORDER_GATE.md Teststand). */
function makeBackend(opts: {
  signIn?: () => Promise<void>;
  rpc?: (key: string) => Promise<OrderRpcRow>;
}): OrderBackend {
  const calls = { signIn: 0, rpc: 0 };
  return {
    async signInAnonymously() {
      calls.signIn += 1;
      await (opts.signIn ?? (() => Promise.resolve()))();
      // calls-Objekt hält diese Closure lebendig für eventuelle Assertions.
      void calls;
    },
    async submitOrderRpc(args) {
      calls.rpc += 1;
      void calls;
      void args;
      return (opts.rpc ?? (() => Promise.resolve(okRow())))(args.idempotencyKey);
    },
  };
}

describe("cartToSubmitItems", () => {
  it("übersetzt nur Positionen mit Menge > 0 in RPC-Items", () => {
    const items = cartToSubmitItems(
      cartWith(["kuerbissuppe", 2], ["flammkuchen", 0]),
      venue,
    );
    expect(items).toEqual([
      { slug: "kuerbissuppe", quantity: 2, option_ids: [] },
    ]);
  });

  it("überträgt Konfigurationen desselben Artikels als getrennte Positionen", () => {
    const items = cartToSubmitItems(
      cartWith(
        ["kuerbissuppe", 1],
        ["kuerbissuppe", 2, ["suppe-gross"]],
      ),
      venue,
    );
    expect(items).toEqual([
      { slug: "kuerbissuppe", quantity: 1, option_ids: [] },
      { slug: "kuerbissuppe", quantity: 2, option_ids: ["suppe-gross"] },
    ]);
  });
});

describe("buildIdempotencyKey", () => {
  it("ist deterministisch für gleiche Inhalte unabhängig von der Reihenfolge", async () => {
    const a = await buildIdempotencyKey({
      attemptID: "attempt-a",
      venueSlug: "alte-muehle",
      items: [
        { slug: "kuerbissuppe", quantity: 1, option_ids: [] },
        { slug: "wiener-schnitzel", quantity: 1, option_ids: [] },
      ],
      serviceMode: "dine_in",
      customerNote: "",
    });
    const b = await buildIdempotencyKey({
      attemptID: "attempt-a",
      venueSlug: "alte-muehle",
      items: [
        { slug: "wiener-schnitzel", quantity: 1, option_ids: [] },
        { slug: "kuerbissuppe", quantity: 1, option_ids: [] },
      ],
      serviceMode: "dine_in",
      customerNote: "",
    });
    expect(a).toBe(b);
  });

  it("unterscheidet sich bei anderer Menge (kein versehentliches Replay)", async () => {
    const one = await buildIdempotencyKey({
      attemptID: "attempt-quantity",
      venueSlug: "alte-muehle",
      items: [{ slug: "kuerbissuppe", quantity: 1, option_ids: [] }],
      serviceMode: "dine_in",
      customerNote: "",
    });
    const two = await buildIdempotencyKey({
      attemptID: "attempt-quantity",
      venueSlug: "alte-muehle",
      items: [{ slug: "kuerbissuppe", quantity: 2, option_ids: [] }],
      serviceMode: "dine_in",
      customerNote: "",
    });
    expect(one).not.toBe(two);
  });

  it("unterscheidet verschiedene Auswahlen desselben Artikels", async () => {
    const base = await buildIdempotencyKey({
      attemptID: "attempt-options",
      venueSlug: "alte-muehle",
      items: [{ slug: "kuerbissuppe", quantity: 1, option_ids: [] }],
      serviceMode: "dine_in",
      customerNote: "",
    });
    const configured = await buildIdempotencyKey({
      attemptID: "attempt-options",
      venueSlug: "alte-muehle",
      items: [
        { slug: "kuerbissuppe", quantity: 1, option_ids: ["suppe-gross"] },
      ],
      serviceMode: "dine_in",
      customerNote: "",
    });
    expect(base).not.toBe(configured);
    expect(configured.startsWith("gw2-")).toBe(true);
    expect(configured.length).toBe(68);
  });

  it("bleibt auch bei großem gültigem Inhalt unter dem Serverlimit", async () => {
    const key = await buildIdempotencyKey({
      attemptID: "attempt-large",
      venueSlug: "alte-muehle",
      items: Array.from({ length: 100 }, (_, index) => ({
        slug: `artikel-${index}`,
        quantity: 1,
        option_ids: Array.from({ length: 10 }, (__, optionIndex) =>
          `option-${index}-${optionIndex}`,
        ),
      })),
      serviceMode: "dine_in",
      customerNote: "x".repeat(2000),
    });
    expect(key.length).toBeLessThanOrEqual(512);
  });

  it("erzeugt für zwei echte Bestellversuche mit gleichem Inhalt verschiedene Keys", async () => {
    const parts = {
      venueSlug: "alte-muehle",
      items: [{ slug: "kuerbissuppe", quantity: 1, option_ids: [] }],
      serviceMode: "dine_in" as const,
      customerNote: "",
    };
    const first = await buildIdempotencyKey({ ...parts, attemptID: "attempt-1" });
    const second = await buildIdempotencyKey({ ...parts, attemptID: "attempt-2" });
    expect(first).not.toBe(second);
  });
});

describe("backendErrorToResult", () => {
  it("erkennt Idempotenz-Konflikt (gleicher Key, anderer Inhalt)", () => {
    const result = backendErrorToResult(new Error("guest_web_idempotency_conflict: x"));
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe("idempotency_conflict");
    }
  });

  it("erkennt unbekannten/inaktiven Artikel", () => {
    const unknown = backendErrorToResult(new Error("guest_web_unknown_item: foo"));
    const unavailable = backendErrorToResult(new Error("guest_web_unavailable_item: bar"));
    if (!unknown.ok) expect(unknown.code).toBe("unknown_item");
    if (!unavailable.ok) expect(unavailable.code).toBe("unavailable_item");
  });

  it("fällt auf rpc_error für unbekannte Fehler", () => {
    const result = backendErrorToResult(new Error("netzwerk weg"));
    if (!result.ok) expect(result.code).toBe("rpc_error");
  });
});

describe("submitOrder", () => {
  it("melden no_backend, wenn kein Backend verfügbar ist (kein falsches ACK)", async () => {
    const result = await submitOrder({
      venue,
      attemptID: "attempt-submit",
      cart: cartWith(["kuerbissuppe", 1]),
      backend: null,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.code).toBe("no_backend");
  });

  it("fühlen SignIn aus, dann RPC und geben das ACK aus der Serverantwort zurück", async () => {
    const signIn = vi.fn(() => Promise.resolve());
    let capturedKey = "";
    const rpc = vi.fn((args: { key: string }) => {
      capturedKey = args.key;
      return Promise.resolve(okRow({ status: "accepted", total_cents: 690 }));
    });
    const result = await submitOrder({
      venue,
      attemptID: "attempt-submit",
      cart: cartWith(["kuerbissuppe", 1]),
      backend: makeBackend({ signIn, rpc: () => rpc({ key: "used" }) }),
    });
    expect(capturedKey.length).toBeGreaterThan(0);
    expect(signIn).toHaveBeenCalledTimes(1);
    expect(rpc).toHaveBeenCalledTimes(1);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.ack.status).toBe("accepted");
      expect(result.ack.totalCents).toBe(690);
    }
  });

  it("brechen mit anonymous_sign_in_failed ab, wenn SignIn scheitert (keine RPC)", async () => {
    const rpc = vi.fn();
    const result = await submitOrder({
      venue,
      attemptID: "attempt-submit",
      cart: cartWith(["kuerbissuppe", 1]),
      backend: makeBackend({
        signIn: () => Promise.reject(new Error("auth down")),
        rpc: (key) => rpc(key),
      }),
    });
    expect(rpc).not.toHaveBeenCalled();
    if (!result.ok) expect(result.code).toBe("anonymous_sign_in_failed");
  });

  it("lassen einen Inhaltskonflikt aus der RPC als idempotency_conflict durch", async () => {
    const result = await submitOrder({
      venue,
      attemptID: "attempt-submit",
      cart: cartWith(["kuerbissuppe", 1]),
      backend: makeBackend({
        rpc: () =>
          Promise.reject(new Error("guest_web_idempotency_conflict: hash")),
      }),
    });
    if (!result.ok) expect(result.code).toBe("idempotency_conflict");
  });

  it("melden invalid_response bei defekter Serverantwort statt eines falschen ACK", async () => {
    const result = await submitOrder({
      venue,
      attemptID: "attempt-submit",
      cart: cartWith(["kuerbissuppe", 1]),
      backend: makeBackend({
        rpc: () =>
          Promise.resolve(okRow({ order_id: null, accepted: true })),
      }),
    });
    if (!result.ok) expect(result.code).toBe("invalid_response");
  });

  it("lehnen leeren Warenkorb ab", async () => {
    const result = await submitOrder({
      venue,
      attemptID: "attempt-submit",
      cart: cartWith(["kuerbissuppe", 0]),
      backend: makeBackend({}),
    });
    if (!result.ok) expect(result.code).toBe("rpc_error");
  });

  it("übermittelt Service-Modus pickup mit Abholnotiz an das Backend", async () => {
    const rpcSpy = vi.fn().mockResolvedValue(okRow());
    const backend: OrderBackend = {
      signInAnonymously: vi.fn().mockResolvedValue(undefined),
      submitOrderRpc: rpcSpy,
    };

    const result = await submitOrder({
      venue,
      attemptID: "attempt-pickup",
      cart: cartWith(["kuerbissuppe", 1]),
      serviceMode: "pickup",
      customerNote: "Abholung um 19:30 Uhr · Maria",
      tableToken: null,
      backend,
    });

    expect(result.ok).toBe(true);
    expect(rpcSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        serviceMode: "pickup",
        customerNote: "Abholung um 19:30 Uhr · Maria",
        tableToken: null,
      }),
    );
  });
});
