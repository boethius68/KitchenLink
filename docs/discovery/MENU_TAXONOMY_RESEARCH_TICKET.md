# KL-MENU-001: Evidenzbasierte Speisekarten-Ontologie

**Status:** Weiterleitbarer Rechercheauftrag; noch nicht ausgefuehrt
**Empfohlener Erstlauf:** GLM-5.2 mit Thinking/hohem Reasoning-Aufwand und aktivem
Z.AI Web Search/Search Agent
**Empfohlener Gegencheck:** DeepSeek-V4-Pro im Thinking-/Expert-Modus
**Ergebnis ist Discovery, keine freigegebene Produktentscheidung.**

## Warum GLM zuerst

Fuer diese Aufgabe ist nicht nur Modellstaerke, sondern eine auditierbare
Webrecherche entscheidend. Z.AI dokumentiert fuer seine Websuche strukturierte
Treffer, Domain- und Zeitraumfilter, Publikationsdaten und zitierbare Quellen.
Deshalb ist GLM fuer den ersten Quellenlauf die praktischere Wahl. DeepSeek ist
anschliessend ein guter unabhaengiger Kritiker fuer Gegenbeispiele, Luecken und
unbelegte Verallgemeinerungen.

Nicht oeffentliche oder von KitchenLink-Nutzern hochgeladene Speisekarten duerfen
fuer diesen Rechercheauftrag weder in einen Consumer-Chat noch in den
Recherchekorpus geladen werden.

## Prompt fuer GLM

Den folgenden Block vollstaendig weiterleiten:

