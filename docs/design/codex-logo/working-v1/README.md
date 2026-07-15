# KitchenLink Logo - Working V1

**Status:** Favorisierte technische Arbeitsfassung, nicht final freigegeben
**Visuelle Referenz:** `../round-01/15-gastronomy-refinement.png`

## Idee

Das Zeichen bewahrt die vom Nutzer bevorzugte Grundidee:

- links die ruhige Betriebsseite
- rechts die offene, gastliche Seite
- dazwischen eine farbige Schale beziehungsweise Uebergabe
- eine weiche, kompakte Wortmarke ohne separate Produktuntermarke

Die Form wurde nicht neu interpretiert, sondern fuer echte Vektorausgabe,
Monochrom, Negativdarstellung und kleine Groessen rekonstruiert.

## Arbeitswerte

| Rolle | Wert | Status |
| --- | --- | --- |
| Ink | `#201813` | aus der Referenz angenaehert |
| Handoff | `#D7522B` | aus der Referenz angenaehert |
| Warm Light | `#FBF3EB` | nur Praesentations- und Negativwert |

Diese Werte reproduzieren den favorisierten Entwurf. Sie sind keine Freigabe der
spaeteren KitchenLink-Farbpalette.

Fuer die naechste Kontextpruefung ist Claude Designs Farbwelt `Zitrus` aus Turn
3b der bevorzugte Vergleich. Zitrone und Traube sind damit als Richtung gesetzt,
aber weder ihre exakten Werte noch ihre Rollen im Logo und Produkt sind final.

## Wortmarke

Die Arbeitswortmarke basiert auf **Nunito Variable, Gewicht 750**. Nunito dient
als frei lizenzierbare Ausgangsgeometrie und liegt unter der SIL Open Font License
1.1. Die Lizenz und Fontdatei sind in `fonts/` gesichert. Die sichtbaren
Wortmarken-SVGs enthalten bereits Vektorpfade und benoetigen keine installierte
Schrift.

Vor einer finalen Markenfreigabe stehen weiterhin aus:

- optische Eigenanpassung charakteristischer Buchstaben und Abstaende
- Marken- und Aehnlichkeitspruefung
- finale Farbentscheidung
- Freigabe durch den Nutzer

## Dateien

- `kitchenlink-symbol.svg`: farbiges Zeichen
- `kitchenlink-symbol-mono.svg`: einfarbiges Zeichen
- `kitchenlink-symbol-reverse.svg`: Zeichen fuer dunkle Flaechen
- `kitchenlink-wordmark.svg`: Wortmarke als Pfade
- `kitchenlink-lockup.svg`: selbststaendiger horizontaler Farb-Lockup
- `kitchenlink-lockup-mono.svg`: selbststaendiger Monochrom-Lockup
- `kitchenlink-lockup-reverse.svg`: selbststaendiger Negativ-Lockup
- `kitchenlink-app-icon.svg`: Arbeitsfassung des App-Icons
- `technical-board.svg` und `technical-board.png`: Vergleich und Kleinpruefung

## Reproduzierbarkeit

Die Wortmarkenpfade werden mit HarfBuzz erzeugt:

```bash
hb-view fonts/Nunito-Variable.ttf KitchenLink \
  --font-size=1000 --variations='wght=750' \
  --background=none --foreground=201813 --margin=0 --ink \
  --output-format=svg --output-file=kitchenlink-wordmark.svg

python3 build_lockups.py
rsvg-convert -w 1600 -h 1120 technical-board.svg -o technical-board.png
```

Das bestehende App-Icon im Produkt wird durch diesen Arbeitsstand noch nicht
ersetzt.
