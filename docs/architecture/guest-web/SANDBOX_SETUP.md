# SANDBOX_SETUP — Gast-Web-Sandbox in Betrieb nehmen

**Stand:** 18. Juli 2026
**Ticket:** KL-WEB-003
**Gültigkeit:** Sandbox/Preview. Keine Produktionsfreigabe (Blueprint §20,
DECISIONS.md). Keine echten Zahlungen.

Dieser Leitfaden führt Schritt für Schritt durch das In-Betrieb-nehmen der
Gast-Web-Sandbox gegen eine echte Supabase-Instanz und ein Vercel-Deployment.
Er ist für den Nutzer (Account-Inhaber) geschrieben; die Agenten legen keine
Cloud-Ressourcen an und committen keine Secrets.

> **Vorgaben:** [`ADR-001_GUEST_WEB_STACK.md`](./ADR-001_GUEST_WEB_STACK.md)
> (§6 Bestellgrenze, §6.3 Anonymous Sign-in, §8 Hosting-PoC). Das Vercel-
> Deployment hier ist der **erste Sandbox-Deploy**, **keine** Hosting-Entscheidung
> (D4) — die PoC-Matrix aus ADR-001 §8 bleibt offen.

---

## 0. Voraussetzungen

- Supabase-Account (kostenloser Tier reicht für die Sandbox).
- Vercel-Account (kostenloser Tier reicht).
- Lokal: Node 20+, `npm`. Optional die Supabase-CLI (`npm i -g supabase`).
- Dieses Repository ausgecheckt; `guest-web/` und `supabase/migrations/`
  vorhanden.

---

## 1. Supabase-Sandbox-Projekt anlegen

1. Im Supabase-Dashboard **New Project**.
2. **Region: Frankfurt (eu-central-1)** — ADR-001 [S25] fordert EU-Frankfurt.
3. Datenbank-Passwort sicher notieren (wird für CLI gebraucht, kommt nicht ins
   Repo).
4. Projekt warten, bis es „Ready" ist.

### 1.1 Anonymous Sign-in aktivieren (zwingend)

Ohne aktiven Anonymous Sign-in scheitert jede Bestellung, weil die RPC
`guest_web_submit_order` einen anonym eingelogten User verlangt (ADR-001 §6.3,
DECISIONS.md Guest Web).

- Dashboard → **Authentication** → **Providers** → **Anonymous** → **Enable**.

### 1.2 URL + Anon-Key besorgen

- Dashboard → **Project Settings** → **API**:
  - **Project URL** kopieren.
  - **anon public** Key kopieren (NICHT den service_role key — der bleibt
    serverseitig und kommt nie ins Gast-Web).

---

## 2. Migrationen anwenden

Es gibt **drei** Migrationen, die in Reihenfolge angewendet werden müssen:

| Datei | Zweck |
|---|---|
| `supabase/migrations/20260318011000_kitchenlink_core_schema.sql` | Basis-Schema (venues, menu_items, orders, …) |
| `supabase/migrations/20260717120000_guest_web_order_gate.sql` | RLS, Idempotenz, Seed, RPC (KL-WEB-002) |
| `supabase/migrations/20260718010000_guest_web_submit_order_race_fix.sql` | Race-safe RPC (KL-WEB-003) |

### Weg A — über die CLI (empfohlen)

```bash
# Einmalig: CLI einloggen
supabase login

# Repo mit dem Projekt verknüpfen (im Repo-Wurzel-Verzeichnis)
supabase link --project-ref <DEINE_PROJECT_REF>

# Alle Migrationen anwenden
supabase db push
```

`<DEINE_PROJECT_REF>` steht im Dashboard unter Project Settings → API. Die
`supabase/config.toml` im Repo ist dafür vorbereitet; sie enthält keine Secrets.

### Weg B — über den SQL-Editor

Dashboard → **SQL Editor** → nacheinander die drei Dateien aus
`supabase/migrations/` einfügen und **Run**. Reihenfolge einhalten.

### Verifikation des Schemas

```sql
-- sollte 8 Zeilen liefern (die Sandbox-Artikel)
select slug, name, price_cents from public.menu_items order by sort_order;

-- RLS muss überall an sein
select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename in
  ('venues','menus','menu_categories','menu_items','orders','order_items');
-- Erwartung: sechs Zeilen, rowsecurity = true bei jeder.
```

---

## 3. Gast-Web lokal konfigurieren

Im Verzeichnis `guest-web/` eine **`.env.local`** anlegen (wird von der
`.gitignore` ausgeschlossen — sie wird nicht committet):

```bash
# guest-web/.env.local  (NICHT committen)
NEXT_PUBLIC_SUPABASE_URL=https://<dein-projekt>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<dein-anon-public-key>
```

Die Vorlage dafür steht in `guest-web/.env.example`.

> **Wichtig seit KL-WEB-004:** das Menü wird aus Supabase geladen (ISR,
> `revalidate = 60s`). Die `NEXT_PUBLIC_SUPABASE_*`-Env-Variablen werden daher
> auch **zur Build-Zeit** gebraucht (Hostinger-PaaS-Env setzt sie für beide
> Phasen). Fällt Supabase während eines Rebuilds aus, greift der
> Fixture-Fallback (`venue-data.ts`) — der Build rotiert nicht, und DB-Änderungen
> sind nach max. 60 Sekunden sichtbar.

Dann lokal starten:

```bash
cd guest-web
npm install
npm run dev
```

