# Scanner-Demo-Karten

Diese Karten sind lokale Entwicklungs-Fixtures für die KitchenLink-Sandbox. Sie
werden nicht als Produktionsinhalt verwendet. Die App rendert die Seiten als
PNG-Ressourcen und führt sie durch denselben OCR-, Review- und Importpfad wie
echte Fotos.

## Auswahl in der App

Der Import-Einstieg bietet bewusst genau drei komplementäre Karten:

| Fixture | Seiten | Zweck | Abdeckung |
| --- | ---: | --- | --- |
| KitchenLink Prüfküche | 3 | deterministische Vollabdeckung | Kategorien, Beschreibungen, Speisen/Getränke, Allergene, Zusatzstoffe, Varianten/Extras, Gangmenü und Preis pro Person |
| Lichtburg Berlin | 7 | reale schwierige Karte | dichtes und zweisprachiges Layout, Varianten und Set-Menüs |
| Alexxanders Chemnitz | 4 | reale schwierige Karte | dichte Saisonkarte, Kategorien, Varianten und Set-Menüs |

Die Prüfküche wird reproduzierbar mit
`scripts/generate_demo_test_menu.py` erzeugt. Ihre erwartete Struktur und
Anker stehen in `kitchenlink-pruefkueche-truth.json`. Damit können neue
Importfelder gezielt getestet werden, ohne von einer extern veränderlichen
Restaurantkarte abzuhängen.

Die historische Gold-Baseline bleibt davon getrennt und unverändert: Scheune,
Lichtburg und Alexxanders bilden weiterhin die bekannten 14 Seiten mit ihren
bestehenden Regressionsschwellen ab. Der menschliche Batch-Review enthält
zusätzlich die KitchenLink-Prüfküche.

## Quellen

Die PDFs wurden am 16.07.2026 von den offiziellen Speisekarten-Seiten geladen:

| Fixture | Seiten | Offizielle Quelle | PDF-Datei |
| --- | ---: | --- | --- |
| Scheune Berlin | 3 | https://scheune-restaurant.de/pages/karte | `menus/scheune-berlin.pdf` |
| Lichtburg Berlin | 7 | https://www.restaurant-lichtburg.de/essen-trinken/speise-karte/ | `menus/lichtburg-berlin.pdf` |
| Alexxanders Chemnitz | 4 | https://www.alexxanders.de/de/restaurant/speisen/speisekarte.html | `menus/alexxanders-chemnitz.pdf` |

Die extern bezogenen Dateien und gerenderten PNGs sind ausschließlich für
interne Tests gedacht.
Vor einer öffentlichen Veröffentlichung müssen sie entfernt oder mit den
jeweiligen Betreibern rechtlich freigegeben werden.
