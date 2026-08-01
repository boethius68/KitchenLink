# SANDBOX_SETUP — Gast-Web-Sandbox in Betrieb nehmen

**Stand:** 18. Juli 2026
**Ticket:** KL-WEB-003
**Gültigkeit:** Sandbox/Preview. Keine Produktionsfreigabe (Blueprint §20,
DECISIONS.md). Keine echten Zahlungen.

Dieser Leitfaden führt Schritt für Schritt durch das In-Betrieb-nehmen der
Gast-Web-Sandbox gegen eine echte Supabase-Instanz und ein Git-basiertes
PaaS-Deployment. Der aktuelle Deploy läuft auf Hostinger PaaS.
Er ist für den Nutzer (Account-Inhaber) geschrieben. Die Agenten committen keine
Secrets und legen keine Cloud-Ressourcen an — kein Projekt, keine Keys, keine
Auth-Einstellungen. **Migrationen sind davon ausgenommen:** ist die
Supabase-CLI lokal eingeloggt und verknüpft, wendet ein Agent sie über
`supabase db push` selbst an und prüft danach den Zustand (Abschnitt 2). Sie
gegen den Nutzer zurückzuhalten war ein Missverständnis — sein Urteil wird für
das Produkt gebraucht, nicht für ein `db push`.

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

Es gibt **21** Migrationen, die in Reihenfolge angewendet werden müssen:

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
| `supabase/migrations/20260723120000_operator_additive_menu_edit.sql` | Einzelne Artikel anlegen/ändern/löschen ohne Vollersatz (KL-MENU-009) |
| `supabase/migrations/20260723150000_operator_item_availability.sql` | Verfügbarkeit und Zeitfenster je Artikel (KL-MENU-010) |
| `supabase/migrations/20260724000000_operator_create_order.sql` | Cloud-Weg für lokal aufgenommene Bestellungen |
| `supabase/migrations/20260730120000_table_context.sql` | Tische, QR-Tokens, Tisch-Session; RLS auf der Tischschicht (KL-TABLE-001) |
| `supabase/migrations/20260730160000_operator_create_order_table.sql` | Kellnerbestellung mit Tisch, Idempotenz-Fix (KL-TABLE-002) |
| `supabase/migrations/20260731100000_sandbox_payments.sql` | Rechnung, Trinkgeld, simulierte Zahlung, Storno (KL-PAY-001) |
| `supabase/migrations/20260731140000_station_routing.sql` | Küche/Bar je Position, Stationsfreigabe (KL-STATION-001) |
| `supabase/migrations/20260731160000_order_confirmation_rule.sql` | Bestätigungspflicht je Kanal, Status `rejected` (KL-ORDER-001) |
| `supabase/migrations/20260731180000_operator_create_venue.sql` | Eigenes Restaurant anlegen, Slug-Vorschlag, eigene Venues (KL-ONBOARD-001) |
| `supabase/migrations/20260731200000_business_shift.sql` | Betriebsschicht, Bargeldbewegungen, Kassenabschluss und Z-Bericht (KL-SHIFT-001) |
| `supabase/migrations/20260731220000_roles_and_permissions.sql` | Standardrollen je Venue, fünf Rechte, Personalverwaltung (KL-ROLE-001) |
| `supabase/migrations/20260731230000_manager_pin.sql` | Persönliche Manager-PIN, einmalige Freigabe je Aktion, Audit (KL-ROLE-002) |
| `supabase/migrations/20260801120000_time_clock.sql` | Zeiterfassung: stempeln, Pausen, Korrektur mit Audit (KL-TIME-001) |

> **Stand der Sandbox-Instanz (1. August 2026):** angewendet sind die ersten 19
> sowie eine Manager-PIN-Migration (`20260731230000`) aus einer parallelen
> Arbeitslinie. **Offen ist `20260801120000_time_clock.sql`** — sie ist lokal
> gegen echtes PostgreSQL geprüft, auch zusammen mit der PIN-Migration, aber
> noch nicht gepusht: `supabase db push` verlangt eine lückenlose lokale
> Historie, und die PIN-Datei liegt bis zu ihrer Integration in einem anderen
> Arbeitsbaum. Sobald beide auf `main` sind, ist der Push ein einzelner Aufruf.
>
> Zuletzt geprüft: keine Tabelle im Schema `public` ohne RLS, sechs aktive
> Tische, die RPCs `operator_table_check`, `operator_record_payment`,
> `operator_mark_station_ready`, `operator_reject_order` und
> `operator_create_venue` vorhanden. Die Schrittlisten in Abschnitt 6 bleiben
> für eine frische Instanz gültig.