```text
TITEL
Evidenzbasierte Speisekarten-Ontologie und Datensatzplanung fuer KitchenLink

ROLLE
Du arbeitest als leitende:r Researcher:in fuer Information Extraction,
Gastronomie-Domaenenmodellierung und Datenqualitaet. Verwende dein staerkstes
Thinking/Reasoning und einen aktiven Web-Search- oder Search-Agent-Modus. Wenn du
nicht wirklich im Web suchen, einzelne Quellen oeffnen und direkte URLs belegen
kannst, brich ab und melde diese Einschraenkung. Erfinde keine Recherche.

KONTEXT
KitchenLink importiert fotografierte, hochgeladene oder spaeter auch als PDF
bereitgestellte Speisekarten. Eine vorhandene iPhone-Pipeline nutzt
Apple-Vision-OCR, Textkoordinaten, Bildverbesserung und lokale Preis-/Layoutregeln.
Das alte semantische Zielmodell ist aber zu klein: freie Abschnittstitel,
food/drink, ein Basispreis und flache Optionen portion/variant/extra.

Wir brauchen eine empirisch begruendete, versionierbare Ontologie und ein
verlustfreies Import-Schema fuer sehr unterschiedliche reale Speisekarten. Die
KI erzeugt immer nur einen pruefbaren Entwurf; das Original und seine sichtbare
Struktur bleiben erhalten.

HAUPTZIEL
Ermittle anhand offizieller Standards, Gastronomie-/POS-APIs, Forschung und einer
breit gestreuten Stichprobe realer offizieller Restaurantkarten:

1. welche Dokumentbloecke und Strukturbeziehungen vorkommen,
2. welche unabhaengigen Kategorisierungsachsen benoetigt werden,
3. wie Artikel, Bundles, Mengen, Varianten, Extras, Auswahlregeln und Preise
   verlustfrei darzustellen sind,
4. wie Allergene, Zusatzstoffe, Claims, Warnungen und lokale Legenden ohne
   Erfindung modelliert werden,
5. welche seltenen und schwierigen Muster ein Benchmark abdecken muss und
6. wie ein annotierter, rechtebewusster Testdatensatz aufgebaut werden soll.

VERBINDLICHE MODELLIERUNGSGRUNDSAETZE

- Eine einzige globale, flache Kategorienliste ist verboten. "Getraenk",
  "Vorspeise", "Pizza" und "Kinderkarte" liegen auf verschiedenen Achsen.
- Bewahre Originaltitel, Schreibweise, Reihenfolge, Hierarchie, Rohpreise,
  Beschreibungen, Sprachen und Quellenstellen.
- Erlaube mehrere Facetten gleichzeitig sowie unknown, unmapped und lokale
  Erweiterungen.
- Trenne mindestens Verkaufstyp/Konsumfamilie, Gang-/Funktionsrolle,
  Produktfamilie und Kontext.
- Trenne verkaufbare Varianten mit absolutem Preis von Modifiern mit
  Preisdelta, inklusive Auswahl oder unbekanntem Preiseffekt.
- Modelliere Optionsgruppen mit Pflicht/optional, single/multiple, min/max,
  Defaults, kostenloser Auswahlanzahl, Wiederholbarkeit und Abhaengigkeiten.
- Trenne Allergene, Zusatzstoffe, Zutatenangaben, Dietary-Claims und Warnungen.
- Leite keine Allergene, Zusatzstoffe, Zutaten oder Claims aus Weltwissen ab.
  Uebernimm nur ausdruecklich belegte Angaben und deren Geltungsbereich.
- Jeder normalisierte Wert braucht Rohtext, Quelle/Evidenz, Confidence und
  Pruefstatus. Unknown ist besser als eine erfundene Zuordnung.

QUELLENPRIORITAET

1. Gesetze, Behoerden und offizielle Leitlinien
2. offene Standards und offizielle API-/POS-Dokumentationen
3. offizielle Webseiten oder PDFs der Restaurants/Hotels/Caterer
4. Forschungsarbeiten und dokumentierte offene Datensaetze
5. Sekundaerquellen nur zur Entdeckung, nicht als alleiniger Beleg

Nutze als Startpunkte, aber beschraenke dich nicht darauf:

- Schema.org Menu, MenuSection, MenuItem und Offer
- Google Business Profile FoodMenus
- offizielle POS-/Ordering-Schemata wie Toast ModifierGroup
- EU- und DACH-Vorgaben zu Allergenen, Zusatzstoffen, Preis- und
  Mengenkennzeichnung
- wissenschaftliche Arbeiten/Datasets zu Menu OCR, Document Layout Analysis,
  Key Information Extraction und Food/Menu Ontologies

STICHPROBE UND ABDECKUNG

Erstelle zunaechst ein Kandidatenregister mit mindestens 200 oeffentlich
zugaenglichen offiziellen Speisekartenquellen. Analysiere davon 100 bis 150
eindeutige Karten tief, sofern Rechte und Zugriff dies zulassen. Berichte immer
die tatsaechlich erreichten Zahlen; behaupte nie eine Stichprobengroesse, die du
nicht geprueft hast.

Schwerpunkte:

- DACH und Europa, ergaenzt um internationale Gegenbeispiele
- Deutsch, Englisch, Italienisch, Franzoesisch sowie weitere beobachtete Sprachen
- unabhaengige Restaurants mindestens 60 Prozent der tiefen Stichprobe
- maximal drei Karten derselben Kette oder desselben Templates
- Restaurant, Cafe, Bar, Biergarten, Fine Dining, Hotel, Lieferdienst,
  Baeckerei/Imbiss, Kantine/Catering und saisonale/temporare Angebote
- Foto/Scan, textbasiertes PDF, bildbasiertes PDF, responsive HTML, QR-Menue und
  mehrspaltige Gestaltung
- Speisen, Getraenke, Wein-/Cocktailkarten, Fruehstueck, Kinderkarte,
  Tages-/Wochenkarte, Menues/Bundles und Mehrsprachigkeit

Fuehre fuer die letzten 20 tief analysierten eindeutigen Karten einen
Saettigungstest durch: Welche neuen Struktur-, Preis-, Options- oder
Deklarationsmuster kamen jeweils hinzu? Markiere Achsen, die noch nicht
gesaettigt sind.

RECHTE, ZUGRIFF, DATENSCHUTZ

- Nutze nur oeffentlich und rechtmaessig zugaengliche Quellen.
- Umgehe keine Anmeldung, Paywall, robots.txt-Regel, Captcha, Rate-Limits oder
  technische Zugriffssperre.
- Pruefe Nutzungsbedingungen, Lizenzhinweise und robots.txt und protokolliere
  einen Rechte-/Zugriffsstatus je Quelle: reusable, research-only,
  metadata-only, unclear oder excluded.
- Sammle fuer die Ontologierecherche bevorzugt URL, Metadaten und abgeleitete
  Strukturbeobachtungen. Speichere oder liefere keine umfangreichen
  urheberrechtlich geschuetzten Kartenkopien oder Bildsammlungen.
- Fuer einen spaeteren Benchmark duerfen nur Quellen mit dokumentierter
  Erlaubnis/Lizenz oder intern bereitgestellte, rechtmaessig nutzbare Testkarten
  empfohlen werden.
- Entferne EXIF, Gesichter und sonstige personenbezogene Daten aus zulassigen
  Testbildern. Keine echten privaten Nutzeruploads in dieses Researchprojekt.
- Dies ist keine Rechtsberatung. Kennzeichne unsichere Faelle fuer menschliche
  Rechtspruefung.

DUPLIKATKONTROLLE

Vergib stabile source_id-Werte und protokolliere mindestens kanonische URL,
Restaurant/Anbieter, Land, Sprache, Format, Abrufdatum, Rechte-/Zugriffsstatus
und Inhaltsfingerabdruck. Erkenne Duplikate und Templatevarianten ueber:

- kanonische URL und Dateihash,
- OCR-normalisierten Texthash,
- bei Bildern perceptual hash,
- bei aehnlichen Texten MinHash oder ein vergleichbares Verfahren.

Zaehle fuer Abdeckungs- und Haeufigkeitsaussagen nur eindeutige Vertreter. Weise
Duplicate-Cluster separat aus.

ZU UNTERSUCHENDE ENTITAETEN UND ACHSEN

A. Dokumentebene
- Menutitel, Abschnitt, Unterabschnitt, Hinweis, Artikel, Optionsgruppe, Option,
  Legende, Preis-/Verfuegbarkeitshinweis, rechtlicher Text, Branding/dekorativ,
  unbekannt
- Lesereihenfolge, Spalten, Tabellen, ueber Seiten fortgesetzte Abschnitte,
  Fussnoten und globale versus lokale Legenden

B. Menue-/Abschnittsebene
- sichtbare Hierarchie und freie Originaltitel
- Konsum-/Verkaufsfamilie: Speise, Getraenk, Bundle, Retail, Gebuehr/Pfand,
  Information, unbekannt
- Gang-/Funktionsrolle: z. B. Fruehstueck, Vorspeise, Suppe, Salat, Hauptgang,
  Beilage, Dessert, Snack, Kinderangebot, Sharing, Tagesangebot, Tasting/Set Menu
- Produktfamilie als erweiterbarer Baum statt geschlossener Enum
- Kontext: Zeit, Tag, Saison, Kanal, Standort, Kinder, Sharing, Mindestpersonen

C. Artikelebene
- einfacher Artikel, konfigurierbarer Artikel, Bundle/Set Menu, Notice,
  Gebuehr/Pfand, unbekannt
- Name, Beschreibung, Nummer, Sprache/Uebersetzung, wiederholte Platzierung,
  Zutaten nur wenn explizit, Verfuegbarkeit und Quellenstellen

D. Mengen, Varianten und Modifier
- ml/cl/l, mg/g/kg, Stueck, Portion, Person, Durchmesser und freie Einheiten
- Groesse, Portion, Volumen, Zubereitung, Protein, Zutaten, Beilage, Sauce,
  Dressing, Geschmack, Temperatur, Add-on, Entfernen, Austausch, Upgrade,
  Bundle-Komponente
- single/multiple, required, min/max, defaults, freeSelectionCount,
  Wiederholung, Abhaengigkeiten und verschachtelte Auswahl
- absolute Variantenpreise versus delta/included/per-unit/unknown
- Beispiele wie Fleisch oder Garnelen, eine Beilage inklusive, weitere gegen
  Aufpreis, "ohne", "extra", kleine/grosse Portion, mehrere Volumina

E. Preise
- fixed, from/ab, range, market/Tagespreis, on request, included, free, unknown
- Basis pro Artikel, Person, Stueck, Gewicht oder Volumen
- Waehrung, Rohformat, Pfand, Verpackung, Zuschlag, Mindestmenge,
  zeit-/kanalabhaengiger Preis
- Artikel ohne sichtbaren Basispreis und Preis nur an Varianten

F. Deklarationen
- lokale Codes und Legendentext getrennt von kanonischen IDs
- Allergene, Zusatzstoffe, contains/may contain/traces/free from,
  Dietary-Claims, Warnungen
- Geltungsbereich Menue/Seite/Abschnitt/Artikel/Option
- unbekannte Codes, widerspruechliche Legenden und variantenspezifische Angaben

EVIDENZREGELN

- Oeffne jede verwendete Quelle und verlinke direkt auf die belegende Seite oder
  das Dokument, nicht auf Suchergebnisse.
- Verknuepfe jede vorgeschlagene Kategorie, Regel und jedes Gegenbeispiel mit
  mindestens einer konkreten Evidenzzeile.
- Trenne sichtbar: Beobachtung, daraus abgeleitete Interpretation und Empfehlung.
- Quantitative Aussagen brauchen Zaehler, Nenner und Angabe der eindeutigen
  Stichprobe. "Haeufig" ohne Messwert ist unzulaessig.
- Bei widerspruechlichen Standards dokumentiere den Konflikt; erfinde keine
  scheinbare Einigung.

ERWARTETE ARTEFAKTE

Liefere, wenn deine Arbeitsumgebung Dateien erlaubt, genau diese Artefakte:

1. research_report.md
   - Methode, Quellenklassen, erreichte Stichprobe, Befunde pro Achse,
     Gegenbeispiele, Rechts-/Zugriffsgrenzen und Empfehlungen
2. source_registry.csv
   - source_id, canonical_url, provider, country, languages, venue_type, format,
     official_source, accessed_at, rights_status, robots_status, content_hash,
     duplicate_cluster, deep_reviewed, notes
3. pattern_evidence.csv
   - pattern_id, entity_level, raw_example_short, normalized_candidate,
     source_id, direct_url, page_or_location, observation, confidence,
     inclusion_decision
4. menu_ontology_v0.1.yaml
   - Achsen, IDs, Labels, Definitionen, Eltern, Ausschluesse, Beispiele,
     unknown/unmapped-Strategie und Versionsregeln
5. menu_schema_v0.1.json
   - ein valides JSON Schema fuer SourceEvidence, MenuImportDraft, Section,
     Entry, Offer/Price, Quantity, OptionGroup/Choice, Bundle und Declaration
   - fuege mindestens Beispiele fuer Groessenpreise, Toppings, Fleisch/Garnelen,
     Beilagenauswahl, Bundle/Set Menu, Pfand, Allergenlegende und unknown hinzu
6. annotation_guideline.md
   - genaue Annotierungsregeln, Grenzfaelle, Konfliktloesung, Inter-Annotator-
     Vorgehen und mindestens 30 schwierige Golden Cases
7. benchmark_plan.md
   - zulassige Datenquellen, Split- und Deduplogik, Metriken fuer Werte und
     Beziehungen, Halluzinations-/Verlustmetriken, lokale Laufzeit/RAM/Energie,
     menschliche Korrekturzeit und Akzeptanzschwellen als Vorschlag
8. excluded_sources.csv
   - URL, Ausschlussgrund, Rechte-/Zugriffsproblem und Datum

Wenn du keine Dateien erstellen kannst, gib jedes Artefakt in einem klar
benannten Codeblock aus. Kuerze dann nicht stillschweigend die Stichprobe oder
die Evidenztabellen. Teile die Arbeit stattdessen in nummerierte Fortsetzungen
und nenne den tatsaechlichen Stand.

QUALITAETSKONTROLLE VOR ABGABE

- Validiere JSON und YAML syntaktisch.
- Pruefe, dass jede Enum/Familie unknown oder eine dokumentierte
  Erweiterungsstrategie hat.
- Pruefe, dass absolute Preise und Preisaufschlaege getrennt sind.
- Pruefe, dass Rohwerte und Originalstruktur nicht durch Normalisierung verloren
  gehen.
- Pruefe, dass keine Deklaration ohne explizite Evidenz normalisiert wurde.
- Pruefe alle direkten Links stichprobenartig erneut.
- Suche aktiv nach Gegenbeispielen fuer die zehn wichtigsten Empfehlungen.
- Weise offen aus, welche Teile nur Hypothesen oder noch nicht gesaettigt sind.

ABSCHLUSSBERICHT

Beende die Arbeit mit:

1. tatsaechlicher Zahl der Kandidaten, tief analysierten eindeutigen Karten,
   Laender, Sprachen, Formate und Venue-Typen,
2. Rechte-/Zugriffsverteilung und Duplicate-Cluster,
3. Ergebnis des Saettigungstests,
4. zehn wichtigsten Modellierungsentscheidungen samt Evidenz,
5. zehn groessten verbleibenden Risiken oder ungesaettigten Bereichen,
6. konkretem Plan fuer die naechste manuelle Datensammlung.

WICHTIG
Implementiere noch keinen Produktionsparser. Das Ziel dieses Auftrags ist ein
belegter fachlicher Vertrag und ein serioeser Datensatz-/Benchmarkplan. Gib
nichts als abgeschlossen aus, das du nicht tatsaechlich recherchiert,
protokolliert oder validiert hast.
```

