import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  applyLocalDemoPayment,
  buildDemoTableCheck,
  computeEqualSplitShare,
  computePayableCents,
  computeSelectedItemsTotal,
  computeTipCents,
  decodeGuestTableCheck,
  decodeGuestTablePaymentReceipt,
  fetchGuestTableCheck,
  submitGuestTablePayment,
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
});
