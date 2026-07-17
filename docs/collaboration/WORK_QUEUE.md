# KitchenLink Work Queue

**Stand:** 17. Juli 2026
**Phase:** Designsystem-Implementierung im internen Sandbox-Build

Diese Queue zerlegt die naechste Ausbaustufe in konfliktfreie Arbeitspakete. Ein
Agent uebernimmt immer genau ein Ticket in einem eigenen Branch oder Worktree.
Bestehende Demo-, Offline- und Simulationspfade duerfen nicht entfernt werden.

## Arbeitsregeln

- Vor Beginn `AGENTS.md`, `docs/collaboration/CURRENT.md`,
  `docs/collaboration/DECISIONS.md`, `docs/PRODUCT_BLUEPRINT.md` und
  `docs/design/DESIGN_SYSTEM.md` lesen.
- Der im Ticket genannte Schreibbereich ist exklusiv. Aenderungen ausserhalb
  dieses Bereichs werden vorher mit dem anderen aktiven Agenten oder dem Nutzer
  abgestimmt.
- Claude Code, Codex und weitere Agenten arbeiten nach
  `docs/collaboration/PEER_WORKFLOW.md` auf Augenhoehe.
- Keine neuen Produktentscheidungen aus Designs ableiten.
- Keine Runtime-Abhaengigkeit von extern geladenen Schriften oder Farbdiensten.
- Jedes Ticket endet mit Build-/Testnachweis und einer kurzen Risikonotiz.

## Aktiver Schnitt

### KL-CLAUDE-001 - Unabhaengiges Integrationsaudit

**Status:** Erledigt
**Abhaengigkeit:** Checkpoint des integrierten Scanner-/Draft-Stands
**Schreibbereich:** `docs/collaboration/reviews/` und
`docs/collaboration/handoffs/CLAUDE.md`

**Ergebnis**

- Der Stand seit `03c146a` wurde unabhaengig auf Code-, Daten-, Test-,
  Accessibility- und Designsystemprobleme geprueft; siehe
  `docs/collaboration/reviews/CLAUDE_AUDIT_2026-07-16.md`.
- Keine P0- oder P1-Findings. Ein P2 (unlokalisierte Draft-Evidenz; Eingangs-
  bedingung fuer KL-MENU-004) und vier P3-Notizen sind dokumentiert.
- Review-Gate bestanden: Phase B (KL-OPS-001) wurde ohne Vorfix im selben
  Claude-Worktree begonnen.

### KL-DS-001 - Semantische SwiftUI-Bausteine

**Status:** Erledigt
**Abhaengigkeit:** keine
**Schreibbereich:** `kitchenlink/DesignSystem/KitchenLinkDesignSystemV2.swift`
und optional eine gleichnamige Unit-Testdatei

**Auftrag**

- 4a-`Ruhe` als semantische Hell-/Dunkel-Tokens abbilden.
- Vorgangsart und Dringlichkeit als getrennte Typen modellieren.
- Flaeche, Karte, Primaer- und Sekundaeraktion fuer SwiftUI bereitstellen.
- Touch-Ziele ab 44 Punkt und die Zitronenregel technisch absichern.
- Bis zur Font-Freigabe sichere System-Fallbacks verwenden.

**Abnahme**

- App-Target kompiliert fuer iOS 17.
- Kein bestehendes Theme und kein Produktscreen wurde veraendert.
- Zitrone taucht in keinem Status-Token auf.

### KL-IOS-001 - Schaltbarer Scan-Einstieg V2

**Status:** Erledigt; mit PR #1 in `main` integriert
**Abhaengigkeit:** KL-DS-001
**Schreibbereich:** `kitchenlink/App/`,
`kitchenlink/Features/MenuImport/` und gezielte UI-Tests

**Auftrag**

- Die neue Richtung als standardmaessig aktive Designvorschau integrieren.
- Einen gut sichtbaren Rueckweg zur bisherigen Oberflaeche erhalten.
- Den bestehenden Dokumentkamera-, Foto-, OCR-, Review- und Sandbox-Ablauf
  unveraendert weiterverwenden.
