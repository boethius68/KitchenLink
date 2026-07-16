# Menu Intelligence V0

**Status:** Arbeitsentwurf vom 15. Juli 2026; keine freigegebene Produktentscheidung
**Zweck:** Fachlicher Zielrahmen fuer die erneute Entwicklung und Evaluation der
Speisekartenerkennung
**Geltungsbereich:** Importentwurf, Taxonomie, Optionen, Preise, Deklarationen,
Evidenz und Pruefung; noch keine Produktionsmigration

## Kurzfassung

Das urspruengliche Verfahren der iPhone-App ist als Prototyp sinnvoll:

1. Kamera oder Fotobibliothek liefert eine oder mehrere Seiten.
2. Apple Vision erzeugt OCR-Text, Seitenindex und Bounding Boxes.
3. Bild, OCR und Layout werden semantisch interpretiert.
4. Ein Mensch prueft den Entwurf vor der Uebernahme.

Die vorhandene Zielstruktur ist fuer den produktiven Einsatz jedoch zu eng. Sie
kennt im Wesentlichen nur freie Abschnittstitel, `food | drink`, einen positiven
Basispreis und flache Optionen vom Typ `portion | variant | extra`. Eine echte
Grundmatrix existiert bislang nicht.

Die neue Matrix darf nicht als eine einzige globale Kategorienliste gebaut
werden. Begriffe wie "Getraenk", "Vorspeise", "Pizza" und "Kinderkarte"
beschreiben unterschiedliche Achsen. KitchenLink sollte deshalb gleichzeitig:

- die sichtbare Struktur und Originalbezeichnungen des Restaurants bewahren,
- kanonische, mehrdimensionale Facetten hinzufuegen,
- Varianten, Modifier, Preise und Deklarationen strukturiert abbilden,
- jeden erkannten Wert zur Originalstelle zurueckverfolgbar machen und
- unbekannte oder mehrdeutige Inhalte ohne Erfindung erhalten.

Ein lokales Modell in der Groessenklasse eines 4B-Gemma-Modells ist eine gute
erste Baseline, aber noch keine Architekturentscheidung. Zuerst werden Schema,
Goldstandard und Messverfahren festgelegt; danach werden lokale und gehostete
Modelle gegen dieselben Seiten verglichen.

## Befund zur urspruenglichen App

### Erhaltenswerte Bausteine

- Dokumentkamera und Mehrseiten-Fotoupload
- Apple-Vision-OCR mit `.accurate`-Erkennung
- OCR auf kontrastierter Fassung und Originalbild
- Seitenindex und Bounding Boxes je Textbeobachtung
- lokale Spalten-, Preis- und Legendenheuristiken
- Originalbild plus OCR als gemeinsamer Modelleingang
- explizite menschliche Freigabe vor der Uebernahme

### Grenzen des bisherigen Modells

- `MenuItemKind` unterscheidet nur `food` und `drink`
  (`kitchenlink/ContentView.swift`, ab Zeile 486).
- `MenuItemData` besitzt einen einzelnen Pflichtpreis und einen CSV-String fuer
  Deklarationscodes (ab Zeile 509).
- `MenuItemOptionKind` kennt nur `variant`, `extra` und `portion` (ab Zeile 569).
- Abschnittstitel sind frei; bekannte Begriffe wie Vorspeisen, Pizza, Bier oder
  Wein dienen nur der Ueberschriftenerkennung und bilden keine Taxonomie (ab
  Zeile 6151).
- Optionen tragen ein einziges Feld `priceCents`, obwohl ein absoluter
  Variantenpreis und ein Preisaufschlag verschiedene Bedeutungen haben.
- Artikel und Optionen ohne positiven Preis werden beim LLM-Mapping verworfen
  (ab Zeile 4904). Dadurch gehen unter anderem inklusive Auswahlmoeglichkeiten,
  Marktpreise und Artikel verloren, deren Preis nur an Groessen steht.
- LLM-Ergebnisse erhalten pauschal Confidence `0.9`; Feldkonfidenz und Evidenz
  fehlen.
- Bei aktivem LLM gibt es nach dessen Fehler keinen lokalen Fallback.
- Der Review zeigt keine Originalseite neben dem Ergebnis und erlaubt keine
  Korrektur einzelner Felder.
- Die SQL-Struktur kennt `variant_options`, der aktuelle Swift-Sync uebertraegt
  diese aber nicht. Auch Bestellpositionen enthalten keine gewaehlten Modifier.
