/**
 * Setup für Integrationstests: lädt `guest-web/.env.local`, damit die Tests
 * NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY sehen, ohne dass
 * der Nutzer Variablen manuell `export`-en muss.
 *
 * Wird NUR von der Integration-Config (vitest.integration.config.ts) über
 * `setupFiles` geladen — die instanzfreie Unit-Suite bleibt unberührt.
 *
 * Fehlt `.env.local` (noch nicht konfiguriert), passiert nichts; die Tests
 * skippen dann weiterhin sauber (siehe Test-Header). Fehler beim Laden werden
 * ignoriert, damit ein leeres/partialles Env nicht den Lauf abbricht.
 */

try {
  // Node >= 20.12: lädt .env-Dateien in process.env. Die Default-Reihenfolge
  // von loadEnvFile() ist .env -> .env.local; das entspricht den Next.js-
  // Konventionen für lokale Überschreibung.
  process.loadEnvFile(".env.local");
} catch {
  // Keine .env.local vorhanden (oder nicht ladbar) — Tests skippen via
  // KL_INTEGRATION-Opt-in. Kein Abbruch.
}
