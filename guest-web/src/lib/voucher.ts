export interface VoucherResult {
  valid: boolean;
  discountCents: number;
  discountType: "percentage" | "fixed_amount" | "";
  discountValue: number;
  message: string;
}

const SIMULATED_VOUCHERS: Record<
  string,
  { type: "percentage" | "fixed_amount"; value: number; minOrderCents: number }
> = {
  WILLKOMMEN10: { type: "percentage", value: 10, minOrderCents: 1500 },
  STAMMGAST5: { type: "fixed_amount", value: 500, minOrderCents: 2500 },
};

export function validateVoucherLocal(
  code: string,
  totalCents: number
): VoucherResult {
  const clean = code.trim().toUpperCase();
  if (!clean) {
    return {
      valid: false,
      discountCents: 0,
      discountType: "",
      discountValue: 0,
      message: "Gutscheincode eingeben",
    };
  }

  const found = SIMULATED_VOUCHERS[clean];
  if (!found) {
    return {
      valid: false,
      discountCents: 0,
      discountType: "",
      discountValue: 0,
      message: "Ungültiger Gutscheincode",
    };
  }

  if (totalCents < found.minOrderCents) {
    const minEuro = (found.minOrderCents / 100).toFixed(2).replace(".", ",");
    return {
      valid: false,
      discountCents: 0,
      discountType: "",
      discountValue: 0,
      message: `Mindestbestellwert von ${minEuro} € nicht erreicht`,
    };
  }

  const discountCents =
    found.type === "percentage"
      ? Math.round((totalCents * found.value) / 100)
      : Math.min(totalCents, found.value);

  return {
    valid: true,
    discountCents,
    discountType: found.type,
    discountValue: found.value,
    message: "Gutschein erfolgreich angewendet",
  };
}
