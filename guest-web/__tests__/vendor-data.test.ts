import { describe, it, expect, beforeEach } from "vitest";
import {
  sandboxSuppliers,
  getVendorPurchaseOrders,
  getPurchaseOrderById,
  confirmPurchaseOrder,
  markPurchaseOrderInTransit,
  markPurchaseOrderDelivered,
  resetVendorOrdersDemo,
  generateDeliverySlip,
  formatCents,
  getStatusBadgeInfo,
} from "../src/lib/vendor-data";

describe("vendor-data domain & B2B procurement counterpart", () => {
  beforeEach(() => {
    resetVendorOrdersDemo();
  });

  it("provides predefined suppliers matching restaurant inventory fixtures", () => {
    expect(sandboxSuppliers.length).toBeGreaterThanOrEqual(3);
    const kochberg = sandboxSuppliers.find((s) => s.id === "kochberg");
    expect(kochberg).toBeDefined();
    expect(kochberg?.name).toContain("Kochberg");
    expect(kochberg?.contactEmail).toBe("bestellung@kochberg-frische.de");
  });

  it("filters purchase orders by supplier", () => {
    const allOrders = getVendorPurchaseOrders();
    expect(allOrders.length).toBeGreaterThanOrEqual(4);

    const hoelleOrders = getVendorPurchaseOrders("weingut-hoelle");
    expect(hoelleOrders.length).toBe(1);
    expect(hoelleOrders[0].orderNumber).toBe("PO-2026-082");
    expect(hoelleOrders[0].lines.length).toBe(2);
  });

  it("retrieves a purchase order by ID or order number", () => {
    const byId = getPurchaseOrderById("po-081");
    expect(byId).toBeDefined();
    expect(byId?.orderNumber).toBe("PO-2026-081");

    const byNumber = getPurchaseOrderById("PO-2026-081");
    expect(byNumber).toBeDefined();
    expect(byNumber?.id).toBe("po-081");
  });

  it("allows a supplier to confirm an incoming purchase order with target date", () => {
    const updated = confirmPurchaseOrder(
      "po-081",
      "2026-10-25",
      "Waren für Samstagmorgen disponiert.",
    );
    expect(updated.status).toBe("confirmed");
    expect(updated.confirmedDeliveryDate).toBe("2026-10-25");
    expect(updated.notes).toContain("Waren für Samstagmorgen disponiert.");

    // Check persistence
    const reloaded = getPurchaseOrderById("po-081");
    expect(reloaded?.status).toBe("confirmed");
  });

  it("advances order to in_transit and then received (delivered)", () => {
    const inTransit = markPurchaseOrderInTransit("po-082");
    expect(inTransit.status).toBe("in_transit");

    const delivered = markPurchaseOrderDelivered("po-082");
    expect(delivered.status).toBe("received");
    expect(delivered.receivedAt).toBeDefined();
  });

  it("generates an accurate digital delivery slip (Lieferschein)", () => {
    const slip = generateDeliverySlip("po-081");
    expect(slip).not.toBeNull();
    expect(slip?.orderNumber).toBe("PO-2026-081");
    expect(slip?.slipNumber).toBe("LS-2026-081");
    expect(slip?.venueName).toBe("Gasthaus Alte Mühle");
    expect(slip?.supplierName).toContain("Kochberg");
    expect(slip?.lines.length).toBe(3);

    const firstLine = slip?.lines[0];
    expect(firstLine?.name).toContain("Mehl");
    expect(firstLine?.quantity).toBe(25);
    expect(firstLine?.unit).toBe("kg");
  });

  it("formats currency correctly into German Euro standards", () => {
    expect(formatCents(18250)).toBe("182,50 €");
    expect(formatCents(0)).toBe("0,00 €");
    expect(formatCents(99)).toBe("0,99 €");
  });

  it("provides descriptive status badge info", () => {
    const sent = getStatusBadgeInfo("sent");
    expect(sent.label).toContain("Offen");
    expect(sent.isActionable).toBe(true);

    const received = getStatusBadgeInfo("received");
    expect(received.label).toContain("Geliefert");
    expect(received.isActionable).toBe(false);
  });
});