- Der Legacy-Import besitzt noch keinen PDF-Pfad.

### Bewertung

Die Bild- und OCR-Schicht ist eine gute technische Ausgangsbasis. Die bisherige
semantische Ergebnisstruktur war fuer einen Sandbox-Prototyp vertretbar, ist
aber weder als kanonisches Produktmodell noch als Trainings- oder Testziel
geeignet. Sie sollte nicht schrittweise durch weitere Sonderfaelle erweitert,
sondern durch einen versionierten Importvertrag abgeloest werden.

## Leitprinzipien

1. **Original vor Normalisierung.** Restauranttitel, Schreibweise, Reihenfolge,
   Beschreibung und Rohpreise bleiben erhalten.
2. **Facetten statt einer flachen Kategorie.** Funktionsrolle, Produktfamilie,
   Verkaufstyp und Kontext werden getrennt klassifiziert.
3. **Keine Halluzination.** Zutaten, Allergene, Zusatzstoffe, Ernaehrungsclaims
   und Auswahlregeln werden nur uebernommen, wenn sie auf der Karte belegt sind.
4. **Unknown ist ein gueltiges Ergebnis.** Ungeklaerte Werte werden markiert und
   nicht in die naechstbeste Klasse gezwungen.
5. **Evidenz ist Teil des Datensatzes.** Jeder wichtige Wert verweist auf Seite,
   Bounding Box, Rohtext und Erkennungsmethode.
6. **KI erzeugt Entwuerfe.** Erst eine menschliche Pruefung schreibt einen
   Import in den aktiven Katalog.
7. **Providerneutralitaet.** Dasselbe Schema gilt fuer lokale Open-Weight-Modelle,
   Cloudmodelle und deterministische Regeln.
8. **Versionierung.** Taxonomie, Schema, Prompt, Parser und Modell werden an
   jedem Importentwurf festgehalten.

## Zielpipeline

```text
Quelle (Foto, Bibliothek, PDF)
  -> unveraenderliches Quelldokument mit Seiten
  -> Bildaufbereitung
  -> OCR- und Layoutevidenz
  -> semantischer Provider gegen versioniertes Schema
  -> deterministische Validierung und seitenuebergreifende Abstimmung
  -> editierbarer Importentwurf neben dem Original
  -> menschlich bestaetigte Katalogversion
```

Der lokale Regelparser bleibt als Baseline, Evidenzgenerator und Fallback
erhalten. Er ist nicht mehr die kanonische Wahrheit. Ein LLM darf umgekehrt
keine strukturell ungueltigen Ergebnisse direkt in den Produktkatalog schreiben.

## Vorgeschlagener Importvertrag

### 1. Quelle und Dokumentstruktur

`SourceDocument`

- stabile Import-ID
- Quelle: `camera | photo_library | pdf | other`
- Seiten in Originalreihenfolge
- Sprache(n), nur wenn erkannt oder bestaetigt
- Datei-/Bildfingerabdruck fuer Duplikaterkennung
- Importzeitpunkt und Verarbeitungsversionen

`SourceEvidence`

- `pageIndex`
- Bounding Box in normierten Koordinaten
- OCR-Rohtext und optionale OCR-Confidence
- Referenz auf Bildausschnitt
- Methode/Provider/Modell
- alternative Kandidaten

Vor der Artikelerkennung werden Dokumentbloecke klassifiziert:

- Menutitel
- Abschnitts- oder Unterabschnittsueberschrift
- Abschnittsnotiz
- Artikel
- Optionsgruppenueberschrift
- Option
- Preis- oder Verfuegbarkeitshinweis
- Allergen-/Zusatzstofflegende
- rechtlicher Hinweis
- Branding/Kontakt/dekorativer oder zu ignorierender Inhalt
- unbekannter Block

### 2. Sichtbare Restaurantstruktur

`Menu -> MenuVersion -> Section -> Subsection -> EntryPlacement`

Eine Section bewahrt:

- `rawTitle`, `rawSubtitle` und optionale Uebersetzungen
- Eltern-Kind-Beziehung
- sichtbare Reihenfolge
- Originalnotizen
- Quellenstellen
- null, eine oder mehrere kanonische Klassifizierungen

Dies verhindert, dass kreative oder lokale Strukturen wie "Aus Omas Topf",
"Zum Teilen" oder "Nur mittags" in eine starre Standardkarte umgeschrieben
werden.

