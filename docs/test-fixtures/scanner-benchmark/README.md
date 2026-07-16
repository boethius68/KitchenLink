# Scanner Benchmark Gold-Baseline

Diese Baseline ist eine kleine, manuell prüfbare Ankersammlung für Regressionen
in OCR, Layoutanalyse und Menüparsern. Sie ist bewusst keine vollständige
Transkription der drei Speisekarten.

## Methode

1. Die Quellen und erwarteten Seitenzahlen wurden mit
   [`../DEMO_MENUS.md`](../DEMO_MENUS.md) abgeglichen.
2. `pdfinfo` bestätigte 3, 7 und 4 Seiten. SHA-256-Hashes binden die Baseline an
   die konkret geprüften PDF-Dateien.
3. Der vorhandene Textlayer wurde mit `pdftotext -layout` für jede Seite separat
   extrahiert.
4. Alle 14 Seiten wurden mit `pdftoppm -png -r 120` gerendert und visuell gegen
   Abschnittstitel, Artikelnamen, Preiszuordnung, Claims, Codes und Hinweise
   geprüft. Bei Abweichungen ist die gerenderte PDF-Seite maßgeblich, nicht die
   lineare Textreihenfolge.
5. Ausgewählt wurden stabile Anker über möglichst viele Seiten und gezielte
   schwere Fälle. Nicht sichtbare Allergene, Zusatzstoffe, Zutatenbedeutungen
   oder Farbcodes wurden nicht ergänzt.

Die Seitenangaben sind 1-basiert. `exactName`, `exactTitle` und `exactText`
bewahren sichtbare Schreibweise und Interpunktion; lediglich visuelle
Zeilenumbrüche innerhalb eines Namens oder Titels werden zusammengezogen.
`normalizedName` und `normalizedTitle` verwenden Unicode NFC, reduzieren
Whitespace und schreiben klein. Sie korrigieren weder Schreibfehler noch
Bindestriche und entfernen keine Diakritika.

`expectedPriceString` bildet den sichtbaren Preistoken ab. Ein Eurozeichen wird
nur aufgenommen, wenn es dort gedruckt ist. `expectedPriceCents` ist der dazu
gehörige ganzzahlige Centwert. Die drei Dokumente belegen Euro als Währung
jeweils an anderer Stelle ausdrücklich.

## Grenzen

- Die Baseline misst repräsentative Anker, nicht Vollständigkeit aller Artikel,
  Beschreibungen oder Übersetzungen.
- Sie enthält keine Bounding Boxes, OCR-Confidence, Taxonomiezuordnung oder
  kanonische Auflösung lokaler Deklarationscodes.
- Deklarationen werden nur bei sichtbarem Text verankert. Farbe allein ist ohne
  Legende kein Claim; Scheunes Buchstabencodes bleiben ohne vorhandene Legende
  bewusst unaufgelöst.
- Mehrfachpreise, Aufschläge, Bundles und fehlende Preise stehen unter
  `knownHardCases`. Ein einfacher Ankertest darf diese Beziehungen nicht zu
  Einzelartikeln oder festen Basispreisen vereinfachen.
- Laut [`../DEMO_MENUS.md`](../DEMO_MENUS.md) sind die PDFs ausschließlich für
  interne Tests vorgesehen und vor öffentlicher Veröffentlichung zu entfernen
  oder rechtlich freizugeben.

## Abdeckung

| Fixture | geprüfte Seiten | Abschnittsanker | Artikelanker | Seiten mit Artikelankern | Deklarationsanker | schwere Fälle |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| `scheune-berlin` | 3 | 4 | 15 | 1-3 | 5 | 6 |
| `lichtburg-berlin` | 7 | 12 | 16 | 1-7 | 5 | 7 |
| `alexxanders-chemnitz` | 4 | 7 | 15 | 2-4; Seite 1 ist Cover | 3 | 7 |
| **Gesamt** | **14** | **23** | **46** |  | **13** | **20** |

Die Auswahl deckt dekorativ getrennte Überschriften, mehrsprachige Blöcke,
absolute Variantenpreise, relative Aufschläge, Pro-Person-Bundles, separate
Beilagen, explizite Dietary-Claims, unaufgelöste Codes, einen Allergenhinweis
ohne Einzelliste und einen sichtbar preislosen Artikel ab.

## Ausfuehrung

Der Benchmark nutzt Apple Vision und ausschliesslich die lokalen Parserregeln.
Ein konfigurierter LLM-Zugang wird fuer diesen Lauf bewusst nicht verwendet.
Er prueft zwei Ergebnisse aus demselben OCR-Lauf getrennt:

- den weiterhin aktiven, preisgebundenen `[MenuSectionData]`-Sandbox-Pfad;
- den verlustarmen `MenuImportDraft` mit Seite, Bounding Box, Rohpreis und
  Review-Warnungen.

```bash
scripts/run-scanner-benchmark.sh
```

Mit `KITCHENLINK_BENCHMARK_DESTINATION` kann ein bestimmter Simulator gesetzt
werden. Der Lauf baut die App, startet nur den OCR-Benchmarktest, exportiert den
JSON-Anhang und vergleicht ihn mit `gold-baseline.json` und `thresholds.json`.
Die generierten Berichte liegen standardmaessig unter
`/tmp/kitchenlink-scanner-benchmark/` und werden nicht eingecheckt.

Die Draft-Metriken messen Namen und Preis auf der erwarteten Quellseite. Der
Benchmark verlangt ausserdem explizit, dass `Haehnchenbrustfilet "Pfeffer"`,
`Gegrillte Garnelen` und der sichtbar preislose `Gemischter Eisbecher` im Draft
erhalten bleiben, ohne einen Nachbarpreis zu uebernehmen.

Die Schwellen sind als Regressionsgrenzen knapp unter dem gemessenen
Referenzstand gesetzt. Sie sind keine Produktfreigabe und ersetzen keine
vollstaendige semantische Pruefung. Der aktuelle Befund steht in
[`CURRENT_RESULTS.md`](CURRENT_RESULTS.md).
