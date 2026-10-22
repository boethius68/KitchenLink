import { describe, expect, it } from "vitest";
import { validateVoucherLocal } from "@/lib/voucher";

describe("validateVoucherLocal", () => {
  it("akzeptiert WILLKOMMEN10 bei ausreichendem Bestellwert", () => {
    const res = validateVoucherLocal("WILLKOMMEN10", 2000);
    expect(res.valid).toBe(true);
    expect(res.discountCents).toBe(200); // 10% von 20,00 € = 2,00 €
    expect(res.discountType).toBe("percentage");
  });

  it("akzeptiert Klein-/Großschreibung und Leerzeichen", () => {
    const res = validateVoucherLocal("  willkommen10  ", 3000);
    expect(res.valid).toBe(true);
    expect(res.discountCents).toBe(300);
  });

  it("lehnt WILLKOMMEN10 bei Nichterreichen des Mindestbestellwerts ab", () => {
    const res = validateVoucherLocal("WILLKOMMEN10", 1200);
    expect(res.valid).toBe(false);
    expect(res.discountCents).toBe(0);
    expect(res.message).toContain("Mindestbestellwert");
  });

  it("berechnet Festbetragsrabatt für STAMMGAST5", () => {
    const res = validateVoucherLocal("STAMMGAST5", 3500);
    expect(res.valid).toBe(true);
    expect(res.discountCents).toBe(500); // 5,00 €
    expect(res.discountType).toBe("fixed_amount");
  });

  it("lehnt unbekannte Gutscheincodes ab", () => {
    const res = validateVoucherLocal("FANTASIE99", 5000);
    expect(res.valid).toBe(false);
    expect(res.message).toBe("Ungültiger Gutscheincode");
  });
});
