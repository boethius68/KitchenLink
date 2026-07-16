# Integration Review: KL-MENU-001

**Stand:** 16. Juli 2026
**Status:** Integrationsbewertung, keine freigegebene Produktontologie

## Kurzurteil

Die GLM-Recherche und der DeepSeek-Gegencheck liefern eine brauchbare fachliche
Arbeitsgrundlage fuer einen verlustfreien Importentwurf. Sie reichen nicht aus,
um die vorgeschlagene Ontologie als finales KitchenLink-Katalogmodell
festzuschreiben. Wir uebernehmen daher nur die belastbare gemeinsame
Schnittmenge in einen versionierten, internen Importvertrag.

Weitere breite Recherche blockiert die Implementierung nicht. Neue Evidenz wird
gegen den Importvertrag getestet und erweitert ihn versioniert, statt den Bau der
App bis zu einer theoretischen Saettigung aufzuhalten.

## Maschinenpruefbarer Bestand

Aus `source_registry.csv` und `pattern_evidence.csv` ergeben sich aktuell:

- 59 registrierte Quellen
- 55 Pattern-Evidenzen aus 34 referenzierten Quellen
- `deep_reviewed=true`: 7 Quellen
- `deep_reviewed=partial`: 7 Quellen
- `deep_reviewed=false`: 45 Quellen
- 58 Quellen mit `rights_status=research_only`
- 1 Quelle mit `rights_status=metadata_only`
- 31 `text_pdf`- und 28 `html`-Quellen
- keine tief gepruefte Foto-, Scan-, Bild-PDF- oder QR-Quelle

Damit gibt es aus diesem Korpus keine dauerhaft wiederverwendbare Benchmarkquelle.
Unsere drei App-Fixtures bleiben gesonderte interne Testmittel mit dokumentierter
Rechtewarnung, nicht Teil eines oeffentlich freigegebenen Datensatzes.

## Inkonsistenzen

- GLM-Handoff, DeepSeek-Handoff, Research Report und Quellenregister nennen
  unterschiedliche Zahlen fuer tief analysierte Karten: 7, 9 oder 12.
- `PROGRESS.md` meldet einen auf 12 Karten aktualisierten Saettigungstest;
  `saturation_test.md` enthaelt weiterhin 8 Karten.
- Dateinamen und Titel tragen `v0.1`, interne Felder teilweise `v0.2.0`, waehrend
  das DeepSeek-Handoff den Stand `v0.2.1` nennt. Ein konsistentes Release-Artefakt
  existiert noch nicht.
- Das Discovery-Schema speichert `pageOrLocation` als Freitext. Fuer die App
  brauchen wir stattdessen strukturierte Seite und normalisierte Bounding Box.
- `SourceEvidence` verlangt eine URL und einen Rechte-Status. Das passt zu einem
  Recherchekorpus, aber nicht zu privaten Kamera- oder Fotobibliothek-Imports.

Bis diese Punkte bereinigt sind, gelten Hauefigkeiten, Saettigung und
Versionsbezeichnungen nicht als belastbare Produktmetriken.

## Uebernommene Prinzipien

Folgende Punkte sind durch Recherche, Gegencheck und unsere realen Scannerfehler
ausreichend begruendet, um sie als internen Vertrag umzusetzen:

1. Originaltext, sichtbare Reihenfolge und Quellposition bleiben erhalten.
2. Jeder semantische Entwurf bleibt auf Seite und Bounding Box zurueckfuehrbar.
3. Artikel ohne sichtbaren Preis bleiben im Entwurf erhalten.
4. Absolutpreis, Preisspanne, `ab`, Marktpreis, inklusive, kostenlos, Delta und
   unbekannt sind unterschiedliche Preisbedeutungen.
5. Varianten, Modifier und Bundles werden nicht in ein gemeinsames Preisfeld
   gepresst.
6. Deklarationen werden nur aus expliziter Evidenz uebernommen; unbekannte Codes
   bleiben unbekannt.
7. Regeln, lokale Modelle und Cloudprovider liefern denselben versionierten
   Draft und schreiben niemals direkt in den aktiven Katalog.
8. Erst menschliche Bestaetigung oder Korrektur erzeugt spaeter eine
   Katalogversion.

## Noch nicht uebernommen

- finale Namen oder geschlossene Werte aller Taxonomieachsen
- Hauefigkeits- oder Vollstaendigkeitsaussagen aus der kleinen Stichprobe
- verschachtelte oder abhaengige Optionsgruppen als fertige V1-Semantik
- automatische rechtliche oder allergenfachliche Validierung
- ein bestimmtes lokales oder gehostetes KI-Modell
- dauerhafte Speicherung oder Veroeffentlichung der recherchierten Karten

## Integrationsfolge

1. Schlanken Swift-Vertrag `MenuImportDraft` mit strukturierten Evidenzen und
   harten Validatoren einfuehren.
2. Bestehenden Apple-Vision-/Regelparser ueber einen Adapter in diesen Draft
   schreiben lassen; der alte Sandboxpfad bleibt parallel erhalten.
3. Benchmark um Verlustmetriken erweitern: preislose Artikel, falsche
   Abschnittsbildung, Preisbedeutung und Beziehungen.
4. Review-UI als Originalseite plus editierbaren Draft bauen.
5. Erst danach lokale oder gehostete semantische Provider gegen denselben
   Vertrag vergleichen.

Die naechste Produktarbeit ist damit KL-MENU-002, nicht eine weitere ungebremste
Web-Stichprobe.

## Implementierungsstand

KL-MENU-002 ist als interner Swift-Vertrag `MenuImportDraft` in Version `0.1.0`
umgesetzt. Der Vertrag ist noch nicht mit Parser, Persistenz oder UI verdrahtet.
Seine Validatoren behandeln fehlende Preise als Review-Warnung und strukturell
ungueltige Preise, Evidenzen, IDs oder Auswahlregeln als Fehler. Der naechste
Schnitt ist der verlustfreie Adapter aus Apple-Vision-/Regelparser-Evidenz.
