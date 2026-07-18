import { defineConfig } from "vitest/config";
import path from "node:path";

// Integrationstest-Konfiguration: läuft nur die Tests unter
// __tests__/integration/ gegen eine echte Supabase-Instanz. Skippt sauber,
// wenn keine Instanz konfiguriert ist (siehe Test-Header). Getrennt vom
// instanzfreien Unit-Run `npm test`.
//
// setupFiles lädt .env.local, damit `npm run test:integration` die Supabase-
// Variablen ohne manuelles `export` sieht.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
  test: {
    include: ["__tests__/integration/**/*.test.ts"],
    exclude: ["**/load-env.ts"],
    environment: "node",
    // Lädt .env.local (wenn vorhanden), bevor die Tests laufen.
    setupFiles: ["__tests__/integration/load-env.ts"],
    // Echte Netzwerk-Instanz: Tests dürfen länger laufen.
    testTimeout: 30_000,
  },
});
