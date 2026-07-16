# KitchenLink Work Queue

**Stand:** 16. Juli 2026
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

**Status:** Erledigt; PR #1 nach `main` gemergt
**Abhaengigkeit:** Checkpoint des integrierten Scanner-/Draft-Stands
**Schreibbereich:** `docs/collaboration/reviews/` und
`docs/collaboration/handoffs/CLAUDE.md`

Claude prueft den gesamten Stand seit `03c146a` unabhaengig auf Code-, Daten-,
Test-, Accessibility- und Designsystemprobleme. Produktcode bleibt waehrend des
Audits unveraendert. Der vollstaendige Auftrag und das anschliessende Review-Gate
stehen in `docs/collaboration/CLAUDE_MISSION.md`.

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

**Status:** In Review
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
Dynamic-Type-Pruefung sind erledigt. Offen bleibt ein lokaler End-to-End-Test vom
Gastauftrag bis zum Kuechenstatus ohne Cloudverbindung.

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

**Status:** Aktiv bei Claude Fable 5
**Abhaengigkeit:** KL-MENU-003
**Voraussichtlicher Schreibbereich:** `kitchenlink/Features/MenuImport/` und
gezielte UI-/Adaptertests

Draft-Sektionen und -Eintraege mit Originalseitenausschnitt, Rohtext,
Preiszustand und Review-Grund anzeigen. Preislose und strukturell unsichere
Kandidaten muessen korrigiert, umsortiert oder verworfen werden koennen, bevor
eine explizite Konvertierung in das bestehende Sandbox-Menue erfolgt. Keine
automatische Freigabe und keine Produktionspersistenz.

## Naechste parallele Scheiben

### KL-OPS-001 - Heute und Kueche

**Status:** Erledigt; PR #1 nach `main` gemergt
**Abhaengigkeit:** KL-DS-001, KL-IOS-001
**Voraussichtlicher Schreibbereich:** neue Views unter `kitchenlink/Features/Today/`
und `kitchenlink/Features/Kitchen/`

Ereignisorientiertes `Heute` und eine iPad-Kuechenansicht mit sechs gleichzeitig
lesbaren Tickets bauen. Beide verwenden echte Sandbox-Daten und das zweiachsige
Statusmodell. Kein Umbau der Bestell-Domain in diesem Ticket.

### KL-WEB-001 - Gast-Web-Grundlage

**Status:** Stack-Entscheidung aktiv bei Claude Fable 5
**Abhaengigkeit:** semantische Token-Namen aus KL-DS-001

Zuerst den Web-Stack und den Deployment-Pfad als kleine Architecture Decision
festlegen. Danach eine mobile Gastkarte mit acht Gerichten, Venue-fuehrendem
Branding, traubenbasierter Mengensteuerung und genau einer fixierten
Zitronenaktion umsetzen. Noch keine Live-Zahlung und keine Entfernung der
Sandbox-Daten.

## Parallele Runde 2

Die vollstaendigen Missionen und kopierfertigen Prompts stehen in
`docs/collaboration/PARALLEL_MISSIONS_2026-07-16.md`.

### KL-OFFLINE-003 - Autoritatives Event-Log und Outbox

**Status:** Vergeben an GLM 5.2
**Branch:** `glm/offline-event-log-v2`
**Schreibbereich:** `prototypes/KitchenLinkEventLog/`,
`docs/architecture/offline/EVENT_LOG_V2.md`, `handoffs/GLM.md`

Ausfuehrbarer Swift-/SQLite-Referenzprototyp mit transaktionaler Idempotenz,
Payload-Version, Aggregate-Revision, lease-basierter Outbox, ACK-Vertrag,
Fehler-Injektion und mindestens 20 Tests. Keine Integration in die App.

### KL-QA-002 - Lokaler Bestell-E2E-Smoke

**Status:** Vergeben an DeepSeek
**Branch:** `deepseek/offline-e2e-smoke`
**Schreibbereich:** neue Offline-Test-/Supportdateien, Testplan,
`handoffs/DEEPSEEK.md`

Zwei Relay-/Repository-Instanzen pruefen Gastauftrag, Owner-Empfang, komplette
Statuskette, Gast-Tracking, ungueltige Uebergaenge und Neustartpersistenz ohne
Cloud. Der Test darf nicht als echter Venue-Hub-Nachweis ausgegeben werden.

### KL-WORKFORCE-001 - Schichtplan-Domaene

**Status:** Vergeben an Kimi
**Branch:** `kimi/workforce-domain`
**Schreibbereich:** neue Dateien unter `Features/Workforce/`, fokussierte Tests,
Domain-Dokument und `handoffs/KIMI.md`

Isolierte Domaenengrundlage fuer Mitarbeiter, Verfuegbarkeit, Planung,
Veroeffentlichung, Reaktionen, Tauschanfragen, Sollbesetzung, Zeiterfassung,
Pausen und Korrekturaudit mit mindestens 25 Tests. Keine UI oder Persistenz.

### KL-INVENTORY-001 - Warenwirtschafts-Domaene

**Status:** Vergeben an MiniMax
**Branch:** `minimax/inventory-domain`
**Schreibbereich:** neue Dateien unter `Features/Inventory/`, fokussierte Tests,
Domain-Dokument und `handoffs/MINIMAX.md`

Dimensionssichere Mengen, Rezepte, append-only Bestandsledger, Idempotenz,
Reservierung, Transfers, Gegenbuchungen, Projektion und Bestellvorschlaege mit
mindestens 25 Tests. Keine UI oder Persistenz.

## Integrationsreihenfolge

1. KL-CLAUDE-001 unabhaengig ausfuehren und Findings bewerten.
2. P0-/P1-Findings vor neuer Oberflaechenarbeit entscheiden oder beheben.
3. KL-OPS-001 im Claude-Worktree als Round-04-Referenz umsetzen.
4. KL-MENU-004 und die Web-Stack-Entscheidung in getrennten Claude-Scopes
   fortsetzen.
5. KL-OFFLINE-003, KL-QA-002, KL-WORKFORCE-001 und KL-INVENTORY-001 in den
   dokumentierten disjunkten Worktrees bearbeiten.
6. Jedes Ergebnis einzeln reviewen; Discovery oder Prototypen werden nicht durch
   ihre Existenz zur Produktentscheidung.