### 3. Mehrdimensionale Kategoriegrundlage

Die folgenden Werte sind ein Startvokabular und werden durch die empirische
Recherche validiert oder erweitert.

#### Verkauf-/Konsumfamilie

- `prepared_food`
- `beverage`
- `bundle_or_set_menu`
- `retail_product`
- `fee_or_deposit`
- `informational`
- `other`
- `unknown`

#### Funktions- oder Gangrolle

- `breakfast`
- `starter`
- `soup`
- `salad`
- `main`
- `side`
- `dessert`
- `snack`
- `kids_offer`
- `sharing`
- `daily_special`
- `tasting_menu`
- `meal_combo`
- `unknown`

Diese Achse darf mehrere Werte tragen. Sie darf nicht allein aus der
Produktfamilie abgeleitet werden: Pizza ist nicht in jeder Karte automatisch ein
Hauptgang, und Dessertwein ist keine Speisen-Dessertrolle.

#### Produktfamilie

Die Produktfamilie ist ein versionierter, erweiterbarer Baum und keine
geschlossene App-Enum. Seed-Beispiele:

- Speisen: Brot/Backware, Suppe/Eintopf, Salat, Pizza/Flammkuchen, Pasta/Nudeln,
  Reisgericht, Burger/Sandwich, Fleischgericht, Gefluegel, Fisch/Meeresfruechte,
  vegetarisches/veganes Gericht, Beilage, Dessert/Suessspeise
- Getraenke: Wasser, Softdrink, Saft/Schorle, Kaffee, Tee, Bier, Wein,
  Schaumwein, Spirituose, Cocktail/Longdrink, alkoholfreier Mixdrink

Neue oder lokale Familien bleiben als `rawLabel` erhalten und koennen als
`unmapped` in spaeteren Taxonomieversionen zugeordnet werden. Dietary-Claims wie
vegan sind fachlich eine eigene Achse, auch wenn sie als Suchfacette angeboten
werden.

#### Kontext

- Tageszeit oder Wochentag
- Saison/Aktionszeitraum
- Kinderangebot
- Sharing
- Lunch/Happy Hour
- vor Ort/Abholung/Lieferung
- Standort oder Teilbereich des Restaurants
- Mindestbestellmenge oder Mindestpersonenzahl

Kontext ist nicht mit Produktart oder Gangrolle zu vermischen.

### 4. Eintraege und Bundles

`CatalogEntry.type`

- `item`
- `configurable_item`
- `bundle_or_set_menu`
- `notice`
- `fee_or_deposit`
- `unknown`

Ein Artikel enthaelt mindestens Originalname, optionale Beschreibung,
Platzierung, Angebote/Preise, Optionsgruppen, explizite Deklarationen und
Evidenz. Ein Bundle enthaelt Komponenten oder Komponentengruppen mit eigenen
Auswahlregeln. Derselbe Artikel kann in mehreren Abschnitten oder Menues mit
unterschiedlichen Preisen platziert sein.

### 5. Varianten und Modifier

Eine Variante ist eine verkaufbare Auspraegung mit absolutem Preis; ein Modifier
veraendert oder konfiguriert eine Auswahl. Beide duerfen nicht mehr dasselbe
Preisfeld teilen.

`OptionGroup`

- Zweck: `size | portion | volume | preparation | protein_choice |
  ingredient_choice | side_choice | sauce | dressing | flavor | temperature |
  add_on | removal | substitution | upgrade | bundle_component | other`
- Auswahlmodus: `single | multiple | quantity | unknown`
- `required`, `minSelections`, `maxSelections`, `freeSelectionCount`
- Standardauswahl, Wiederholbarkeit und optionale Abhaengigkeiten
- Rohtext und Evidenz

`OptionChoice`

- Originalname
- strukturierte Menge, falls vorhanden
- Rolle: `variant | add | remove | substitute | preparation | component | other`
- Preiseffekt: `absolute | delta | included | per_unit | unknown`
- optionale artikelspezifische Deklarationen
- Rohtext, Confidence und Evidenz

Beispiele:

- "klein 6,90 / gross 8,90" wird zu einer Variantengruppe mit zwei absoluten
  Preisen.
- "wahlweise mit Haehnchen oder Garnelen +2,00" wird zu einer
  `protein_choice`-Gruppe; nur Garnelen erhalten den belegten Aufpreis.
