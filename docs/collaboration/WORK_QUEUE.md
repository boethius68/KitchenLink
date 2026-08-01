# KitchenLink Work Queue

**Stand:** 22. Juli 2026
**Phase:** Integrierte Sandbox mit oeffentlichem Gast-Web

Diese Queue enthaelt sowohl die abgeschlossene Aufbauhistorie als auch aktuelle
Arbeitspakete. Seit dem 19. Juli 2026 gilt der Main-Only-Modus
(`DECISIONS.md`): alle Agenten arbeiten direkt auf `main`, es gibt keine
langlebigen Feature-Branches mehr. Bestehende Demo-, Offline- und
Simulationspfade duerfen nicht entfernt werden.

Der letzte bereits begonnene GLM-Strang, PR #15 (`KL-INVENTORY-002`), wurde am
18. Juli 2026 von Codex reviewt, korrigiert und integriert. Neue Tickets werden
nur noch von Claude Code oder Codex uebernommen, bis der Nutzer diese Vorgabe
aendert.

## Arbeitsregeln

- Vor Beginn `AGENTS.md`, `docs/collaboration/CURRENT.md`,
  `docs/collaboration/DECISIONS.md`, `docs/PRODUCT_BLUEPRINT.md` und
  `docs/design/DESIGN_SYSTEM.md` lesen.
- Der im Ticket genannte Schreibbereich ist exklusiv. Aenderungen ausserhalb
  dieses Bereichs werden vorher mit dem anderen aktiven Agenten oder dem Nutzer
  abgestimmt.
- Claude Code und Codex arbeiten nach `docs/collaboration/PEER_WORKFLOW.md` auf
  Augenhoehe. Handoffs anderer Modelle werden nur noch als Historie gelesen.
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
Router auf Basis von ADR-001 (`glm/guest-web-architecture`), hosting-neutraler
Code, Supabase Anonymous Sign-in fuer Gastbestellungen und pfadbasierte
Venue-Routen in der Sandbox. Der damalige Vercel-Plan wurde am 18. Juli durch
den realen Hostinger-PaaS-Deploy fuer die Sandbox abgeloest.

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

## Discovery: Offline Venue Hub (Blueprint §16)

**Status:** Discovery reviewt; lokale Gastbestellung am 18. Juli 2026 als
Produktrichtung bestaetigt; lokaler Hostsurrogat umgesetzt, echter
Geraete-/Netzwerknachweis noch offen

Die beiden zuvor ungereviewten Branches `deepseek/offline-venue-hub-review`
(Superset) und `glm/offline-venue-hub` wurden von Claude Code gelesen. Die
fuenf Discovery-Dokumente (GLM-Architektur + Quellen, DeepSeek-Red-Team,
Stage-1-Event-Log-Contract, Netzwerk-POC-Testmatrix) liegen jetzt unter
`docs/discovery/offline-venue-hub/` auf `main`, zusammen mit einer
Integrationslesart (`INTEGRATION_REVIEW.md`) analog zur Taxonomie-Recherche.
Die veralteten Handoff-Dateien der Branches wurden bewusst nicht uebernommen.

