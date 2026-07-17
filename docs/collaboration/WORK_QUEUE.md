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

**Status:** Wartet auf Nutzer-Stack-Entscheidung; zwei konkurrierende Vorschlaege
**Abhaengigkeit:** semantische Token-Namen aus KL-DS-001

Zuerst den Web-Stack und den Deployment-Pfad als kleine Architecture Decision
festlegen. Danach eine mobile Gastkarte mit acht Gerichen, Venue-fuehrendem
Branding, traubenbasierter Mengensteuerung und genau einer fixierten
Zitronenaktion umsetzen. Noch keine Live-Zahlung und keine Entfernung der
Sandbox-Daten.

Hinweis: Neben der urspruenglichen Claude-Fable-5-Zuweisung hat GLM den Branch
`glm/guest-web-architecture` mit einem eigenen ADR (Next.js + Cloudflare Pages,
ueberarbeitet um einen autoritativen Order-Gate) gepusht. Beides sind Vorschlaege;
nur der Nutzer entscheidt den Stack.

## Parallele Runde 2 (Stand 17. Juli 2026, nach Integration von PR #9)

Die urspruengliche Rebase-Warnung ist ueberholt: Die Missionszweige wurden vor
Integrationsbeginn auf die PR-#4-Merge-Basis rebased. KL-QA-002 ist konfliktfrei
integriert; die verbleibenden Zweige brauchen weiterhin je ein unabhaengiges
Review in eigenem Scope.

### KL-OFFLINE-003 - Autoritatives Event-Log und Outbox

**Status:** Implementiert auf `glm/offline-event-log-v2`, nicht integriert
**Abhaengigkeit:** keine
**Schreibbereich:** `prototypes/KitchenLinkEventLog/`,
`docs/architecture/offline/EVENT_LOG_V2.md`, `handoffs/GLM.md`

Ausfuehrbarer Swift-/SQLite-Referenzprototyp. 27 Dateien, Schema, Outbox,
Transport, mindestens 20 Tests. Isoliertes Swift Package, kein App-Konflikt;
geringstes Rebase-Risiko.

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

**Status:** Implementiert auf `kimi/workforce-domain`, nicht integriert
**Abhaengigkeit:** keine
**Schreibbereich:** neue Dateien unter `Features/Workforce/`, fokussierte Tests,
Domain-Dokument, `handoffs/KIMI.md`

Isolierte Swift-Domaenengrundlage fuer Mitarbeiter, Verfuegbarkeit, Planung,
Zeiterfassung. 632 Zeilen Tests. Niedriges Rebase-Risiko (neue Dateien).

### KL-INVENTORY-001 - Warenwirtschafts-Domaene

**Status:** Nicht begonnen; kein Branch vorhanden
**Abhaengigkeit:** keine
**Schreibbereich:** neue Dateien unter `Features/Inventory/`, fokussierte Tests,
Domain-Dokument, `handoffs/MINIMAX.md`

Ein Branch `minimax/inventory-domain` existiert auf `origin` nicht (mehr); es
gibt keinen MiniMax-Commit und keine `Features/Inventory/`-Dateien. Die Mission
muss neu vergeben oder gestrichen werden.

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
6. Verbleibende Round-2-Zweige einzeln reviewen und integrieren:
   KL-OFFLINE-003 (PR #7), dann KL-WORKFORCE-001 (PR #8); danach
   KL-INVENTORY-001 neu vergeben oder streichen.
7. KL-WEB-001 erst nach Nutzervorgabe des Web-Stacks weiterverfolgen.
8. Erst nach stabilen Referenzscreens weitere Produktmodule migrieren.
