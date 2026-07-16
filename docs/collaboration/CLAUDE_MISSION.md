# Claude Code Mission

**Stand:** 16. Juli 2026
**Zielbranch:** `codex/claude-design-audit`
**Arbeitsweise:** Zwei getrennte Phasen mit Review-Gate

Claude Code erhaelt Zugriff auf das vollstaendige Repository in einem eigenen
Git-Worktree. Produktcode darf nicht gleichzeitig im Integrations-Worktree
bearbeitet werden. Die bestehende Sandbox, Demo-Fixtures, Offline-Simulation und
der Legacy-Startpfad bleiben erhalten.

## Verbindliche Quellen

Vor jeder Phase in dieser Reihenfolge lesen:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/collaboration/CURRENT.md`
4. `docs/collaboration/DECISIONS.md`
5. `docs/PRODUCT_BLUEPRINT.md`
6. `docs/collaboration/handoffs/CODEX.md`
7. `docs/design/DESIGN_SYSTEM.md`
8. `docs/design/claude-design/round-04/REVIEW.md`
9. `docs/collaboration/WORK_QUEUE.md`

Designboards sind Referenz, aber keine zusaetzliche Produktfreigabe. Die
freigegebenen Entscheidungen in `DECISIONS.md` haben Vorrang.

## Phase A: Unabhaengiges Audit

### Auftrag

Den integrierten Stand ab Commit `03c146a` bis zum aktuellen Branch-HEAD als
Senior-Code-, Produkt- und Designsystem-Review pruefen. Nicht nur Dokumente
zusammenfassen, sondern Implementierung, Tests und sichtbares App-Verhalten
unabhaengig verifizieren.

Besonders pruefen:

- Datenverlust, falsche Preissemantik oder erfundene Evidenz in
  `MenuImportDraft`, `MenuImportDraftAdapter` und der dualen Scanner-Pipeline.
- Rueckwaertskompatibilitaet des Legacy-Sandbox-Imports und der Demo-Fixtures.
- Architekturgrenzen, Nebenlaeufigkeit, Fehlerpfade und testbare Schnittstellen.
- Uebereinstimmung von SwiftUI-V2 mit Round 04 und `DESIGN_SYSTEM.md`, speziell
  Zitronenregel, Statusachsen, Kontrast, Touch-Ziele und Dynamic Type.
- Startpfade fuer V2 und Legacy sowie offensichtliche UI- oder
  Accessibility-Regressionen.
- Reproduzierbarkeit und Aussagekraft von Unit-, UI- und Scanner-Benchmarktests.

### Erlaubter Schreibbereich

- `docs/collaboration/reviews/CLAUDE_AUDIT_2026-07-16.md`
- `docs/collaboration/handoffs/CLAUDE.md`

In Phase A keine Produktcode-, Test-, Design-, Entscheidungs- oder
Blueprint-Datei veraendern. Keine gefundenen Probleme nebenbei reparieren.

### Ergebnisformat

Findings zuerst, nach `P0` bis `P3` sortiert, jeweils mit:

- konkreter Datei und Zeile
- beobachtbarem Risiko oder fehlerhaftem Verhalten
- Reproduktions- oder Belegweg
- kleinstmoeglicher belastbarer Korrektur

Danach separat:

- verifizierte Staerken
- ausgefuehrte Befehle und Testergebnisse
- visuell gepruefte Geraete, Farbschemata und Dynamic-Type-Stufen
- Restunsicherheiten
- Empfehlung, ob Phase B ohne Vorfix beginnen kann

Wenn keine Findings bestehen, das ausdruecklich sagen und verbleibende
Testluecken benennen. Das Audit als eigenen Commit abschliessen. Nicht pushen.

## Review-Gate

Nach Phase A stoppen. Codex wertet den Audit-Commit aus. Phase B beginnt erst
nach einer ausdruecklichen Folgeanweisung im selben Claude-Worktree. P0- oder
P1-Findings werden vor der Designumsetzung entschieden oder behoben.

## Phase B: Round-04-Design umsetzen

### Ziel

Die von Claude Design erarbeitete Round-04-Richtung als zwei echte, testbare
Referenzbereiche in KitchenLink Business umsetzen:

- iPhone `Heute`: ereignisorientierte Arbeitsliste mit naechsten Handlungen
- iPad `Kueche`: sechs gleichzeitig lesbare Tickets ohne horizontales Scrollen

Beide Bereiche verwenden bestehende Sandbox-Daten und das zweiachsige
Statusmodell. Sie sind keine statischen Bildkopien des Boards.

### Voraussichtlicher Schreibbereich

- neue Dateien unter `kitchenlink/Features/Today/`
- neue Dateien unter `kitchenlink/Features/Kitchen/`
- gezielte Navigation in `kitchenlink/App/`
- notwendige, begrenzte Erweiterungen in
  `kitchenlink/DesignSystem/KitchenLinkDesignSystemV2.swift`
- gezielte Tests in `kitchenlinkTests/` und `kitchenlinkUITests/`
- `docs/collaboration/handoffs/CLAUDE.md`

Scanner-Domain und `MenuImportDraft` sind ausserhalb dieses Schreibbereichs.
Audit-Fixes dort werden getrennt beauftragt und committed.

### Funktionale Grenzen

- Vorhandene `KitchenLinkStore`-/Repository-Sandboxdaten nutzen; keine zweite,
  konkurrierende Bestell-Domain einfuehren.
- V2 und Legacy bleiben per Launch-Argument und sichtbarer Navigation erreichbar.
- Kein Supabase-Umbau, keine Produktionspersistenz, keine Live-Zahlung und kein
  Deployment.
- Zitrone nur fuer eine Primaeraktion oder kurzen Uebergabemoment verwenden,
  niemals fuer Status.
- Vorgangsart bleibt Form, Dringlichkeit bleibt Farbe, Klartext bleibt sichtbar.
- Touch-Ziele mindestens 44 Punkt; Dynamic Type und Reduce Motion respektieren.
- Helle und dunkle Darstellung muessen funktionieren.

### Abnahme

- Heute zeigt mindestens Bestellung, wartende Aufgabe, neutrale offene Zahlung
  und Offline-/Sync-Zustand aus Sandboxdaten.
- Kueche zeigt auf einem iPad sechs Tickets mit Zeit, Tisch, Zustand,
  Aenderung/Offline-Fall und wichtigsten Positionen gleichzeitig.
- Status und Aktionen besitzen stabile Accessibility-IDs und aussagekraeftige
  Labels.
- Unit-Tests, V2-/Legacy-UI-Smokes und der Scanner-Benchmark bleiben erfolgreich.
- Mindestens je ein visueller Check auf iPhone hell/dunkel und iPad dunkel wird
  im Handoff dokumentiert.
- Phase B endet in einem eigenen Commit und wird nicht gepusht.
