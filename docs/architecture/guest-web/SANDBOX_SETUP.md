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
`guest_web_submit_order_v2` einen anonym eingelogten User verlangt (ADR-001 §6.3,
DECISIONS.md Guest Web).

- Dashboard → **Authentication** → **Providers** → **Anonymous** → **Enable**.

### 1.2 URL + Anon-Key besorgen

- Dashboard → **Project Settings** → **API**:
  - **Project URL** kopieren.
  - **anon public** Key kopieren (NICHT den service_role key — der bleibt
    serverseitig und kommt nie ins Gast-Web).

---

## 2. Migrationen anwenden

Es gibt **acht** Migrationen, die in Reihenfolge angewendet werden müssen:

| Datei | Zweck |
|---|---|
| `supabase/migrations/20260318011000_kitchenlink_core_schema.sql` | Basis-Schema (venues, menu_items, orders, …) |
| `supabase/migrations/20260717120000_guest_web_order_gate.sql` | RLS, Idempotenz, Seed, RPC (KL-WEB-002) |
| `supabase/migrations/20260718010000_guest_web_submit_order_race_fix.sql` | Race-safe RPC (KL-WEB-003) |
| `supabase/migrations/20260719000000_menu_items_tag.sql` | Menü-Tag-Feld und Seed für den Supabase-Leseweg (KL-WEB-004) |
| `supabase/migrations/20260719100000_operator_cloud_orders.sql` | Betreiber: venue_staff, Staff-Lese-Policies, Status-RPC, Hub-Presence (KL-CLOUD-001) |
| `supabase/migrations/20260719200000_operator_publish_menu.sql` | Betreiber-RPC zum Veröffentlichen einer gescannten Karte (KL-MENU-005) |
| `supabase/migrations/20260721120000_operator_publish_menu_legend_variants.sql` | Publish-V1 um Kennzeichnungslegenden und Legacy-Varianten erweitert |
| `supabase/migrations/20260722120000_guest_menu_configurations.sql` | Rich-Optionsvertrag, Publish-/Order-V2 und Auswahl-Snapshot (KL-MENU-008) |

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

Dashboard → **SQL Editor** → nacheinander die acht Dateien aus
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

## 6.2 Gescannte Karte online veröffentlichen (KL-MENU-005)

Die Scan-zu-Publish-Brücke bringt eine geprüfte, gescannte Speisekarte in die
Supabase-Venue, sodass sie auf dem Gast-Web erscheint. Voraussetzung ist das
Betreiber-Konto aus 6.1 (dieselbe Anmeldung; eine bestehende Sitzung genügt).

1. Alle Migrationen bis einschließlich
   `20260722120000_guest_menu_configurations.sql` anwenden (Abschnitt 2).
