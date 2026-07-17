import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  KL_COLOR_TOKENS,
  KL_RADIUS_TOKENS,
  cssVariableName,
} from "@/lib/design-tokens";

const tokensCss = readFileSync(
  path.resolve(__dirname, "../src/styles/tokens.css"),
  "utf8",
);

describe("cssVariableName", () => {
  it("maps semantic names to kebab-case CSS variables", () => {
    expect(cssVariableName("brand.grape")).toBe("--kl-brand-grape");
    expect(cssVariableName("brand.lemonPressed")).toBe(
      "--kl-brand-lemon-pressed",
    );
    expect(cssVariableName("text.primaryInverse")).toBe(
      "--kl-text-primary-inverse",
    );
  });
});

describe("tokens.css mirrors DESIGN_SYSTEM.md semantics", () => {
  it("declares every color token with its documented value", () => {
    for (const [name, value] of Object.entries(KL_COLOR_TOKENS)) {
      const declaration = `${cssVariableName(name)}: ${value};`;
      expect(tokensCss, `fehlend: ${declaration}`).toContain(declaration);
    }
  });

  it("declares every radius token with its documented value", () => {
    for (const [name, value] of Object.entries(KL_RADIUS_TOKENS)) {
      const declaration = `${cssVariableName(name)}: ${value};`;
      expect(tokensCss, `fehlend: ${declaration}`).toContain(declaration);
    }
  });

  it("keeps lemon out of every status/urgency declaration", () => {
    // Zitronenregel (§5): Zitrone ist nie Status- oder Dringlichkeitsfarbe.
    const urgencyLines = tokensCss
      .split("\n")
      .filter((line) => line.includes("--kl-urgency-"));
    expect(urgencyLines.length).toBeGreaterThan(0);
    for (const line of urgencyLines) {
      expect(line.toLowerCase()).not.toContain("#b6cc1b");
      expect(line.toLowerCase()).not.toContain("lemon");
    }
  });
});