- Scan-Rahmen im Ruhezustand neutral halten; Zitrone nur fuer Primaeraktion und
  kurzen Erkennungserfolg nutzen.

**Abnahme**

- Scan und Fotoauswahl sind mit stabilen Accessibility-IDs erreichbar.
- Die Legacy-Sandbox bleibt aus der V2-Oberflaeche erreichbar.
- Ein Launch-Argument kann V2 fuer UI-Tests explizit ein- oder ausschalten.
- Dynamic Type schneidet bei den Accessibility-Groessen keine Pflichttexte ab.

### KL-QA-001 - Design- und Regressionspruefung

**Status:** Teilweise erledigt
**Abhaengigkeit:** KL-DS-001, KL-IOS-001
**Schreibbereich:** `kitchenlinkTests/` und `kitchenlinkUITests/`

**Auftrag**

- V2- und Legacy-Startpfad automatisiert pruefen.
- Mindestzielgroessen, wichtige Accessibility-Bezeichnungen und Reduce Motion
  fuer den Scan-Einstieg absichern.
- Bestehende Repository-, Relay-, Offline- und Bestelltests vollstaendig laufen
  lassen.

**Abnahme**

- Unit- und UI-Test-Suite laufen auf einem fest benannten iPhone-Simulator.
- Fehlende visuelle Assertions werden als konkrete Restluecke dokumentiert.

