# Phase-1-Qualitätsgate für Speisekarten

Dieses Verzeichnis ist die feste Messlatte für den verlustfreien Import. Es
enthält zehn visuell geprüfte Seiten: drei synthetische Prüfküchen-Seiten sowie
sieben ausgewählte Seiten aus drei realen Testkarten.

`manifest.json` fixiert Seite, Dateipfad, Abmessungen und SHA-256. Die vier
Dokumentdateien enthalten die erwartete Menüstruktur. `policy.json` trennt
Qualitätsziele von harten Sicherheitsfehlern.

## Zwei Profile

`policy.json` trennt seit `1.3.0` zwei Schwellenprofile:

- **`launch`** ist der freigabewirksame Maßstab. Jeder Entwurf durchläuft einen
  verpflichtenden menschlichen Review (`MenuImportDraftReviewModel.canConvert`
  bleibt false, solange ein Eintrag offen ist). Gemessen wird deshalb, was der
  Review **nicht** reparieren kann — kein fehlender Eintrag, kein stiller
  Seitenverlust, kein erfundener Ernährungs-/Allergenclaim, kein ungültiger
  Entwurf — sowie ob jeder nötige Prüfhinweis tatsächlich gesetzt ist. Leitwert
  für den Aufwand ist `correctionsPerPage` (Budget 3,0).
- **`strict`** bleibt unverändert als Diagnose und Fernziel erhalten und ist
  ausdrücklich **nicht** zum Bestehen vorgesehen: es verlangt nahezu exakte
  semantische Wiederholbarkeit über Läufe, die ein gesampeltes Modell nicht
  liefern kann. Die Distanz zu messen ist nützlich, darauf zu gaten nicht.

Jeder Lauf berichtet beide Profile (`profileComparison` im JSON), ein späteres
Anziehen braucht also keinen zweiten Lauf. Profilwahl:

```sh
KITCHENLINK_QUALITY_PROFILE=strict scripts/run-menu-quality-gate.sh
```

Der lokale Lauf:

```sh
scripts/run-menu-quality-gate.sh
```

Er misst den aktuellen Stand und schreibt eine verständliche Zusammenfassung.
Mit `KITCHENLINK_QUALITY_ENFORCE=1` wird daraus ein blockierendes Gate.
Externe KI-Aufrufe finden nur statt, wenn der bestehende Review-Runner
ausdrücklich mit seiner LLM-Option gestartet wird.

Ein Release-Lauf besteht aus drei unabhängigen Wiederholungen:

```sh
KITCHENLINK_QUALITY_REPEAT_RUNS=3 \
KITCHENLINK_QUALITY_ENFORCE=1 \
scripts/run-menu-quality-gate.sh
```

Das Gate misst pro Karte und insgesamt Feldtreffer, allgemeine sichtbare
Hinweise samt Übersetzungen, fehlende und erfundene Einträge/Preise,
Seitenfehler, Evidenzabdeckung und Seitenlatenz. Es vergleicht bei mehreren
Reports außerdem die vollständige semantische Ausgabe paarweise; zufällig
erzeugte interne IDs und reine Laufzeitdaten zählen dabei nicht als
Inhaltsunterschied. Bereits vorhandene Reports können mit wiederholtem
`--report` direkt an `scripts/evaluate-menu-quality-gate.py` übergeben werden.

Die Release-Grenzen stehen versioniert in `policy.json`: Kein fehlender oder
erfundener Artikel, kein erfundener Preis, kein Deckseiten-Phantom, kein
stiller Seitenverlust und kein ungültiger Draft. Zusätzlich müssen alle
Seiten eine Laufzeitmessung besitzen, die Seitenfehlerrate null sein, die
P95-Seitenlatenz höchstens 60 Sekunden betragen und drei Läufe mindestens
98 Prozent exakte semantische Wiederholbarkeit erreichen.

## Annotationsregeln

- Seitenindizes sind nullbasiert und beziehen sich auf das vollständige
  Quelldokument.
- Schreibweise, Preistext, Übersetzungen und Quellcodes bleiben sichtbar
  erhalten. Es werden keine Allergenbedeutungen ohne sichtbare Legende ergänzt.
- Preislose Einträge bleiben Einträge und tragen `missing_visible_price`.
- Absolute Portions-/Variantenpreise sind `fixed`; sichtbare Zuschläge sind
  `delta`; enthaltene Auswahlmöglichkeiten sind `included`.
- Gangmenüs bleiben ein Bundle. Der Bundlepreis darf nicht auf Gänge kopiert
  werden.
- Sichtbare allgemeine Hinweise bleiben eigene Hinweise; vorhandene
  Übersetzungen werden als belegte Alternativen am selben Hinweis bewahrt.
- Deckseiten, Logos, Wasserzeichen und Marketingtexte sind keine Menüartikel.

Die realen Kartenbilder und Quell-PDFs sind ausschließlich interne
Test-Fix­tures. Diese Ground Truth ist keine Freigabe zur anderweitigen
Veröffentlichung oder Weiterverteilung.

## Ablauf kommender Prompt- oder Modellrunden

Jede Runde verändert genau eine begrenzte Hypothese. Danach wird der gesamte
Korpus neu importiert, deterministisch bewertet und in drei Läufen auf
Wiederholbarkeit geprüft. Eine davon getrennte Prüfpassage sucht anhand von
Originalbild und OCR-Belegen ausdrücklich nach fehlenden, doppelten,
unbelegten oder widersprüchlichen Elementen. Befunde werden als OCR-,
Vision/LLM-, Prompt-, Parser/Mapping-, Schema- oder Review/UI-Fehler
klassifiziert. Ein neuer echter Fehler wird vor der nächsten Änderung als
Ground-Truth-Erwartung oder reproduzierbarer Test ergänzt.
