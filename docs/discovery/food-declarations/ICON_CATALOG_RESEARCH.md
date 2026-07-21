# Recherchebasis: Icons für Allergene und Zusatzstoffhinweise

**Stand:** 22. Juli 2026
**Geltungsbereich:** deutsche Gastronomie, lose Ware und digitale Gastkarte

## Ergebnis in Kürze

Es gibt zwei grundverschiedene Mengen, die in Speisekarten häufig unter
„Allergene & Zusatzstoffe“ zusammengefasst werden:

1. **14 EU-Hauptallergene.** Diese Liste ist vollständig und stabil in
   Anhang II der Verordnung (EU) Nr. 1169/2011 definiert.
2. **Lebensmittelzusatzstoffe.** Die EU-Positivliste enthält sehr viele
   einzelne Stoffe und wird fortgeschrieben. Für lose Ware schreibt § 5 LMZDV
   deshalb keine universelle Nummernlegende vor, sondern bestimmte
   verbraucherverständliche Angaben wie „mit Farbstoff“ oder
   „mit Konservierungsstoff“.

Die häufig auf Speisekarten verwendeten Buchstaben und Zahlen sind somit
**Quellencodes des jeweiligen Betriebs, kein europa- oder deutschlandweit
einheitlicher Standard**. KitchenLink bewahrt sie beim Import, löst ihre
Bedeutung aber gegen die erkannte Kartenlegende auf. Ein Icon ergänzt immer
den Klartext und ersetzt ihn nicht.

## Vollständige Kollektion der EU-Hauptallergene

| App-Code | Pflichtgruppe nach Anhang II | Piktogramm |
| --- | --- | --- |
| a | Glutenhaltiges Getreide, insbesondere Weizen, Roggen, Gerste und Hafer | Ähre |
| b | Krebstiere | Garnele |
| c | Eier | Ei mit Dotter |
| d | Fisch | Fisch |
| e | Erdnüsse | Erdnussschale |
| f | Sojabohnen | Sojaschote |
| g | Milch einschließlich Laktose | Milchkarton |
| h | Schalenfrüchte/Nüsse | Nuss |
| i | Sellerie | Selleriestangen |
| j | Senf | Senfglas |
| k | Sesamsamen | drei Samen |
| l | Schwefeldioxid und Sulfite über dem gesetzlichen Schwellenwert | SO₂ |
| m | Lupinen | Lupinenblüte |
| n | Weichtiere | Muschelschale |

Knoblauch und Zwiebeln gehören nicht zu diesen 14 Hauptallergenen. Importierte
Hauscodes dafür bleiben möglich, werden aber nicht mehr als gesetzlicher
Standard angeboten.

## Vollständige Kollektion der einschlägigen Angaben für lose Ware

Die Standardauswahl bildet die in § 5 LMZDV genannten Angabefälle ab:

| Interner semantischer Code | Anzeige |
| --- | --- |
| `farbstoff` | mit Farbstoff |
| `konserviert` | mit Konservierungsstoff / konserviert |
| `antioxidationsmittel` | mit Antioxidationsmittel |
| `nitritpoekelsalz` | mit Nitritpökelsalz |
| `nitrat` | mit Nitrat |
| `nitritundnitrat` | mit Nitritpökelsalz und Nitrat |
| `geschmacksverstaerker` | mit Geschmacksverstärker |
| `geschwaerzt` | geschwärzt |
| `gewachst` | gewachst |
| `phosphat` | mit Phosphat |
| `suessungsmittel` | mit Süßungsmittel(n) |
| `tafelsuesse` | auf der Grundlage von … |
| `phenylalanin` | enthält eine Phenylalaninquelle |
| `polyole` | kann bei übermäßigem Verzehr abführend wirken |

Hinzu kommen getrennte **weitere Verbraucherhinweise**, insbesondere
`chininhaltig` nach § 5 AromenDV sowie die einschlägigen Hinweise für erhöhten
Koffeingehalt und Lakritz aus Anhang III der LMIV. Diese sind keine Allergene
und werden deshalb in einer eigenen Gruppe angezeigt.

Die vollständige Liste der einzelnen zugelassenen E-Nummern wird bewusst nicht
hart in die App kopiert: Sie ist eine fortgeschriebene Positivliste mit
Verwendungsbedingungen. KitchenLink kann einen konkreten `E…`-Code kompakt mit
einem neutralen E-Piktogramm darstellen; die konkrete Kartenlegende bleibt für
die Bedeutung maßgeblich.

## Priorität und Erkennbarkeit

Ein lokaler Lauf über die 17-seitige semantische Testkarte ergab als häufigste
Quellencodes: Gluten 24, Milch 23, Ei 15, Senf 5, Sellerie 4 und Fisch 4.
Deshalb sind Ähre, Milchkarton und Ei die visuell stärksten und konkretesten
Formen. Danach folgen eindeutige Lebensmittel-Silhouetten für Nüsse,
Erdnüsse, Fisch, Soja, Senf, Sellerie und Sesam.

Gestaltungsregeln:

- einfarbige, skalierbare Linien-/Flächenpiktogramme statt Rasterbilder;
- eine gemeinsame quadratische Grundfläche für ruhige, kompakte Zeilen;
- keine Information nur über Farbe;
- der Quellencode bleibt klein sichtbar, sofern er kurz genug ist;
- jedes Piktogramm ist ein eigenes Bedienelement mit zugänglichem Namen;
- Tippen öffnet Klartext, Gruppe, Quellencode und eine kurze Erläuterung;
- eine Gesamtlegende bleibt für Artikel mit vielen Kennzeichnungen verfügbar.

## Primärquellen

- [Verordnung (EU) Nr. 1169/2011, insbesondere Art. 9, Art. 14, Anhang II und III](https://eur-lex.europa.eu/eli/reg/2011/1169)
- [§ 5 Lebensmittelinformations-Durchführungsverordnung (LMZDV)](https://www.gesetze-im-internet.de/lmzdv/__5.html)
- [§ 5 Aromenverordnung (AromenDV)](https://www.gesetze-im-internet.de/aromendv/__5.html)
- [EU-Kommission: Food additives](https://food.ec.europa.eu/food-safety/food-improvement-agents/additives_en)
- [EU-Kommission: EU rules on additives](https://food.ec.europa.eu/food-safety/food-improvement-agents/additives/eu-rules_en)
- [EU-Kommission: Additives database](https://food.ec.europa.eu/food-safety/food-improvement-agents/additives/database_en)

## Rechtliche Darstellungsgrenze

Die LMIV verlangt Pflichtinformationen grundsätzlich in Worten und Zahlen;
Piktogramme dürfen zusätzlich verwendet werden. Die Kollektion ist daher eine
Orientierungs- und Interaktionsschicht, keine Rechtsberatung und kein Ersatz
für die korrekte Betreiberkennzeichnung. Vor Veröffentlichung bleibt der
Betreiber für Stoff, Schwellenwert, Ausnahmen und exakten Wortlaut
verantwortlich.