### Weg A — über die CLI (empfohlen)

```bash
# Einmalig: CLI einloggen
supabase login

# Repo mit dem Projekt verknüpfen (im Repo-Wurzel-Verzeichnis)
supabase link --project-ref <DEINE_PROJECT_REF>

# Zeigt an, was lokal vorliegt und was die Instanz kennt
supabase migration list

# Alle offenen Migrationen anwenden
supabase db push
```

`<DEINE_PROJECT_REF>` steht im Dashboard unter Project Settings → API. Die
`supabase/config.toml` im Repo ist dafür vorbereitet; sie enthält keine Secrets.

**Ist die CLI verknüpft, wendet ein Agent die Migrationen selbst an.** Das ist
kein Nutzerschritt (siehe Abschnitt 0). Zu erledigen bleibt für den
Account-Inhaber nur, was ein Dashboard-Recht braucht: Projektanlage, Anonymous
Sign-in, Auth-Einstellungen.

### Weg B — über den SQL-Editor

Dashboard → **SQL Editor** → nacheinander die Dateien aus
`supabase/migrations/` einfügen und **Run**. Reihenfolge einhalten.

> **Achtung, Ledger-Drift:** Weg B trägt **nichts** in die Ledger-Tabelle
> `supabase_migrations.schema_migrations` ein. `supabase migration list` zeigt
> eine von Hand angewendete Migration danach weiterhin als offen, und ein
> späteres `db push` spielt sie erneut ein. Deshalb muss **jede** Migration
> dieses Repos wiederholbar sein: `create policy` und `create trigger` bekommen
> ihr `drop … if exists` davor, `create table`/`create index` ihr
> `if not exists`, Seeds ein `on conflict`. Der zweite Durchlauf in
> `scripts/verify-supabase-migrations.sh` erzwingt genau das und lässt den Lauf
> scheitern, sobald eine Migration sich nicht wiederholen lässt.

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

## 6.5 Rechnung kassieren (KL-PAY-001)

Blueprint §8.1, Meilenstein 1.11 — der Abschluss des Ablaufs vom Scan bis zur
Zahlung. **Keine Sandbox-Zahlung bewegt echtes Geld.**

1. Migration `20260731100000_sandbox_payments.sql` anwenden (Abschnitt 2).
2. **Service → „Rechnung kassieren"**, Tisch wählen.
3. Die Rechnung listet alle Positionen der gemeinsamen Tisch-Session — auch die
   von mehreren Gästen und vom Kellner.
   - **Gemeinsam zahlen:** nichts auswählen, „Kassieren".
   - **Getrennt zahlen:** die Positionen antippen, die dieser Gast zahlt.
   - **Teilbetrag:** ohne Auswahl kassiert die App den offenen Betrag; ein
     abweichender Teilbetrag ist über die RPC möglich.
4. Zahlart wählen (Bar, Karte, Tap to Pay, Gutschein) und optional Trinkgeld.
   Karte und Tap to Pay laufen über den simulierten Zahlungsanbieter.
5. Der Beleg nennt Betrag, Trinkgeld, den verbleibenden offenen Betrag und die
   Sandbox-Referenz. „Zahlung stornieren" gibt die Positionen wieder frei.
6. Ist nichts mehr offen, schließt sich die Tisch-Session; der nächste Gast an
   diesem Tisch eröffnet eine neue.

**Semantik:** Der Betrag kommt nie vom Gerät. Bei ausgewählten Positionen
rechnet die Datenbank ihn aus deren Zeilensummen und weist eine abweichende
Behauptung ab. Eine Position kann nicht zweimal offen bezahlt sein — das
erzwingt ein Index, nicht die App; zwei gleichzeitig kassierende Geräte können
denselben Gang also nicht doppelt abrechnen. Jede Zahlung trägt einen
Idempotenz-Schlüssel: ein wiederholter Versuch bucht nicht erneut.

**Noch nicht enthalten** (eigene Scheiben): Betriebsschicht und Tagesabschluss
(§8.3), Onlinezahlung im Gast-Web, Gutschein-/Guthabenkonten, Zahlung bei
Lieferung, Fiskalisierung und Belegdruck (§8.2 `FiscalizationProvider`,
`ReceiptProvider`).

