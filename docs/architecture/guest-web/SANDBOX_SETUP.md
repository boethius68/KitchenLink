# SANDBOX_SETUP — Gast-Web-Sandbox in Betrieb nehmen

**Stand:** 18. Juli 2026
**Ticket:** KL-WEB-003
**Gültigkeit:** Sandbox/Preview. Keine Produktionsfreigabe (Blueprint §20,
DECISIONS.md). Keine echten Zahlungen.

Dieser Leitfaden führt Schritt für Schritt durch das In-Betrieb-nehmen der
Gast-Web-Sandbox gegen eine echte Supabase-Instanz und ein Git-basiertes
PaaS-Deployment. Der aktuelle Deploy läuft auf Hostinger PaaS.
Er ist für den Nutzer (Account-Inhaber) geschrieben; die Agenten legen keine
Cloud-Ressourcen an und committen keine Secrets.

> **Vorgaben:** [`ADR-001_GUEST_WEB_STACK.md`](./ADR-001_GUEST_WEB_STACK.md)
> (§6 Bestellgrenze, §6.3 Anonymous Sign-in). ADR-001 §8 ist für die Sandbox
> durch den realen Hostinger-Deploy überholt; eine produktionsreife
> Hosting-Entscheidung bleibt offen.

---

## 0. Voraussetzungen

- Supabase-Account (kostenloser Tier reicht für die Sandbox).
- Für eine Reproduktion des aktuellen Deploys: Hostinger-PaaS-Zugang. Ein
  anderer Next.js-fähiger Git-Host funktioniert ebenfalls.
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

Es gibt **fünf** Migrationen, die in Reihenfolge angewendet werden müssen:

| Datei | Zweck |
|---|---|
| `supabase/migrations/20260318011000_kitchenlink_core_schema.sql` | Basis-Schema (venues, menu_items, orders, …) |
| `supabase/migrations/20260717120000_guest_web_order_gate.sql` | RLS, Idempotenz, Seed, RPC (KL-WEB-002) |
| `supabase/migrations/20260718010000_guest_web_submit_order_race_fix.sql` | Race-safe RPC (KL-WEB-003) |
| `supabase/migrations/20260719000000_menu_items_tag.sql` | Menü-Tag-Feld und Seed für den Supabase-Leseweg (KL-WEB-004) |
| `supabase/migrations/20260719100000_operator_cloud_orders.sql` | Betreiber: venue_staff, Staff-Lese-Policies, Status-RPC, Hub-Presence (KL-CLOUD-001) |

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

Dashboard → **SQL Editor** → nacheinander die fünf Dateien aus
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

## 6.1 Betreiber-Konto für den Online-Service (KL-CLOUD-001)

Damit die iPhone-App die Gast-Web-Bestellungen sehen und abarbeiten darf,
braucht die Sandbox genau ein Betreiber-Konto plus Venue-Zuordnung. RLS gibt
Bestellungen nur für eingetragenes Personal frei; die Zuordnung selbst wird
bewusst nur über das Dashboard/Service Role geschrieben.

1. Migration `20260719100000_operator_cloud_orders.sql` anwenden (Abschnitt 2).
2. Dashboard → **Authentication → Users → Add user**: E-Mail + Passwort für
   den Sandbox-Operator anlegen (z. B. `operator@kitchenlink.test`),
   **Auto Confirm** aktivieren.
3. Die User-UUID aus der Nutzerliste kopieren und im **SQL Editor** der Venue
   zuordnen:

   ```sql
   insert into public.venue_staff (user_id, venue_id)
   values (
     '<USER-UUID>',
     (select id from public.venues where slug = 'alte-muehle')
   )
   on conflict do nothing;
   ```

4. In der iPhone-App: **Service** öffnen und in der Karte „Online-Bestellungen
   (Gast-Web)" nur **E-Mail + Passwort** des Betreiber-Kontos aus Schritt 2
   eingeben, dann **Online-Service aktivieren**. Supabase-URL, Anon-Key und
   Venue sind fest eingebacken (`KitchenLinkCloudConfig.sandboxDefault`) — sie
   werden nicht mehr eingetippt. Die Sitzung wird über das Refresh-Token
   erneuert; das Passwort wird nicht gespeichert. Danach verbindet sich das
   iPhone bei jedem Öffnen von selbst.

   > Zeigt der Menüpunkt noch „Lokaler Service" statt „Service", läuft ein
   > alter Build — dann erst `claude/cloud-order-loop` neu aufs Gerät bauen.

Smoke-Check der geschlossenen Schleife: auf `https://kitchenlink.luneq.eu/alte-muehle/menu`
bestellen → die Bestellung erscheint in der App unter **Service → Küche**,
`Bestellung zubereitet` verschiebt sie in den Kellner-Modus, `Bestellung
serviert` schließt sie ab (Status-Spalten in **Table Editor → orders**
wandern mit).

Hinweis zur Ausfall-Anzeige: solange die Service-Ansicht offen ist, meldet die
App alle 15 s einen Heartbeat nach `venue_hub_presence` (inklusive der lokalen
Hub-URL). Bleibt der Heartbeat > 45 s aus, blendet das Gast-Web den Hinweis
„Online-Bestellung gerade nicht möglich" ein und verweist auf die lokale
Bestellseite im Restaurant-WLAN.

---

## 7. Was bewusst NICHT hier gelöst ist

- **Produktionsreifes Hosting:** Hostinger ist für die Sandbox gewählt; eine
  spätere Produktionsentscheidung bleibt offen.
- **PWA/Offline-Shell** ist Stage 2, eigene Entscheidung (ADR-001 §5, D5).
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
| Bestellung klappt lokal, nicht auf Hostinger | Env-Variablen im Hostinger-Projekt fehlen oder die URL endet fälschlich auf `.supabase.com` statt `.supabase.co` (Abschnitt 5) |