## Prompt fuer den DeepSeek-Gegencheck

Nach dem GLM-Lauf alle erzeugten Artefakte zusammen mit diesem Block an
DeepSeek-V4-Pro im Thinking-/Expert-Modus geben:

```text
Du bist die unabhaengige Red-Team-Instanz fuer eine recherchierte
Speisekarten-Ontologie. Pruefe die beigefuegten GLM-Artefakte kritisch; fuehre
bei Bedarf eigene Webrecherche mit direkten, geoeffneten Quellen durch.

Dein Auftrag ist nicht, den Bericht umzuschreiben oder pauschal zu bestaetigen.
Suche gezielt nach:

1. unbelegten oder uebergeneralisierten Kategorien,
2. vermischten Achsen (Produktart, Gangrolle, Kontext, Dietary Claim),
3. verlorenen Originalinformationen,
4. falscher Semantik von absolutem Preis, Delta, inklusive und pro Einheit,
5. nicht modellierbaren Options-/Bundlefaellen,
6. erfundenen Allergenen, Zusatzstoffen, Zutaten oder Claims,
7. falschem Geltungsbereich von Legenden,
8. Ketten-/Template-, Sprach-, Laender- oder Formatbias,
9. Duplikaten und fehlerhaften Haeufigkeitsangaben,
10. Quellen, deren Rechte-/Zugriffsstatus einen Benchmark ungeeignet macht,
11. JSON-Schema-Widerspruechen und nicht validen Beispielen,
12. Golden Cases, die reale Fehlerklassen nicht abdecken.

Liefere:

- audit_report.md mit Findings nach Schweregrad,
- konkrete Gegenbeispiele mit direkten Quellen,
- eine Tabelle aller beanstandeten Aussagen mit Artefakt/Zeile,
- minimal erforderliche Patches fuer Ontologie, Schema und Annotation Guide,
- eine Liste offener Fragen, die nur durch weitere Karten oder Fachpruefung
  beantwortet werden koennen.

Trenne Beobachtung, Schlussfolgerung und Empfehlung. Nenne die tatsaechlich
gepruefte Stichprobe. Erfinde keine Webrecherche und billige nichts allein wegen
scheinbarer Vollstaendigkeit.
```

## Referenzpunkte fuer die spaetere Auswertung

- Schema.org modelliert Menues, Abschnitte, Artikel, Angebote, Sprachen und
  Add-ons, deckt aber komplexe POS-Auswahlregeln nicht allein ab.
- Google FoodMenus zeigt unter anderem strukturierte Allergene,
  Dietary-Informationen, Nahrungswerte, Zutaten und Zubereitungsmethoden.
- Toast dokumentiert Modifiergruppen und eigene Preisstrategien; das bestaetigt,
  dass eine flache Optionsliste mit einem einzigen Preisfeld nicht ausreicht.

Diese Referenzen sind Seed-Quellen, kein Ersatz fuer die angeforderte breite
Stichprobe.

## Offizielle Seed-Quellen

- https://schema.org/MenuItem
- https://developers.google.com/my-business/reference/rest/v4/FoodMenus
- https://doc.toasttab.com/openapi/menus/tag/Data-definitions/schema/ModifierGroup/
- https://docs.z.ai/guides/tools/web-search
- https://api-docs.deepseek.com/news/news260424/
- https://www.gesetze-im-internet.de/urhg/__44b.html
- https://www.rfc-editor.org/rfc/rfc9309.html
- https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679
