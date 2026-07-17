import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
  test: {
    // Unit-Tests bleiben instanzfrei und schnell. Integrationstests (gegen
    // eine echte Supabase-Instanz) liegen unter __tests__/integration/ und
    // laufen über `npm run test:integration` (eigene Config).
    include: ["__tests__/**/*.test.ts"],
    exclude: ["__tests__/integration/**", "node_modules/**", ".next/**"],
    environment: "node",
  },
});
