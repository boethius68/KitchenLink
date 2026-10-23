import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  applyLocalDemoPayment,
  buildDemoTableCheck,
  computeEqualSplitShare,
  computePayableCents,
  computeRoundUpTipCents,
  computeSelectedItemsTotal,
  computeTipCents,
  computeVatBreakdown,
  decodeGuestTableCheck,
  decodeGuestTablePaymentReceipt,
  fetchGuestTableCheck,
  getVenueTaxInfo,
  isDrinkItem,
  submitGuestTablePayment,
  type BewirtungsbelegData,
} from "@/lib/table-check";
import { sandboxVenues } from "@/lib/venue-data";

const SANDBOX_VENUE = sandboxVenues[0];

describe("table-check domain & split-payment calculations (KL-WEB-007)", () => {
  it("decodes a valid guest table check payload with both QR and service items", () => {
    const raw = {
      table_session_id: "sess-101",
      table_label: "4",
      table_area: "Biergarten",
      total_cents: 4150,
      paid_cents: 1200,
      tip_cents: 150,
      open_cents: 2950,
      items: [
        {
          order_item_id: "item-1",
          order_id: "ord-1",
          name: "Mühlen-Schnitzel",
          quantity: 1,
          unit_price_cents: 1890,
          line_total_cents: 1890,
          paid: false,
          payment_id: null,
          source: "guest_qr",
        },
        {
          order_item_id: "item-2",
          order_id: "ord-2",
          name: "Kellerbier vom Fass",
          quantity: 2,
          unit_price_cents: 530,
          line_total_cents: 1060,
          paid: false,
          payment_id: null,
          source: "service",
        },
        {
          order_item_id: "item-3",
          order_id: "ord-1",
          name: "Tagessuppe",
          quantity: 1,
          unit_price_cents: 1200,
          line_total_cents: 1200,
          paid: true,
          payment_id: "pay-prev",
          source: "guest_qr",
        },
      ],
    };

    const decoded = decodeGuestTableCheck(raw);
    expect(decoded).not.toBeNull();
    expect(decoded?.tableSessionId).toBe("sess-101");
    expect(decoded?.tableLabel).toBe("4");
    expect(decoded?.tableArea).toBe("Biergarten");
    expect(decoded?.totalCents).toBe(4150);
    expect(decoded?.paidCents).toBe(1200);
    expect(decoded?.openCents).toBe(2950);
    expect(decoded?.items).toHaveLength(3);
    expect(decoded?.items[1].source).toBe("service");
    expect(decoded?.items[2].paid).toBe(true);
  });

  it("computes selected items total ignoring already paid items and capping at openCents", () => {
    const check = buildDemoTableCheck(SANDBOX_VENUE, "3", "Gastraum");
    const firstId = check.items[0].orderItemId;
    const secondId = check.items[1].orderItemId;

    const sum = computeSelectedItemsTotal(check, new Set([firstId, secondId]));
    expect(sum).toBe(check.items[0].lineTotalCents + check.items[1].lineTotalCents);

    // Mark first item paid and ensure it is no longer counted
    const withFirstPaid = {
      ...check,
      items: check.items.map((item, idx) =>
        idx === 0 ? { ...item, paid: true } : item,
      ),
    };
    const sumAfterPaid = computeSelectedItemsTotal(
      withFirstPaid,
      new Set([firstId, secondId]),
    );
    expect(sumAfterPaid).toBe(check.items[1].lineTotalCents);
  });

  it("computes equal split share accurately across guest counts", () => {
    expect(computeEqualSplitShare(3000, 2)).toBe(1500);
    expect(computeEqualSplitShare(3000, 3)).toBe(1000);
    // Odd cents round up so the table never underpays on equal splits
    expect(computeEqualSplitShare(1000, 3)).toBe(334);
    expect(computeEqualSplitShare(0, 4)).toBe(0);
  });

  it("computes tip and total payable cents", () => {
    expect(computeTipCents(2000, 0)).toBe(0);
    expect(computeTipCents(2000, 5)).toBe(100);
    expect(computeTipCents(2000, 10)).toBe(200);
    expect(computeTipCents(2000, 15)).toBe(300);
    expect(computePayableCents(2000, 200)).toBe(2200);
  });

  it("executes item-by-item split payment and prevents paying the same item twice", () => {
    const initial = buildDemoTableCheck(SANDBOX_VENUE, "5", "Terrasse");
    const firstItem = initial.items[0];

    const step1 = applyLocalDemoPayment(initial, {
      orderItemIds: [firstItem.orderItemId],
      tipCents: 200,
      idempotencyKey: "idem-key-step-1",
    });

    expect(step1.ok).toBe(true);
    if (!step1.ok) return;

    expect(step1.receipt.amountCents).toBe(firstItem.lineTotalCents);
    expect(step1.receipt.tipCents).toBe(200);
    expect(step1.receipt.sessionClosed).toBe(false);
    expect(step1.check.openCents).toBe(initial.totalCents - firstItem.lineTotalCents);
    expect(step1.check.items[0].paid).toBe(true);

    // Attempting to pay the exact same item again must be rejected
    const duplicateAttempt = applyLocalDemoPayment(step1.check, {
      orderItemIds: [firstItem.orderItemId],
      tipCents: 0,
      idempotencyKey: "idem-key-step-2",
    });
    expect(duplicateAttempt.ok).toBe(false);

    // Paying the remaining open balance closes the table session and marks all items paid
    const settleRest = applyLocalDemoPayment(step1.check, {
      amountCents: step1.check.openCents,
      tipCents: 150,
      idempotencyKey: "idem-key-step-3",
    });
    expect(settleRest.ok).toBe(true);
    if (!settleRest.ok) return;

    expect(settleRest.receipt.sessionClosed).toBe(true);
    expect(settleRest.check.openCents).toBe(0);
    expect(settleRest.check.items.every((i) => i.paid)).toBe(true);
    expect(settleRest.receipt.tseSignature).toMatch(/^TSE-SIM-/);
  });

  it("calls guest_web_get_table_check and guest_web_pay_table_check RPCs via Supabase", async () => {
    const rpcMock = vi.fn();
    const fakeSupabase = { rpc: rpcMock } as unknown as SupabaseClient;

    rpcMock.mockResolvedValueOnce({
      data: {
        table_session_id: "sess-live-1",
        table_label: "7",
        table_area: "Stube",
        total_cents: 2500,
        paid_cents: 0,
        tip_cents: 0,
        open_cents: 2500,
        items: [],
      },
      error: null,
    });

    const loaded = await fetchGuestTableCheck("alte-muehle", "tok-7", fakeSupabase);
    expect(rpcMock).toHaveBeenCalledWith("guest_web_get_table_check", {
      p_venue_slug: "alte-muehle",
      p_table_token: "tok-7",
    });
    expect(loaded?.tableSessionId).toBe("sess-live-1");

    rpcMock.mockResolvedValueOnce({
      data: {
        payment_id: "11111111-2222-3333-4444-555555555555",
        amount_cents: 1250,
        tip_cents: 125,
        method: "online",
        provider_reference: "sandbox-wallet-xyz",
        tse_signature: "TSE-SIM-111111112222",
        open_cents: 1250,
        session_closed: false,
        replayed: false,
      },
      error: null,
    });

    const payResult = await submitGuestTablePayment(
      {
        venueSlug: "alte-muehle",
        tableToken: "tok-7",
        idempotencyKey: "idem-live-1",
        amountCents: 1250,
        tipCents: 125,
      },
      fakeSupabase,
    );

    expect(payResult.ok).toBe(true);
    if (payResult.ok) {
      expect(payResult.receipt.amountCents).toBe(1250);
      expect(payResult.receipt.tseSignature).toBe("TSE-SIM-111111112222");
    }
  });

  it("decodes payment receipt defensively", () => {
    expect(decodeGuestTablePaymentReceipt(null)).toBeNull();
    expect(decodeGuestTablePaymentReceipt({})).toBeNull();
  });

  describe("German Hospitality Tax (Bewirtungsbeleg § 4 Abs. 5 Nr. 2 EStG & TSE § 6 KassenSichV)", () => {
    it("distinguishes food (7% VAT) from beverages (19% VAT) reliably", () => {
      expect(isDrinkItem("Kellerbier vom Fass")).toBe(true);
      expect(isDrinkItem("Riesling trocken 0,2l")).toBe(true);
      expect(isDrinkItem("Apfelschorle")).toBe(true);
      expect(isDrinkItem("Doppelter Espresso")).toBe(true);
      expect(isDrinkItem("Mineralwasser")).toBe(true);
      expect(isDrinkItem("Aperol Spritz")).toBe(true);

      expect(isDrinkItem("Wiener Schnitzel")).toBe(false);
      expect(isDrinkItem("Käsespätzle mit Röstzwiebeln")).toBe(false);
      expect(isDrinkItem("Kürbissuppe")).toBe(false);
      expect(isDrinkItem("Flammkuchen Elsässer Art")).toBe(false);
    });

    it("computes 7% / 19% VAT breakdown with tax-exempt tip accurately", () => {
      const items = [
        { name: "Wiener Schnitzel", lineTotalCents: 2180, kind: "food" as const }, // 7%
        { name: "Kellerbier", lineTotalCents: 1060, kind: "drink" as const },      // 19%
      ];
      const tipCents = 300; // tax-exempt gem. § 3 Nr. 51 EStG

      const vat = computeVatBreakdown(items, tipCents);

      // 7% food: 21,80 € / 1.07 = 20,37 € Netto, 1,43 € MwSt
      expect(vat.rate7.grossCents).toBe(2180);
      expect(vat.rate7.netCents).toBe(2037);
      expect(vat.rate7.vatCents).toBe(143);

      // 19% drink: 10,60 € / 1.19 = 8,91 € Netto, 1,69 € MwSt
      expect(vat.rate19.grossCents).toBe(1060);
      expect(vat.rate19.netCents).toBe(891);
      expect(vat.rate19.vatCents).toBe(169);

      // Totals
      expect(vat.totalGrossCents).toBe(3240);
      expect(vat.totalNetCents).toBe(2037 + 891);
      expect(vat.totalVatCents).toBe(143 + 169);
      expect(vat.tipCents).toBe(300);
      expect(vat.grandTotalCents).toBe(3540);
    });

    it("computes round-up tip cents correctly to the next full Euro", () => {
      // 18,30 € -> 0,70 € tip (= 19,00 €)
      expect(computeRoundUpTipCents(1830)).toBe(70);
      // 21,85 € -> 0,15 € tip (= 22,00 €)
      expect(computeRoundUpTipCents(2185)).toBe(15);
      // Exactly 20,00 € -> 1,00 € tip (= 21,00 €)
      expect(computeRoundUpTipCents(2000)).toBe(100);
      // 0,00 € -> 0 €
      expect(computeRoundUpTipCents(0)).toBe(0);
    });

    it("supports item selection with quantity splitting", () => {
      const check = buildDemoTableCheck(SANDBOX_VENUE, "3", "Gastraum");
      // Find the drink item which has quantity 2 (5,30 € each = 10,60 €)
      const drinkItem = check.items.find((i) => i.quantity === 2) ?? check.items[2];
      expect(drinkItem.quantity).toBe(2);

      // Select only 1 of 2 drinks
      const selectedIds = new Set([drinkItem.orderItemId]);
      const selectedQuantities = { [drinkItem.orderItemId]: 1 };

      const subtotal1 = computeSelectedItemsTotal(check, selectedIds, selectedQuantities);
      expect(subtotal1).toBe(drinkItem.unitPriceCents); // 530

      // Select both drinks
      const selectedQuantities2 = { [drinkItem.orderItemId]: 2 };
      const subtotal2 = computeSelectedItemsTotal(check, selectedIds, selectedQuantities2);
      expect(subtotal2).toBe(drinkItem.lineTotalCents); // 1060
    });

    it("generates a complete Bewirtungsbeleg and TSE fiscal metadata upon payment", () => {
      const initial = buildDemoTableCheck(SANDBOX_VENUE, "3", "Stube");
      const firstItem = initial.items[0];

      const bewirtung: BewirtungsbelegData = {
        enabled: true,
        hostName: "Philipp Horn, KitchenLink GmbH",
        guests: "Dr. Johann Weber (Partner), Anna Schmidt",
        purpose: "Projektbesprechung Q4 Roadmap & Bewirtung",
      };

      const result = applyLocalDemoPayment(initial, {
        orderItemIds: [firstItem.orderItemId],
        tipCents: 250,
        idempotencyKey: "idem-bewirtung-test-1",
        bewirtungsbeleg: bewirtung,
        venueName: "Gasthaus Alte Mühle",
      });

      expect(result.ok).toBe(true);
      if (!result.ok) return;

      const receipt = result.receipt;
      expect(receipt.amountCents).toBe(firstItem.lineTotalCents);
      expect(receipt.tipCents).toBe(250);

      // Bewirtungsbeleg data attached
      expect(receipt.bewirtungsbeleg?.enabled).toBe(true);
      expect(receipt.bewirtungsbeleg?.hostName).toBe("Philipp Horn, KitchenLink GmbH");
      expect(receipt.bewirtungsbeleg?.guests).toContain("Dr. Johann Weber");
      expect(receipt.bewirtungsbeleg?.purpose).toContain("Projektbesprechung");

      // TSE Fiscal metadata
      expect(receipt.tseTransactionNumber).toMatch(/^TSE-TX-#\d{6}$/);
      expect(receipt.tseSignatureCounter).toBeGreaterThan(0);
      expect(receipt.tseSerialNumber).toBe("TSE-KL-DEMO-001");
      expect(receipt.tseStartedAt).toBeDefined();
      expect(receipt.tseFinishedAt).toBeDefined();
      expect(receipt.tseSignature).toMatch(/^TSE-SIM-/);
      expect(receipt.tseQrData).toContain("Gasthaus Alte Mühle");

      // VAT breakdown
      expect(receipt.vatBreakdown).toBeDefined();
      expect(receipt.vatBreakdown?.grandTotalCents).toBe(firstItem.lineTotalCents + 250);
      expect(receipt.vatBreakdown?.tipCents).toBe(250);

      // Tax information lookup
      const taxInfo = getVenueTaxInfo("alte-muehle");
      expect(taxInfo.name).toBe("Gasthaus Alte Mühle");
      expect(taxInfo.legalName).toBe("Alte Mühle Gastronomie GmbH");
      expect(taxInfo.vatId).toBe("DE 314 892 019");
      expect(taxInfo.taxNumber).toBe("143/218/90123");
    });
  });
});