Kernbefunde der Lesart:
- Der Stage-1-Event-Log-Contract (der einzige Teil mit „bedingtem Go") ist
  faktisch bereits durch den gemergten KL-OFFLINE-003-Prototyp abgedeckt; die
  Entwuerfe konvergieren im Prinzip, divergieren in der Umsetzung (eigenes
  SQLite vs. GRDB). Naechster risikoarmer Schritt waere die iOS-
  Integrationsnaht (Event-Store hinter `KitchenLinkRepository`).
- Der Nutzer hat die Produktweggabelung entschieden: Lokale Gastbestellung bei
  Cloud-Ausfall ist Pflicht der Sandbox-Beta. Ein cloud-first per HTTPS
  ausgeliefertes Gast-Web kann einen lokalen HTTP-Hub dennoch nicht direkt
  erreichen (Mixed Content + Chrome Local Network Access). Zu pruefen sind
  deshalb lokale Top-Level-Zustellung/Bootstrap, QR-Wechsel, AP-Isolation,
  TLS/Trust und ACK-nach-Commit auf echten Geraeten.
- `DECISIONS.md` und Blueprint §16.2 halten das Produktziel fest. Discovery
  bleibt die technische Erkenntnisgrundlage; keine Netzwerkimplementierung ist
  allein dadurch freigegeben.

### KL-OFFLINE-004 - Lokale Gastbestellung, Hostsurrogat

**Status:** Erledigt; mit PR #20 reviewt und in `main` integriert
**Abhaengigkeit:** KL-OFFLINE-003, bestaetigte Blueprint-§16.2-Anforderung
**Schreibbereich:** `prototypes/KitchenLinkLocalGuestPOC/`, Offline-Discovery-
Status, `CURRENT.md`, `handoffs/CODEX.md`

Der isolierte macOS-Prozess liefert die Gastseite und `/bootstrap` aus derselben
lokalen Origin aus, nimmt `POST /orders` an und verwendet das gemergte
`KitchenLinkEventLog` als autoritative SQLite-Persistenz. Artikel, Mengen und
Preise werden serverseitig normalisiert; ein ACK entsteht erst nach dem
atomaren Event-/Outbox-Commit. Retry und Same-Key-Konflikt sind explizit
abgedeckt. Sechs Swift-Tests, ein HTTP-Smoke und eine mobile Browserbestellung
sind gruen.

Der Scope waehlt noch keine Produktionsarchitektur: Der Server ist ein
sequentieller macOS-Entwickler-Surrogat ohne Zahlung, Cloud-Sync, Bonjour oder
QR-Erzeugung. Der Stage-2-Gate aus `LOCAL_NETWORK_POC.md` bleibt bis zu Tests
auf iOS Safari und Android Chrome im Referenz-WLAN offen.

### KL-OFFLINE-005 - Lokaler Kuechen-/Kellner-Workflow auf dem iPhone

**Status:** Erledigt; auf zwei echten Geraeten abgenommen und mit PR #23 in
`main` integriert
**Abhaengigkeit:** KL-OFFLINE-004, PR #22
**Schreibbereich:** `prototypes/KitchenLinkLocalGuestPOC/`,
`kitchenlink/Features/LocalOperations/`, additive V2-Navigation,
gezielte Tests und Statusdokumente

Der lokale Hostsurrogat projiziert Gastbestellungen aus dem autoritativen
Event-Log und akzeptiert die enge Statusfolge `preparing -> ready -> served`.
Die iPhone-App pollt diese Projektion einmal pro Sekunde. Im Kuechen-Modus
markiert `Bestellung zubereitet` den Auftrag als `ready`; er erscheint dann im
Kellner-Modus und wird dort mit `Bestellung serviert` abgeschlossen. Status-
Retries sind auch nach einem spaeteren Folgestatus idempotent.

Die App verwendet die bestehende `LiveOrderMessage`-/`OrderLifecycleStatus`-
Domaene und behaelt alle Demoablaeufe. Lokales HTTP ist fuer das gemeinsame
WLAN explizit im App-Info-Plist erlaubt und erklaert. Keine Zahlung, kein
Cloud-Sync, keine produktive Aktivierung, kein Bonjour und keine neue Hub-
Architektur. Der aktuelle Referenzhost ist editierbar vorbelegt; Discovery und
IP-Wechsel bleiben Folgearbeit.

**Geraeteabnahme, 19. Juli 2026:** KitchenLink blieb auf dem iPhone im
Kuechen-Modus geoeffnet, waehrend ein zweites Geraet im selben WLAN ueber die
lokale Gastseite bestellte. Der Auftrag erschien live auf dem iPhone, wechselte
nach `Bestellung zubereitet` in den Kellner-Modus und wurde dort mit
`Bestellung serviert` abgeschlossen. Der Nutzer bestaetigte den gesamten Lauf
als erfolgreich.

### KL-OFFLINE-006 - iPhone als Foreground-Venue-Hub

**Status:** Erledigt; echte Mac-zu-iPhone-Abnahme bestanden und mit PR #25 in
`main` integriert
**Abhaengigkeit:** KL-OFFLINE-003 bis KL-OFFLINE-005
**Branch:** `codex/iphone-venue-hub-poc`
**Schreibbereich:** `prototypes/KitchenLinkLocalGuestPOC/`,
`kitchenlink/Features/LocalOperations/`, App-Konfiguration, gezielte Tests und
Codex-Statusdokumente

Die in Blueprint §16 beschriebene iPhone-Hub-Naht ist als enger Foreground-PoC
umgesetzt: Solange `Lokaler Service` geoeffnet bleibt, betreibt das iPhone einen
lokalen `NWListener`, liefert die bestehende Gastseite im WLAN aus und nimmt
Bestellungen ueber denselben `LocalGuestOrderService` und dasselbe dauerhafte
SQLite-Event-Log an wie der bisherige macOS-Hostsurrogat. Die App verbindet
Kuechen- und Kellnermodus intern ueber Loopback mit diesem Hub. Ein QR-Code,
die sichtbare Gast-URL und Teilen erleichtern den Aufruf vom zweiten Geraet.

Der macOS-Hub bleibt als aufklappbarer Fallback mit seiner gespeicherten Adresse
erhalten. Die App stoppt den iPhone-Hub beim Verlassen der Ansicht oder im
Hintergrund und weist sichtbar auf Vordergrund-, WLAN- und Strombedarf hin.
Bonjour wird nur angekuendigt; automatische Client-Discovery ist noch nicht
Teil dieser Scheibe.

Verifiziert sind die neun Kern-/Event-Log-Tests, ein echter iOS-Loopback-Lauf
von Health ueber Order-POST mit `local-event-log-committed` bis zur
Kuechenprojektion, Parser-/Lifecycle-/Fallback-Tests, Simulator-Build sowie ein
signierter Build fuer `Philipps iPhone XR`. Der finale Build ist auf dem Geraet
installiert; der automatisierte Start wurde vom gesperrten iPhone abgewiesen.

**Geraeteabnahme, 19. Juli 2026:** KitchenLink blieb auf dem iPhone in
`Lokaler Service` geoeffnet und zeigte seine dynamische Gastadresse. Der Mac
oeffnete diese Adresse im selben WLAN und gab eine Bestellung direkt beim
iPhone-Hub ab. Der Auftrag erschien live im Kuechenmodus, wechselte nach
`Bestellung zubereitet` in den Kellnermodus und wurde dort erfolgreich
weiterbearbeitet. Der Nutzer bestaetigte den gesamten Ablauf als bestanden.

Keine Hintergrundfreigabe, Produktionshaertung, Zahlung oder aktive
Cloud-Synchronisation. LAN-Authentisierung, Mehrgeraetekonkurrenz, DHCP-
Adresswechsel, AP-Isolation, Android Chrome und TLS/Trust bleiben Folge-Gates.

### KL-OFFLINE-007 - Foreground-Hub bei WLAN-/IP-Wechsel stabilisieren

**Status:** Erledigt; reale WLAN-Recovery-Abnahme bestanden und mit PR #27 in
`main` integriert
**Abhaengigkeit:** KL-OFFLINE-006, bestandene Mac-zu-iPhone-Geraeteabnahme
**Schreibbereich:** `kitchenlink/Features/LocalOperations/`, gezielte Tests in
`kitchenlinkTests/`, dieser Queue-Eintrag und
`docs/collaboration/handoffs/CODEX.md`

Der laufende iPhone-Hub soll eine fehlende oder geaenderte WLAN-IPv4-Adresse
im Vordergrund erkennen, ohne Listener, Port oder lokales Event-Log neu
anzulegen. Solange keine WLAN-Adresse verfuegbar ist, bleibt die interne
Kuechen-/Kellner-Verbindung ueber Loopback aktiv und die Ansicht zeigt einen
eigenen Wartezustand. Nach Rueckkehr ins WLAN werden Gast-URL, QR-Code und
Teilen-Aktion automatisch mit der neuen Adresse veroeffentlicht.

Abnahme: Start ohne WLAN-Adresse, Verlust und Wiederkehr der Adresse sowie ein
echter lokaler HTTP-Bestelllauf sind automatisiert getestet; der Port bleibt
ueber den simulierten Wechsel stabil. Hintergrundbetrieb, automatische
Client-Discovery, Authentisierung, AP-Isolation, Android und TLS bleiben
ausdruecklich ausserhalb dieser Scheibe.

**Geraeteabnahme, 19. Juli 2026:** Der Nutzer fuehrte den vorbereiteten
WLAN-aus/an-Test mit dem signierten iPhone-Build durch und bestaetigte die
Recovery als vollstaendig funktionsfaehig. PR #27 wurde danach aus dem Draft
genommen und als Merge-Commit `dc67ecc` nach `main` integriert.

## Aktive Scheiben

### KL-CLOUD-001 - Cloud-Bestellschleife schließen + automatischer Lokal-Fallback

**Status:** In `main` integriert (19. Juli 2026, inkl. vereinfachter
E-Mail/Passwort-Anmeldung mit eingebackenen Sandbox-Verbindungsdaten);
offen sind nur noch Migrations-Anwendung + Betreiber-Konto auf der echten
Instanz (SANDBOX_SETUP.md §6.1) und die reale Web-zu-iPhone-Abnahme
**Abhaengigkeit:** KL-WEB-002/003/004 (Gast-Web live), KL-OFFLINE-006/007
(iPhone-Hub)
**Schreibbereich:** `kitchenlink/Features/CloudOperations/` (neu),
`kitchenlink/Features/LocalOperations/KitchenLinkV2LocalOperationsView.swift`,
`kitchenlink/App/KitchenLinkV2BusinessHomeView.swift` (nur Service-Zeile),
additive Migration `supabase/migrations/20260719100000_operator_cloud_orders.sql`,
`guest-web/src/lib/hub-presence.ts`, `guest-web/src/components/GuestMenuCard.tsx`,
`guest-web/src/app/globals.css`, gezielte Tests, `SANDBOX_SETUP.md`, dieser
Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Schließt die Lücke, dass Bestellungen von `kitchenlink.luneq.eu` zwar dauerhaft
in Supabase landeten, aber keine Betreiberoberfläche sie je anzeigte (die
einzige Lese-Policy war `orders_owner_read` für den Gast selbst; der einzige
Supabase-Code der App zeigte auf ein altes, hartkodiertes Projekt).

- **Migration (additiv):** `venue_staff` + `is_venue_staff()`, Staff-Lese-
  Policies auf `orders`/`order_items`, Status-RPC
  `operator_update_order_status` (SECURITY DEFINER, Staff-Pflicht,
  Vorwärtskette mit Replay-Semantik wie beim lokalen Hub) und
  `venue_hub_presence` (öffentlich lesbarer Heartbeat + lokale Gast-URL,
  Schreiben nur über Staff-RPC).
- **App:** Neuer `CloudOperations`-Client/-Model (konfigurierbare URL/Key,
  E-Mail-Anmeldung, Refresh-Token-Erneuerung, 3-s-Polling, Status über die
  RPC, 15-s-Presence-Heartbeat). Die bisherige Ansicht `Lokaler Service`
  heißt jetzt `Service`: Online- und lokale Bestellungen in einer
  Küchen-/Kellner-Liste (Merge testbar in
  `KitchenLinkServiceOrderMerge`), der lokale Hub läuft immer als Fallback
  mit — keine Vorauswahl mehr. Beim geordneten Verlassen wird die lokale URL
  in der Cloud geräumt.
- **Gast-Web:** `hub-presence.ts` wertet den Heartbeat aus (frisch → online;
  >45 s alt + lokale URL → Verweis; sonst unverändertes Verhalten). Bei
  Ausfall des Service-Geräts erscheint ein Warte-Hinweis, die Bestellleiste
  wird zum Link auf die lokale Bestellseite, der Sheet-Submit ist gesperrt.
  URL-Sanitizing lässt nur http(s) zu.

Verifikation: Gast-Web typecheck/lint sauber, 63/63 Vitest, Build mit ISR
intakt, beide UI-Zustände visuell geprüft (mobil 375×812). iOS: 12 neue
Cloud-Tests, komplette Unit-Suite 186 bestanden / 0 fehlgeschlagen / 1
übersprungen auf iPhone-17-Pro-Simulator. Offen: Migration + Betreiber-Konto
auf der echten Instanz (SANDBOX_SETUP.md §6.1), reale
Web-zu-iPhone-Abnahme, danach Merge.
### KL-OFFLINE-008 - Lokale Hub-Erkennung in der Business-App

**Status:** In `main` integriert (19. Juli 2026, Merge von
`codex/local-hub-discovery` mit manueller Aufloesung gegen die
vereinheitlichte Service-Ansicht aus KL-CLOUD-001); Installation des
aktuellen Stands auf dem Geraet steht noch aus
**Abhaengigkeit:** KL-OFFLINE-006 und KL-OFFLINE-007
**Schreibbereich:** `kitchenlink/Features/LocalOperations/`, gezielte Tests in
`kitchenlinkTests/`, bei Bedarf additive lokale Netzwerkdeklarationen sowie
dieser Queue-Eintrag und `docs/collaboration/handoffs/CODEX.md`

Die Business-App soll von KitchenLink angekuendigte Venue-Hubs im selben WLAN
per Bonjour erkennen und im externen Hub-Fallback als direkt waehlbare Ziele
anzeigen. Manuelles Eintragen einer IP bleibt erhalten. Discovery darf weder
einen fremden Dienst automatisch verbinden noch die bestehende iPhone-
Self-Hosting-Voreinstellung verdraengen.

Diese Scheibe gilt nur fuer native Operator-Clients. Normale Gastbrowser
koennen Bonjour-Dienste nicht selbst durchsuchen und verwenden weiterhin die
konkrete IP-Gastadresse beziehungsweise QR-Code/Link. Hintergrundbetrieb,
Failover-Wahl, LAN-Authentisierung, AP-Isolation, Android und TLS bleiben
ausserhalb des Tickets.

### KL-MENU-005 - Scan-zu-Publish-Bruecke (gescannte Karte online veroeffentlichen)

**Status:** Implementiert in `main` (Code + Migration + Tests gruen); offen ist
nur die reale Abnahme durch den Nutzer (Migration anwenden + einmal
veroeffentlichen gegen die echte Instanz, SANDBOX_SETUP.md §6.2)
**Abhaengigkeit:** KL-MENU-004 (Draft-Review), KL-CLOUD-001 (venue_staff,
Betreiber-Anmeldung), KL-WEB-004 (Supabase-Menue-Leseweg)
**Schreibbereich:** `supabase/migrations/20260719200000_operator_publish_menu.sql`
(neu), `kitchenlink/Features/CloudOperations/KitchenLinkMenuPublishClient.swift`
(neu), `kitchenlink/Features/CloudOperations/KitchenLinkCloudOrderClient.swift`
(Transport-Extension + schmales Auth-Protokoll), `kitchenlink/Features/MenuImport/
MenuPublishSheet.swift` (neu), `kitchenlink/Features/MenuImport/
MenuImportDraftReviewView.swift` (Aktion), `kitchenlinkTests/
KitchenLinkMenuPublishTests.swift` (neu), `SANDBOX_SETUP.md`, dieser Eintrag und
`docs/collaboration/handoffs/CLAUDE.md`

Schliesst die zweite Haelfte des Kern-Pitches: Bisher publizierte der Menuescan
**nur** in das lokale Sandbox-Menue, nie ins Gast-Web. Jetzt kann der Betreiber
eine gepruefte importierte Karte direkt aus dem Draft-Review nach Supabase
veroeffentlichen; die Gastkarte auf `kitchenlink.luneq.eu/<slug>/menu` zeigt sie
nach der ISR-Frist (max. 1 min).

- **Migration (additiv):** SECURITY-DEFINER-RPC `operator_publish_menu(
  p_venue_slug, p_menu jsonb)`, staff-gated ueber `is_venue_staff`. Ersetzt die
  aktive Karte der Venue **vollstaendig** (kein Merge — gespiegelt zu
  `store.replaceMenu`), garantiert genau eine aktive Karte und lehnt doppelte
  `menu_items.slug` in der Nutzlast ab (lastende order-gate-Invariante). Loeschen
  der Kategorien kaskadiert auf Items; historische `order_items.menu_item_id`
  fallen per FK auf NULL (Name/Preis bleiben als Snapshot erhalten). `tag` und
  `variant_options` werden bewusst nicht gesetzt (Folgearbeit).
- **App:** Reiner, getesteter Nutzlast-Bau (`KitchenLinkMenuPublishPayload`) mit
  deutscher Slug-Erzeugung (ä→ae) und deterministischer Slug-Deduplizierung;
  `KitchenLinkMenuPublishModel` nutzt eine bestehende Betreiber-Sitzung oder
  meldet mit vertrauten Zugangsdaten an (genau-einmaliger 401-Refresh wie im
  Cloud-Modell). Die Anmeldung/Erneuerung teilt sich das schmale
  `KitchenLinkCloudAuthenticating`-Protokoll mit dem Bestell-Transport.
- **UI:** `MenuPublishSheet` als Bestaetigungs-/Anmelde-Sheet aus dem
  Draft-Review (`draftReview.publishOnline`), nur E-Mail/Passwort, klarer
  Ersetzen-Hinweis, Erfolgskarte mit Live-URL. Usability-Leitplanke: keine
  technischen Verbindungsfelder.

Verifikation: App-Target-Build gruen; komplettes `kitchenlinkTests`-Target
**0 Fehlschlaege** (11 neue Publish-Tests: Slugify/Umlaute/Dedup/Kind/Allergen
sowie Model gegen Transport-Spy inkl. gespeicherte Sitzung, Anmeldung,
genau-einmaliger 401-Refresh, tote Sitzung, leere Zugangsdaten). Nicht ohne
Nutzer verifizierbar: die RPC-SQL lief nicht gegen echtes Postgres (gleiche
Grenze wie KL-WEB-002/KL-CLOUD-001) — aufzuloesen durch die reale Abnahme
(SANDBOX_SETUP.md §6.2).

### KL-SCAN-002 - Import-Qualitaetsrunden mit Review-Umgebung

**Status:** Runden 1–4 abgeschlossen (20. Juli 2026). Der KI-Textpfad
(OpenCode Zen Free-Modell `big-pickle`, keylos/kostenlos, Textmodus mit
koordinaten-annotierten OCR-Zeilen) schlaegt den Regel-Parser klar und ist
der neue Default. Belegte Befunde je Runde in
`ROUND_01..04_FINDINGS.md`; Kernpunkte: R1 — Engpass ist der Regel-Parser,
nicht die OCR; R2 — keyloser Free-Zugang, Reasoning-Antworten, JSON-Reparatur,
Teilergebnisse; R3 — Set-/Gang-Menues als ein bepreister Eintrag, `per_person`,
German-quote-JSON-Reparatur, Retry-auf-JSON-Fehler (alle Karten laufen
vollstaendig); R4 — Vision gemessen (funktioniert, aber Timeout-anfaellig →
Textmodus bleibt Default, Vision Opt-in). Offen (Runde 5, abnehmender Ertrag):
preislose Set-Menue-Gang-Reste (kosmetisch, unpubliziert; Ursache: lokale
`unpricedCandidates` im KI-Modus), Streupreise, Kategorienschnitt. Prozessregel
seit R1: Agent verifiziert jeden Lauf zuerst selbst (QUALITY_TARGETS.md §2).
Verifikation: komplette `kitchenlinkTests`-Suite 207/0, 5 JSON-Repair-Tests.
**Empfehlung:** guter Zwischenstand; hoehere Prioritaet haben die realen
Produkt-Abnahmen (KL-MENU-005 §6.2, KL-CLOUD-001 §6.1).
**Abhaengigkeit:** KL-SCAN-001 (Fixtures + Benchmark), KL-MENU-003/004
(Draft-Pipeline); motiviert durch Nutzerbefund nach KL-MENU-005 („Namen passen
groesstenteils, aber nicht alle")
**Schreibbereich:** `kitchenlinkTests/MenuImportReviewHarnessTests.swift` (neu),
`scripts/run-import-review.sh` (neu), `scripts/import-review-report.html` (neu),
`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md` (neu), spaeter
Parser-Fixes unter `kitchenlink/Features/MenuImport/` + `ContentView.swift`
sowie Gold-Baseline-Erweiterungen, dieser Eintrag und
`docs/collaboration/handoffs/CLAUDE.md`

Der Nutzer hat einen mehrstufigen Qualitaets-Workflow gefordert: Kategorien aus
Kartentiteln, Artikel mit Varianten/Groessen/Beschreibungen, strukturierte
Allergen-Zuordnung ueber die Karten-Legende (spaeter einheitliche Icons in der
UI) und die harte Regel, dass Legende-Codes nie in Namen oder Beschreibungen
landen. Die verbindliche Zielliste steht in
`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`.

Damit der Nutzer nicht in Dutzenden Einzelschritten am iPhone importieren muss,
existiert jetzt eine Batch-Review-Umgebung: `./scripts/run-import-review.sh`
jagt alle Demo-Fixtures (und optional beliebige eigene Karten via
`KITCHENLINK_REVIEW_MENUS=<Ordner>`, PDFs oder Bild-Unterordner) durch die
echte lokale OCR-/Parser-Pipeline und oeffnet einen HTML-Report: pro Seite
links das Original mit eingezeichneten Fundstellen (Name durchgezogen, Preis
gestrichelt), rechts das Erkennungsergebnis mit automatischen Markierungen
(ohne Preis, zu klaeren, ohne Fundstelle, Codes im Namen/Beschreibung, ohne
Beschreibung), dazu Veroeffentlichungs-Vorschau und Roh-OCR pro Seite.
OK/Falsch + Notiz pro Eintrag und Fehlend-Feld pro Seite werden lokal
gespeichert; „Feedback exportieren" erzeugt `import-review-feedback.json` fuer
die Uebergabe an den Agenten. Laeufe sind zeitgestempelt (`latest`-Symlink).

Verifiziert: kompletter Lauf ueber alle 3 Fixtures/14 Seiten (48 s, echte
Vision-OCR), Report im Browser geprueft (Overlays, Flags, Feedback-Speicherung,
Zahlen decken sich mit dem dokumentierten Stand: 7 preislose Lichtburg- und 2
Alexxanders-Kandidaten). Der erste Lauf macht bereits echte Befunde sichtbar,
die die Nutzerbeobachtung bestaetigen: Legende-Codes in Beschreibungen
(z. B. `-A,G,)-`) und sogar im Namen (`Gulaschsuppe-A,G,l,-`), doppelte
Beschreibungsfragmente, OCR-Verwechslungen (`)`/`J`, `l`/`1`).

**Workflow pro Runde:** Lauf -> Nutzer prueft im Report und exportiert
Feedback -> Agent uebersetzt in Parser-Fixes + Gold-Baseline-Anker ->
Benchmark + Unit-Suite gruen -> naechster Lauf zeigt Fortschritt. Parser-Fixes
selbst sind bewusst NICHT Teil des Umgebungsbaus; sie beginnen mit Runde 1.

### KL-MENU-006 - Import-Oberflaeche konsolidieren und Testabdeckung verbreitern

**Status:** Erledigt (22. Juli 2026, direkt auf `main`)
**Abhaengigkeit:** KL-MENU-004, KL-SCAN-002
**Schreibbereich:** App-/Import-/Editor-Views, Demo-Fixtures, gezielte Tests und
Dokumentation

**Ergebnis**

- Der V2-Import oeffnet die draft-native Pruefung direkt. Sichtbare
  Legacy-Sandbox-, Designwechsel- und doppelte Review-Einstiege sind entfernt.
- Pruefung und Gaeste-Vorschau zeigen die zuvor fehlende strukturierte Ebene:
  drei Speisen-/Getraenke-/Gesamtzaehler, Beschreibungen, einheitliche
  Allergen-/Zusatzstoffsymbole, Varianten/Extras und kompakte Mengensteuerung.
- Die App bietet genau drei dokumentierte Testkarten. Eine reproduzierbare
  KitchenLink-Pruefkueche deckt auf drei Seiten alle wichtigen Felder ab;
  Lichtburg und Alexxanders bleiben als reale schwierige Layouts erhalten.
- Die historische 14-Seiten-Gold-Baseline wurde nicht umgedeutet oder
  aufgeweicht. Der Batch-Review nimmt die neue Vollabdeckung additiv auf.
- Der strukturierte Preisbezug `per_person` und enthaltene Nullpreis-Optionen
  bleiben jetzt durch Mapping, Draft, Review, Konvertierung und Persistenz
  erhalten.
- Abschlussnachweis: komplette Unit-Suite, gezielte Import-UI-Smokes,
  14-Seiten-Gold-Benchmark und lokaler 17-Seiten-OCR-/Review-Lauf bestanden.

### KL-MENU-007 - Semantische Icons fuer Allergene und Zusatzstoffe

**Status:** Erledigt (22. Juli 2026, direkt auf `main`)
**Abhaengigkeit:** KL-MENU-006
**Schreibbereich:** Deklarationskatalog und -darstellung in iOS und Gast-Web,
gezielte Tests sowie Recherche- und Kollaborationsdokumentation

**Ergebnis**

- Der gemeinsame semantische Katalog umfasst alle 14 EU-Allergene, die
  einschlaegigen deutschen Zusatzstoff-Kennzeichnungstexte, getrennte
  Verbraucherhinweise und dynamische E-Nummern.
- Kompakte, code-native Piktogramme priorisieren die in der 17-seitigen
  Testkarte haeufigsten Allergene Gluten, Milch und Ei, ohne Information nur
  ueber Farbe zu vermitteln.
- Jedes einzelne Symbol ist im iOS-Gastvorschaupfad und im Gast-Web antippbar
  und zeigt Klartext, Gruppe, Quellcode und Erlaeuterung. 44-Punkt-Touchziele
  und zugaengliche Namen bleiben erhalten.
- Quelllegenden ueberschreiben nicht-standardisierte Hauscodes semantisch.
  Historische Zahlencodes bleiben lesbar, werden aber nicht mehr als
  universelles Rechtssystem dargestellt; Knoblauch und Zwiebel gehoeren nicht
  zur EU-14-Standardauswahl.
- Abschlussnachweis: iOS-Build, 228 Tests (2 bewusst uebersprungen), gezielter
  UI-End-to-End-Smoke, Web-Typecheck, Lint, 73 Tests, Produktions-Build sowie
  mobile visuelle Browserpruefung bestanden.

## Abgeschlossene Web-Straenge

### KL-WEB-003 - Gast-Web-Sandbox in Betrieb nehmen (Deploy + echte Tests)

**Status:** Erledigt; mit PR #10/#12 integriert und auf Hostinger deployt
**Abhaengigkeit:** KL-WEB-002 (erledigt, gemergt)
**Schreibbereich:** `guest-web/`, `supabase/` (nur additive/neue Config,
Migrationen unangetastet), `docs/architecture/guest-web/`,
`docs/collaboration/handoffs/GLM.md`, dieser Eintrag

Die Gast-Web-Logik aus KL-WEB-002 war nie gegen eine echte Supabase-Instanz
gelaufen und nicht deployt. Dieser Strang macht sie lauffaehig, ohne dass der
Agent Cloud-Ressourcen anlegt oder Secrets committet:

- **Race-Follow-up aus KL-WEB-002 (Behoben):** neue additive Migration
  `supabase/migrations/20260718010000_guest_web_submit_order_race_fix.sql`
  redefiniert `guest_web_submit_order` so, dass eine enge Race Condition bei
  zwei gleichzeitigen Sendungen mit demselben Idempotenz-Key nicht mehr als
  generisches rpc_error durchgeht, sondern sauber auf Replay/Konflikt abgebildet
  wird (`EXCEPTION WHEN unique_violation`). Die Kerngarantie (nie zwei
  Bestellungen fuer einen Key) galt schon; der Verlierer bekommt jetzt ein
  klares Ergebnis statt eines generischen Fehlers.
- **Supabase-CLI-Initialisierung:** `supabase/config.toml` (keine Secrets, keine
  feste `project_id`), sodass `supabase link`/`db push` funktioniert.
- **Integrationstest-Geruest:** `guest-web/__tests__/integration/` mit echten
  RPC-End-to-End-Tests (Anonymous Sign-in -> Bestellung -> ACK -> Replay ->
  Konflikt -> RLS-Anon-Ablehnung). Skippt sauber, wenn keine Instanz
  konfiguriert ist (`KL_INTEGRATION=1`); getrennt vom instanzfreien Unit-Run
  via `npm run test:integration`.
- **Setup-Leitfaden:** `docs/architecture/guest-web/SANDBOX_SETUP.md` fuehrt den
  Nutzer Schritt fuer Schritt durch Supabase-Projekt (EU-Frankfurt), Anonymous-
  Sign-in-Aktivierung, Migrationen, `.env.local` und das aktuelle
  Hostinger-PaaS-Deployment.
- `guest-web/README.md` auf den aktuellen Stand gebracht (Kommandos +
  In-Betrieb-nehmen-Verweis).

Verifikation in `guest-web/`: typecheck + lint sauber, 40/40 Unit-Tests,
Integrationstests skippen sauber ohne Instanz, SSG-Build mit
`/alte-muehle/menu` intakt.

Der Nutzer hat Supabase, Anonymous Sign-in, Migrationen und Hostinger-Env
konfiguriert. Der oeffentliche Sandbox-Smoke-Test inklusive Server-ACK ist
erfolgt; Produktionsfreigabe und echte Zahlungen folgen daraus nicht.

### KL-WEB-004 - Menue-Anzeige aus Supabase (ISR) statt lokaler Fixture

**Status:** Erledigt; mit PR #14 in `main` integriert
**Abhaengigkeit:** KL-WEB-002, KL-WEB-003 (beide erledigt, gemergt)
**Schreibbereich:** `guest-web/`, neue additive Migration unter
`supabase/migrations/`, `docs/architecture/guest-web/`,
`docs/collaboration/handoffs/GLM.md`, dieser Eintrag

Schließt die Menü-Quell-Inkonsistenz aus KL-WEB-002/003: die Gastkarte holte
ihr Menü bisher aus der lokalen Fixture `venue-data.ts`, während die Bestellung
serverseitig aus der DB validiert wurde. Ab jetzt holt `guest-web/src/lib/
menu-loader.ts` die Venue mit Menü aus Supabase, gerendert als **ISR
(`revalidate = 60s`)**: Seite bleibt CDN-cachebar, DB-Änderungen sind nach max.
einer Minute sichtbar. Additive Migration `20260719000000_menu_items_tag`
ergänzt die nullable `menu_items.tag`-Spalte (ge seedet für die 8 Sandbox-
Items, deckungsgleich mit der Fixture), damit die „beliebt"/„vegetarisch"-
Pills beim Supabase-Fetch erhalten bleiben.

**Lastende Invariante (für andere Agenten wichtig):** in `menu-loader.ts` ist
`GuestMenuItem.id = menu_items.slug` (NICHT die UUID), weil `order-submit.ts`
`item.id` als Bestell-Slug an die RPC schickt, die über `menu_items.slug`
auflöst. Wer den Lese-Pfad ändert, darf diese Zuordnung nicht brechen.

Die lokale Fixture bleibt als **Build-Fallback** erhalten (Hostinger-Rebuild
bei Supabase-Ausfall fällt nicht rot). Verifikation: typecheck/lint sauber,
50/50 Unit-Tests, 8/8 Integrationstests gegen die echte Instanz, `next build`
meldet `Revalidate 1m` auf `/[venueSlug]/menu`. Kein visuelles Delta, kein
Bestellpfad-Change, keine neuen Tokens. Offen: Live-Smoke-Test durch den
Nutzer nach Merge + Hostinger-Redeploy.

### KL-INVENTORY-002 — Read-only Inventory-Operator-UI (V2-Bestand)

**Status:** Erledigt; von Codex reviewt und mit PR #15 in `main` integriert
**Abhängigkeit:** KL-INVENTORY-001 (erledigt, gemergt), KL-OPS-001
(Heute/Küche als Referenzmuster, erledigt)
**Historischer Schreibbereich:** neue Dateien unter
`kitchenlink/Features/Inventory/Views/`, neue Testdatei
`kitchenlinkTests/KitchenLinkV2InventoryStockProjectionTests.swift`, additive
Navigation/Launch-Arg-/Screenshot-Harness-Edits sowie Review-Korrekturen an der
Sandbox-Anzeige, diesem Eintrag und `docs/collaboration/handoffs/CODEX.md`

Schließt die mit KL-INVENTORY-001 bewusst vertagte UI-Sicht: eine read-only
Bestandsansicht für Betreiber:innen, die ihren Zustand ausschließlich aus
der echten `InventoryProjection` und `InventoryReplenishmentAdvisor` ableitet
— kein zweites Bestandsmodell, keine Mockwerte. Die Ansicht gruppiert je
Lagerort (Küche vor Bar vor Keller/Lager/Eingang), zeigt physisch/reserviert/
verfügbar und eine Schwere-Bewertung (`ok`/`warning`/`critical`) als Klartext-
Verb plus Urgency-Farbe. Buchen, Persistenz und Cloud-Sync bleiben vertagt.

**Design-Entscheidung (im Rahmen bereits genehmigter Specs):** Schwere wird
auf die 4-stufige Dringlichkeit abgebildet (`ok`→neutral, `warning`→waiting,
`critical`→critical). Zitrone ausschließlich in der einzelnen Demo-Aktion,
nie in einer Statusfarbe. Es wird **kein** neuer `KitchenLinkV2Operation`-
Case (`.stock`) erfunden und `KitchenLinkDesignSystemV2.swift` nicht angetastet
— `DESIGN_SYSTEM.md` §6 erlaubt explizit den Interim, dass eine Operation ohne
eigenes Form-Muster über Farbe und Klartext sichtbar bleibt. Ein späterer
`.stock`-Glyph ist eine separate Designfreigabe.

**Domain-Grenze:** Quantity, Models, Movement, Ledger, Projection,
Replenishment, RecipeResolution und `INVENTORY_MODEL.md` blieben unveraendert.
Im Review wurde lediglich der sichtbare Fixture-Name `Kueche` auf `Küche`
korrigiert. Die UI liegt im Unterverzeichnis `Features/Inventory/Views/`.

Review-Follow-up: Die erste visuelle Abnahme zeigte falsche lagerortfremde
Warnungen aus dem vollständigen Zutaten×Lagerort-Kreuzprodukt sowie
abgeschnittene Pflichttexte. Die UI-Projektion zeigt deshalb nur Paare mit
tatsächlicher Ledger-Aktivität; physisch, reserviert und verfügbar sind jetzt
explizit sichtbar, und Accessibility-Schriftgrößen stapeln die Zeile ohne
Abschneiden.

Verifikation: 13/13 Stock-Projektion-Tests und die komplette Unit-Suite grün;
Screenshot-Capture Light+Dark grün und visuell geprüft. Nach einem
Simulator-Runner-Flake liefen die drei betroffenen Navigations-UI-Tests im
isolierten Wiederholungslauf vollständig grün. Keine neue Produkt- oder
Designentscheidung; `DECISIONS.md` unberührt.

### KL-TABLE-001 - Tischkontext: QR je Tisch, Tisch an der Bestellung

**Status:** Implementiert auf `main` (30. Juli 2026); offen ist nur die reale
Abnahme durch den Nutzer (Migration anwenden + einmal ueber einen Tisch-QR
bestellen, `SANDBOX_SETUP.md` §6.3)
**Abhaengigkeit:** KL-CLOUD-001 (venue_staff, Betreiber-Anmeldung), KL-WEB-004
(Supabase-Lesepfad der Gastkarte)
**Schreibbereich:** `supabase/migrations/20260730120000_table_context.sql` (neu),
`scripts/verify-supabase-migrations.sh` + `scripts/tests/` (neu),
`guest-web/src/lib/table-context.ts` (neu), `guest-web/src/lib/order-submit.ts`,
`order-backend-supabase.ts`, `components/GuestMenuCard.tsx`, `app/globals.css`,
`guest-web/__tests__/table-context.test.ts` (neu),
`kitchenlink/Features/Tables/` (neu), `kitchenlink/OrderingDomain.swift`
(Bezeichnungsregel), `OrderRelayService.swift`, `Features/Today/`,
`Features/CloudOperations/KitchenLinkCloudOrderClient.swift`,
`App/KitchenLinkV2BusinessHomeView.swift`,
`App/KitchenLinkDesignPreviewConfiguration.swift`,
`kitchenlinkTests/KitchenLinkTablesTests.swift` (neu),
`kitchenlinkUITests/kitchenlinkUITests.swift`, `SANDBOX_SETUP.md`, dieser Eintrag
und `docs/collaboration/handoffs/CLAUDE.md`

Schliesst die erste der zwei tragenden Luecken nach dem Menue-Import: eine
Gastbestellung gehoerte bisher dem **Lokal**, nicht einem Tisch. Weder App noch
Gast-Web noch Datenbank kannten einen Tischbegriff im Produktpfad, obwohl
`tables`, `qr_tokens`, `table_sessions` und `orders.table_id` seit dem
Kernschema existieren.

- **Sicherheitsbefund (behoben):** Diese drei Tabellen waren als **einzige**
  des Gastschemas ohne Row Level Security, waehrend Supabase `anon`
  Tabellenrechte per Default-Privileg gibt. Lokal reproduziert: vor der
  Migration konnte `anon` einen QR-Token direkt schreiben. Jetzt: RLS aktiv,
  Lesen nur fuer Personal, Schreiben ausschliesslich ueber RPCs.
- **Migration (additiv):** `tables.area`/`sort_order`, Partial-Unique-Indizes
  (genau eine offene Session je Tisch, genau ein aktives Tisch-Token je Tisch),
  Staff-RPCs `operator_upsert_table`, `operator_delete_table`,
  `operator_rotate_table_token`, Gastauskunft `guest_web_resolve_table` und ein
  zusaetzlicher, vorbelegter Parameter `p_table_token` an
  `guest_web_submit_order_v2` (Drop/Create in derselben Transaktion statt einer
  v3, die 470 Zeilen Bestelllogik dupliziert haette).
- **Gast-Web:** `?tisch=<token>` wird nach der Hydration gelesen, aufgeloest und
  im Kartenkopf sowie im Bestell-Sheet angezeigt; das Token geht in den
  Idempotenzschluessel ein. Die Seite bleibt ISR-gerendert (`Revalidate 1m`) —
  `searchParams` serverseitig zu lesen haette den CDN-Cache jeder Karte gekostet.
- **iOS:** neuer Bereich `Tische` (Bereiche, Tische, QR-Code je Tisch, Teilen/
  Drucken, Umbenennen, Stilllegen, Code rotieren). Cloud-Bestellungen tragen
  ihren Tisch jetzt bis in `Service` und `Heute`.
- **Gemeinsame Tisch-Session (Blueprint §6.1):** die erste Bestellung eines
  Tisches eroeffnet sie, jede weitere haengt sich an dieselbe; das Rennen
  zwischen zwei gleichzeitig bestellenden Gaesten entscheidet der Index.

**Produktentscheidung, die der Nutzer drehen kann:** ein unbekannter,
abgelaufener oder stillgelegter QR-Code fuehrt zu einer **Absage** statt zu
einer tischlosen Bestellung. Begruendung: eine nicht zuordenbare Bestellung
kostet im Betrieb mehr als eine abgewiesene. Umschaltbar an einer Stelle
(`tableUnknown` in `GuestMenuCard.tsx` plus die Abweisung in der RPC).

Verifikation: **erstmals lief die RPC-SQL dieses Projekts vor der Abnahme gegen
ein echtes PostgreSQL** — `scripts/verify-supabase-migrations.sh` faehrt eine
Wegwerf-Instanz hoch, spielt alle zwoelf Migrationen ein und prueft
Tischaufloesung, Session-Zusammenlegung, Idempotenz mit Tisch, Token-Rotation,
Loeschschutz und die RLS-Sperre fuer `anon`. Der Lauf fand zwei echte Fehler
(Loeschen verletzte die neue Token-Bedingung; ein mehrdeutiger Spaltenverweis
im Test). Ausserdem: iOS-Unit-Suite und Standard-UI-Suite gruen (ein
vorbestehender, von dieser Aenderung unabhaengiger Fehlschlag in
`MenuManualEditorUITests`, auch auf ungeaendertem Stand reproduziert),
Gast-Web typecheck/lint/105 Tests/Build mit ISR intakt, visuelle Pruefung
hell und dunkel auf iPhone 17 Pro und mobil im Browser.

### KL-TABLE-002 - Kellnerbestellung am Tisch

**Status:** Implementiert auf `main` (31. Juli 2026); offen ist die reale
Abnahme (Migrationen anwenden, eine Bestellung aufnehmen, Cloud-Ankunft
pruefen, `SANDBOX_SETUP.md` §6.4)
**Abhaengigkeit:** KL-TABLE-001 (Tische), KL-CLOUD-001 (Betreiber-Sitzung,
Outbox-Versand)
**Schreibbereich:** `supabase/migrations/20260730160000_operator_create_order_table.sql`
(neu), `scripts/tests/table-context.sql`, `kitchenlink/Features/Tables/
KitchenLinkWaiterOrderModel.swift` und `KitchenLinkV2WaiterOrderView.swift`
(neu), `Features/LocalOperations/KitchenLinkV2LocalOperationsView.swift`,
`Features/CloudOperations/KitchenLinkServiceOrderMerge.swift`,
`KitchenLinkCloudOperationsModel.swift`, `KitchenLinkCloudOrderClient.swift`,
`EventLogOrderRepository.swift`, `kitchenlinkTests/
KitchenLinkWaiterOrderTests.swift` (neu), `KitchenLinkCloudOperationsTests.swift`,
`KitchenLinkEventLogOrderRepositoryTests.swift`, `SANDBOX_SETUP.md`, dieser
Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Macht den in `DECISIONS.md` (Local-First, 23. Juli 2026) beschlossenen
Offline-Pfad erstmals durchfuehrbar: „Gaeste bestellen verbal, der Kellner
erfasst die Bestellung auf dem Service-iPhone." Im Produkt gab es diesen Weg
nicht — `Service` konnte nur Status schalten, die Bestellaufnahme lag im
stillgelegten Legacy-Checkout, und `operator_create_order` war ungenutzt.

- **Reihenfolge als Zusage:** erst der dauerhafte Commit im lokalen
  Ereignisprotokoll, dann die Bestaetigung, dann die Cloud. Der Kellner sieht
  ausdruecklich, ob die Cloud die Bestellung schon kennt — ohne Verbindung
  bleibt sie angenommen und wird von der Outbox nachgereicht.
- **Migration (additiv):** `operator_create_order` bekommt `p_table_id`,
  haengt die Bestellung an Tisch und offene Tisch-Session (gemeinsame Funktion
  `kitchenlink_open_table_session`) und weist stillgelegte Tische ab.
  **Behobener Idempotenzfehler:** die bisherige Fassung liess die Bestellung
  dank `on conflict (id) do nothing` einmalig, fuegte die **Positionen** bei
  einer Wiederholung aber erneut ein — bei jedem Outbox-Retry haette die
  Bestellung doppelte Positionen und einen falschen Betrag gehabt.
- **Zwei Fehler, die erst der Simulator zeigte:** die lokale Liste filterte auf
  `preparing`, waehrend eine Kellnerbestellung `pending` startet (sie war
  unsichtbar), und der Merge entdoppelte nicht nach ID (nach der
  Synchronisation haette dieselbe Bestellung zweimal auf dem Pass gelegen).
  Beides in `KitchenLinkServiceOrderMerge` behoben und getestet.
- **Bestellkarte:** der Tisch fuehrt jetzt die Karte an (`Tisch 1`), Zeit und
  Herkunft ruecken in die zweite Zeile. Die Kueche muss wissen, wohin.
- **Nebenbefund behoben:** die Bestell-Abfrage holte `tables(label,area)`;
  `area` kommt erst mit 20260730120000. Ein Betrieb mit neuer App und alter
  Datenbank haette seine Bestellliste verloren. Jetzt nur `tables(label)`.

Verifikation: SQL gegen echtes PostgreSQL (Kellnerbestellung teilt die offene
Session der Gaeste, Wiederholung verdoppelt keine Positionen, stillgelegter
Tisch und fehlende Personalrolle abgewiesen), iOS-Unit-Suite und Standard-UI-
Suite gruen (410 bestanden; der eine Fehlschlag in `MenuManualEditorUITests`
ist vorbestehend), sowie der vollstaendige Ablauf im Simulator: aufnehmen →
dauerhaft gespeichert → Kueche zeigt `Tisch 1` → zubereitet → Kellner-Modus →
serviert.

### KL-PAY-001 - Rechnung, Trinkgeld und simulierte Zahlung

**Status:** Implementiert auf `main` (31. Juli 2026); offen ist die reale
Abnahme (Migration anwenden, einmal getrennt kassieren, `SANDBOX_SETUP.md` §6.5)
**Abhaengigkeit:** KL-TABLE-001 (Tisch-Session), KL-TABLE-002 (Bestellungen am
Tisch), KL-CLOUD-001 (Betreiber-Sitzung)
**Schreibbereich:** `supabase/migrations/20260731100000_sandbox_payments.sql`
(neu), `scripts/tests/payments.sql` (neu), `kitchenlink/Features/Payments/`
(neu: Provider, Transport, Modell, Ansicht, Demo-Transport),
`Features/LocalOperations/KitchenLinkV2LocalOperationsView.swift` (Einstieg),
`Features/Tables/KitchenLinkV2TablesView.swift` (geteilte Anmeldekarte),
`kitchenlinkTests/KitchenLinkPaymentTests.swift` (neu), `SANDBOX_SETUP.md`,
dieser Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Schliesst Meilenstein 1 (Blueprint §8.1, „Split-Rechnung, Trinkgeld und
Sandbox-Zahlung"): die gemeinsame Tisch-Session bekommt eine Rechnung.
Mehrere Zahlungen, mehrere Zahlarten, getrennt nach Positionen, Trinkgeld je
Zahlung, Storno. **Keine Sandbox-Zahlung bewegt echtes Geld.**

- **Der Betrag kommt nie vom Geraet.** Bei ausgewaehlten Positionen rechnet die
  Datenbank ihn aus deren Zeilensummen; ein abweichender behaupteter Betrag
  wird abgewiesen (`payment_amount_mismatch`).
- **Tragende Invariante als Index:** `payment_items_one_open_payment_per_item`
  — eine Position kann nicht zweimal offen bezahlt sein. Zwei gleichzeitig
  kassierende Geraete koennen denselben Gang nicht doppelt abrechnen; der
  Verlierer bekommt eine klare Absage statt eines rohen Datenbankfehlers.
- **Idempotenz:** jede Zahlung traegt einen Schluessel; eine Wiederholung
  liefert die erste Antwort zurueck statt einer zweiten Buchung. Der Schluessel
  ueberlebt auch die Sitzungserneuerung nach einem 401.
- **Storno** laesst die Zahlung als `refunded` stehen (auditiert, §8.2), gibt
  ihre Positionen wieder frei und oeffnet die Rechnung erneut — aber nur, wenn
  am Tisch nicht laengst neue Gaeste sitzen.
- **Provider-Naht (§8.2):** `KitchenLinkPaymentProviding` mit
  `KitchenLinkSandboxPaymentProvider`. Karte und Tap to Pay laufen darueber;
  eine abgelehnte Autorisierung erzeugt keine Buchung. Bar und Gutschein
  brauchen keinen Anbieter. Kartendaten sieht die App nie.

Bewusst nicht enthalten: Betriebsschicht und Tagesabschluss (§8.3),
Onlinezahlung im Gast-Web, Gutschein-/Guthabenkonten, Zahlung bei Lieferung,
Fiskalisierung und Belegdruck.

Verifikation: SQL gegen echtes PostgreSQL (Rechnung ueber zwei Gastbestellungen,
serverseitig gerechneter Betrag, doppelte Position abgewiesen, Replay ohne
zweite Buchung, Teilbetrag ueber offenem Betrag abgewiesen, Rechnung schliesst
sich, Storno gibt frei, `anon` sieht nichts), iOS 427 Testfaelle bestanden (der
eine Fehlschlag in `MenuManualEditorUITests` ist weiterhin vorbestehend), und
der Ablauf im Simulator: eine Position gewaehlt, 10 % Trinkgeld, Karte ueber den
simulierten Anbieter, Beleg mit Restbetrag, danach Storno mit wieder offener
Position.

### KL-STATION-001 / KL-ORDER-001 - Stationen und Annahmeregel

**Status:** Implementiert auf `main` (31. Juli 2026); offen ist die reale
Abnahme (Migrationen anwenden, einmal ueber zwei Stationen abarbeiten,
`SANDBOX_SETUP.md` §6.6)
**Abhaengigkeit:** KL-CLOUD-001, KL-TABLE-001/002
**Schreibbereich:** `supabase/migrations/20260731140000_station_routing.sql`
und `20260731160000_order_confirmation_rule.sql` (neu),
`scripts/tests/stations-and-confirmation.sql` (neu),
`kitchenlink/OrderingDomain.swift` (Station), `OrderRelayService.swift`
(`LiveOrderLine.readyAt`), `Features/CloudOperations/` (Wire-Modell,
Stations-Transport, schmale Modell-Zugriffe),
`Features/LocalOperations/KitchenLinkV2LocalOperationsView.swift`,
`kitchenlinkTests/KitchenLinkStationTests.swift` (neu), `SANDBOX_SETUP.md`,
dieser Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Schliesst die letzten beiden offenen Punkte von Meilenstein 1 (Blueprint §7
und §6.3).

- **Stationen (§7, Meilenstein 1.9):** `Service` hat jetzt `Küche | Bar |
  Kellner`. Jede Station sieht **nur ihre** Positionen und gibt **nur ihre**
  frei; der Barkeeper bekommt keine Schnitzelliste mehr. Die Zuordnung folgt
  `kind` (Speise → Küche, Getränk → Bar) und steht als eigene Spalte
  `order_items.station`, damit eine spätere Zuordnung je Artikel nichts
  umbaut. Die Bestellung wird erst `ready`, wenn **keine** Station mehr offen
  ist — das entscheidet `operator_mark_station_ready` in der Datenbank, nicht
  die App. Die Karte nennt die noch arbeitende Station („Küche arbeitet
  noch", §7).
- **Annahmeregel (§6.3, Meilenstein 1.8):** `venues.order_confirmation_channels`
  haelt die Kanaele mit Bestaetigungspflicht; leer bleibt der Standard
  „automatisch angenommen". Betroffene Bestellungen erreichen die Station erst
  nach `accepted` und stehen bis dahin in einer eigenen Liste mit Annehmen und
  Ablehnen. `rejected` fehlte im Statusmodell der Datenbank, obwohl Blueprint
  §6.4 es fuehrt — es ist jetzt da, mit Grund und Zeitstempel. Ablehnen ist nur
  vor der Annahme moeglich; danach ist Stornieren der richtige Weg.

**Grenze, bewusst so:** Der Stationsstatus wird in der Cloud gefuehrt. Rein
lokale Bestellungen (Offline-Fall, ein Geraet) behalten den Bump ueber die
ganze Bestellung — Stationstrennung loest ein Mehrgeraeteproblem, und offline
ist per Definition ein Geraet im Spiel.

**Vertraeglichkeit:** Der Bestell-Lesepfad faellt automatisch auf die alte
Spaltenliste zurueck, wenn `order_items.ready_at` noch fehlt. Ein Betrieb, der
die App aktualisiert hat, aber die Migration noch nicht, sieht seine
Bestellungen weiter.

Verifikation: SQL gegen echtes PostgreSQL (Station aus `kind` abgeleitet, erst
beide Stationen machen `ready`, zweiter Tap ohne Wirkung, reine
Getraenkebestellung braucht nur die Bar, unbekannte Station und fremde
Identitaet abgewiesen, Regel nur fuer ihren Kanal, unbekannter Kanal abgelehnt,
Ablehnen nur vor der Annahme, Replay), iOS 438 Testfaelle bestanden (weiterhin
ein vorbestehender Fehlschlag in `MenuManualEditorUITests`), und der
Simulator-Durchlauf: Bar zeigt nur Getraenke, meldet „Küche arbeitet noch" und
schaltet mit „Getränke fertig".

### KL-ONBOARD-001 - Konto und eigenes Restaurant (Meilenstein 1 abgeschlossen)

**Status:** Implementiert auf `main` (31. Juli 2026); offen ist die reale
Abnahme (Migration anwenden, eigenes Restaurant anlegen, `SANDBOX_SETUP.md` §6.7)
**Abhaengigkeit:** KL-CLOUD-001 (Betreiberkonto), alle vorherigen Betreiber-RPCs
**Schreibbereich:** `supabase/migrations/20260731180000_operator_create_venue.sql`
(neu), `scripts/tests/venue-onboarding.sql` (neu),
`kitchenlink/Features/Onboarding/` (neu),
`Features/CloudOperations/KitchenLinkCloudOrderClient.swift` (aktive Venue),
`App/KitchenLinkV2BusinessHomeView.swift`,
`kitchenlinkTests/KitchenLinkVenueOnboardingTests.swift` (neu),
`SANDBOX_SETUP.md`, dieser Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Schliesst den letzten offenen Punkt von Meilenstein 1 (Blueprint §5,
Meilenstein 1.3) — und damit **Meilenstein 1 insgesamt**.

Der Kern-Pitch endete bisher genau dort, wo er anfangen sollte: gescannt wurde
immer in die eine mitgelieferte Demo-Venue, und wer ein zweites Lokal sehen
wollte, musste `venue_staff` von Hand per SQL anlegen (`SANDBOX_SETUP.md` §6.1).

- **`operator_create_venue`** legt Venue an, macht den Anleger zum Personal und
  erzeugt eine leere aktive Karte, damit die Gastseite sofort eine gueltige
  Venue vorfindet. Ein anonymer Gast darf das ausdruecklich nicht.
- **`operator_suggest_venue_slug`** weicht auf eine freie Variante aus, statt
  den Betreiber raten zu lassen. Der Name kommt vom Betreiber, die Adresse
  ergibt sich (Usability-Leitplanke: keine URL erfinden).
- **`operator_my_venues`** ist die eine Quelle fuer „welche Venue gehoert mir".
- **App:** neuer Bereich `Restaurant` (Konto anlegen oder anmelden, Restaurant
  anlegen, zwischen eigenen Lokalen wechseln, zurueck ins Demo-Lokal).

**Die tragende Aenderung ist klein und wirkt ueberall:**
`KitchenLinkCloudConfig.sandboxDefault` ist keine Konstante mehr, sondern folgt
der aktiven Venue. Instanz und Anon-Key bleiben eingebacken (die Sandbox hat
genau eine Instanz), die Venue nicht. Damit arbeiten Scan-Publish, Tische,
Bestellungen, Stationen und Rechnung ohne weitere Aenderung auf dem eigenen
Lokal — jede dieser RPCs prueft ohnehin ueber `is_venue_staff`.

Sandbox-Grenze: fuenf Restaurants je Konto, gegen versehentliche Massenanlage.
Kein Produktlimit.

Verifikation: SQL gegen echtes PostgreSQL — und zwar der **ganze Weg** im neuen
Lokal: Venue anlegen, Karte veroeffentlichen, Tisch anlegen, Gast bestellt ueber
den Tisch-QR, Betreiber liest die Rechnung. Dazu: fremdes Konto wird abgewiesen,
anonymer Gast darf nichts anlegen, Name/Slug werden geprueft statt
zurechtgebogen, Slug-Vorschlag weicht aus, Obergrenze greift. iOS-Unit-Tests
gruen; Simulator-Durchlauf mit Anlegen, Aktivwerden, Liste und Rueckweg ins
Demo-Lokal.

### KL-SHIFT-001 - Betriebsschicht und Kassenabschluss (Meilenstein 2 begonnen)

**Status:** Implementiert auf `main` (31. Juli 2026), Migration angewendet und
auf der Instanz verifiziert; offen ist nur ein realer Tagesdurchlauf am Geraet
(`SANDBOX_SETUP.md` §6.8)
**Abhaengigkeit:** KL-PAY-001 (Zahlungen), KL-TABLE-001 (Tisch-Sessions)
**Schreibbereich:** `supabase/migrations/20260731200000_business_shift.sql`
(neu), `scripts/tests/business-shift.sql` (neu),
`kitchenlink/Features/Shift/` (neu),
`App/KitchenLinkV2BusinessHomeView.swift`,
`kitchenlinkTests/KitchenLinkShiftTests.swift` (neu),
`scripts/verify-supabase-migrations.sh` (Wiederholbarkeitslauf),
`SANDBOX_SETUP.md`, dieser Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Erster Punkt von Meilenstein 2 (Blueprint §8.3). Meilenstein 1 hat den
Geldkreis geoeffnet, aber nicht geschlossen: es wurde kassiert, storniert und
Trinkgeld genommen — und am Ende des Tages gab es nichts, wogegen jemand
zaehlen konnte.

- **`business_shifts`** mit Anfangsbestand, gezaehltem Bargeld, erwartetem
  Bestand, Abweichung und Z-Nummer. Die tragende Zusage steht als partieller
  Unique-Index: **je Venue ist hoechstens eine Schicht offen.** Sonst kassieren
  zwei Geraete in zwei Kassen und keine Zaehlung stimmt je wieder.
- **`cash_movements`** fuer Entnahme, Ausgabe und Einlage.
- **`kitchenlink_shift_totals`** ist die *eine* Quelle fuer Bericht, Abschluss
  und Live-Anzeige. Waere das dreimal getrennt gerechnet, driftet der erwartete
  Bestand irgendwann von dem ab, was der Abschluss festhaelt.
- **Zuordnung per Trigger statt per RPC-Aenderung:** `payments.shift_id` setzt
  ein `before insert`-Trigger aus der offenen Schicht der Venue. Damit greift
  die Zuordnung auch fuer jeden spaeteren Zahlungsweg (Onlinezahlung im
  Gast-Web, Theke, Lieferung), ohne dass ihn jemand daran erinnern muss.
- **App:** neuer Bereich `Kasse` (oeffnen mit Anfangsbestand, laufende Summen,
  Bargeld bewegen, zaehlen und abschliessen, Z-Bericht, Rueckblick).

**Zwei bewusste Entscheidungen:**

1. Eine **Zahlung** ohne offene Schicht wird *nicht* blockiert — Geld
   anzunehmen darf nie an einem vergessenen Knopfdruck scheitern. Sie bleibt
   ohne `shift_id` und taucht im Bericht als „ausserhalb der Schicht" auf,
   statt still zu verschwinden. Eine **Entnahme** dagegen verlangt eine offene
   Kasse: sie ist die Buchung *auf* die Schicht und waere ohne sie nirgends
   zugeordnet.
2. Die Abweichung wird **festgehalten, nicht verhindert**. Ein Abschluss, der
   eine Differenz verschweigt, ist wertlos. Offene Rechnungen werden vor dem
   Abschluss gewarnt, aber nicht erzwungen.

Verifikation: SQL gegen echtes PostgreSQL (zweite offene Schicht abgewiesen,
Karte zaehlt nicht in die Schublade, Bar-Trinkgeld schon, Storno senkt den
Bestand wieder, geschlossene Schicht bleibt eingefroren, Z-Nummern lueckenlos,
RLS mit `set role` belegt). 462 iOS-Unit-Tests gruen; Simulator-Durchlauf ueber
oeffnen, Ausgabe buchen, mit Abweichung und ohne abschliessen.

Nebenbefund und Fix: die Ansicht war die einzige Stelle im Projekt mit
`.dateTime` und zeigte auf einem englisch eingestellten Geraet „Jul 31 at
17:11" in einer durchgehend deutschen App. Jetzt fest auf `de_DE`, wie ueberall
sonst.

### KL-ROLE-001 - Rollen und Rechte

**Status:** Implementiert auf `main` (31. Juli 2026), Migration angewendet und
auf der Instanz verifiziert; offen ist ein realer Durchlauf mit einem zweiten
Konto (`SANDBOX_SETUP.md` §6.9)
**Abhaengigkeit:** KL-SHIFT-001 (die zu schuetzenden Geldaktionen)
**Schreibbereich:** `supabase/migrations/20260731220000_roles_and_permissions.sql`
(neu), `scripts/tests/roles-and-permissions.sql` (neu),
`scripts/tests/supabase-stubs.sql` (`auth.users`),
`kitchenlink/Features/Team/` (neu), `Features/Shift/` (Rechte in der Kasse),
`App/KitchenLinkV2BusinessHomeView.swift`,
`kitchenlinkTests/KitchenLinkTeamTests.swift` (neu), `KitchenLinkShiftTests.swift`,
vier bestehende SQL-Tests (explizite Rolle), `SANDBOX_SETUP.md`, dieser Eintrag
und `docs/collaboration/handoffs/CLAUDE.md`

Blueprint §9.1. Bis hierher galt: **wer angemeldet ist, darf alles.**
`is_venue_staff` prueft die Mitgliedschaft, nicht die Befugnis — also konnte
jede Servicekraft die Kasse abschliessen, eine Zahlung stornieren und Geld aus
der Schublade nehmen.

**Der Zuschnitt ist die eigentliche Entscheidung.** Es gibt 25 `operator_`-RPCs;
sie alle zu ersetzen waere ein Wartungsalbtraum gewesen, und die meisten
*sollen* jedem Personal offenstehen (die Kueche braucht
`operator_mark_station_ready`, der Service `operator_record_payment`). Diese
Migration fuehrt deshalb genau **fuenf** Rechte ein und erzwingt **alle fuenf**:
`shift.open`, `shift.close`, `cash.movement`, `payments.refund`,
`staff.manage`. Kein Recht steht in der Liste, das nirgends geprueft wird — eine
Rolle mit leerer Rechteliste heisst „darf alles Alltaegliche, aber nichts
Sensibles". Die Konfigurationsrechte (Karte, Tische) sind eine eigene Scheibe
und kommen zusammen mit ihrer Durchsetzung.

- **`venue_roles` je Venue** statt einer Aufzaehlung im Code, mit den neun
  Standardrollen aus §9.1. „Eigene Rollen mit granularen Rechten" ist damit
  spaeter ein Datensatz mehr, kein Umbau. Ein Trigger auf `venues` legt sie an.
- **`venue_staff.role`** hatte einen CHECK auf den einen Wert `'operator'`;
  jetzt ein Fremdschluessel auf `venue_roles(venue_id, key)`.
- **`kitchenlink_require_permission`** loest Venue auf, prueft Mitgliedschaft
  und Recht und bricht sprechend ab — ein Aufruf statt vier Zeilen je RPC.
- **App:** neuer Bereich `Team`; die Kasse sperrt Abschluss und Bargeldbewegung
  und **erklaert**, warum („Als Service darfst du … nicht. Frag Inhaber,
  Manager oder Schichtleitung.") statt in einen Serverfehler zu laufen.

**Bestandspersonal verliert nichts:** `operator` wird zu `owner`. Alles andere
waere eine stille Entrechtung durch eine Migration. Der Spaltendefault fuer
*neue* Zeilen steht dagegen auf `service` — geringste Befugnis.

**Drei Sperren gegen Fuehrungslosigkeit:** niemand aendert oder entfernt den
eigenen Zugang, nur ein Inhaber kann einen Inhaber anfassen, der letzte Inhaber
bleibt Inhaber.

Verifikation: SQL gegen echtes PostgreSQL in einer eigenen Testvenue (Service
wird bei allen fuenf Aktionen abgewiesen und darf den Alltag weiterhin;
Schichtleitung darf die Kasse, aber kein Personal; alle drei Sperren belegt;
Bestandspersonal behaelt seine Rechte; RLS mit `set role`). 483 iOS-Unit-Tests
gruen, 13 UI-Tests gruen; Simulator-Durchlauf mit Rollenwechsel.

Nebenbefund und Fix: E-Mail-Platzhalter wurden blau statt grau gezeichnet, weil
`Text("…@…")` als `LocalizedStringKey` durch die Markdown-Verarbeitung laeuft
und die Adresse verlinkt. Betraf **fuenf** Stellen (Team, Restaurant, Tische,
Service, Publish-Sheet); jetzt ueberall `Text(verbatim:)`.

**Noch nicht enthalten:** eigene Rollen, Qualifikationen, Mitarbeiterprofile,
Standortzuordnung ueber mehrere Venues. Der Manager-PIN kam mit KL-ROLE-002
nach (31. Juli 2026): §9.1 verlangt „besonderes Recht **oder** Manager-PIN",
und damit ist beides umgesetzt.

## KL-ROLE-002 — Manager-PIN (Claude Code, 31. Juli 2026, erledigt)

Zweite Haelfte von Blueprint §9.1. Eine Fuehrungskraft gibt am Tisch **eine**
Aktion frei, ohne dass sich jemand ab- und anmeldet: PIN je Person (nicht je
Lokal — sonst waere §8.2 „wer hat freigegeben?" nicht beantwortbar), bcrypt
gehasht, einmaliger Token mit fuenf Minuten Gueltigkeit, Sperre nach fuenf
Fehlversuchen, jede Freigabe protokolliert. Ueberbrueckbar sind `shift.open`,
`shift.close`, `cash.movement` und `payments.refund`; `staff.manage`
ausdruecklich nicht.

Migration `20260731230000_manager_pin.sql`, SQL-Test
`scripts/tests/manager-pin.sql`, App: Freigabe-Blatt in Kasse und Rechnung,
eigene PIN und Freigabeprotokoll im Team-Bildschirm.

### KL-TIME-001 - Zeiterfassung

**Status:** Implementiert auf `main` (1. August 2026), lokal gegen echtes
PostgreSQL geprueft — **Migration noch nicht gepusht**, siehe „Offen" unten
**Abhaengigkeit:** KL-ROLE-001 (`staff.manage` fuer den Team-Stand)
**Schreibbereich:** `supabase/migrations/20260801120000_time_clock.sql` (neu),
`scripts/tests/time-clock.sql` (neu), `kitchenlink/Features/TimeClock/` (neu),
`App/KitchenLinkV2BusinessHomeView.swift`,
`kitchenlinkTests/KitchenLinkTimeClockTests.swift` (neu), `SANDBOX_SETUP.md`,
dieser Eintrag und `docs/collaboration/handoffs/CLAUDE.md`

Blueprint §9.3. Seit KL-WORKFORCE-001 (17. Juli) lag unter
`kitchenlink/Features/Workforce/` eine vollstaendige, getestete Domaene fuer
Personal, Planung und Zeit — mit **null Referenzen** aus der App. 1850 Zeilen
Code und Tests, die nichts taten. Diese Scheibe liefert Persistenz und
Oberflaeche fuer den ersten Teil davon: das Stempeln.

**Die Trennung der drei Fachobjekte bleibt** (Blueprint §9): Betriebsschicht
(`business_shifts`), geplante Schicht (noch nicht persistiert) und Zeiteintrag.
Ein Zeiteintrag haengt deshalb ausdruecklich **nicht** an einer
Betriebsschicht — wer um 15 Uhr die Kueche vorbereitet, arbeitet auch dann,
wenn die Kasse noch zu ist.

- `time_entries` und `time_breaks`, beide mit der tragenden Zusage als Index:
  **niemand steht zweimal gleichzeitig auf der Uhr**, und in einem Eintrag
  laeuft hoechstens eine Pause.
- `kitchenlink_time_entry_seconds` als *eine* Quelle fuer brutto, Pause und
  netto.
- Die eigene Zeit zu stempeln braucht **kein** Recht (die Kueche muss auf die
  Uhr kommen, ohne zu fragen); fremde Zeiten zu sehen und zu korrigieren
  verlangt `staff.manage`. Bewusst **kein sechstes Recht** — ein Recht, das nur
  an einer Stelle wirkt, waere eine Zeile mehr in jeder Rollenliste ohne
  Gewinn, und die parallele PIN-Arbeitslinie fasst dieselbe Stelle an.
- Ein Nachtdienst zaehlt zu dem Tag, an dem er **begonnen** hat.
- Korrektur mit Grund und Audit: `original_started_at`/`original_ended_at`
  bleiben stehen, eine zweite Korrektur ueberschreibt sie nicht.

**Warum die Korrektur nicht optional ist:** ohne sie bliebe ein vergessener
Ausstempel fuer immer offen — und die betroffene Person kaeme wegen des Index
nie wieder auf die Uhr. Der Bildschirm meldet Eintraege ueber zwoelf Stunden
deshalb aktiv und bietet die Korrektur an.

Verifikation: SQL gegen echtes PostgreSQL in einer eigenen Testvenue
(zweimal einstempeln abgewiesen, Pause zieht ab, laufende Pause wird beim
Ausstempeln mitbeendet, Tagesgrenze, Team-Stand nur mit `staff.manage`,
Korrektur behaelt den Originalwert, RLS mit `set role`). 498 iOS-Unit-Tests
gruen; Simulator-Durchlauf ueber einstempeln, Pause, Korrektur eines
vergessenen Ausstempels.

Zwei Fehler unterwegs: der SQL-Test haing an der Uhrzeit des Laufs (er lief um
01:57, und „zwei Stunden zurueck" fiel damit auf den Vortag) — statt die
Tagesgrenze zu umgehen, prueft er sie jetzt ausdruecklich. Und der
Constraint `ended_at > started_at` wies einen Eintrag ohne Dauer ab; wer sich
vergreift und sofort wieder ausstempelt, erzeugt genau den. Jetzt `>=`, weil
eine Null-Dauer ehrliche Datenlage ist — eine Korrektur von Hand verlangt
weiterhin ein Ende nach dem Beginn.

**Offen:** Die Migration ist **nicht gepusht**. Auf der Instanz liegt bereits
`20260731230000_manager_pin.sql` aus einer parallelen Arbeitslinie, deren Datei
noch in einem eigenen Arbeitsbaum liegt; `supabase db push` verlangt eine
lueckenlose lokale Historie und verweigert deshalb. Die Kombination beider
Migrationen ist lokal geprueft (alle sieben SQL-Tests bestehen). Sobald die
PIN-Arbeit auf `main` ist, ist der Push ein einzelner Aufruf.

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
9. ~~Offline-Venue-Hub-Discovery reviewen.~~ Erledigt (18. Juli 2026);
   Discovery-Dokumente und Integrationslesart nach `main` gebracht, siehe
   Discovery-Abschnitt oben. Netzwerkseitiger Hub-Teil bleibt bis zu
   Nutzerentscheidungen blockiert.
10. ~~Gast-Web zur laufenden Sandbox bringen (KL-WEB-003).~~ Erledigt und mit
    PR #10/#12 integriert; Supabase und Hostinger sind konfiguriert, die
    oeffentliche Sandbox-Bestellung wurde Ende-zu-Ende verifiziert.
11. ~~Read-only Bestandsansicht integrieren (KL-INVENTORY-002).~~ Nach
    technischer und visueller Abnahme, Review-Fixes und vollstaendiger
    Verifikation mit PR #15 am 18. Juli 2026 integriert.
12. Erst nach stabilen Referenzscreens weitere Produktmodule migrieren.
13. ~~KL-OFFLINE-004 reviewen und den lokalen Top-Level-Pfad auf iOS Safari
    messen.~~ Review und iPhone-Bestellung erledigt; PR #22 behebt den dabei
    gefundenen Plain-HTTP/Web-Crypto-Fehler.
14. ~~KL-OFFLINE-005 auf dem echten iPhone mit einem zweiten Bestellgeraet
    abnehmen und integrieren.~~ Erfolgreich am 19. Juli 2026 und mit PR #23
    in `main` integriert. Android Chrome, AP-Isolation und Discovery bleiben
    die naechsten Netzwerk-Gates.
15. ~~KL-OFFLINE-006 als Foreground-Hub direkt auf dem iPhone abnehmen und
    integrieren.~~ Mac bestellte erfolgreich ueber die vom iPhone bereitgestellte
    Gastadresse; Kueche-zu-Kellner-Ablauf bestanden und mit PR #25 in `main`
    integriert. Hintergrundbetrieb und die verbleibenden Netzwerk-Gates bleiben
    offen.
16. ~~KL-OFFLINE-007 mit echtem WLAN-Verlust und Recovery auf dem iPhone
    abnehmen und integrieren.~~ Nutzerabnahme bestanden und mit PR #27 in
    `main` integriert. Background-Lifecycle, Discovery, AP-Isolation, Android
    und TLS/Trust bleiben getrennte Folge-Gates.
17. KL-CLOUD-001 abnehmen: Migration + Betreiber-Konto auf der echten
    Instanz einrichten (SANDBOX_SETUP.md §6.1), Web-Bestellung auf dem
    iPhone in `Service` empfangen und abschließen, Offline-Hinweis im
    Gast-Web bei getrenntem Internet prüfen, dann Branch
    `claude/cloud-order-loop` integrieren.
