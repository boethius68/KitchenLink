# KitchenLink Work Queue

**Stand:** 19. Juli 2026
**Phase:** Integrierte Sandbox mit oeffentlichem Gast-Web

Diese Queue enthaelt sowohl die abgeschlossene Aufbauhistorie als auch aktuelle
Arbeitspakete. Neue Tickets werden bis auf Weiteres nur von Claude Code oder
Codex in einem eigenen Branch oder Worktree uebernommen. Bestehende Demo-,
Offline- und Simulationspfade duerfen nicht entfernt werden.

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

### KL-OFFLINE-008 - Lokale Hub-Erkennung in der Business-App

**Status:** Discovery auf dem iPhone bestaetigt; Startoptimierung in Draft-PR
#29 implementiert und fuer einen kurzen Geraetevergleich installiert
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