Unit-Tests, V2-/Legacy-UI-Smoke-Tests sowie manuelle Hell-, Dunkel- und maximale
Dynamic-Type-Pruefung sind erledigt. Die frueher offene Restluecke — ein lokaler
End-to-End-Test vom Gastauftrag bis zum Kuechenstatus ohne Cloudverbindung — ist
mit KL-QA-002 (PR #9) geschlossen.

### KL-SCAN-001 - Reale Scanner-Fixtures und Regressionstest

**Status:** Erledigt
**Abhaengigkeit:** KL-IOS-001
**Schreibbereich:** `kitchenlink/Features/MenuImport/`, `kitchenlink/Resources/`,
`kitchenlinkTests/`, `docs/test-fixtures/` und `scripts/`

**Ergebnis**

- Drei reale, mehrseitige Speisekarten sind im internen Scan-Einstieg waehlbar.
- Eine visuell gepruefte Gold-Baseline deckt 14 Seiten mit 23 Abschnitts- und 46
  Artikelankern ab.
- Der lokale Apple-Vision-Parser kann reproduzierbar per
  `scripts/run-scanner-benchmark.sh` gegen Regressionsgrenzen getestet werden.
- Verbleibende Modell- und Strukturfehler sind in
  `docs/test-fixtures/scanner-benchmark/CURRENT_RESULTS.md` festgehalten.

### KL-MENU-001 - Evidenzbasierte Menue-Discovery

**Status:** Erledigt mit offenen Evidenzgrenzen
**Abhaengigkeit:** keine
**Schreibbereich:** `docs/discovery/taxonomy-research/`

**Ergebnis**

- GLM lieferte Quellenregister, Pattern-Evidenz, Ontologie, JSON-Schema,
  Guideline und Benchmarkplan; DeepSeek fuehrte zwei Red-Team-Paesse aus.
- Belastbar sind die Prinzipien fuer Rohwerterhalt, Evidenz, Preissemantik,
  Unknown und menschliche Freigabe.
- Stichprobe, Saettigung, Wiederverwendungsrechte und Artefaktversionen reichen
  nicht fuer eine finale Produktontologie.
- `INTEGRATION_REVIEW.md` ist die verbindliche Integrationslesart; die
  Rechercheartefakte bleiben Discovery.

### KL-MENU-002 - Versionierter Import-Draft

**Status:** Erledigt
**Abhaengigkeit:** KL-MENU-001, KL-SCAN-001
**Schreibbereich:** neue Domain-Datei unter `kitchenlink/Features/MenuImport/`
und zugehoerige Unit-Tests

**Auftrag**

- Providerneutralen `MenuImportDraft` als verlustfreies Zwischenmodell bauen.
- Strukturierte Seite/Bounding Box, Rohtext, Confidence und Review-Status
  erhalten.
- Preislose Artikel erlauben und absolute Preise strikt von Deltas trennen.
- Mengen, einfache Optionsgruppen, Bundles und explizite Deklarationen
  erweiterbar abbilden.
- Harte Invarianten testen; noch keine UI- oder Parsermigration in diesem Ticket.

**Ergebnis**

- `MenuImportDraft` `0.1.0` bildet Quelle, strukturierte Evidenz, sichtbare
  Hierarchie, optionale typisierte Preise, Mengen, einfache Optionsgruppen,
  Bundles, Deklarationen und Review-Status ab.
- Rekursive Validatoren sichern Preisbedeutung, Seiten/Bounding Boxes, IDs,
  Reihenfolge und Auswahlgrenzen ab.
- Preislose Artikel bleiben gueltig und erzeugen eine Review-Warnung.

### KL-MENU-003 - Scanner-zu-Draft-Adapter

**Status:** Erledigt
**Abhaengigkeit:** KL-MENU-002
**Schreibbereich:** `kitchenlink/Features/MenuImport/`,
gezielte Adaptertests und Erweiterung des Scanner-Benchmarks

**Ergebnis**

- Apple Vision und der lokale Regelparser erzeugen aus einem OCR-Lauf sowohl den
  unveraenderten `[MenuSectionData]`-Pfad als auch `MenuImportDraft`.
- OCR-Methode, Confidence, Seite, Bounding Box und sichtbarer Rohpreis werden in
  der Draft-Evidenz erhalten; die Quelle erhaelt Typ und Fingerprint.
- Preislose Pending-Bloecke werden nicht mehr verworfen, sondern als
  `needsReview`-Eintraege ohne erfundenen Preis aufgenommen.
- Der 14-Seiten-Benchmark validiert jeden Draft und misst Legacy- und
  Draft-Recall getrennt. Lichtburg steigt im Draft bei den Namensankern von
  14/16 auf 16/16, waehrend die zwei nicht zugeordneten Preise offen bleiben.
- Der bestehende Sandbox-Review und die lokale Menueuebernahme bleiben aktiv;
  der Draft ersetzt diesen Pfad noch nicht.

### KL-MENU-004 - Evidenzbasierte Import-Pruefung

**Status:** Erledigt (PR #2 und Abschluss-PR #3 in `main`)
**Abhaengigkeit:** KL-MENU-003
**Schreibbereich (exklusiv):** `kitchenlink/Features/MenuImport/` und
gezielte UI-/Adaptertests; enthaelt die Entscheidung zum Audit-P2
(unlokalisierte Draft-Evidenz)

Draft-Sektionen und -Eintraege mit Originalseitenausschnitt, Rohtext,
Preiszustand und Review-Grund anzeigen. Preislose und strukturell unsichere
Kandidaten muessen korrigiert, umsortiert oder verworfen werden koennen, bevor
eine explizite Konvertierung in das bestehende Sandbox-Menue erfolgt. Keine
automatische Freigabe und keine Produktionspersistenz.

**Ergebnis**

- Der Audit-P2 ist aufgeloest: nicht lokalisierte Evidenz wird ausdruecklich als
  solche angezeigt und erzeugt keinen falschen Seitenausschnitt.
- Eintraege koennen mit Fundstelle geprueft, bearbeitet, verschoben, angenommen
  oder verworfen werden. Preislose Eintraege lassen sich nicht versehentlich
  annehmen.
- Eine ausdrueckliche Sammelaktion uebernimmt nur bereits bepreiste Kandidaten;
  preislose Kandidaten bleiben fuer die Einzelpruefung offen.
- Die Konvertierung bleibt bis zur vollstaendigen Klaerung gesperrt und schreibt
  danach ausschliesslich in das lokale Sandbox-Menue.
- Fokussierter End-to-End-Test, komplette Unit- und Standard-UI-Tests sowie der
  14-seitige Scanner-Benchmark sind gruen. Screenshots wurden visuell geprueft.
- Die WIP-Grundlage wurde mit PR #2 integriert; der korrigierte gefuehrte Ablauf
  und seine vollstaendige Verifikation folgten mit PR #3.

## Naechste parallele Scheiben

### KL-OPS-001 - Heute und Kueche

**Status:** Erledigt
**Abhaengigkeit:** KL-DS-001, KL-IOS-001
**Schreibbereich:** `kitchenlink/Features/Today/`, `kitchenlink/Features/Kitchen/`,
gezielte Navigation in `kitchenlink/App/`, `kitchenlink/DesignSystem/KitchenLinkDesignSystemV2.swift`
sowie gezielte Tests in `kitchenlinkTests/` und `kitchenlinkUITests/`

**Ergebnis**

- Ereignisorientiertes `Heute` (iPhone) und ein iPad-Kuechenboard mit sechs
  gleichzeitig lesbaren Tickets ohne horizontales Scrollen sind umgesetzt.
- Beide leiten ihren Zustand aus der bestehenden Sandbox-Bestelldomaene
  (Repository/Relay) ab; ein Demo-Seeder erzeugt ein realistisches
  Serviceszenario ueber die regulaeren Statusuebergaenge.
- Vorgangsart bleibt Form, Dringlichkeit bleibt Farbe; offene Zahlung ist
  neutral, nie rot. Zitrone erscheint nur als eine Primaeraktion in `Heute`,
  nie im Kuechenstatus.
- Nach Nutzerfeedback (nasse Haende, Zeitdruck am Pass) wurde die
  Ticket-Bump-Aktion statt als Wischgeste als voller, hell gefuellter
  52-Punkt-Button mit haptischem Erfolgsfeedback umgesetzt; siehe Abwaegung im
  Claude-Handoff.
- Unit-, UI- und Scanner-Benchmark-Suiten sind gruen; visuelle Pruefung auf
  iPhone hell/dunkel und iPad Pro 13" dunkel dokumentiert im Handoff.
- Der Nutzer hat beide Referenzflaechen visuell geprueft und PR #1 gemergt.

### KL-WEB-001 - Gast-Web-Grundlage

**Status:** Erledigt; mit `claude/guest-web-foundation` in `main` integriert
**Abhaengigkeit:** semantische Token-Namen aus KL-DS-001
**Schreibbereich:** war exklusiv `guest-web/`, `docs/collaboration/handoffs/CLAUDE.md`
und dieser Eintrag; jetzt frei fuer die Folgeticket KL-WEB-002

**Ergebnis des Fundaments (17. Juli 2026):** Next.js-16-App-Router-Projekt
unter `guest-web/` mit statisch generierter Menueroute
(`/[venueSlug]/menu`), lokaler Sandbox-Venue (acht Gerichte) als bewusster
Naht fuer den spaeteren Supabase-Pfad, Bestelluebersicht als Sheet ohne
Uebermittlung, Sandbox-Banner auf jeder Seite und System-Font-Fallbacks
ohne Google-Fonts-Laufzeitabhaengigkeit. Tokens liegen als CSS-Variablen
mit den semantischen DESIGN_SYSTEM-Namen vor; ein Vitest-Abgleich haelt
`tokens.css` und `design-tokens.ts` konsistent.

**Nutzer-Review gegen die visuelle Quelle (17. Juli 2026):** Der Nutzer hat
die erste Fassung mit dem tatsaechlichen Claude-Design-Referenzscreen
(`docs/design/claude-design/round-04/export/territories.html`, 6c Screen 2)
verglichen und eine strukturelle Abweichung festgestellt. Nach Klaerung
einzeln korrigiert:

- randloser Venue-Kopf mit "geoeffnet"/"geschlossen"-Badge statt abgesetzter
  Karte mit Tagline;
- umrandete (`border-control`) statt gefuellte Mengensteuerung;
- die gesamte Bestellleiste ist jetzt die Zitronenflaeche (ein durchgehender
  Button), nicht eine neutrale Leiste mit eingebettetem Button;
- kleine Tag-Pills ("beliebt", "vegetarisch") neben dem Artikelnamen;
- dichtere Abstaende naeher an der Referenzkarte.
- Bewusst NICHT uebernommen (Nutzerentscheidung): der Preis bleibt eine
  eigene, fett hervorgehobene Zeile statt inline in der Beschreibung.
- Zusaetzlich als Nebeneffekt bereinigt: der ungefragte volle
  Seiten-Dark-Modus-Wechsel entfiel, da kein Referenzscreen ein durchgehend
  dunkles Gast-Web zeigt (nur die Kueche ist "immer Tief").

Erneut verifiziert: Typecheck, ESLint, 18 Vitest-Tests und SSG-Build gruen;
Interaktion (Stepper, Bestellleiste, Sheet-Summe) sowie hell/dunkel mobil im
Browser erneut visuell geprueft. Bestellgrenze, Supabase-Anbindung und
PWA-Stufe folgen weiterhin als eigene Tickets.

Der Nutzer hat entschieden (siehe `DECISIONS.md`, Guest Web): Next.js App
Router auf Basis von ADR-001 (`glm/guest-web-architecture`), Sandbox-Deployment
auf Vercel bei hosting-neutralem Code (Cloudflare-PoC als Gate vor Produktion),
Supabase Anonymous Sign-in fuer Gastbestellungen und pfadbasierte Venue-Routen
in der Sandbox.

### KL-WEB-002 - Autoritative Bestellgrenze und Anonyme Identitaet

**Status:** Erledigt; von Claude Code reviewt und in `main` integriert
**Abhaengigkeit:** KL-WEB-001 (erledigt, gemergt)
**Schreibbereich:** war `guest-web/` (Fortsetzung), additive Migration unter
`supabase/migrations/`, `docs/architecture/guest-web/` und
`docs/collaboration/handoffs/GLM.md`

GLM hat ADR-001 §6 (autoritative Bestellgrenze) und §6.3 (Anonymous Sign-in)
technisch umgesetzt: additive Migration (`idempotency_key` +
Payload-Hash-Vergleich + Unique-Constraint auf `orders`, `menu_items.slug`,
deckungsgleicher Sandbox-Seed), Row Level Security auf allen sechs
betroffenen Tabellen aktiviert (vorher keine einzige RLS-geschuetzt),
`guest_web_submit_order` als `SECURITY DEFINER`-RPC mit `FOR UPDATE`-Sperre
als einziger Schreibpfad, Frontend-Verdrahtung (`order-submit.ts`,
`order-ack.ts`, `order-backend-supabase.ts`) mit ausschliesslich
serverseitigem ACK. Die bestehende Gastkarte (Tokens, Layout, Controls)
blieb unangetastet, bestaetigt durch CSS-/Komponenten-Diff (nur neue Klassen).

Claude-Review fand und behob einen echten Fund waehrend der Integration:
Nach erfolgreicher Bestellung fiel die Sheet-Summe auf "0,00 €" zurueck
(Warenkorb wurde vor der naechsten Renderung geleert), obwohl der
Server-Betrag (`ack.totalCents`) korrekt berechnet, aber nie angezeigt
wurde. Behoben durch Warenkorb-Schnappschuss zum Sende-Zeitpunkt; verifiziert
mit Typecheck, Lint, 40/40 Vitest-Tests, Build und manueller Browser-Pruefung
der ohne echte Supabase-Instanz erreichbaren Zustaende.

Dokumentiertes, nicht behobenes Restrisiko: eine enge Race Condition bei
zwei nahezu gleichzeitigen Sendungen mit demselben Idempotenz-Key wird nur
vom DB-Unique-Constraint aufgefangen, nicht von einem gezielten
Exception-Handler, der sie sauber auf Konflikt/Replay abbildet — der
Verlierer bekommt ein generisches `rpc_error` statt eines sauberen Signals.
Die Kerngarantie (nie zwei Bestellungen fuer einen Key) haelt trotzdem;
Fix ist ein Folgeticket fuer echte Supabase-Integrationstests, kein
Merge-Blocker.

### KL-INVENTORY-001 - Warenwirtschafts-Domaene

**Status:** Erledigt; von Claude Code reviewt und in `main` integriert
**Abhaengigkeit:** keine
**Schreibbereich:** war neue Dateien unter `Features/Inventory/`, fokussierte
Tests und `docs/collaboration/handoffs/MINIMAX.md`

MiniMax hat den Warenwirtschafts-Kern nach Blueprint §11 geliefert:
dimensionssichere Mengen (Masse/Volumen/Stueck, Decimal, deterministische
Halb-Auf-Rundung), ein append-only Ledger mit Idempotenz-Schluesseln,
Reversal- und ausgeglichenem Transfer-Schutz, eine frisch berechnete
physisch/reserviert/verfuegbar-Projektion, ein Rezept-Resolver und ein
erklaerbarer Bestellvorschlags-Advisor. 52 Inventory-Tests (Vorgabe: 25+),
komplette Unit-Suite gruen.

Claude-Review ging einer moeglichen Design-Frage nach, statt sie ungeprueft
als Bug zu behandeln: `record()` prueft den Reversal-/Transfer-Schutz vor
der Idempotenzpruefung, wodurch ein zweiter `reverse()` derselben Bewegung
immer als `alreadyReversed` scheitert, obwohl Schluessel und Signatur wie
ein identischer Retry aussehen wuerden. Nach genauer Konsequenzanalyse ist
das die sicherere Wahl fuer ein Ledger (garantiert "genau einmal" statt
einen zweiten Storno-Klick still als Erfolg zu replayen) — MiniMax
dokumentiert diese Abwaegung bereits selbst im Handoff unter
"Designentscheidungen". Kein Codeeingriff noetig.
`INVENTORY_MODEL.md` liegt neben dem Feature-Code statt unter `docs/domain/`
wie im urspruenglichen Mission-Brief — harmlose Pfadabweichung, kein
Scope-Verstoss.

## Parallele Runde 2 (Stand 17. Juli 2026, nach Integration von PR #9)

Die urspruengliche Rebase-Warnung ist ueberholt: Die Missionszweige wurden vor
Integrationsbeginn auf die PR-#4-Merge-Basis rebased. Alle vier Missionszweige
dieser Runde (KL-OFFLINE-003, KL-QA-002, KL-WORKFORCE-001, KL-INVENTORY-001)
sind mittlerweile reviewt und integriert.

### KL-OFFLINE-003 - Autoritatives Event-Log und Outbox

**Status:** Erledigt; von Claude Code reviewt und in `main` integriert
**Abhaengigkeit:** keine
**Schreibbereich:** `prototypes/KitchenLinkEventLog/`,
`docs/architecture/offline/EVENT_LOG_V2.md`, `handoffs/GLM.md`

Ausfuehrbarer Swift-/SQLite-Referenzprototyp: autoritatives Append-only-
Ereignisprotokoll, Optimistic Concurrency, Idempotenz ueber
`(venue_id, idempotency_key, request_fingerprint)`, Outbox mit
Lease-basiertem Claim/NACK/ACK und Wiederanlauf, ehrliche Durability-Policy.
Claude-Review ohne P0/P1: 35/35 Tests grün (erneut auf dem gemergten Stand
verifiziert), Invarianten aus `EVENT_LOG_V2.md` gegen die tatsaechliche
Implementierung geprueft. Drei kleine, bereits von GLM selbst offengelegte
Beobachtungen (veralteter AUTOINCREMENT-Kommentar auf einer
`WITHOUT ROWID`-Tabelle, zwei Testnamen die echte Nebenlaeufigkeit
suggerieren aber sequentiell laufen, ungeschuetzte Newline-Trennung im
Fingerprint) sind nicht blockierend. Isoliertes Swift Package, kein
App-/Domain-Code beruehrt; Branch lokal rebased, GLMs Remote-Branch
unveraendert gelassen.

### KL-QA-002 - Lokaler Bestell-E2E-Smoke

**Status:** Erledigt; mit PR #9 konfliktfrei in `main` integriert
**Abhaengigkeit:** Repository-/Relay-Domaene
**Schreibbereich:** Offline-Test-/Supportdateien, Testplan, `handoffs/DEEPSEEK.md`

Zwei Relay-/Repository-Instanzen pruefen Gastauftrag, Owner-Empfang, Statuskette,
Tracking, alle 36 Statusuebergaenge, Neustartpersistenz und beobachtbaren
Teardown. Claude-Review ohne Befunde; auf dem gemergten Stand liefen die
komplette Unit-Suite (60/60), die Standard-UI-Suite und der 14-Seiten-
Scanner-Benchmark gruen. Das befuerchtete Rebase-Risiko trat nicht ein: Der
finale Branch fasste keine geteilten Testdateien mehr an. Die Abgrenzung zum
echten Venue-Hub steht in `docs/test-plans/OFFLINE_ORDER_FLOW.md`.

### KL-WORKFORCE-001 - Schichtplan-Domaene

**Status:** Erledigt; von Claude Code reviewt und in `main` integriert
**Abhaengigkeit:** keine
**Schreibbereich:** neue Dateien unter `Features/Workforce/`, fokussierte Tests,
Domain-Dokument, `handoffs/KIMI.md`

Isolierte Swift-Domaenengrundlage fuer Mitarbeiter, Verfuegbarkeit, Planung,
Zeiterfassung: getrennte Betriebsschicht/geplante Schicht/Zeiteintrag-Objekte,
explizite Zeitzonen mit DST-korrekter Vorlagenausloesung (beide
Europe/Berlin-Uebergaenge 2025 verifiziert), reine Validatoren, deterministische
Sandbox-Fixture. 38 Tests gruen (Handoff nannte 33; tatsaechlich mehr geliefert
als angegeben). Claude-Review fand einen echten, engen Bug:
`finalizeSwap(accepted: false)` liess einen veralteten `acceptedAt`-Zeitstempel
stehen, wenn eine bereits angenommene Schicht per abgelehnter Tauschanfrage
zurueck auf `published` fiel — Status und Zeitstempel widersprachen sich. Bei
der Integration behoben (beide Zweige setzen `acceptedAt` jetzt konsistent
zurueck) plus Regressionstest, der genau diesen zuvor ungetesteten Pfad
abdeckt. Komplette Unit-Suite auf dem gemergten Stand gruen.

KL-INVENTORY-001 (die vierte Mission dieser Runde) steht jetzt als eigener,
erledigter Abschnitt weiter oben.

## Integrationsreihenfolge

1. ~~KL-CLAUDE-001 unabhaengig ausfuehren und Findings bewerten.~~ Erledigt,
   keine P0/P1.
2. ~~P0-/P1-Findings vor neuer Oberflaechenarbeit entscheiden oder beheben.~~
   Entfaellt, keine vorhanden.
3. ~~KL-OPS-001 im Claude-Worktree als Round-04-Referenz umsetzen.~~ Erledigt
   und gemergt (PR #1).
4. ~~KL-MENU-004 inklusive P2-Entscheidung abschliessen.~~ Erledigt und mit PR
   #2 sowie Abschluss-PR #3 integriert.
5. ~~PR #5 (`codex/kitchen-hardening-fix`) reviewen und mergen.~~ Erledigt;
   zusammen mit PR #6 (Doku-Sync) und PR #9 (KL-QA-002) am 17. Juli 2026
   reviewt und integriert.
6. ~~Claude Code reviewt und integriert PR #7 (KL-OFFLINE-003) und PR #8
   (KL-WORKFORCE-001) einzeln in eigenem Scope.~~ Beide erledigt (17. Juli
   2026, keine P0/P1; PR #8 mit einem kleinen Fix zur `finalizeSwap`-Logik
   waehrend der Integration, siehe Handoff).
7. ~~KL-WEB-001 erst nach Nutzervorgabe des Web-Stacks weiterverfolgen.~~
   Stack am 17. Juli 2026 entschieden; Fundament gemergt.
8. ~~Parallel dazu: KL-WEB-002 an GLM 5.2, KL-INVENTORY-001 (Neuvergabe) an
   MiniMax.~~ Beide erledigt und am 17. Juli 2026 reviewt und integriert
   (siehe Handoff fuer Details: ein behobener Fund bei KL-WEB-002, eine
   gepruefte und bestaetigte Design-Entscheidung bei KL-INVENTORY-001).
9. Erst nach stabilen Referenzscreens weitere Produktmodule migrieren.
