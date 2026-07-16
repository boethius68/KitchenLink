# Handoff — DeepSeek (KL-MENU-001, Red-Team v2)

**Datum:** 2026-07-16
**Agent:** DeepSeek-V4-Pro (Red-Team-Instanz)
**Ticket:** `docs/discovery/MENU_TAXONOMY_RESEARCH_TICKET.md` (KL-MENU-001)
**Status:** Gegencheck v0.2.0 abgeschlossen; 9/16 Ursprungs-Findings geschlossen

## Was in dieser Session erledigt wurde

Red-Team Review des aktualisierten GLM-Stands (F03b–F03f, v0.2.0):

### Geprüft & validiert
- GLM hat meine 16 ursprünglichen Findings systematisch abgearbeitet.
- **9 von 16 Findings sind geschlossen** (u.a. if/then-Constraints, preModifier, choiceKind-Abgrenzung, BundleComponent, Facet-Inheritance, per_unit→grundpreis, Sättigungstest).
- Alle Patches P-01…P-06 aus dem ersten Audit sind korrekt umgesetzt.
- Schema if/then mit 7 Negativtests validiert.
- Stichprobe auf 59 Quellen / 55 Pattern / 9 tiefe Karten erweitert.

### Kritische Inkonsistenzen gefixt (v0.2 → v0.2.1)

| Problem | Fundort | Fix |
|---|---|---|
| Ontologie hatte noch `per_unit` in `priceKind` | menu_ontology_v0.1.yaml:188 | Entfernt, Exclusion-Regel ergänzt |
| Ontologie header sagte `deepSampleSize: 6` | menu_ontology_v0.1.yaml:19 | Auf 9 aktualisiert |
| Research Report §2 zeigte alte Zahlen (38/16/6) | research_report.md §2 | Auf 59/27/9 aktualisiert |

### Neue Findings (v0.2)

7 neue Findings identifiziert (F-17…F-23):
- F-17 (🟠) Ontologie/Schema per_unit-Inkonsistenz → **gefixt**
- F-18 (🟠) Veraltete Report-Zahlen → **gefixt**
- F-19 (🟠) Header deepSampleSize → **gefixt**
- F-20 (🟡) Versionitis Dateiname vs. Inhalt
- F-21 (🟡) saturation_test.md nicht auf 12 Karten aktualisiert
- F-22 (🟡) Kein GC für weight/from/per_person
- F-23 (🔵) PE-028/030 noch theoretical

### Offene Blocking Issues
- **F-01** (🔴): 9/150 tiefe Karten – Ontologie bleibt Hypothese
- **F-02** (🔴): 0/59 reusable – kein Benchmark baubar
- **F-08** (🟠): 8/35 Golden Cases noch theoretical

## Veränderte Dateien (diese Session)

- `docs/discovery/taxonomy-research/audit_report.md` (komplett neu: v2)
- `docs/discovery/taxonomy-research/menu_ontology_v0.1.yaml` (per_unit entfernt, deepSampleSize korrigiert)
- `docs/discovery/taxonomy-research/research_report.md` (§2 Zahlen aktualisiert)
- `docs/collaboration/handoffs/DEEPSEEK.md` (dieses Update)

## Empfohlener nächster Schritt

1. **Weitere Stichprobe** in Richtung ≥100 Karten (F03 fortsetzen)
2. **Rechteklärung** für ≥20 reusable-Quellen (oder interne Testfotos, Ticket Zeile 138)
3. **saturation_test.md** auf die tatsächliche Kartenzahl (12+) aktualisieren
4. **Golden Cases erweitern** (GC36–GC40 aus Brechts/Cocina Argentina)
5. **Versionitis bereinigen** (Dateinamen bei nächstem Bump angleichen)

## Schreibbereich & Kollisionsfreiheit

- Nur Dateien unter `docs/discovery/taxonomy-research/` + Handoff geändert.
- Kein Produkt-Code; keine bestehenden uncommitteten Änderungen berührt.
- Keine Entscheidung in `DECISIONS.md` oder `CURRENT.md`.
