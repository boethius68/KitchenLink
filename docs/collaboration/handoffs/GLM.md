# Handoff — GLM (KL-WEB-003 Gast-Web-Sandbox in Betrieb)

**Datum:** 18. Juli 2026
**Agent:** GLM-5.2 via ZCode
**Branch:** `glm/web-next` (von aktuellem `main`, `4f65ac2`)
**Ticket:** KL-WEB-003 — Gast-Web zur laufenden Sandbox (Deploy + echte Tests)
**Status:** Vollständig umgesetzt und verifiziert (typecheck/lint/test/build
grün); committet und gepusht. Bereit für Review.

> KL-WEB-002 (autoritative Bestellgrenze) ist zuvor gemergt worden
> (`1cfd253`, inkl. Claude-Review-Fix). Dieser Strang macht jene Logik
> lauffähig. Der alte `glm/guest-web-order-gate`-Branch war nach dem Merge
> divergiert und wurde auf Nutzerwunsch gelöscht; die Arbeit liegt vollständig
> auf `main`.

## Anlass und Entscheidung

Nachdem alle aktiven Tickets gemergt waren, hat der Nutzer als nächsten Strang
„Gast-Web deployen & echt testen" gewählt — die KL-WEB-002-Logik war nie gegen
eine echte Supabase-Instanz gelaufen und nicht deployt. Im Repo war dazu noch
nichts Konkretes angelegt (kein `config.toml`, keine Projektverknüpfung, keine
`.env`, keine Vercel-Konfig.; Secrets nirgends hartcodiert). Für das Hosting
wurde „Vercel jetzt vorbereiten" gewählt, bewusst **ohne** die Hosting-
Entscheidung D4 (ADR-001 §8 PoC) vorwegzunehmen.

## Umgesetzte Dateien (alle im exklusiven Schreibbereich)

- `supabase/migrations/20260718010000_guest_web_submit_order_race_fix.sql`
  (neu, additiv): redefiniert `guest_web_submit_order` so, dass der INSERT in
  einen `EXCEPTION WHEN unique_violation`-Subblock eingebettet ist. Schließt
  das dokumentierte, nicht behobene Restrisiko aus KL-WEB-002: eine enge Race
  bei zwei gleichzeitigen Sendungen mit demselben Idempotenz-Key wird jetzt
  sauber auf Replay (gleicher Payload) bzw. Konflikt (anderer Payload)
  abgebildet, statt als generisches `rpc_error` nach oben zu reichen. Keine
  Tabellen-/Policy-Änderung; grants bleiben wie gehabt.
- `supabase/config.toml` (neu): Supabase-CLI-Initialisierung für `supabase
  link`/`db push`, ohne Secrets und ohne feste `project_id`.
- `guest-web/__tests__/integration/guest-web-submit-order.integration.test.ts`
  (neu): echte RPC-End-to-End-Tests (Anonymous Sign-in → Bestellung → ACK →
  Replay → Konflikt → RLS-Anon-Ablehnung). Skippt sauber, wenn keine Instanz
  konfiguriert ist (`KL_INTEGRATION=1` + Env-Variablen).
- `guest-web/vitest.config.ts`: `__tests__/integration/**` aus dem Unit-Run
  ausgeschlossen (Unit bleibt instanzfrei).
- `guest-web/vitest.integration.config.ts` (neu): eigene Config für
  Integrationstests (Timeout 30 s für echte Netz-Aufrufe).
