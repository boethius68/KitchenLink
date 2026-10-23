/**
 * Semantische Design-Token-Namen und Werte aus docs/design/DESIGN_SYSTEM.md
 * Farbwelt: Zitrus / "Frisch" (Turn 3b / 4b).
 *
 * SwiftUI und Web teilen dieselben semantischen Namen (§11). Dieses Modul
 * ist die typisierte Referenz; `src/styles/tokens.css` trägt dieselben
 * Werte als CSS-Variablen (`brand.grape` -> `--kl-brand-grape`). Ein
 * Vitest-Abgleich hält beide Quellen konsistent.
 */

export const KL_COLOR_TOKENS = {
  "brand.grape": "#2c2438",
  "brand.deep": "#0d0d10",
  "brand.lemon": "#b6cc1b",
  "brand.lemonPressed": "#9fb014",
  "surface.base": "#f4f4f1",
  "surface.raised": "#ffffff",
  "surface.recessed": "#eaeae5",
  "surface.darkRaised": "#1e1e24",
  "content.light": "#f4f4f1",
  "text.primary": "#17171b",
  "text.secondary": "#52525c",
  "text.muted": "#71717d",
  "border.control": "#7e7e8a",
  "focus.ring": "#17171b",
  "text.primaryInverse": "#f4f4f1",
  "text.secondaryInverse": "#b0b0bc",
  "text.mutedInverse": "#888896",
  "border.controlInverse": "#888896",
  "focus.ringInverse": "#b6cc1b",
} as const;

export const KL_RADIUS_TOKENS = {
  "radius.label": "6px",
  "radius.compact": "9px",
  "radius.control": "12px",
  "radius.card": "14px",
  "radius.sheet": "20px",
} as const;

/** `brand.lemonPressed` -> `--kl-brand-lemon-pressed` */
export function cssVariableName(semanticName: string): string {
  const kebab = semanticName
    .replaceAll(".", "-")
    .replaceAll(/([a-z0-9])([A-Z])/g, "$1-$2")
    .toLowerCase();
  return `--kl-${kebab}`;
}