- "eine Beilage inklusive, jede weitere 2,50" wird zu einer Mehrfachauswahl mit
  `freeSelectionCount = 1` und einer Folgeregel.
- "ohne Zwiebeln" ist eine Entfernung, nicht automatisch ein Extra zum Preis 0.

### 6. Mengen und Einheiten

Mengen werden als `value + unit + rawText` gespeichert. Das Startvokabular muss
mindestens unterstuetzen:

- `ml`, `cl`, `l`
- `mg`, `g`, `kg`
- Stueck, Scheibe, Kugel, Portion
- Person
- Durchmesser
- frei formulierter oder unbekannter Einheitentyp

Normalisierung darf den Rohtext nicht ersetzen. "0,4 l", "40 cl" und "400 ml"
koennen vergleichbar werden, bleiben aber als Originalwerte sichtbar.

### 7. Preise und Preisregeln

`Price`

- `kind: fixed | from | range | market | on_request | included | free | unknown`
- `amountMinor?`, `upperAmountMinor?`, `currency?`
- Basis: `item | person | piece | weight | volume | unknown`
- optionale Menge/Einheit
- Kanal, Ort oder Gueltigkeitszeitraum
- `rawText`, Confidence und Evidenz

Pfand, Verpackung, Bedien- oder andere Zuschlaege werden als getrennte
Preiskomponenten modelliert. Die Waeh­rung darf nicht allein aufgrund der
App-Locale erfunden werden. Ein fehlender oder nicht lesbarer Preis darf keinen
Artikel loeschen.

### 8. Deklarationen

Vier Klassen bleiben getrennt:

- Allergene
- Zusatzstoffe
- Dietary-/Ernaehrungsclaims
- Warnungen oder sonstige rechtliche Hinweise

`SourceLegendEntry`

- lokaler Code und Originaltext
- Deklarationstyp
- Geltungsbereich: Menue, Seite, Abschnitt, Artikel oder Option
- optionale kanonische Zuordnung
- Evidenz und Pruefstatus

`ItemDeclaration`

- Beziehung: `contains | may_contain | traces | free_from | explicitly_claimed |
  unknown`
- lokale und kanonische ID
- ausdruecklich genannter Rohtext
- Geltungsbereich, Confidence und Evidenz

Die KI darf insbesondere keine Allergene oder Zutaten aus allgemeinem
Kochwissen ableiten. Nicht aufloesbare Codes bleiben als Rohcode erhalten und
werden zur Pruefung markiert.

### 9. Feldstatus und Konflikte

Jeder erkannte Feldwert oder jede Beziehung kann enthalten:

- Rohwert und normalisierten Wert
- `confidence`
- eine oder mehrere Evidenzstellen
- Provider/Modell/Promptversion
- Alternativkandidaten
- Warnungen oder Validierungsfehler
- `reviewState: unreviewed | confirmed | corrected | rejected`

Confidence ist kein Ersatz fuer Evidenz. Harte Validatoren pruefen unter
anderem:

- absolute und relative Preise werden nicht verwechselt,
- Auswahlgrenzen sind widerspruchsfrei,
- Waehrung und Einheiten werden nicht erfunden,
- ein Artikel bleibt auch ohne positiven Basispreis erhalten,
- Deklarationscodes sind nur innerhalb des belegten Geltungsbereichs aktiv,
- seitenuebergreifende Zusammenfuehrung erzeugt keine stillen Duplikate,
- jedes normalisierte Pflichtfeld verweist auf eine Quelle oder eine bestaetigte
  Nutzerkorrektur.

## Providervertrag

Ein spaeteres `MenuIntelligenceProvider` erhaelt:

- Originalseiten oder relevante Crops
- OCR-Zeilen mit Geometrie und Sprache
- erkannte Legendenkandidaten
- die genaue Schema- und Taxonomieversion
- bei Bedarf Ergebnisse deterministischer Kandidatengeneratoren

Es liefert ausschliesslich einen `MenuImportDraft` mit strukturierten
Unsicherheiten. Direkte Netzwerkanbieter, lokale Open-Weight-Modelle und ein
regelbasierter Provider implementieren denselben Vertrag. Providerfehler werden
pro Seite isoliert; erfolgreiche Seiten bleiben pruefbar.

## Review-Zielbild

Die Review zeigt Originalseite und strukturierten Entwurf nebeneinander.
Auswahl eines Feldes hebt die zugehoerige Bounding Box hervor. Der Betreiber
kann mindestens korrigieren:

- Abschnitt und Unterabschnitt
- Artikelname und Beschreibung
- Kategorie-/Kontextfacetten
- Preise und Preisbedeutung
- Mengen, Varianten und Modifiergruppen
- Deklarationen und deren Geltungsbereich
- Duplikate und seitenuebergreifende Zusammenfuehrungen

Niedrige Confidence, fehlende Evidenz, ungeklaerte Preise, unbekannte Codes und
widerspruechliche Auswahlregeln bilden eine priorisierte Arbeitsliste. Erst eine
explizite Bestaetigung erzeugt eine neue Katalogversion.

## Modell- und Teststrategie

### Reihenfolge

1. Taxonomie und JSON-Schema als V0.1 festlegen.
2. Rechte- und quellenbewussten Menuekorpus recherchieren.
3. 100 bis 150 repraesentative Karten fuer die Strukturabdeckung untersuchen.
4. Einen kleineren, manuell annotierten Goldstandard mit schwierigen Faellen
   erstellen.
5. Apple OCR plus Regeln als reproduzierbare Baseline messen.
6. Lokales 4B-Modell, groesseres lokales Modell und gehostete Modelle mit
   identischem Input und Schema vergleichen.
7. Fehlerklassen gezielt nachannotieren und Regressionstests aufbauen.

### Messgroessen

- Block- und Abschnittserkennung
- Artikelnamen- und Beschreibungsgenauigkeit
- Preiswert **und Preisbedeutung**
- Zuordnung mehrerer Preise zu Groesse/Portion/Artikel
- OptionGroup-Erkennung und Auswahlregeln
- Deklarationscode, Legendenaufloesung und Geltungsbereich
- Struktur-/Beziehungs-F1 statt nur Textaehnlichkeit
- Rate erfundener Felder und verlorener Artikel
- Anteil korrekt als `unknown` markierter Faelle
- menschliche Korrekturzeit pro Seite
- Laufzeit, Spitzen-RAM, Energie und Kosten pro Seite

Ein lokales 4B-Modell gilt erst dann als ausreichend, wenn es nicht nur einfache
Einspaltenkarten, sondern auch kleine Schrift, mehrere Spalten, Legenden,
mehrsprachige Karten, Mehrfachpreise, Bundles und komplexe Optionsgruppen mit
vertretbarer Korrekturzeit bewaeltigt. Schwierige Seiten koennen spaeter
providerneutral an ein groesseres Modell eskaliert werden.

## Empfohlene Arbeitspakete

1. **KL-MENU-001 — Taxonomie- und Quellenrecherche:** Recherche-Ticket aus
   `MENU_TAXONOMY_RESEARCH_TICKET.md` ausfuehren und Befunde belegen.
2. **KL-MENU-002 — Schema V0.1:** Ontologie, JSON-Schema, Beispiele und
   Validator-Invarianten aus den Rechercheergebnissen ableiten.
3. **KL-MENU-003 — Goldstandard:** Rechtegepruefte Testseiten annotieren und
   schwere Golden Cases festhalten.
4. **KL-MENU-004 — Legacy-Baseline:** Bestehende OCR-/Regelpipeline auf den
   Goldstandard anwenden und Fehlerklassen messen.
5. **KL-MENU-005 — Provider-Spike:** Lokales 4B-Modell und mindestens zwei
   staerkere Referenzmodelle unter demselben Vertrag evaluieren.
6. **KL-MENU-006 — Editierbarer Draft-Review:** Original, Evidenz und
   Feldkorrektur als Sandbox-Flow implementieren.
7. **KL-MENU-007 — Verlustfreie Persistenz/Order:** Optionen und bestaetigte
   Snapshotdaten ohne Informationsverlust synchronisieren.

## Noch explizit zu entscheiden

- Welche V0.1-Taxonomie nach der Recherche freigegeben wird
- Welche Menuequellen dauerhaft gespeichert werden duerfen
- Welche Qualitaetsschwellen ein lokales Modell erfuellen muss
- Ob und wann schwierige Seiten an einen Cloudprovider eskalieren duerfen
- Welche Deklarationen KitchenLink nur abbildet und welche es aktiv validiert
- Welche Felder vor einer Veroeffentlichung zwingend menschlich bestaetigt sein
  muessen

Bis zu diesen Entscheidungen bleibt dieses Dokument ein Discovery-Artefakt und
aendert weder den verbindlichen Blueprint noch den bestehenden Sandboxpfad.