- `guest-web/package.json`: `npm run test:integration` hinzugefügt.
- `guest-web/README.md`: Stand auf KL-WEB-003 korrigiert (Bestellgrenze ist da,
  nicht mehr „noch nicht enthalten"); Kommandos + „In Betrieb nehmen"-Verweis.
- `docs/architecture/guest-web/SANDBOX_SETUP.md` (neu): Schritt-für-Schritt-
  Leitfaden für den Nutzer — Supabase-Projekt (EU-Frankfurt), Anonymous-Sign-in
  aktivieren, drei Migrationen anwenden, `.env.local`, Vercel-Deployment,
  Integrationstests, Smoke-Check, Fehler-Checkliste.
- `docs/collaboration/WORK_QUEUE.md` (dieser Eintrag): KL-WEB-003 dokumentiert.

## Verifikation (in `guest-web/`)

- `npm run typecheck`: ✓ sauber.
- `npm run lint`: ✓ sauber (0 Probleme).
- `npm test` (Vitest Unit): ✓ 40/40 Tests (Integrationstests ausgeschlossen).
- `npm run test:integration`: ✓ skippt sauber (4 skipped) ohne konfigurierte
  Instanz — kein falsches Rot, kein falsches Grün.
- `npm run build`: ✓ SSG intakt, `/alte-muehle/menu` statisch vorgerendert.

## Was dieser Strang bewusst NICHT tut

- Keine Hosting-Entscheidung D4 (Vercel = erster Sandbox-Deploy; CF-PoC aus
  ADR-001 §8 bleibt offen). Keine `vercel.json`-Lock-in-Datei.
- Kein PWA/Offline-Shell (Stage 2, Entscheidung D5).
- Keine Menü-Fetch-Umstellung auf Supabase (Folgeticket; Fixture bleibt für
  SSG/Anzeige).
- Keine Secrets im Repo; kein Anlegen von Cloud-Ressourcen durch den Agent.

## Offen für den Nutzer (nicht für den Agent)

`SANDBOX_SETUP.md` führt Schritt für Schritt: Supabase-Projekt anlegen
(EU-Frankfurt), **Anonymous Sign-in aktivieren** (sonst scheitert jede
Bestellung), drei Migrationen anwenden (`supabase db push` oder SQL-Editor),
`guest-web/.env.local` befüllen (gitignore-geschützt), Repo in Vercel
verbinden mit `NEXT_PUBLIC_SUPABASE_*` als Env-Variablen. Ist die Instanz
konfiguriert, laufen `KL_INTEGRATION=1 npm run test:integration` echte Aussagen
(siehe `ORDER_GATE.md` §7 Abgrenzung).

## Restrisiken / Offenpunkte (ehrlich)

- **Integrationstests sind code-seitig vorbereitet, aber nicht gelaufen** —
  dafür fehlt die echte Instanz (vom Nutzer anzulegen). Die Tests beweisen
  erst etwas, wenn `KL_INTEGRATION=1` gegen ein echtes Projekt läuft.
- **Race-Fix ist SQL, nicht gegen echtes PostgreSQL verifiziert.** Die
  `EXCEPTION WHEN unique_violation`-Logik ist Standard-PL/pgSQL und
  sorgfältig geschrieben, aber in dieser Umgebung nicht laufend geprüft. Der
  Integrationstest „Replay" deckt den seriellen Fall ab; die echte
  Concurrent-Race wäre ein eigenes Last-Test-Szenario.
- **`npm audit`:** unverändert zwei moderate Findings in Dev-/Transitiv-
  Abhängigkeiten des Scaffolds (KL-WEB-001 notiert); Sandbox-unkritisch.
- **Cleanup orphaned anonymous users** (DECISIONS.md Guest Web) noch nicht
  umgesetzt; Supabase-Projekt-Konfiguration, kein Code-Scope.

## Schreibbereich & Kollisionsfreiheit

`guest-web/`, `supabase/` (nur neue additive Dateien; bestehende Migrationen
unangetastet), `docs/architecture/guest-web/SANDBOX_SETUP.md`, dieser
`WORK_QUEUE.md`-Eintrag und diese Handoff-Datei. Keine Berührung von
PR-#7/#8-Scopes oder iOS-Code; nichts außerhalb. Keine `DECISIONS.md`/
`CURRENT.md`-Edits (keine neue Nutzerentscheidung; D4 bleibt dem Nutzer).
`.zcode/` im Repo-Wurzel liegt außerhalb meines Bereichs und wurde bewusst
nicht committet.

## Empfohlener nächster Schritt

Review von KL-WEB-003 (Peer oder Nutzer). Danach führt der Nutzer die
Account-Schritte aus `SANDBOX_SETUP.md` aus; sobald eine Instanz steht, laufen
die Integrationstests echte Aussagen und das Vercel-Deployment kann live
getestet werden. Erst danach: D4-Hosting-PoC (Vercel vs. Cloudflare Workers)
als eigenes Ticket.
