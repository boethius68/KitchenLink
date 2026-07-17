import { defineConfig } from "vitest/config";
import path from "node:path";

// Integrationstest-Konfiguration: läuft nur die Tests unter
// __tests__/integration/ gegen eine echte Supabase-Instanz. Skippt sauber,
// wenn keine Instanz konfiguriert ist (siehe Test-Header). Getrennt vom
// instanzfreien Unit-Run `npm test`.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
  test: {
    include: ["__tests__/integration/**/*.test.ts"],
    environment: "node",
    // Echte Netzwerk-Instanz: Tests dürfen länger laufen.
    testTimeout: 30_000,
  },
});