Menü unter `http://localhost:3000/alte-muehle/menu` öffnen, Artikel in den
Warenkorb legen, „Sandbox-Bestellung senden" klicken. Bei korrekt konfigurierter
Instanz erscheint das ACK aus der Serverantwort (Status „pending", Bestell-ID).

---

## 4. Integrationstests gegen die echte Instanz

Diese Tests beweisen das, was die Unit-Tests nicht beweisen können (echte RPC,
RLS-Durchsetzung, Anonymous-Sign-in-Pfad) — siehe
[`ORDER_GATE.md`](./ORDER_GATE.md) §7.

```bash
cd guest-web
# Env-Variablen muessen gesetzt sein (z. B. ueber die .env.local oder export)
KL_INTEGRATION=1 npm run test:integration
```

Ohne `KL_INTEGRATION=1` bzw. ohne gesetzte Env-Variablen skippen die
Integrationstests sauber (kein falsches Rot). Der Opt-in schützt davor, dass
zufällig gesetzte Produktiv-Variablen versehentlich eine echte Instanz triggern.

---

## 5. Deployment (Git-basierte PaaS)

Der Gast-Web-Code ist hosting-neutral (keine `vercel.json`/`wrangler.toml`-
Lock-in-Datei im Repo). Für die Sandbox haben wir uns für ein **Git-basiertes
PaaS** entschieden, das automatisch aus `main` baut und deployed.

### Gewählter Sandbox-Host: Hostinger PaaS

Der aktuelle Sandbox-Deploy läuft auf **Hostinger PaaS** (Git-Auto-Deploy aus
`main`) unter **`https://kitchenlink.luneq.eu`**. Das ersetzt den in ADR-001
§8 skizzierten Vercel-vs-Cloudflare-PoC für Sandbox-Zwecke; eine spätere
produktionsreife Hosting-Entscheidung bleibt offen.

Schritte (die der Nutzer im Hostinger-Dashboard gemacht hat):

1. Hostinger → neues PaaS-Projekt, **GitHub-Repo** verbinden, Branch `main`.
2. **Root Directory** auf `guest-web/` setzen.
3. Framework: **Next.js**, Node 22.x (automatisch erkannt).
4. **Environment Variables** setzen (siehe Warnung unten):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
5. Domain `kitchenlink.luneq.eu` angebunden; Hostinger besorgt SSL automatisch.
6. **Deploy**. Jeder Push auf `main` löst anschließend einen Neubau aus.

> **Bekannter Tippfehler, der teuer war:** die Supabase-URL endet auf **`.co`**,
> nicht `.com`. `https://<ref>.supabase.com` ist die Marketingseite und erzeugt
> im Browser das irreführende „Load failed". Immer `.supabase.co` verwenden.

Andere Git-basierte PaaS-Hosts (Vercel, Cloudflare Pages, Render, Railway)
folgen demselben Muster: Repo/`main` verbinden, Root Directory `guest-web/`,
die zwei `NEXT_PUBLIC_SUPABASE_*`-Env-Variablen setzen, deployen. Der Code
erfordert keine host-spezifische Anpassung.

### Nach dem Deploy

Die URL öffnen, Route `/<venue-slug>/menu` anhängen
(z. B. `https://kitchenlink.luneq.eu/alte-muehle/menu`) und den Smoke-Check
aus Abschnitt 6 wiederholen.

---

## 6. Smoke-Check (manuell)

- Menü lädt, acht Gerichte, Preise korrekt.
- Artikel hinzufügen → Bestellleiste füllt sich gelb, Summe stimmt.
- Sheet öffnen → „Sandbox-Bestellung senden" → ACK erscheint (Status „pending",
  Bestell-ID).
- Erneut dieselbe Bestellung senden → `idempotent_replay: true`, gleiche
  Bestell-ID.
- Bestätigung: im Supabase-Dashboard unter **Table Editor → orders** erscheint
  die Bestellung mit `created_by` = Anonymous-User-ID.

---

## 7. Was bewusst NICHT hier gelöst ist

- **Hosting-Entscheidung D4** (Vercel vs. Cloudflare Workers) bleibt offen
  (ADR-001 §8 PoC).
- **PWA/Offline-Shell** ist Stage 2, eigene Entscheidung (ADR-001 §5, D5).
- **Menü-Fetch via Supabase** statt lokaler Fixture ist ein Folgeticket; die
  Menüanzeige/SSG läuft weiter über `guest-web/src/lib/venue-data.ts`.
- **Cleanup orphaned anonymous users** (DECISIONS.md Guest Web) muss im
  Supabase-Projekt konfiguriert werden (Cron/Retention), ist kein Code-Scope.
- Keine echten Zahlungen, keine produktive Freigabe.

---

## 8. Fehler-Checkliste

| Symptom | Wahrscheinliche Ursache |
|---|---|
| „Supabase ist nicht konfiguriert" | `.env.local` fehlt oder Variablen leer |
| Bestellung schlägt mit `unauthenticated` fehl | Anonymous Sign-in im Dashboard nicht aktiviert (Abschnitt 1.1) |
| RPC-Fehler `unknown_venue` | Migrationen nicht (vollständig) angewendet; Seed fehlt |
| `permission denied` auf RPC | Migration 20260717… nicht angewendet (grants fehlen) |
| Bestellung klappt lokal, nicht auf Vercel | Env-Variablen in Vercel nicht gesetzt (Abschnitt 5.4) |
