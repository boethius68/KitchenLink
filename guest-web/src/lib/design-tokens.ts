/**
 * Semantische Design-Token-Namen und Werte aus docs/design/DESIGN_SYSTEM.md.
 *
 * SwiftUI und Web teilen dieselben semantischen Namen (§11). Dieses Modul
 * ist die typisierte Referenz; `src/styles/tokens.css` trägt dieselben
 * Werte als CSS-Variablen (`brand.grape` -> `--kl-brand-grape`). Ein
 * Vitest-Abgleich hält beide Quellen konsistent.
 */

export const KL_COLOR_TOKENS = {
  "brand.grape": "#2c2438",
  "brand.deep": "#221b2e",
  "brand.lemon": "#b6cc1b",
  "brand.lemonPressed": "#9fb014",
  "surface.base": "#f4f2f8",
  "surface.raised": "#fcfbfe",
  "surface.recessed": "#eceaf3",
  "surface.darkRaised": "#383048",
  "content.light": "#f1eff7",
  "text.primary": "#2c2438",
  "text.secondary": "#56506a",
  "text.muted": "#6e6880",
  "border.control": "#7e7890",
  "focus.ring": "#2c2438",
  "text.primaryInverse": "#f1eff7",
  "text.secondaryInverse": "#b4aec6",
  "text.mutedInverse": "#9a94ae",
  "border.controlInverse": "#9a94ae",
  "focus.ringInverse": "#f1eff7",
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
