# Scanner-Benchmark: aktueller Stand

**Lauf:** 16. Juli 2026

**Umgebung:** iPhone 17 Pro Simulator, Apple Vision, lokale Parserregeln

**Umfang:** 14 Seiten, 23 Abschnittsanker, 46 Artikelanker

## Ergebnis

| Fixture | Abschnitte | Artikelnamen | Preise | OCR-Namen |
| --- | ---: | ---: | ---: | ---: |
| Scheune Berlin | 4/4 (100 %) | 15/15 (100 %) | 15/15 (100 %) | 15/15 (100 %) |
| Lichtburg Berlin | 11/12 (91,7 %) | 14/16 (87,5 %) | 14/16 (87,5 %) | 16/16 (100 %) |
| Alexxanders Chemnitz | 6/7 (85,7 %) | 15/15 (100 %) | 15/15 (100 %) | 15/15 (100 %) |

Der Lauf besteht die in `thresholds.json` festgelegten Regressionsgrenzen. Die
Ankerwerte messen Wiedererkennung, nicht die Vollstaendigkeit oder Korrektheit
jeder importierten Zeile.

## Draft-Ergebnis

| Fixture | Draft-Eintraege | Namensanker | Preisanker | Preislose Review-Kandidaten |
| --- | ---: | ---: | ---: | ---: |
| Scheune Berlin | 28 | 15/15 (100 %) | 15/15 (100 %) | 0 |
| Lichtburg Berlin | 50 | 16/16 (100 %) | 14/16 (87,5 %) | 7 |
| Alexxanders Chemnitz | 27 | 15/15 (100 %) | 15/15 (100 %) | 2 |

Alle Drafts bestehen die rekursive `MenuImportDraft`-Validierung. Die neue
Namensabdeckung misst nicht nur den Text, sondern die strukturierte
Draft-Aufnahme mit gueltiger Seite und Bounding Box. Die Preisabdeckung verlangt
den erwarteten Centwert auf derselben Quellseite.

## Verbleibende Luecken

- Lichtburg Seite 4: Vision liest `Haehnchenbrustfilet "Pfeffer"` und
  `Gegrillte Garnelen`, liefert fuer diese beiden Bloecke aber keinen
  zuordenbaren Preis. Der Legacy-Pfad kann sie weiterhin nicht darstellen; der
  Draft behaelt beide als `needsReview` ohne erfundenen Nachbarpreis.
- Lichtburg Seite 6: `Haupgerichte` ist Teil eines Menue-Bundles ohne eigenen
  Preisblock und wird im flachen Zielmodell nicht als eigener Abschnitt
  erhalten.
- Alexxanders Seite 2: `Speisekarte` ist ein Dokumenttitel ohne direkte Artikel;
  leere Abschnitte werden vom aktuellen Importmodell entfernt.
- Der sichtbar preislose `Gemischter Eisbecher` bleibt jetzt samt Evidenz im
  Draft. Er kann erst nach einer expliziten Review-Entscheidung in das weiterhin
  preisgebundene Sandbox-Menue konvertiert werden.
- Verlustarmes Sammeln erzeugt zusaetzliche Review-Kandidaten: bei Lichtburg
  unter anderem englische Struktur-/Uebersetzungszeilen, bei Alexxanders zwei
  strukturelle Titel. Diese neun Kandidaten werden weder automatisch verworfen
  noch als sichere Artikel veroeffentlicht; die Review-UI muss sie klassifizieren.
- Mehrfachpreise, Portionsspalten, Bundle-Hierarchien und zweisprachige
  Beschreibungen werden nur teilweise strukturiert. Im Lichtburg-Ergebnis bleibt
  ausserdem mindestens eine englische Beschreibungszeile als falscher Abschnitt
  uebrig. Diese Punkte sind vor einer Scanner-Produktfreigabe separat zu loesen.

## Einordnung

Der Benchmark ist ein reproduzierbarer Fehlerdetektor fuer die drei lokalen
Fixtures. Er belegt, dass OCR und zentrale Preiszuordnung nicht mehr komplett
ausfallen; er belegt noch keine vollstaendige Speisekarten-Digitalisierung. Der
naechste Scanner-Schnitt ist die evidenzbasierte Review-UI. Sie muss Original,
Rohtext, optionalen Preis und strukturelle Unsicherheit gemeinsam zeigen, bevor
der Nutzer explizit in das Sandbox-Menue uebernimmt.
