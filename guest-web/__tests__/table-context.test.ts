import { describe, expect, it, vi } from "vitest";
import {
  fetchTable,
  readTableToken,
  tableContextLabel,
  tableGuestUrl,
  tableHeadline,
  TABLE_QUERY_PARAM,
} from "@/lib/table-context";
import { buildIdempotencyKey, submitOrder, type OrderBackend, type OrderRpcRow } from "@/lib/order-submit";
import { emptyCart, setQuantity } from "@/lib/cart";
import { sandboxVenues } from "@/lib/venue-data";

const venue = sandboxVenues[0];

describe("readTableToken", () => {
  it("liest das Token aus dem Query-String", () => {
    expect(readTableToken("?tisch=abc123")).toBe("abc123");
    expect(readTableToken(`?a=1&${TABLE_QUERY_PARAM}=sandbox-tisch-3`)).toBe(
      "sandbox-tisch-3",
    );
  });

  it("akzeptiert auch eine vollständige URL", () => {
    expect(
      readTableToken("https://kitchenlink.luneq.eu/alte-muehle/menu?tisch=xy9"),
    ).toBe("xy9");
  });

  it("ohne Parameter gibt es keinen Tisch", () => {
    expect(readTableToken("")).toBeNull();
    expect(readTableToken("?andere=1")).toBeNull();
    expect(readTableToken("?tisch=")).toBeNull();
    expect(readTableToken("?tisch=%20%20")).toBeNull();
  });

  it("weist Werte ab, die diese Datenbank nie ausgegeben hat", () => {
    // Kein Token ist wichtiger als ein Token, das die RPC nur mit Muell füttert.
    expect(readTableToken("?tisch=" + encodeURIComponent("tisch 1"))).toBeNull();
    expect(readTableToken("?tisch=" + encodeURIComponent("<script>"))).toBeNull();
    expect(readTableToken("?tisch=" + "a".repeat(129))).toBeNull();
  });
});

describe("tableHeadline", () => {
  it("ergänzt „Tisch“ nur bei nummerierten Tischen", () => {
    expect(tableHeadline("3")).toBe("Tisch 3");
    expect(tableHeadline("12b")).toBe("Tisch 12b");
    // Bereichskürzel wie „A1“ sind im Betrieb üblich.
    expect(tableHeadline("A1")).toBe("Tisch A1");
    expect(tableHeadline("Theke")).toBe("Theke");
    expect(tableHeadline("  Terrasse links ")).toBe("Terrasse links");
    // Ein Name mit Nummer bleibt ein Name.
    expect(tableHeadline("Terrasse 1")).toBe("Terrasse 1");
  });
});

describe("tableContextLabel", () => {
  it("zeigt Tisch und Bereich, sobald beides bekannt ist", () => {
    expect(
      tableContextLabel({
        kind: "resolved",
        token: "t",
        label: "3",
        area: "Gastraum",
      }),
    ).toBe("Tisch 3 · Gastraum");
  });

  it("lässt einen leeren Bereich weg", () => {
    expect(
      tableContextLabel({ kind: "resolved", token: "t", label: "3", area: "" }),
    ).toBe("Tisch 3");
  });

  it("benennt Prüfung und Fehlschlag klar", () => {
    expect(tableContextLabel({ kind: "resolving", token: "t" })).toBe(
      "Tisch wird geprüft …",
    );
    expect(tableContextLabel({ kind: "unknown", token: "t" })).toBe(
      "Tisch nicht erkannt",
    );
    expect(tableContextLabel({ kind: "none" })).toBeNull();
  });
});

describe("tableGuestUrl", () => {
  it("hängt das Token als Query-Parameter an", () => {
    expect(
      tableGuestUrl("https://kitchenlink.luneq.eu/alte-muehle/menu", "abc"),
    ).toBe("https://kitchenlink.luneq.eu/alte-muehle/menu?tisch=abc");
  });

  it("respektiert eine bereits vorhandene Query", () => {
    expect(tableGuestUrl("https://example.test/menu?a=1", "abc")).toBe(
      "https://example.test/menu?a=1&tisch=abc",
    );
  });
});