## 6.6 Stationen und Annahmeregel (KL-STATION-001 / KL-ORDER-001)

Blueprint §7 und §6.3 — die letzten beiden Punkte von Meilenstein 1.

1. Migrationen `20260731140000_station_routing.sql` und
   `20260731160000_order_confirmation_rule.sql` anwenden (Abschnitt 2).
2. **Service** hat jetzt drei Modi: `Küche | Bar | Kellner`.
   - Die Küche sieht nur Speisen, die Bar nur Getränke.
   - Jede Station schaltet mit „Speisen fertig" bzw. „Getränke fertig" **nur
     ihre eigenen** Positionen frei.
   - Solange die andere Station arbeitet, steht das auf der Karte („Küche
     arbeitet noch"). Erst wenn keine Station mehr offen ist, erscheint die
     Bestellung beim Kellner.
3. **Bestätigungspflicht** (optional): Standard ist automatische Annahme. Zum
   Einschalten für einen Kanal, z. B. Abholung:

   ```sql
   select operator_set_confirmation_channels('alte-muehle', array['pickup']);
   ```

   Danach erscheinen Abholbestellungen zuerst unter **„Zu bestätigen"** mit
   Annehmen und Ablehnen; die Station sieht sie erst nach dem Annehmen.
   Zurück auf den Standard: `array[]::text[]`.

**Semantik:** Die Station folgt der Artikelart (Speise → Küche, Getränk → Bar)
und steht als eigene Spalte, damit eine spätere Zuordnung je Artikel nichts
umbaut. Ablehnen ist nur vor der Annahme möglich — was schon läuft, wird
storniert, nicht abgelehnt; das sind fachlich zwei verschiedene Dinge und sie
sehen in den Daten auch verschieden aus.

**Grenze, bewusst so:** Der Stationsstatus wird in der Cloud geführt. Rein
lokale Bestellungen (Offline-Fall) behalten den Bump über die ganze Bestellung
— die Stationstrennung löst ein Mehrgeräteproblem, und offline ist per
Definition ein Gerät im Spiel.

## 6.7 Eigenes Restaurant anlegen (KL-ONBOARD-001)

Blueprint §5, Meilenstein 1.3 — ab hier braucht niemand mehr SQL, um ein
Restaurant einzurichten.

1. Migration `20260731180000_operator_create_venue.sql` anwenden (Abschnitt 2).
2. In der App **Restaurant** öffnen (Startseite). Die Karte oben zeigt, welches
   Lokal dieses iPhone gerade bedient — anfangs das mitgelieferte Demo-Lokal.
3. Anmelden oder **Konto anlegen**. Verlangt die Instanz eine E-Mail-Bestätigung
   (Supabase-Standard), sagt die App das und wartet auf die Anmeldung.
4. Namen des Restaurants eingeben. Die Gast-Adresse wird darunter live
   angezeigt; ein bereits vergebener Name weicht automatisch aus
   (`…-2`). **Restaurant anlegen**.
5. Ab sofort arbeiten Scan-Veröffentlichung, Tische, Bestellungen, Stationen
   und Rechnung auf diesem Lokal. Über **Demo-Lokal verwenden** geht es für eine
   Vorführung zurück.

**Semantik:** Wer anlegt, wird automatisch Personal seiner Venue — der manuelle
`venue_staff`-Eintrag aus §6.1 entfällt für neue Restaurants. Instanz und
Anon-Key bleiben eingebacken; nur die Venue wechselt. In der Sandbox sind fünf
Restaurants je Konto möglich.

## 6.8 Betriebsschicht und Kassenabschluss (KL-SHIFT-001)

Blueprint §8.3, Meilenstein 2 — die Klammer um alles, was Geld bewegt.
**Kein Sandbox-Abschluss ist ein steuerlich gültiger Z-Bericht.**

1. Migration `20260731200000_business_shift.sql` anwenden (Abschnitt 2).
2. **Kasse** öffnen (Startseite). Ist keine Schicht offen, gibt es genau einen
   Knopf: Anfangsbestand eintragen (darf leer bleiben) und **Schicht öffnen**.
3. Während des Betriebs zeigt die Karte oben, was in der Schublade liegen muss,
   und darunter, wie diese Zahl zustande kommt. Alle Geräte der Venue arbeiten
   auf derselben Schicht.
4. **Bargeld bewegen** für alles, was keine Zahlung ist: *Entnahme* in den
   Tresor, *Ausgabe* an einen bar bezahlten Lieferanten, *Einlage* für
   nachgelegtes Wechselgeld.
5. **Kasse zählen und abschließen:** eintragen, was tatsächlich in der
   Schublade liegt. Die Abweichung wird vor dem Buchen als Vorschau gezeigt und
   danach mit dem Z-Bericht festgehalten.

**Semantik:** Der erwartete Bestand kommt nie vom Gerät — er wird bei jedem
Bericht in der Datenbank gerechnet, weil ein zweites Gerät jederzeit kassiert
haben kann. Nur Bargeld zählt hinein, und zwar **inklusive Trinkgeld** (der
Gast legt beides auf den Tisch); Karte, Tap to Pay, Gutschein und Onlinezahlung
nicht. Eine stornierte Barzahlung senkt den Bestand wieder. Je Venue ist
höchstens eine Schicht offen — das erzwingt ein Index, nicht die App.

Zwei bewusste Entscheidungen: eine **Zahlung** ohne offene Schicht wird nicht
blockiert (Geld anzunehmen darf nie an einem vergessenen Knopfdruck scheitern),
erscheint aber im Bericht als „außerhalb der Schicht"; eine **Entnahme**
verlangt eine offene Kasse. Und die Abweichung wird festgehalten, nicht
verhindert — offene Rechnungen werden vor dem Abschluss gewarnt, aber nicht
erzwungen.

**Noch nicht enthalten** (eigene Scheiben): Schichtplanung und Zeiterfassung
(§9.2/§9.3 — die Domäne dafür liegt getestet unter `Features/Workforce/`, ist
aber noch nirgends sichtbar), Kassenbuch und Ausgabenbelege (§20 Meilenstein 6),
Fiskalisierung und Belegdruck.

## 6.9 Rollen und Rechte (KL-ROLE-001)

Blueprint §9.1, Meilenstein 2 — bis hierher galt: **wer angemeldet ist, darf
alles.** Jede Servicekraft konnte die Kasse abschließen und Zahlungen
stornieren.

1. Migration `20260731220000_roles_and_permissions.sql` anwenden (Abschnitt 2).
2. **Team** öffnen (Startseite). Der Bildschirm ist selbst rechtepflichtig: ohne
   `staff.manage` zeigt er die Rollenübersicht, aber kein Personal.
3. Rolle einer Person über das Menü rechts in ihrer Zeile ändern.
4. Jemanden hinzufügen: die Person **registriert sich zuerst selbst** in der App
   (Bereich `Restaurant` → Konto anlegen), danach ordnest du ihre E-Mail zu.
   KitchenLink legt keine fremden Konten an.

**Der Zuschnitt ist bewusst eng.** Es gibt genau fünf Rechte, und alle fünf
werden auch geprüft — kein Recht steht in der Liste, das nirgends wirkt:

| Recht | Wirkt auf |
|---|---|
| `shift.open` | `operator_open_shift` |
| `shift.close` | `operator_close_shift` |
| `cash.movement` | `operator_record_cash_movement` |
| `payments.refund` | `operator_refund_payment` |
| `staff.manage` | `operator_venue_team`, `operator_add_staff`, `operator_set_staff_role`, `operator_remove_staff` |

Alles andere — bestellen, Status ändern, Station freigeben, kassieren, Rechnung
und Kassenstand lesen — bleibt jedem Personal offen. Das ist keine Lücke,
sondern der Betrieb: Küche, Bar und Service brauchen genau diese Handgriffe.
Die Konfigurationsrechte (Karte veröffentlichen, Tische ändern) sind eine eigene
Scheibe und kommen zusammen mit ihrer Durchsetzung, nicht davor.

**Standardrollen** (§9.1): Inhaber und Manager tragen alle fünf Rechte,
Schichtleitung alle außer `staff.manage`, Service, Küche, Bar, Fahrer, Lager und
Buchhaltung keines. Sie liegen **je Venue** in `venue_roles` statt als
Aufzählung im Code — „eigene Rollen mit granularen Rechten" (§9.1) ist damit
später ein Datensatz mehr, kein Umbau.

**Drei Sperren** verhindern, dass eine Venue führungslos wird: niemand ändert
oder entfernt den eigenen Zugang, nur ein Inhaber kann einen Inhaber ändern, und
der letzte Inhaber bleibt Inhaber.

**Bestandspersonal verliert nichts:** die Rolle `operator` (faktisch „darf
alles") wird zu `owner`. Der Spaltendefault für neue Zeilen steht dagegen auf
`service` — die geringste Befugnis.

**Noch nicht enthalten:** eigene Rollen, Qualifikationen, Mitarbeiterprofile
und Rechte über mehrere Standorte. Der Manager-PIN aus §9.1 kam mit KL-ROLE-002
nach — siehe 6.10.

## 6.10 Manager-PIN (KL-ROLE-002)

Blueprint §9.1 verlangt „sensible Aktionen per besonderem Recht **oder**
Manager-PIN". KL-ROLE-001 hat nur das Recht gebaut. Damit musste eine
Servicekraft, die am Tisch eine Zahlung stornieren soll, den Manager physisch
holen — die PIN ist genau für diesen Fall: eine Führungskraft gibt **eine**
Aktion vor Ort frei, ohne dass sich jemand ab- und wieder anmeldet.

1. Migration `20260731230000_manager_pin.sql` anwenden (Abschnitt 2).
2. **Team** öffnen und unter *Deine PIN* vier bis acht Ziffern hinterlegen. Das
   kann jeder, der eines der vier überbrückbaren Rechte trägt — also Inhaber,
   Manager und Schichtleitung.
3. Mit einem zweiten Konto in der Rolle *Service* anmelden und am Tisch eine
   Zahlung stornieren wollen. Statt einer Sackgasse steht dort **Freigabe
   holen**.
4. Die Führungskraft tippt am selben Gerät ihre PIN ein — keinen Namen, keine
   Anmeldung. Der Storno geht durch, das Gerät bleibt bei der Servicekraft
   angemeldet.
5. Im **Team**-Bildschirm steht die Freigabe danach unter *Freigaben*: wer, für
   wen, wofür, wann erteilt und wann verbraucht.

**Die PIN gehört einer Person, nicht dem Lokal.** Das folgt aus Blueprint §8.2
(jeder Zahlungsvorgang ist auditiert): eine gemeinsame Haus-PIN könnte die Frage
„wer hat das freigegeben?" prinzipiell nicht beantworten. Daraus folgt auch, was
eine PIN darf — genau das, was ihr Inhaber selbst dürfte. Wird eine
Führungskraft herabgestuft, gibt ihre PIN sofort nichts mehr frei, ohne dass
jemand sie löschen müsste.

**Vier der fünf Rechte sind überbrückbar, `staff.manage` nicht.** Wer per
geliehener PIN Personal verwalten dürfte, könnte sich in derselben Minute selbst
zum Inhaber machen; das wäre keine Freigabe für eine Aktion mehr, sondern eine
dauerhafte Rechteerhöhung.

| Aktion | Recht | Per PIN freigebbar |
|---|---|---|
| Schicht öffnen | `shift.open` | ja |
| Kasse abschließen | `shift.close` | ja |
| Bargeld bewegen | `cash.movement` | ja |
| Zahlung stornieren | `payments.refund` | ja |
| Personal verwalten | `staff.manage` | **nein** |

**Eine Freigabe gilt einmal**, fünf Minuten lang, für diese Aktion, dieses
Lokal und diesen Zugang — sie ist nicht weiterreichbar. Der Token wird beim
Verbrauchen in derselben Anweisung als benutzt markiert, die ihn prüft; zwei
gleichzeitige Versuche können also nicht beide gewinnen.

**Gegen Ausprobieren:** die PIN liegt als bcrypt-Hash (`extensions.crypt`), nie
im Klartext, und nach fünf Fehlversuchen ist das **anfragende Gerät** fünf
Minuten gesperrt — nicht das Lokal, denn eine falsche PIN gehört zu niemandem.
Führen zwei Personen dieselbe PIN, wird nichts freigegeben (`pin_ambiguous`):
eine Freigabe, die sich niemandem zuordnen lässt, ist für §8.2 wertlos.
Durchgehend gleiche Ziffern (`0000`) und fortlaufende Reihen (`1234`) werden
abgelehnt.

`manager_pins`, `manager_pin_attempts` und `manager_overrides` haben Row Level
Security **ohne Policy** und ohne Grants für `anon`/`authenticated`: kein Client
liest dort je eine Zeile. Gelesen wird nur über `operator_recent_overrides`,
das sein eigenes Recht prüft und den Token-Hash nicht herausgibt.

**Vorführbar ohne zweites Konto:** das Launch-Argument
`--kitchenlink-demo-service-role` lässt die Demo-Pfade die Rolle `service`
melden (der Demo-Zugang ist sonst Inhaber und darf alles). Zusammen mit
`--kitchenlink-demo-tables` sind Sperre und Freigabe damit im Simulator
durchspielbar; die Demo-Schichtleitung hat die PIN `4711`, sie steht auch auf
dem Blatt.

**Noch nicht enthalten:** eine Freigabe an ein bestimmtes Objekt zu binden (der
Bezug wird protokolliert, aber nicht erzwungen), PIN-Rotationsfristen, und eine
Freigabe aus der Ferne (das Gerät der Führungskraft bestätigt statt ihrer PIN).

## 6.11 Zeiterfassung (KL-TIME-001)

Blueprint §9.3, Meilenstein 2 — die erste Hälfte der Personalzeit. Seit
KL-WORKFORCE-001 lag unter `kitchenlink/Features/Workforce/` eine getestete
Domäne für Planung und Zeit mit **null Referenzen** aus der App; ihr fehlten
Persistenz und Oberfläche.

1. Migration `20260801120000_time_clock.sql` anwenden (Abschnitt 2).
2. **Zeiterfassung** öffnen (Startseite). Der große Knopf stempelt ein und aus.
3. Während der Schicht **Pause beginnen** und **beenden**; die Arbeitszeit
   steht still, solange die Pause läuft.
4. Wer `staff.manage` trägt, sieht darunter, wer gerade auf der Uhr steht, und
   die abgeschlossenen Einträge des Tages.
5. Steht jemand seit über zwölf Stunden auf der Uhr, meldet der Bildschirm das
   als vergessenen Ausstempel und bietet die Korrektur an.

**Semantik:** Blueprint §9 hält drei Fachobjekte getrennt, und das bleibt so —
die **Betriebsschicht** (`business_shifts`, „die Kasse ist offen"), die
**geplante Schicht** (noch nicht persistiert, §9.2) und der **Zeiteintrag**
(„diese Person hat gearbeitet"). Ein Zeiteintrag hängt deshalb nicht an einer
Betriebsschicht: wer um 15 Uhr die Küche vorbereitet, arbeitet auch dann, wenn
die Kasse noch zu ist.

Die eigene Zeit zu stempeln braucht **kein** besonderes Recht — die Küche muss
auf die Uhr kommen, ohne jemanden zu fragen. Die Zeiten *anderer* zu sehen und
zu korrigieren verlangt `staff.manage`. Ein Nachtdienst zählt zu dem Tag, an
dem er **begonnen** hat. Pausen gehen von der Arbeitszeit ab; eine laufende
Pause wird bis jetzt gerechnet, damit die Anzeige nicht weiterläuft.

Eine **Korrektur** (§9.3 „mit Freigabe und Audit") verlangt einen Grund und
**behält den ursprünglichen Stand**: `original_started_at` und
`original_ended_at` bleiben stehen, dazu Urheber und Zeitpunkt. Eine zweite
Korrektur überschreibt den echten Originalwert nicht. Ohne diesen Weg bliebe ein
vergessener Ausstempel für immer offen — und die Person käme wegen des Index nie
wieder auf die Uhr.

**Noch nicht enthalten:** Schichtplanung, Verfügbarkeiten, Urlaub und Krankheit
(§9.2), Soll-/Ist-Vergleich und Überstunden (§9.3 — beides setzt die Planung
voraus, gegen die verglichen wird), Lohnbuchhaltungsexporte.

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
| „Freigabe holen" fehlt trotz fehlendem Recht | Niemand hat eine PIN hinterlegt (Abschnitt 6.10), oder Migration `20260731230000` fehlt |
| `permission_override_invalid` beim Stornieren | Freigabe abgelaufen (5 Minuten), schon verbraucht, oder sie gehört zu einer anderen Aktion bzw. einem anderen Zugang |
| Bestellung klappt lokal, nicht auf Hostinger | Env-Variablen im Hostinger-Projekt fehlen oder die URL endet fälschlich auf `.supabase.com` statt `.supabase.co` (Abschnitt 5) |