2. In der App eine Speisekarte scannen/importieren und im Prüf-Dialog
   („Import prüfen") alle offenen Einträge klären.
3. Sobald die Karte klarläuft, unten **„Online veröffentlichen"** wählen. Bei
   vorhandener Betreiber-Sitzung genügt ein Tap; sonst einmal E-Mail + Passwort
   des Betreiber-Kontos eingeben. Es werden keine technischen Verbindungsdaten
   abgefragt.
4. Bestätigung: das Sheet meldet „Karte ist online" mit der Live-URL
   (`kitchenlink.luneq.eu/alte-muehle/menu`). Die Gastkarte wird durch die
   ISR-Zwischenspeicherung in der Regel innerhalb einer Minute aktualisiert.

**Semantik:** Ein veröffentlichter Scan **ersetzt** die aktive Karte der Venue
vollständig (kein Merge). Der eingebaute Sandbox-Seed (8 Demo-Artikel) wird
dadurch durch die gescannte Karte abgelöst. Der Schreibweg läuft nur über die
staff-gated RPC `operator_publish_menu_v2`; die Menü-Tabellen bleiben ohne
direkte Client-Schreib-Policy. Varianten, Portionen und Extras werden mit
Preisart und Gruppenregeln veröffentlicht; der Gast sendet bei der Bestellung
nur die gewählten Option-IDs, Preise werden serverseitig neu berechnet.

### KI-Erfassung des Scans (KL-SCAN-002, Datenfluss)

Der Menü-Import analysiert die gescannten **Kartenbilder direkt mit einem
KI-Vision-Modell** (deutlich zuverlässiger als reine OCR bei Spalten, Varianten,
Set-Menüs und Allergen-Legenden). **Sandbox-Default (vom Nutzer freigegeben,
21. Juli 2026):** ohne eigenen Schlüssel läuft das kostenlos und ohne
Konfiguration über das **OpenCode-Zen-Gateway** (`opencode.ai/zen`, Free-Modell
`big-pickle`, keyloser Zugang). Das heißt: die gescannte Karte wird an diesen
externen KI-Dienst übertragen. Speisekarten sind öffentliche Daten (geringe
Sensibilität); die App weist im Import-Bereich sichtbar darauf hin.

Ein eigener Schlüssel (OpenAI-kompatibel) ersetzt den Default und wird unter
„Eigenen KI-Zugang verwenden" hinterlegt. Fällt die KI aus (Netz/Gateway),
fällt der Import automatisch auf die lokalen OCR-Regeln zurück, statt den Scan
abzubrechen. **Für Produktion** ist ein verlässlicher, vertraglich geregelter
Anbieter statt des anonymen Free-Gateways vorzusehen (in §7 als offener Punkt).

## 6.3 Tische und ihre QR-Codes (KL-TABLE-001)

Ab dieser Migration gehört eine Gastbestellung zu einem **Tisch**, nicht mehr
nur zum Lokal. Voraussetzung ist wieder das Betreiber-Konto aus 6.1.

1. Migration `20260730120000_table_context.sql` anwenden (Abschnitt 2). Sie
   aktiviert Row Level Security auf `tables`, `qr_tokens` und `table_sessions`
   — diese drei Tabellen waren bis dahin als einzige des Gastschemas
   ungeschützt — und legt für die Sandbox-Venue sechs Tische mit festen Tokens
   an (`sandbox-tisch-1` … `sandbox-tisch-5`, `sandbox-theke`).
2. In der App **„Tische"** öffnen (Startseite, unter Küche). Beim ersten Mal
   einmal mit den Betreiber-Zugangsdaten anmelden.
3. Einen Tisch antippen: QR-Code, Gast-URL, Teilen/Drucken, Umbenennen,
   Stilllegen, neuen Code ausgeben.
4. Gegenprobe: die Gast-URL im Browser öffnen
   (`kitchenlink.luneq.eu/alte-muehle/menu?tisch=sandbox-tisch-3`). Im Kopf der
   Karte steht jetzt „Tisch 3 · Gastraum". Eine Bestellung darüber erscheint im
   Bereich **Service** mit ihrer Tischangabe.

**Semantik:** Der QR-Code trägt ein Token aus `qr_tokens`, nicht die
Tischnummer. Umbenennen lässt gedruckte Codes gültig; „Neuen QR-Code ausgeben"
macht genau den alten ungültig. Ein unbekannter, abgelaufener oder stillgelegter
Code führt bewusst zu einer **Absage** statt zu einer tischlosen Bestellung —
eine Bestellung, die niemand zuordnen kann, kostet im Betrieb mehr als eine
abgewiesene. Die erste Bestellung eines Tisches eröffnet seine gemeinsame
Tisch-Session; jede weitere Bestellung desselben Tisches hängt sich an dieselbe
(Blueprint §6.1). Ohne Tisch-Token verhält sich die Bestellung exakt wie bisher.

**Die Sandbox-Tokens sind absichtlich vorhersagbar**, damit Doku, Tests und
Vorführung eine feste URL haben. Neu angelegte Tische bekommen zufällige Tokens;
`operator_rotate_table_token` ersetzt auch die Sandbox-Tokens jederzeit.

## 6.4 Bestellung durch den Kellner (KL-TABLE-002)

Der Weg für eine mündlich aufgegebene Bestellung — und der Pfad, der bei
Cloud-Ausfall trägt (`DECISIONS.md`, Local-First).

1. Migrationen bis einschließlich
   `20260730160000_operator_create_order_table.sql` anwenden (Abschnitt 2).
2. In der App **Service → „Bestellung aufnehmen"** öffnen.
3. Kanal wählen (Vor Ort / Bar / Abholung), bei „Vor Ort" den Tisch antippen,
   Artikel über die Plus-Knöpfe aufnehmen, optional einen Küchenhinweis
   erfassen, dann **annehmen**.
4. Die Bestätigung erscheint direkt über der Aktion: „Angenommen · dauerhaft
   gespeichert" plus die Aussage, ob die Cloud sie schon kennt.
5. Gegenprobe: die Bestellung steht in der Küchenliste mit ihrem Tisch als
   Überschrift, lässt sich auf „zubereitet" schalten und erscheint dann im
   Kellner-Modus.

**Semantik:** Die Bestellung gilt erst als angenommen, wenn sie im lokalen
Ereignisprotokoll festgeschrieben ist — nie vorher. Die Cloud ist Folge, nicht
Bedingung: ohne Verbindung bleibt die Bestellung gültig und wird von der Outbox
nachgereicht, sobald das Gerät wieder online ist. Am selben Tisch schreiben
Kellner und Gäste in **dieselbe** offene Tisch-Session.

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
| Gastkarte meldet „Tisch nicht erkannt" | Migration `20260730120000` nicht angewendet, Token rotiert oder Tisch stillgelegt |
| App meldet `column tables.area does not exist` | Migration `20260730120000` fehlt auf der Instanz |
| Bestellung klappt lokal, nicht auf Hostinger | Env-Variablen im Hostinger-Projekt fehlen oder die URL endet fälschlich auf `.supabase.com` statt `.supabase.co` (Abschnitt 5) |
