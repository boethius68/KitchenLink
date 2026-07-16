# Claude App Start

**Modell:** Claude Fable 5
**Projektordner:** `/Users/test/Developments/kitchenlink-claude`
**Branch:** `claude/design-audit`

Dieser Ordner ist ein eigener Git-Worktree mit dem vollstaendigen, auf GitHub
gesicherten KitchenLink-Stand. Codex und Claude bearbeiten dadurch nicht
gleichzeitig denselben Arbeitsbaum.

## In der Claude-App verbinden

1. In Claude den Bereich fuer Code beziehungsweise lokale Projekte oeffnen.
2. `Open Folder`, `Add Project` oder die entsprechende Projektaktion waehlen.
3. Den Ordner `/Users/test/Developments/kitchenlink-claude` auswaehlen.
4. Im Modellwaehler `Claude Fable 5` einstellen.
5. Datei- und Terminalzugriff fuer genau diesen Projektordner erlauben. Keine
   zusaetzlichen uebergeordneten Verzeichnisse freigeben.
6. Claude vor dem ersten Auftrag den aktiven Branch und `git status` anzeigen
   lassen. Erwartet werden `claude/design-audit` und ein sauberer Status.

## Erster Auftrag: Audit

```text
Lies AGENTS.md, CLAUDE.md und docs/collaboration/CLAUDE_MISSION.md. Fuehre jetzt
ausschliesslich Phase A exakt aus. Pruefe Code, Tests und sichtbares
App-Verhalten unabhaengig. Veraendere keinen Produktcode und keine Tests.
Schreibe nur den Auditbericht und deinen CLAUDE-Handoff, committe diese beiden
Ergebnisse auf dem aktuellen Branch, pushe den Branch und erstelle einen Draft
Pull Request gegen main. Bei P0/P1 stoppe und lege mir Befund und Vorschlag vor.
Codex-Freigabe ist nicht erforderlich.
```

Das Ergebnis liegt danach in
`docs/collaboration/reviews/CLAUDE_AUDIT_2026-07-16.md`. P0- oder P1-Findings
werden vor der Designumsetzung behandelt.

## Zweiter Auftrag: Designumsetzung

Nur starten, wenn das Audit Phase B ausdruecklich ohne Vorfix empfiehlt oder die
blockierenden Findings bereits behoben sind.

```text
Lies erneut docs/collaboration/CLAUDE_MISSION.md und deinen Auditbericht. Das
Ich habe das Audit geprueft. Fuehre Phase B fuer KL-OPS-001 vollstaendig aus:
Heute auf dem iPhone und Kueche auf dem iPad als echte Round-04-Referenzbereiche
mit bestehenden Sandboxdaten, Tests und visueller Pruefung. Halte den dort
definierten Schreibbereich und alle Produktgrenzen ein. Committe Phase B separat,
pushe den Claude-Branch, aktualisiere den Draft Pull Request und aktualisiere am
Ende docs/collaboration/handoffs/CLAUDE.md. Warte vor dem Merge auf meine
visuelle Freigabe; eine Freigabe durch Codex ist nicht erforderlich.
```

## Unabhaengig weiterarbeiten

- Claude liest `CLAUDE.md` und die verbindlichen Projektdokumente im Repository.
- Alle Auftraege, Grenzen und Abnahmekriterien stehen in
  `docs/collaboration/CLAUDE_MISSION.md`.
- Claude aktualisiert ausschliesslich seinen eigenen Handoff.
- Vor einem neuen Arbeitsblock immer `git status` und den aktiven Branch pruefen.
- Claude darf nach denselben Regeln wie Codex planen, implementieren, reviewen,
  pushen und integrieren.
- Nicht direkt auf `main` arbeiten und Produkt- oder Designaenderungen nicht ohne
  Nutzerfreigabe nach `main` mergen.