describe("fetchTable", () => {
  function client(result: { data?: unknown; error?: unknown }) {
    return {
      rpc: vi.fn().mockResolvedValue({
        data: result.data ?? null,
        error: result.error ?? null,
      }),
    } as never;
  }

  it("liest Bezeichnung und Bereich aus der RPC-Antwort", async () => {
    const supabase = client({ data: [{ label: "3", area: "Gastraum" }] });
    await expect(fetchTable("alte-muehle", "tok", supabase)).resolves.toEqual({
      label: "3",
      area: "Gastraum",
    });
  });

  it("verträgt eine Einzelzeile statt eines Arrays", async () => {
    const supabase = client({ data: { label: "Theke", area: "Bar" } });
    await expect(fetchTable("alte-muehle", "tok", supabase)).resolves.toEqual({
      label: "Theke",
      area: "Bar",
    });
  });

  it("ein unbekanntes Token ist eine Aussage, kein Ausfall", async () => {
    const supabase = client({ error: { message: "guest_web_unknown_table" } });
    await expect(fetchTable("alte-muehle", "tok", supabase)).resolves.toBeNull();
  });

  it("eine leere oder unbrauchbare Antwort gilt als unbekannt", async () => {
    await expect(
      fetchTable("alte-muehle", "tok", client({ data: [] })),
    ).resolves.toBeNull();
    await expect(
      fetchTable("alte-muehle", "tok", client({ data: [{ label: "  " }] })),
    ).resolves.toBeNull();
  });
});

describe("Bestellung mit Tisch", () => {
  function backend(capture: { args?: Record<string, unknown> }): OrderBackend {
    return {
      async signInAnonymously() {},
      async submitOrderRpc(args) {
        capture.args = args as unknown as Record<string, unknown>;
        return {
          order_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          status: "pending",
          total_cents: 690,
          currency: "EUR",
          idempotent_replay: false,
          accepted: true,
        } satisfies OrderRpcRow;
      },
    };
  }

  const cart = setQuantity(emptyCart, venue.menu[0].id, 1);

  it("reicht das Tisch-Token an die RPC durch", async () => {
    const capture: { args?: Record<string, unknown> } = {};
    const result = await submitOrder({
      venue,
      cart,
      attemptID: "attempt-1",
      tableToken: "sandbox-tisch-3",
      backend: backend(capture),
    });
    expect(result.ok).toBe(true);
    expect(capture.args?.tableToken).toBe("sandbox-tisch-3");
  });

  it("ohne Tisch bleibt der Aufruf wie bisher", async () => {
    const capture: { args?: Record<string, unknown> } = {};
    await submitOrder({
      venue,
      cart,
      attemptID: "attempt-1",
      backend: backend(capture),
    });
    expect(capture.args?.tableToken).toBeNull();
  });

  it("derselbe Warenkorb an einem anderen Tisch ist eine andere Bestellung", async () => {
    const base = {
      attemptID: "attempt-1",
      venueSlug: venue.slug,
      items: [{ slug: venue.menu[0].id, quantity: 1, option_ids: [] }],
      serviceMode: "dine_in" as const,
      customerNote: "",
    };
    const atTableThree = await buildIdempotencyKey({ ...base, tableToken: "t3" });
    const atTableFour = await buildIdempotencyKey({ ...base, tableToken: "t4" });
    const withoutTable = await buildIdempotencyKey(base);

    expect(atTableThree).not.toBe(atTableFour);
    expect(atTableThree).not.toBe(withoutTable);
    // Derselbe Tisch, derselbe Versuch: stabiler Key für Netzwerk-Retries.
    expect(await buildIdempotencyKey({ ...base, tableToken: "t3" })).toBe(
      atTableThree,
    );
  });

  it("meldet einen abgewiesenen Tisch als eigenen Fehlercode", async () => {
    const result = await submitOrder({
      venue,
      cart,
      attemptID: "attempt-1",
      tableToken: "veraltet",
      backend: {
        async signInAnonymously() {},
        async submitOrderRpc() {
          throw new Error("guest_web_unknown_table: Tisch nicht erkannt");
        },
      },
    });
    expect(result).toMatchObject({ ok: false, code: "unknown_table" });
  });
});
