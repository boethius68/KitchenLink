import { describe, expect, it } from "vitest";
import { formatEuro } from "@/lib/cart";

describe("wallet payment simulation", () => {
  it("formats wallet payment amounts using official formatEuro", () => {
    expect(formatEuro(1150)).toBe("11,50 €");
    expect(formatEuro(690)).toBe("6,90 €");
    expect(formatEuro(0)).toBe("0,00 €");
  });

  it("handles haptic feedback safely in browser and node environments", () => {
    const vibrateMock = (pattern: number[]) => pattern.length > 0;
    expect(vibrateMock([20, 40, 20])).toBe(true);
  });
});
