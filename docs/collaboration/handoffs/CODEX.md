# Codex Handoff

**Updated:** 26 July 2026
**Branch:** `main`
**Status:** Phase 1 des Speisekartenimports ist als messbare, verlustbewusste
Grundlage implementiert; die lokale Erkennung besteht das Freigabegate noch
nicht

## Latest Continuation (26. Juli 2026, echter Modellpilot)

- Der Review-Runner kann jetzt ausschliesslich explizit ausgewaehlte Seiten
  verarbeiten. Der Pilot nutzte vier Seiten mit 17 Soll-Eintraegen:
  Pruefkueche 1/2, Lichtburg 6 und das Alexxanders-Cover. Ausgewaehlte
  Deckseiten werden mit den Menue-Seiten als ein Teststapel verarbeitet, damit
  ein korrekt leeres Cover den Lauf nicht faelschlich abbricht.
- `qwen3.5:9b` (6,6 GB) und `gemma4:latest` wurden lokal mit echtem Bildzugriff
  geprueft. Fuer den reichen Verlustfrei-Vertrag erhielten beide 32k-Kontext
  und deaktiviertes Denkprotokoll. Beide ueberschritten auf nur einer dichten
  Seite zweimal 150 Sekunden und fielen vollstaendig auf OCR/Regeln zurueck.
  Sie sind auf dem 16-GB-Mac keine Phase-1-Voll-Extraktoren.
- OpenCode Zen `mimo-v2.5-free` verarbeitete alle vier Bilder selbst, ohne
  Fallback. Ein Pilotmodus des bestehenden Qualitaetspruefers projiziert die
  kanonische Ground Truth auf den ausgewaehlten Teststapel; 9/9 Python-Tests
  und 11/11 Importvertrags-Tests bestanden.
- Ein gezielt verschaerfter Bundle-Prompt `1.0.3` verursachte eine klare
  Regression (Eintrags-F1 `0.059` statt `0.474`) und wurde vollstaendig auf
  `1.0.2` zurueckgesetzt.
- Eine deterministische, verlustfreie Mapping-Korrektur verschiebt kompakte
  sichtbare Codegruppen wie `[A,G,2]` aus dem Artikelnamen in separate
  Deklarationen. Rohtext und Bildbeleg bleiben erhalten; mehrbuchstabige
  Gruppen wie `[XL]` werden bewusst nicht veraendert.
- Drei unveraenderte Mimo-Laeufe mit diesem Mapping ergaben Eintrags-F1
  `0.971`, `0.842`, `0.889`; erfundene Eintraege `1`, `5`, `3`; fehlende
  Eintraege `0`, `1`, `1`; erfundene Preise `4`, `3`, `5`; Beziehungs-F1
  `0.278`, `0.290`, `0.246`. Exakte semantische Wiederholbarkeit: `0.000`.
  Das Cover war stets korrekt leer, alle Seiten hatten einen Modellstatus,
  und es gab keine Schemafehler.
- Der dominante Fehler ist reproduzierbar das Lichtburg-Gangmenue. In zwei
  Laeufen fehlte das Bundle komplett und seine Gaenge wurden als Einzelartikel
  ausgegeben. Im besten Lauf blieb `Antipasti` zusaetzlich einzeln und die
  drei Hauptgerichte wurden nicht als eine Wahlgruppe modelliert.
- Der aktuelle Free-Katalog nennt ausser Mimo noch
  `deepseek-v4-flash-free`, `ling-3.0-flash-free`,
  `nemotron-3-ultra-free`, `north-mini-code-free` und
  `laguna-s-2.1-free`. Deren geplanter Ein-Seiten-Faehigkeitstest sowie ein
  schlanker lokaler Gemma-Gegenpruefer wurden nicht ausgefuehrt, weil die
  Systemfreigabe am Nutzungslimit stoppte. Es gab keinen Umgehungsversuch und
  keine weitere Bilduebertragung.

## Verification (echter Modellpilot)

- Pilot-Pruefer: **9/9 Python-Tests bestanden**.
- Verlustfrei-Vertrag/Mapping: **11/11 Xcode-Tests bestanden**.
- Drei identische Mimo-Piloten: je **4/4 Seiten ohne Fallback**; maschinenlesbar
  unter `/tmp/kitchenlink-ai/mimo-v25/pilot-repeatability.json`.
- Qwen/Gemma-Smokes: korrektes Cover-Verstaendnis; reicher Ein-Seiten-Vertrag
  jeweils nach zwei 150-s-Versuchen **Fallback**, deshalb nicht als KI-Ergebnis
  gewertet.

## Exactly One Recommendation (echter Modellpilot)

Nach Aufhebung des Nutzungslimits die fuenf uebrigen kostenlosen
OpenCode-Modelle ausschliesslich auf der einen Lichtburg-Seite mit einem
kleinen Bundle-Pruefvertrag testen. Nur ein Modell, das Name, Gesamtpreis,
Preis-Basis und den dreifachen Wahlgang korrekt erkennt, wird als unabhaengige
zweite Pruefpassage weiterverfolgt; bis dahin keinen Vollkorpuslauf starten.

## Latest Continuation (26. Juli 2026, Phase 1 Speisekartenimport)

- Der kanonische Importentwurf ist auf
  `kitchenlink-menu-import-draft/0.3.0` erweitert. Er bewahrt Originalseiten,
  Seitenhashes, Seitentypen und Sprachen, OCR-Zeilen, Fundstellen,
  Alternativtexte, alle Preisarten, Mengen, Auswahlregeln, Bundles,
  Deklarationen, allgemeine Hinweise samt sichtbaren Uebersetzungen,
  Seitenstatus, Laufzeiten und Pruefhinweise. Enthaltene Bundle-Bestandteile
  duerfen ohne erfundenen Preistext erhalten bleiben.
- Der reiche Providervertrag
  `kitchenlink-menu-import-extraction/1.0.0` wird jetzt direkt und seitenweise
  in diesen Entwurf montiert. Die alte flache LLM-Zwischenstruktur ist nicht
  mehr semantische Wahrheit. Eine fehlgeschlagene, unvollstaendige oder
  ungueltige Seite verwirft den gesamten KI-Entwurf und faellt sichtbar auf
  die lokale Analyse zurueck; Menue- und Mischseiten duerfen nicht unbemerkt
  als leer gelten.
- Die Pruefansicht und der Konverter laufen rekursiv durch Unterbereiche.
  Verschachtelte Eintraege koennen damit geprueft, verschoben und uebernommen
  werden, ohne verloren zu gehen.
- Das versionierte Pruefkorpus umfasst 10 reale Seiten aus vier unterschiedlich
  schwierigen Karten mit 68 Soll-Eintraegen. Jede Seite besitzt Hash,
  Abmessungen, Nutzungsstatus und eine vollstaendige Sollstruktur.
- Der neue lokale Qualitaetsscanner bewertet pro Lauf und pro Karte Struktur,
  Namen, Kategorien, Beschreibungen, Angebote, Preistext/-basis/-waehrung,
  Beziehungen, Deklarationen, Uebersetzungen, Belege, Review-Erkennung,
  Latenz, Fehlerquote und Wiederholbarkeit. Fehlende oder erfundene Eintraege
  und Preise sind harte Null-Toleranz-Fehler; unscharfe Texttreffer dienen nur
  als Diagnose und koennen das Gate nicht schoenrechnen.
- Drei unabhaengig erzeugte lokale Berichte ueber jeweils alle 10 Seiten wurden
  verglichen. Exakte semantische Wiederholbarkeit: `1.000`; Seitenfehler:
  `0.000`; Latenzabdeckung: `1.000`; P95-Seitenlatenz: `7145 ms`.
- Die strenge Erstbaseline besteht das Freigabegate bewusst nicht:
  Eintrags-F1 `0.592` (Ziel `0.980`), 18 fehlende Eintraege, 51 erfundene
  Eintraege, 50 erfundene Preise, Belegabdeckung `0.893` (Ziel `0.950`) und
  Beziehungs-F1 `0.000` (Ziel `0.950`). Allgemeine Hinweise erreichen
  ebenfalls erst `0.000` (Ziel `0.950`). Es gab keine still verlorene Seite
  und keinen Validierungsfehler.

## Verification (Phase 1 Speisekartenimport)

- Ground Truth: **10/10 Seiten und 68 Eintraege gueltig**; Quelldateihashes und
  Abmessungen stimmen.
- Qualitaetsscanner: **8/8 Python-Tests bestanden**; Syntaxpruefungen fuer
  Scanner und lokalen Runner bestanden.
- Xcode `build-for-testing`: **bestanden** auf iPhone 17 Pro / iOS 26.5.
- Gezielte Xcode-Ausfuehrung: **28/28 Phase-1- und Review-Tests bestanden**.
  Abgedeckt sind unter anderem echtes `snake_case`-Decoding, leere Menueseiten,
  uebersetzte allgemeine Hinweise, unbekannte Fundstellen, enthaltene
  Bestandteile ohne Preistext, Seitenstatus, verschachtelte Unterbereiche und
  verlustfreies Verschieben.
- Drei komplette lokale Messlaeufe: jeweils **10/10 Seiten**, identisches
  semantisches Ergebnis. Der Ergebnisbericht liegt unter
  `/private/tmp/kitchenlink-phase1-quality-final.json`.
- `git diff --check`: **bestanden**.
- Externe KI-Zugaenge blieben deaktiviert; es wurden keine Speisekartendaten an
  einen externen Anbieter uebertragen und keine Kosten ausgeloest.

## Remaining Risk (Phase 1 Speisekartenimport)

- Die neue Messung ist erheblich strenger als die Phase-0-Stichproben. Die
  Zahlen sind deshalb kein direkter Vorher-/Nachher-Vergleich. Sie zeigen
  erstmals objektiv, dass die lokale Regelanalyse besonders bei
  Tabellen/Legenden, Preissemantik, Bundles, Beziehungen und Uebersetzungen
  nicht produktionsreif ist.
- Ein echter Provider-/Prompt-Vergleich samt unabhaengiger Gegenpruefung fand
  noch nicht statt, weil dies externe Verarbeitung, Kosten- und
  Datenschutzfreigabe erfordert. Der dokumentierte Ablauf erzwingt diese
  Gegenpruefung fuer jede kuenftige Modellrunde.
- Der Pruefharness speichert wiederauffindbare Originaldateireferenzen. Direkt
  in der App aufgenommene Bilder leben derzeit noch im Sitzungsspeicher; vor
  dauerhaft gespeicherten Importentwuerfen braucht es eine freigegebene
  Aufbewahrungs- und Loeschregel.
- Entwuerfe der Version `0.2.0` lassen sich noch lesen, benoetigen vor einer
  dauerhaften Aktivierung aber eine explizite Migration auf `0.3.0`.

## Exactly One Recommendation (Phase 1 Speisekartenimport)

Nach ausdruecklicher Kosten- und Datenschutzfreigabe einen kontrollierten
Vision-Modellvergleich auf genau diesem 10-Seiten-Gate durchfuehren und nur
die Variante weiterverfolgen, die alle Null-Toleranz-Fehler reduziert, ohne
Belegtreue oder Wiederholbarkeit zu verschlechtern.

## Latest Continuation (22. Juli 2026, Speise zuerst + Minus-Treffzone)

- Die bisher nur behauptete `dish-first`-Hierarchie ist jetzt metrisch im Code
  verankert: Speisename 20 Punkte/bold, Preis 16 Punkte/semibold. Der rechte
  Preis-/Plus-Cluster bleibt ungekürzt; nur lange Namen umbrechen.
- Pro Zeile erscheinen hoechstens zwei 22-Punkt-Deklarationssymbole. Weitere
  Kennzeichnungen landen in einem neutralen `+N`; die bedienbaren Flaechen
  bleiben trotz der kleineren Optik 44 Punkte gross.
- Ursache des kleinen Minus-Treffers war bestaetigt: Die 44-Punkt-Frames der
  `plain` SwiftUI-Buttons enthielten keine vollflaechige Form. Ein gemeinsamer
  `MenuImportQuantityButton` verwendet nun `Color.clear`, rechteckige
  `contentShape` und einen 44-Punkt-Button fuer Minus und Plus.
- Derselbe Helper deckt einfache und konfigurierte Hauptzeilen, wiederholbare
  Optionen im Konfigurationssheet und den Warenkorb ab. Das Web setzt die
  Stepper-Buttons explizit auf 44 x 44 Pixel und verhindert eine Ueberlagerung
  durch die Deklarationsleiste.
- Der UI-Smoke startet ueber eine isolierte UserDefaults-Suite immer mit der
  deterministischen Demokarte. Er erhoeht auf Menge 2 und tippt das Minus
  zweimal bewusst am linken Rand: `2 -> 1 -> entfernt`.

## Verification (Speise zuerst + Minus-Treffzone)

- Gast-Web: Typecheck, Lint, **86/86 Tests** und Produktions-Build:
  **bestanden**. Der neue Cart-Test deckt `2 -> 1 -> entfernt` sowie den
  unbekannten Artikel ab.
- Read-only Gegenpruefungen bestaetigen fuer 320-Punkt-Breite ausreichend
  Platz fuer zwei Icons, `+N` und Stepper sowie die vollflaechige Verwendung
  des nativen Quantity-Helpers in allen aktuellen Pfaden.
- `git diff --check`: **bestanden**.
- Der native Xcode-/UI-Testlauf und die lokale Browser-Ansicht konnten in
  dieser Session nicht gestartet werden: Das Codex-Freigabekontingent lehnte
  sowohl CoreSimulator als auch den lokalen Dev-Server vor Ausfuehrung ab.
  Dies ist als offene Verifikation dokumentiert, nicht als bestandener Test.

## Remaining Risk (Speise zuerst + Minus-Treffzone)

- Der neue native Randtap-Smoke muss beim naechsten verfuegbaren
  CoreSimulator-Lauf ausgefuehrt werden; die Swift-Struktur wurde statisch
  gegengeprueft, aber nicht als Build-Erfolg ausgegeben.
- Die komplexeren Piktogramme benoetigen bei 22 Punkten noch die subjektive
  Simulator-/Geraeteabnahme. Das aktualisierte Gast-Web ist nicht deployt.

## Latest Continuation (22. Juli 2026, Gastkarten-Hierarchie)

- Die Speise steht wieder im Vordergrund: Noch nicht gewaehlte Artikel zeigen
  nur ein kleines rundes Plus direkt neben dem Preis. Konfigurierbare Gerichte
  oeffnen von dort ihre Auswahl; der breite `Auswaehlen`-Button und leere
  Zubehoerzeilen sind entfernt.
- Das sichtbare Plus bleibt 34 Punkte kompakt, besitzt in iOS und Gast-Web aber
  eine echte 44-Punkt-Touchflaeche. Nach dem Hinzufuegen erscheinen die
  Mengensteuerung und der Warenkorb wie bisher.
- Buchstaben- und Zifferncodes aus Quellkarten erscheinen weder im Badge noch
  in der antippbaren Detailansicht oder Legende. Der Gast sieht ausschliesslich
  Piktogramm, Klartext, Gruppe und eine kurze Erklaerung.
- Alkohol wird mit einem eindeutigen Weinglas statt der generischen
  Sprechblase dargestellt. Der Altcode `13` und freie Legendtexte mit
  `alkohol` werden darauf abgebildet; `mehrwertige Alkohole` bleiben bewusst
  der eigenen Polyol-Kennzeichnung zugeordnet.
- Die Radler-Fixture der Gast-Web-Sandbox enthaelt die Alkoholkennzeichnung,
  damit diese Darstellung im regulaeren Testmenue sichtbar bleibt.

## Verification (Gastkarten-Hierarchie)

- Vollstaendiges `kitchenlinkTests`-Target auf iPhone 17 Pro / iOS 26.5:
  **230 bestanden, 2 bewusst uebersprungen, 0 fehlgeschlagen**.
- Gezielter iOS-UI-Smoke fuer Zaehler, fehlenden `Auswaehlen`-Button,
  44-Punkt-Plus und Warenkorb: **bestanden** auf iPhone 17e / iOS 26.5.
- Gast-Web: Typecheck, Lint, **85/85 Tests** und Produktions-Build:
  **bestanden**.
- Mobile Browserpruefung bei 320 x 844 und 390 x 844: kein horizontaler
  Ueberlauf, alle Plus-Touchziele 44 x 44, Konfigurations- und Warenkorbfluss
  bestanden. Der Alkohol-Dialog zeigt Weinglas und Klartext ohne Quellcode;
  Browserkonsole ohne Fehler oder Warnungen.

## Remaining Risk (Gastkarten-Hierarchie)

- Das aktualisierte Gast-Web wurde lokal geprueft, aber noch nicht auf die
  oeffentliche Sandbox ausgerollt.
- Die native Gastkarte wurde funktional im Simulator verifiziert; die
  subjektive Designabnahme auf einem echten iPhone bleibt beim Nutzer.

## Latest Continuation (22. Juli 2026, KL-MENU-008)

- Die Speisekartenzeilen priorisieren jetzt Uebersicht: hoechstens drei
  26-Punkt-Deklarationssymbole plus `+N` teilen sich eine einzige Zubehoerzeile
  mit der Bestellaktion. Bei einfachen, noch nicht gewaehlten Artikeln ohne
  Kennzeichnungen sitzt das Plus direkt beim Preis; Beschreibungen bleiben auf
  zwei Zeilen begrenzt.
- Statische Listen mit Praefixen wie `Variante:`, `Option:` oder `Extra:` sind
  aus der Gastkarte entfernt. Nur semantische Gruppentitel wie `Groesse` oder
  `Dazu` bleiben in der Auswahl sichtbar; kombinierte generische Titel werden
  ebenfalls unterdrueckt.
- Konfigurierbare Gerichte oeffnen in iOS und Gast-Web eine fokussierte Auswahl
  mit Radio-, Mehrfach- oder Mengenlogik, Pflicht- und Maximalregeln,
  Freiauswahlen sowie sofort aktualisiertem Preis. Der Warenkorb fuehrt gleiche
  Gerichte mit unterschiedlichen Auswahlen als getrennte, einzeln regelbare
  Zeilen und zeigt nur die gewaehlten Namen.
- `MenuItemVariant` und der Publish-Payload behalten Preisart, Gruppen-ID/-Titel
  und die vollstaendige Auswahlregel. Wiederholbare Optionen bleiben als
  wiederholte IDs erhalten. Das Gast-Web sendet ausschliesslich opake Option-IDs
  an `guest_web_submit_order_v2`.
- Migration `20260722120000_guest_menu_configurations.sql` fuegt
  `order_items.selected_options`, `operator_publish_menu_v2` und
  `guest_web_submit_order_v2` hinzu. Die Datenbank validiert Gruppen und IDs,
  berechnet reihenfolgeunabhaengig genau einen Festpreis plus die nach
  Freiauswahlen verbleibenden Aufpreise und speichert die Auswahl als
  unveraenderlichen Snapshot.
- Jeder Checkout erhaelt eine zufaellige Attempt-ID, die nur fuer Retries dieses
  Versuchs stabil bleibt. Dadurch koennen zwei Gaeste — oder derselbe Gast
  spaeter — denselben Warenkorb als zwei echte Bestellungen absenden. Die RPC
  gibt Replays zusaetzlich nur an den urspruenglichen `created_by` zurueck.
- Alle Webdialoge setzen und halten den Tastaturfokus und stellen ihn beim
  Schliessen wieder her. Das Hauptzeilen-Minus folgt der zuletzt geaenderten
  Konfiguration; im Warenkorb bleibt jede Zeile direkt steuerbar.
- VoiceOver erhaelt ausgewaehlte/nicht ausgewaehlte Zustaende, gerichtsspezifische
  Hinweise und eindeutige Konfigurations-IDs; die visuellen Touchziele bleiben
  trotz kleiner Piktogramme ausreichend gross.

## Verification (KL-MENU-008)

- iOS-Simulator-Build auf iPhone 17 Pro / iOS 26.5: **bestanden**.
- Komplettes `kitchenlinkTests`-Target: **bestanden**, inklusive der erweiterten
  Import-/Publish-Vertragstests; nur die zwei bewusst gegateten Harness-Tests
  wurden uebersprungen.
- Bestehender UI-Smoke fuer Zaehler, Vorschau-Navigation und kompaktes
  Hinzufuegen auf einem frischen iPhone-17e-Simulator: **bestanden**.
- Gast-Web: Typecheck, Lint, **83/83 Tests** und Produktions-Build: **bestanden**.
- Mobile Browserpruefung bei 390 x 844: kompakte Deklarationszeile, fokussierte
  Groessenauswahl, Preiswechsel 6,90 -> 8,90 Euro sowie konfigurierter Warenkorb
  visuell und interaktiv bestanden.
- Alle acht Migrationen wurden in einer temporaeren lokalen PostgreSQL-Instanz
  kompiliert. Der finale Verhaltenstest veroeffentlichte eine wiederholbare
  Saucenauswahl, berechnete bei `1 inklusive` zweimal Sauce korrekt, speicherte
  beide Vorkommen und unterschied zwei identische Bestellungen verschiedener
  Gaeste. Retry, Fremd-Key-Abwehr, nicht wiederholbare Duplikate und zwei
  unvereinbare Pflicht-Festpreisgruppen wurden ebenfalls geprueft.

## Remaining Risk (KL-MENU-008)

- Die neue Migration und das aktualisierte Gast-Web wurden nicht auf die
  oeffentliche Sandbox ausgerollt. Vor einem Deployment muessen Datenbank und
  Web gemeinsam auf V2 gehoben werden; der bestehende V1-Pfad bleibt additiv
  erhalten.
- Die iOS-Gastvorschau bleibt eine lokale Sandbox-Simulation und sendet keine
  Bestellung. Der produktnaehere End-to-End-Bestellpfad liegt im Gast-Web.

## Latest Continuation (22. Juli 2026, Icon-Ausrichtung)

- Nutzerfeedback bestaetigt: Die Piktogramme sassen im nativen Badge unten in
  der gemeinsamen `ZStack`-Ausrichtung und wirkten dadurch verkleinert und
  unausgewogen.
- `FoodDeclarationGlyphView` verwendet jetzt eine zentrierte `ZStack`.
  `AllergenBadgeView` richtet das Symbol ebenfalls zentriert aus. Der damals
  noch vorhandene Quellcode-Overlay wurde mit der nachfolgenden
  Gastkarten-Entscheidung vollstaendig entfernt.
- Die Web-Badges waren bereits geometrisch zentriert; die mobile Browserpruefung
  bestaetigt die gleiche optische Mitte und unveraenderte 44-Punkt-Touchziele.

## Verification (Icon-Ausrichtung)

- Gezielter `FoodDeclarationCatalogTests`-Lauf: **6/6 bestanden**.
- Gezielter `MenuManualEditorUITests.testManualMenuEditorCoreFlow`: **bestanden**.
- Die exportierten iOS-Screenshots bestaetigten die geometrische Zentrierung;
  der spaeter entfernte Code ist kein Bestandteil des aktuellen Designs mehr.
- Gast-Web bei 390 x 844: **visuell bestanden**; Symbole und Formeln sitzen
  mittig im Rahmen.

## Latest Continuation (22. Juli 2026, KL-MENU-007)

- `ICON_CATALOG_RESEARCH.md` trennt die vollstaendige EU-14-Allergenliste von
  den einschlaegigen deutschen Zusatzstoff-Kennzeichnungstexten, separaten
  Verbraucherhinweisen und der dynamischen EU-Positivliste der E-Nummern.
- Ein gemeinsamer semantischer Katalog fuer iOS und Gast-Web ersetzt die
  fruehere missverstaendliche Annahme universeller Zahlencodes. Quelllegenden
  sind fuer Hauscodes massgeblich; alte 1–14-Werte bleiben nur als lesbarer
  Fallback erhalten. Knoblauch und Zwiebel sind nicht mehr Teil der
  Standard-Allergenauswahl.
- Skalierbare, code-native Piktogramme decken alle 14 Allergene sowie
  Zusatzstoff- und Hinweisgruppen ab. Aehre, Milchkarton und Ei sind nach der
  lokalen Fixture-Haeufigkeit besonders konkret gestaltet.
- Einzelne Symbole sind in der iOS-Gastvorschau, im aktuellen Import-Review und
  im Gast-Web kompakt dargestellt und antippbar. Das aktuelle Detail zeigt
  Klartext, Gruppe, Erlaeuterung und die Grenze, dass das Icon die
  Pflichtkennzeichnung nicht ersetzt; Quellcodes bleiben intern.
- Der manuelle iOS-Editor verwendet dieselbe vollstaendige Auswahl. Sein
  adaptives Auswahlraster loeste im UI-Test unter iOS 26 eine rekursive
  `UICollectionView`-Layoutberechnung aus und wurde durch ein stabiles
  zweispaltiges SwiftUI-`Grid` ersetzt.

## Verification (KL-MENU-007)

- Generischer iOS-Simulator-Build ohne Code-Signing: **bestanden**.
- Komplettes `kitchenlinkTests`-Target auf iPhone 17 Pro / iOS 26.5:
  **228 bestanden, 2 bewusst uebersprungen, 0 fehlgeschlagen**.
- Gezielter UI-End-to-End-Test vom manuellen Editor ueber die Gastvorschau bis
  zum antippbaren Gluten-Detail: **bestanden**; kompakte und grosse Glyphen
  anhand der Test-Screenshots visuell geprueft.
- Gast-Web: Typecheck, Lint, **73/73 Tests** und Produktions-Build:
  **bestanden**. Mobile Browserpruefung bei 390 x 844 inklusive antippbarem
  Gluten-Dialog: **bestanden**, keine Browserfehler oder Warnungen.
- `git diff --check`: **bestanden**.

## Remaining Risk (KL-MENU-007)

- Piktogramme ergaenzen Pflichtangaben nur. Betreiber bleiben fuer Stoff,
  Schwellenwert, Ausnahme und exakten Wortlaut verantwortlich; die Recherche
  ist keine Rechtsberatung.
- Freie Quelllegendtexte werden heuristisch semantisch zugeordnet. Unbekannte
  Hauscodes erhalten gastseitig nur die neutrale Bezeichnung `Weitere Angabe
  der Speisekarte`, statt einen technisch wirkenden Code oder eine falsche
  rechtliche Bedeutung zu zeigen.
- Das Gast-Web wurde lokal geprueft, aber nicht deployt. Die oeffentliche
  Sandbox erhaelt die neue Kollektion erst mit dem naechsten `main`-Deployment.

## Latest Continuation (22. Juli 2026, KL-MENU-006)

- Der Root startet nur noch die aktuelle V2-Business-App. Der sichtbare
  Legacy-Sandbox-Einstieg, der Designwechsel und der doppelte alte
  Import-Review wurden entfernt; Scanner, Fotos und Fixtures fuehren direkt in
  `MenuImportDraftReviewView`.
- Der Draft-Review zeigt Speisen-, Getraenke- und Gesamtzaehler, dekorativen
  Hintergrund, Beschreibungen, strukturierte Allergene/Zusatzstoffe,
  Varianten/Extras, Preisbasis und Bundle-Details. Eine manuelle
  Preiskorrektur behaelt jetzt `per_person` bei; kostenlose Optionen bleiben
  als enthaltene Auswahl erhalten.
- `MenuImportGuestPreviewView` ist die gemeinsame aktuelle Vorschau fuer Import
  und manuellen Editor. Sie enthaelt die drei filterbaren Zaehler, die
  einheitlichen Deklarationssymbole und eine kompakte Mengensteuerung mit
  weiterhin 44-Punkt-Touchzielen.
- Der App-Picker bietet exakt drei Karten: die deterministische dreiseitige
  KitchenLink-Pruefkueche sowie Lichtburg und Alexxanders. Die Pruefkueche wird
  durch `scripts/generate_demo_test_menu.py` reproduzierbar erzeugt und besitzt
  eine maschinenlesbare Truth-Datei. Die historische Gold-Baseline bleibt bei
  ihren bisherigen drei realen Karten; der menschliche Review bekommt die
  Pruefkueche additiv.

## Verification (KL-MENU-006)

- Generischer iOS-Build ohne Code-Signing: **bestanden**.
- Komplettes `kitchenlinkTests`-Target auf iPhone-17-Pro-Simulator:
  **bestanden**, 2 absichtlich gegatete Harness-Tests uebersprungen,
  0 fehlgeschlagen.
- Alle drei generierten Seiten visuell auf Lesbarkeit, Randbeschnitt und
  vorgesehene Feldabdeckung geprueft.
- Gezielte UI-Smokes fuer entfernte Altpfade, exakt drei Fixtures, Zaehler und
  kompakte Mengensteuerung: **bestanden**.
- Historischer Scanner-Gold-Benchmark ueber 14 Seiten: **bestanden**.
- Lokaler Apple-Vision-/Regel-Review ueber 17 Seiten:
  **bestanden** (`run-20260722-005204`); die Prüfküche liefert 157 OCR-Zeilen,
  darunter `39,90 € pro Person`, beide Nullpreis-Optionen und die vorgesehenen
  groß gesetzten Deklarationscodes.
- Ein erster kompletter keyloser KI-Textreview (`run-20260722-003922`) erkannte
  9/9 Kategorien, 23/23 Artikel, 16/7 Speisen/Getränke, 23/23 Beschreibungen
  und 22/22 deklarierte Artikel. Die dabei gefundenen Verluste von
  `price_basis` und Nullpreis-Optionen sind behoben und regressionstestgeschützt.

## Remaining Risk (KL-MENU-006)

- Der lokale Diagnoseparser ist keine Produktionsalternative zum strukturierten
  KI-Pfad und übersegmentiert die absichtlich dichte Prüfküche; seine Aufgabe
  bleibt OCR-/Overlay-Diagnose und der stabile historische Gold-Benchmark.
- Eine erneute externe Vision-Auswertung der finalen Bilder wurde nicht
  durchgeführt, weil die dafür nötige Bildübertragung nicht ausdrücklich
  freigegeben war. Sie ist für den lokalen Abschluss nicht erforderlich.
- Das Gangmenü bleibt korrekt ein `per_person`-Artikel mit vollständiger
  Beschreibung. Die optionale Zerlegung einzelner Gänge in
  `bundleComponents` bleibt eine spätere Ausbaustufe.

## Latest Continuation (19. Juli 2026, sofortige Local-Service-Navigation)

- Der erste Performance-Fix nahm SQLite-/Router-Erzeugung vom Main Actor, der
  Nutzer beobachtete beim allerersten Tap aber weiterhin eine verzoegerte
  Navigation. Der verbleibende konkrete Erstlaufpfad lag in der UI: Sobald der
  Hub seine URL publizierte, erzeugte `venueHubCard` den QR-Code und eine neue
  `CIContext` synchron im SwiftUI-`body` auf dem Main Thread.
- Ein gezielter Test machte den typischen Warm-up sichtbar: Die erste
  QR-Erzeugung dauerte in einem Lauf rund 218 ms, die unmittelbar folgende nur
  rund 20 ms. Auf einem frischen Simulator wurden rund 399 ms gemessen. Diese
  einmalige Core-Image-Arbeit lief genau waehrend des ersten Navigationsaufbaus.
- `KitchenLinkV2LocalOperationsView` ist jetzt eine leichte Ziel-Huelle. Sie
  liefert Navigationstitel und einen sichtbaren Vorbereitungszustand zuerst an
  den `NavigationStack`; die drei Runtime-Modelle werden erst im naechsten
  Scheduler-Turn als Content-View montiert.
- Der QR-Code wird durch `KitchenLinkLocalGuestQRCodeModel` in einem
  `userInitiated` Detached Task als unveraenderliches `CGImage` erzeugt. Im
  Screen bleibt bis dahin ein lokaler Progress-Zustand sichtbar. URL-Wechsel
  werden mit einer Render-ID gegen spaete Ergebnisse abgesichert.
- Zwei Unit-Regressionen pruefen echte QR-Erzeugung und explizit, dass der
  Renderer nicht auf dem Main Thread laeuft. Ein neuer UI-Test fordert den
  Navigationstitel innerhalb eines kurzen Ein-Sekunden-Gates an und wartet
  danach getrennt auf den Hub-Inhalt.
- Vollstaendiges `kitchenlinkTests`-Target auf einem frischen
  iPhone-17-Pro-Max-Simulator: **179 bestanden, 1 bewusst uebersprungen, 0
  fehlgeschlagen**. Der neue UI-Test bestand ebenfalls. Signierter Device-Build
  fuer das verbundene Test-iPhone: **bestanden**.
- Die anschliessende Installation wurde nicht vom Build oder Geraet abgelehnt,
  sondern vom Codex-Freigabesystem wegen erschoepftem Kontingent fuer externe
  Geraeteaktionen. Der gebaute Stand liegt lokal bereit; Installation und
  subjektiver Ersttap-Vergleich bleiben offen.

## Latest Continuation (19. Juli 2026, Startoptimierung fuer PR #29)

- Der Nutzer bestaetigte, dass der automatisch gefundene Mac-Hub auf dem
  echten iPhone korrekt aussieht. Dabei fiel eine kurze Blockade beim
  Navigieren in `Lokaler Service` auf.
- Ursache war die synchrone Erzeugung des Venue-Hubs auf dem `MainActor`:
  SQLite-Verbindung, WAL-/Durability-Pragmas, Schema-Migration und Router
  wurden waehrend der Navigationsanimation aufgebaut.
- Die Servererzeugung laeuft jetzt in einem `userInitiated` Hintergrund-Task;
  nur der publizierte UI-Zustand bleibt auf dem Main Actor. Eine Start-ID
  verhindert zugleich, dass ein inzwischen abgebrochener Aufbau nach schnellem
  Zuruecknavigieren den Hub verspaetet aktiviert.
- Ein neuer Regressionstest bestaetigt explizit, dass die Server-Factory nicht
  auf dem Main Thread laeuft. Der optimierte signierte Build wurde auf dem
  gekoppelten iPhone installiert; der kurze subjektive Geschwindigkeitsvergleich
  steht noch aus.

## Latest Continuation (19. Juli 2026, KL-OFFLINE-008)

- Ein gemeinsamer Bonjour-Vertrag fuer `_kitchenlink-hub._tcp` uebertraegt
  Schema-Version, stabile Hub-ID, Anzeigename und die konkrete lokale
  HTTP-Basisadresse. Ungueltige, unvollstaendige oder unerwartet versionierte
  Datensaetze werden nicht als waehlbarer Hub angeboten.
- iPhone- und macOS-Hub kuendigen denselben Vertrag an. Das iPhone behaelt eine
  stabile Geraete-ID, aktualisiert bei WLAN-/IP-Wechsel nur den TXT-Datensatz
  und entfernt die waehlbare URL, solange keine LAN-Adresse vorhanden ist.
- Die native Business-App sucht im Vordergrund mit `NWBrowser`, filtert den
  eigenen iPhone-Hub und zeigt andere Hubs unter `Anderen Hub verwenden` als
  bewusste Auswahl. Es gibt keine automatische Verbindung; die manuelle
  Adresse bleibt vollstaendig erhalten.
- HTTP-Listener und Bonjour-Ankuendigung sind getrennt. Das verhindert die im
  Wiederholungstest reproduzierte kurze Listener-Unterbrechung, die beim
  nachtraeglichen Austausch von `NWListener.service` auftrat.
- Normale Gastbrowser erhalten absichtlich keine automatische Discovery. Sie
  verwenden weiterhin den sichtbaren QR-Code beziehungsweise die konkrete
  lokale IP-Adresse.

## Verification (KL-OFFLINE-008)

- `KitchenLinkLocalGuestPOC`: **12/12 Tests bestanden**, darunter drei Tests
  fuer Bonjour-Roundtrip, fehlende LAN-Adresse und unsichere/ungueltige URLs.
- Venue-Hub-Testblock nach der Listener-/Bonjour-Trennung **zehnmal
  hintereinander bestanden**; kein erneuter Loopback-Aussetzer.
- Komplettes `kitchenlinkTests`-Target auf dem iPhone-17-Pro-Simulator nach der
  Startoptimierung: **177 bestanden, 1 bewusst uebersprungen, 0
  fehlgeschlagen**.
- Echter macOS-Bonjour-Smoke mit `dns-sd`: `KitchenLink Mac Hub` unter
  `_kitchenlink-hub._tcp.local.` gefunden, auf Port `18080` aufgeloest und
  TXT-Daten `id`, `name`, `url=http://192.168.178.110:18080`, `v=1`
  verifiziert.
- Signierter arm64-Build fuer `Philipps iPhone XR`: **bestanden** und der
  aktuelle Branch-Stand erfolgreich auf dem gekoppelten Geraet installiert.
- `git diff --check`: bestanden.

## Remaining Risk (KL-OFFLINE-008)

- Automatische Anzeige und bewusste Auswahl des Mac-Hubs sind auf dem echten
  iPhone bestaetigt. Offen ist nur noch der subjektive Vergleich, ob die
  Navigation mit dem optimierten Build jetzt unmittelbar reagiert; bis dahin
  bleibt der PR im Draft.
- Discovery ist auf aktive native Operator-Clients und dasselbe erreichbare
  WLAN begrenzt. Hintergrundbetrieb, automatisches Failover, LAN-
  Authentisierung, AP-Isolation, Android und TLS/Trust bleiben ausserhalb
  dieser Scheibe.

## Latest Continuation (19. Juli 2026, PR #27 Integration)

- Der Nutzer bestaetigte den vorbereiteten realen WLAN-aus/an-Test auf dem
  iPhone als vollstaendig funktionsfaehig. Damit ist die offene interaktive
  Recovery-Abnahme bestanden.
- PR #27 war unveraendert, konfliktfrei und mergebar; es gab keine Reviews,
  Kommentare oder konfigurierten GitHub-Actions-Checks. Die lokale Suite, der
  signierte Geraetebuild und die reale Abnahme bildeten den Freigabenachweis.
- PR #27 nach der Nutzerabnahme aus dem Draft genommen und als Merge-Commit
  `dc67ecc` nach `main` integriert. `origin/main` enthaelt den vollstaendigen
  Feature-Stand `4554607`.
- Diesen reinen CURRENT-/Queue-/Handoff-Nachtrag direkt vom gemergten
  `origin/main` abgezweigt; lokales `main` blieb unangetastet, weil es im
  separaten Claude-Worktree ausgecheckt ist.

## Latest Continuation (19. Juli 2026, KL-OFFLINE-007)

- Der Implementierungsstand wurde auf `codex/iphone-hub-network-recovery`
  veroeffentlicht und mit PR #27 nach `main` integriert.
- Der `NWListener` bleibt bei fehlender oder geaenderter WLAN-Adresse aktiv.
  Ein leichter Zwei-Sekunden-Monitor prueft ausschliesslich die iOS-WLAN-
  Schnittstelle `en0`; Tunnel-, Mobilfunk- und Peer-to-Peer-Adressen werden
  nicht als Gastadresse ausgegeben.
- Listener-Port, Loopback-Operatoradresse und SQLite-Event-Log bleiben ueber
  den Wechsel stabil. Nur die optionale Gastadresse wird als Ereignis an das
  View-Model weitergegeben; ein Listenerfehler wird ebenfalls sichtbar
  propagiert.
- Ohne WLAN-Adresse startet der Hub jetzt in `waitingForWiFi`, statt komplett
  zu scheitern. Kuechen-/Kellneransicht und gespeicherte Bestellungen bleiben
  ueber Loopback verfuegbar. Bei Rueckkehr oder IP-Wechsel aktualisieren sich
  Gast-URL, QR-Code und Teilen-Aktion automatisch.
- Die Oberflaeche zeigt den Wartezustand mit `wifi.slash` und erklaert, welche
  lokalen Funktionen weiterlaufen. Foreground-, Sandbox- und WLAN-Hinweise
  bleiben bestehen.

## Verification (KL-OFFLINE-007)

- Gezielte iOS-Hub-Suite: **6/6 bestanden**, darunter Start ohne WLAN,
  Adresse kommt/geht, unveraenderter Port/Loopback und echter HTTP-Bestelllauf.
- Komplettes `kitchenlinkTests`-Target auf iPhone-17-Pro-Simulator:
  **174 bestanden, 1 bewusst uebersprungen, 0 fehlgeschlagen**.
- Signierter arm64-Build fuer `Philipps iPhone XR`: **bestanden**; der aktuelle
  Draft-PR-Stand wurde erfolgreich auf dem gekoppelten Geraet installiert.
- `git diff --check`: bestanden.

## Remaining Risk (KL-OFFLINE-007)

- Bereits auf einem Gastgeraet geoeffnete Seiten unter der alten IP koennen
  nach einem Netzwechsel naturgemaess nicht umgeleitet werden; der sichtbare
  Link und QR-Code auf dem Hub zeigen danach die neue Adresse.
- Der Hub bleibt ein Foreground-Sandbox-PoC. Hintergrundbetrieb, automatische
  Client-Discovery, LAN-Authentisierung, AP-Isolation, Android und TLS/Trust
  bleiben offen; Zahlung und aktive Cloud-Synchronisation sind unveraendert
  nicht freigegeben.

## Latest Continuation (19. Juli 2026, PR #25 Integration)

- PR #25 nach der positiven Mac-zu-iPhone-Abnahme aus dem Draft genommen und
  als Merge-Commit `cbf7196` nach `main` integriert.
- `origin/main` auf den exakten Merge-Stand verifiziert und diesen reinen
  Statusnachtrag direkt davon abgezweigt; lokales `main` blieb unangetastet,
  weil es im separaten Claude-Worktree ausgecheckt ist.
- Keine GitHub-Actions-Checks waren fuer PR #25 konfiguriert. Die neun
  Core-Tests, 172 App-Tests, Simulator-/Geraetebuilds und die reale Abnahme
  waren vor Integration gruen.
- Der GitHub-Ablauf hielt PR #25 bis zur realen Geraeteabnahme bewusst im
  Draft; erst der bestandene Lauf loeste Ready-Status und Merge aus.

## Latest Continuation (19. Juli 2026, echte iPhone-Hub-Abnahme)

- KitchenLink auf dem iPhone in `Lokaler Service` geoeffnet; der Foreground-Hub
  zeigte seine dynamische Gastadresse im gemeinsamen WLAN.
- Die Gastseite auf dem Mac ueber genau diese iPhone-Adresse geoeffnet und dort
  eine echte Bestellung abgegeben. Der fruehere macOS-Server war dafuer nicht
  erforderlich.
- Bestellung erschien live auf demselben iPhone im Kuechenmodus, wechselte nach
  `Bestellung zubereitet` in den Kellnermodus und liess sich dort erfolgreich
  weiterbearbeiten.
- Nutzer bestaetigte den gesamten Mac-zu-iPhone-Ablauf als erfolgreich. Damit
  ist die offene reale Abnahme fuer PR #25 bestanden.

## Latest Continuation (19. Juli 2026, KL-OFFLINE-006)

- Der iPhone-Hub verwendet den bestehenden `KitchenLinkLocalGuestCore` und das
  bestehende `KitchenLinkEventLog` direkt als lokales Swift Package. Die
  Gastseite wurde deshalb in den Core-Ressourcen gebuendelt; der macOS-Server
  verwendet weiterhin exakt dieselbe Seite.
- Neuer Foreground-HTTP-Server auf Apples `NWListener`: lokale WLAN-Adresse,
  dynamischer Port, Bonjour-Ankuendigung, begrenzter HTTP-Parser und
  one-request-per-connection. Bestell-ACKs kommen unveraendert erst nach dem
  atomaren Event-/Outbox-Commit.
- `Lokaler Service` startet standardmaessig dieses iPhone als Hub, zeigt
  QR-Code, URL und Teilen-Aktion und verbindet die Operatorprojektion intern
  ueber `127.0.0.1`. Der gespeicherte macOS-Hub bleibt als bewusster Fallback
  erhalten und wird durch Loopback nicht ueberschrieben.
- Der Hub stoppt im Hintergrund und beim Verlassen der Ansicht. Die Oberflaeche
  kennzeichnet den PoC daher sichtbar als Foreground-Sandbox mit gemeinsamem
  WLAN und empfohlenem Stromanschluss.

## Verification (KL-OFFLINE-006)

- `KitchenLinkLocalGuestPOC`: **9/9 Swift-Tests bestanden**.
- Neue iOS-Hub-Suite: **4/4 bestanden** (HTTP-Parser, Groessenlimit,
  Model-Lifecycle und echter `NWListener`-Loopback mit Health, Order-POST,
  `local-event-log-committed` und anschliessender Kuechenprojektion).
- Local-Operations-Suite: **4/4 bestanden**, einschliesslich Schutz der
  gespeicherten Mac-Fallback-Adresse.
- Komplettes `kitchenlinkTests`-Target: **172 bestanden, 1 bewusst
  uebersprungen, 0 fehlgeschlagen**.
- iPhone-17-Simulator-Build und signierter arm64-Build fuer
  `Philipps iPhone XR`: **bestanden**.
- Finaler signierter Build erfolgreich auf dem iPhone XR installiert.
  Automatischer Start wurde nur vom gesperrten Geraetezustand abgewiesen; das
  ist kein Build- oder Installationsfehler.
- `git diff --check`: bestanden.

## Remaining Risk (KL-OFFLINE-006)

- Der iPhone-gehostete Pfad ist real mit Safari auf dem Mac als Gastgeraet
  bestanden. Android Chrome, AP-Isolation und ein zweites mobiles Gastgeraet
  bleiben separate Kompatibilitaets-Gates.
- Der Hub ist absichtlich nur im Vordergrund aktiv. Kein Background-Mode,
  Failover oder produktiver Dauerbetrieb ist behauptet.
- Bonjour wird angekuendigt, aber automatische Discovery/Adresswechsel sind
  noch nicht implementiert. LAN-Authentisierung, feindliches WLAN,
  Mehrgeraetekonkurrenz, AP-Isolation, Android und TLS/Trust bleiben offen.
- Keine Zahlung und keine aktive Cloud-Synchronisation; Sandbox- und
  Demoablaeufe bleiben erhalten.

## Latest Continuation (19. Juli 2026, PR #23 Integration)

- PR #23 nach der positiven Nutzerabnahme aus dem Draft genommen und als
  Merge-Commit `7376f5a` nach `main` integriert.
- `origin/main` auf den exakten Merge-Stand aktualisiert und diesen reinen
  Statusnachtrag davon abgezweigt.
- Keine GitHub-Actions-Checks waren fuer den PR konfiguriert; Mergebarkeit,
  kompletter lokaler Testnachweis und die reale Zwei-Geraete-Abnahme waren vor
  der Integration gruen.
- Naechste Netzwerk-Gates bleiben Android Chrome, AP-Isolation,
  Bonjour/Discovery, IP-Wechsel und Hub-Lifecycle. Daraus folgt weiterhin
  keine Produktionsfreigabe.

## Latest Continuation (19. Juli 2026, echte Zwei-Geraete-Abnahme)

- KitchenLink auf dem iPhone im Kuechen-Modus geoeffnet und mit dem lokalen
  macOS-Hub im gemeinsamen WLAN verbunden.
- Eine neue Bestellung live von einem zweiten Geraet ueber die lokale Gastseite
  abgegeben.
- Auftrag erschien live im Kuechen-Modus, wechselte nach
  `Bestellung zubereitet` in den Kellner-Modus und liess sich dort mit
  `Bestellung serviert` abschliessen.
- Nutzer bestaetigte den gesamten Lauf als erfolgreich. Damit ist die bisher
  offene interaktive Geraeteabnahme fuer PR #23 bestanden.

## Latest Continuation (18. Juli 2026, KL-OFFLINE-005)

- PR #22 (`codex/fix-lan-order-uuid`) vor Beginn als Merge-Commit `e93393f`
  nach `main` integriert und den neuen Branch exakt davon erstellt.
- Der lokale Hostsurrogat bietet jetzt `GET /operator/orders` und
  `POST /operator/orders/{id}/status`. Neue Gastbestellungen starten in der
  Operatorprojektion als `preparing`; nur `ready` und danach `served` sind
  erlaubt. Jeder Schritt ist ein eigenes Event mit optimistischer Revision und
  Cloud-Outbox. Auch ein erst nach `served` eintreffender `ready`-Retry liefert
  die urspruengliche Receipt statt einen falschen Konflikt.
- Neue V2-Ansicht `Lokaler Service` auf dem iPhone: editierbare, gespeicherte
  Hub-Adresse, 1-Sekunden-Polling, Kueche/Kellner-Umschaltung,
  `Bestellung zubereitet` und `Bestellung serviert`. Die Ansicht mappt auf die
  bestehende `LiveOrderMessage`-/`OrderLifecycleStatus`-Domaene.
- Statische App-Info-Plist ergaenzt, damit die iOS-Berechtigungsbeschreibung
  und `NSAllowsLocalNetworking` tatsaechlich im Produkt landen. Der zuvor
  versuchte flache generierte Build-Key erzeugte den verschachtelten ATS-Wert
  nicht und wurde vor Abschluss ersetzt.

## Verification (KL-OFFLINE-005)

- Hostsurrogat: **9/9 Swift-Tests bestanden**.
- iOS: fokussierte Local-Operations-Tests **3/3 bestanden**; komplettes
  `kitchenlinkTests`-Target **167 bestanden, 1 bewusst uebersprungen, 0
  fehlgeschlagen**.
- Echter HTTP-Ablauf: Bestellung 201/`preparing`, Status 201/`ready`, danach
  201/`served`; Projektion nach jedem Schritt geprueft. Verzoegerter Ready-
  Retry nach Served: 200 mit der urspruenglichen Event-ID und `replayed=true`.
- App fuer Simulator, generisches iOS und das gekoppelte echte iPhone gebaut.
  Signierter Build erfolgreich auf `Philipps iPhone XR` installiert. Der
  automatische Start wurde nur durch den gesperrten Geraetezustand abgewiesen.
- Gebautes Info.plist kontrolliert: lokale Netzwerkbeschreibung und
  `NSAppTransportSecurity.NSAllowsLocalNetworking = true` vorhanden.
- Echter Zwei-Geraete-Lauf im Referenz-WLAN: zweites Geraet bestellt lokal,
  iPhone empfaengt in Kueche, reicht an Kellner weiter und schliesst als
  serviert ab: **vom Nutzer bestanden bestaetigt**.

## Remaining Risk (KL-OFFLINE-005)

- Polling und feste/editierbare IP sind eine Sandbox-Naht. Bonjour/Discovery,
  IP-Wechsel, Hintergrundbetrieb, Push, Mehrgeraetekonkurrenz, AP-Isolation,
  Android und TLS/Trust sind nicht geloest.
- Der macOS-Hostsurrogat bleibt sequentiell und nicht fuer Produktion oder ein
  feindliches LAN gehaertet. Keine Zahlung oder Cloud-Synchronisation wurde
  aktiviert; Sandboxkennzeichnung und bestehende Demos bleiben erhalten.

## Latest Continuation (18. Juli 2026, iPhone-LAN-Fund)

- Der erste echte iPhone-Safari-Lauf erreichte die Gastseite im WLAN, blieb
  nach dem Absenden aber bei „Bestellung wird lokal gespeichert …“ stehen.
- LAN-Endpunkt separat mit HTTP 201 und lokalem Commit verifiziert. Im Browser
  gegen die LAN-IP reproduziert: Plain-HTTP ist kein sicherer Kontext und
  `window.crypto`/`crypto.randomUUID()` war nicht verfügbar. Die Exception lag
  vor dem `try/catch`, daher blieb der Zwischenzustand sichtbar.
- Fix auf `codex/fix-lan-order-uuid`: LAN-taugliche UUID-Fallback-Erzeugung,
  gesamter Sendeaufbau innerhalb der Fehlerbehandlung und ein stabiler
  `pendingOrder`-Snapshot. Ein Retry derselben Bestellung behält dadurch den
  Idempotenzschlüssel statt eine mögliche Doppelbestellung zu erzeugen.
- Verifikation: 6/6 Swift-Tests; mobile Bestellung über
  `http://192.168.178.110:8080` trotz nicht verfügbarem Web Crypto erfolgreich
  als `lokal #1`, keine Browser-Warnungen oder -Fehler.

## Latest Continuation (18. Juli 2026, PR #20 Integration)

- PR #20 nach dem Integrationsreview aus dem Draft genommen und als Merge-
  Commit `be54d60` nach `main` integriert.
- `origin/main` auf den Merge-Commit aktualisiert und diesen CURRENT-/Queue-
  Nachtrag von der exakten Integrationsbasis angelegt.
- Vor dem Merge wurden zwei Review-Härtungen ergänzt: JSON-Inhaltstyp-Pflicht
  für Order-Writes und DOM-sicheres Menü-Rendering. Danach erneut 6/6 Tests und
  eine mobile Browserbestellung ohne Warnungen oder Fehler.
- Der nächste Gate bleibt unverändert: iOS Safari und Android Chrome müssen den
  lokalen Top-Level-Pfad im Referenz-WLAN tatsächlich erreichen und bestellen.

## Latest Continuation (18. Juli 2026, KL-OFFLINE-004)

- PR #19 mit der bestaetigten Anforderung zur lokalen Gastbestellung nach
  `main` gemergt (`f6c8821`) und den Implementierungsbranch davon erstellt.
- Neues isoliertes Swift Package `prototypes/KitchenLinkLocalGuestPOC/`:
  macOS-LAN-Server, same-origin Gastseite, `/bootstrap`, `/health` und
  `POST /orders`.
- Das bestehende `KitchenLinkEventLog` ist die einzige Annahmenaht. Ein
  `accepted`-Receipt wird erst gebaut, nachdem Event und Cloud-Outbox atomar
  committed sind. Replay liefert Event-ID/Sequenz des Originals; ein gleicher
  Key mit anderem kanonischen Payload ergibt HTTP 409.
- Artikel und Mengen werden gegen die lokale Sandbox-Karte geprueft; Preise und
  Gesamtbetrag entstehen serverseitig. Ein vom Browser gesendeter Gesamtbetrag
  ist nicht vertrauenswuerdig und beeinflusst weder Payload noch ACK.
- Der Browser oeffnet die Gastseite direkt lokal. Es gibt absichtlich keinen
  Cross-Origin-Fetch von der HTTPS-Cloudseite zum HTTP-Hub.
- Commit `ee8c62e` ist auf `codex/local-guest-ordering-poc` gepusht; Draft PR
  #20 zielt auf `main`.

## Verification (KL-OFFLINE-004)

- `swift test`: **6/6 bestanden**.
- HTTP-Smoke mit echtem Server: `/health` 200, Gastseite 200, erste Bestellung
  201 nach Commit, identischer Retry 200 mit gleicher Event-ID/Sequenz,
  Same-Key/Different-Payload 409. Serverpreis 900 Cent statt manipuliertem
  Clientwert 1 Cent.
- Mobile Browserpruefung bei 390 x 844: Karte vollstaendig gerendert,
  Warenkorb bedienbar, lokale Bestellung mit `lokal #1` bestaetigt und danach
  zurueckgesetzt; keine Browser-Warnungen oder -Fehler.
- `git diff --check`: bestanden.

## Integration Review (PR #20)

- PR gegen den exakten `main`-Stand geprueft: mergebar, keine offenen Reviews,
  Kommentare oder CI-Fehler.
- Vor Integration zwei Härtungen eingearbeitet: `POST /orders` akzeptiert nur
  noch `application/json`, sodass einfache Cross-Origin-Form-/Text-Requests
  keine lokale Bestellung ausloesen koennen; Menüdaten werden mit DOM-
  `textContent` statt HTML-Interpolation gerendert.
- Danach erneut 6/6 Swift-Tests und eine echte mobile Browserbestellung bei
  390 x 844: `lokal #1`, keine Browser-Warnungen oder -Fehler.

## Remaining Risk (KL-OFFLINE-004)

- Der Server ist bewusst ein sequentieller macOS-Entwickler-Surrogat. Er ist
  kein iOS-Hub und nicht fuer Produktion, Last oder ein feindliches LAN
  gehaertet.
- QR-Erzeugung, Bonjour, DHCP/IP-Wechsel, AP-Isolation, iOS Safari, Android
  Chrome, Hub-App-Lifecycle, TLS/Trust und Failover sind nicht bewiesen.
- Keine Zahlung und keine Cloud-Synchronisation; der `.cloud`-Outboxeintrag
  bleibt lokal `pending`. Das Sandbox- und Produktionslabeling bleibt erhalten.

## Latest Continuation (18. Juli 2026, lokale Gastbestellung)

- Der Nutzer hat explizit entschieden, dass Gaeste bei Cloud-Ausfall lokal
  bestellen koennen muessen.
- Entscheidung in `DECISIONS.md` und Blueprint §16.2 als verbindliche
  Sandbox-Beta-Anforderung festgehalten: Restaurant-WLAN/lokale Oberflaeche,
  ACK erst nach dauerhafter Speicherung auf einem autoritativen Venue-Knoten.
- `CURRENT.md`, `WORK_QUEUE.md` und die Offline-Hub-Integrationslesart
  nachgezogen. Der Verzicht auf lokalen Gastzugriff ist keine Option mehr.
- Keine konkrete Transporttechnik freigegeben. Lokale Top-Level-Zustellung,
  QR-/Bootstrap-Wechsel, AP-Isolation, TLS/Trust und Failover muessen vor
  Netzwerkcode auf echten Geraeten nachgewiesen werden.

## Latest Continuation (18. Juli 2026, PR #17 Integration)

- Cleanup-PR #17 aus dem Draft genommen und als Merge-Commit `a743723` nach
  `main` integriert.
- `origin/main` und den gemergten `CURRENT.md`-Stand verifiziert.
- Oeffentlicher Read-only-Smoke auf
  `https://kitchenlink.luneq.eu/alte-muehle/menu`: HTTP 200.
- Diesen reinen Doku-Follow-up angelegt, weil die bisherige Ueberschrift
  unmittelbar nach dem Merge noch PR #15 als letzten Merge bezeichnete.

## Latest Continuation (18. Juli 2026, PR #15 Review)

- PR #15 (`KL-INVENTORY-002`) gegen die Inventory-Domain, den aktuellen
  Designvertrag und die echte Simulatoransicht geprueft.
- Der erste Screenshot zeigte einen fachlichen Merge-Blocker: Die vollstaendige
  Zutaten-mal-Lagerorte-Projektion meldete nicht gefuehrte Artikel als Bestand
  `0` und erzeugte dadurch falsche Warnungen, etwa Wein in der Kueche. Die
  Operator-Ansicht zeigt jetzt nur Paare mit Ledger-Aktivitaet. Ein einmal auf
  `0` gefallener, zuvor gefuehrter Artikel bleibt sichtbar.
- Pflichtinformationen werden nicht mehr abgeschnitten. Physisch, reserviert
  und verfuegbar sind explizit sichtbar; Minimum/Ziel bzw. der kritische
  Buchungshinweis bleiben in Klartext erhalten. Header und Zahlenblock stapeln
  sich bei Accessibility-Dynamic-Type-Groessen.
- Den im Dunkelmodus unsichtbaren Text des primaeren Demo-Buttons durch eine
  robuste explizite Symbol-Text-Komposition korrigiert.
- Die Sandbox-Bezeichnung `Kueche` auf `Küche` korrigiert und die
  Projektionsabdeckung auf 13 Tests erweitert, einschliesslich eines Guards
  gegen lagerortuebergreifende Fehlalarme.

## Verification (PR #15 Review)

- Alle 13 `KitchenLinkV2InventoryStockProjectionTests`: **bestanden**.
- Vollstaendiges `kitchenlinkTests`-Target: **bestanden**; der absichtlich
  gegatete OCR-Benchmark wurde uebersprungen.
- Screenshot-UI-Test im Hell- und Dunkelmodus: **bestanden**; beide
  Bestandsansichten visuell geprueft.
- Der erste komplette UI-Lauf hatte nach einem vom Simulator abgewiesenen
  XCTest-Runner-Start drei Navigationsfehler. Genau diese drei Tests wurden auf
  einem frischen Lauf wiederholt und sind **alle bestanden**.
- `git diff --check`: keine Whitespace-Fehler.

## Remaining Risk (PR #15 Review)

- Bis ein eigener lagerortspezifischer Sortimentsvertrag existiert, dient
  Ledger-Aktivitaet als konservativer Sichtbarkeitsnachweis. Das verhindert
  Fehlalarme, kann aber einen neu geplanten Artikel ohne erste Buchung noch
  nicht als `0` anzeigen. Die Domain-Projektion selbst bleibt unveraendert.
- Die Ansicht bleibt bewusst read-only und sandbox-lokal; keine produktive
  Persistenz oder Bestellautomatik wurde aktiviert.

## Scope

The user reported the live guest-web deployment and ended the broader
multi-model working setup. This branch aligns the repository with the actual
integrated state and records Claude Code plus Codex as the only active agents
until further notice. Earlier GLM, DeepSeek, Kimi and MiniMax contributions and
handoffs remain historical context.

The previously open GLM PR #15 (`KL-INVENTORY-002`) was reviewed, corrected and
merged before this cleanup was rebased. Its implementation and review record
remain intact; the cleanup itself stays focused on repository, collaboration
and guest-web maintenance.

## Changes

- Replaced the unusable root `README.md` (two insulting lines) with a proper
  project entry point, live sandbox link, repository map, local guest-web setup
  and source-of-truth links.
- Updated `CURRENT.md`, `DECISIONS.md`, `AGENTS.md`, `PEER_WORKFLOW.md` and the
  queue header for the live Hostinger/Supabase sandbox and the Claude/Codex-only
  working setup.
- Corrected stale Vercel, three-migration, local-menu-only and no-order claims
  in the guest-web README and sandbox setup guide. ADR-001 now clearly marks
  its hosting comparison as historical for sandbox use.
- Corrected `menu-loader.ts`: it previously claimed to respect database
  `sort_order` but actually sorted items by slug. The mapper now preserves
  category/item sort order with a slug tie-breaker; the load-bearing
  `GuestMenuItem.id == menu_items.slug` invariant is unchanged. Added a
  regression assertion whose slug order deliberately differs from DB order.
- Added a narrow npm override from Next.js's pinned vulnerable PostCSS 8.4.31
  to compatible PostCSS 8.5.19. The lockfile was regenerated; audit findings
  fell from two moderate entries to zero.

## Verification

From `guest-web/` after a clean dependency install:

- `npm run typecheck` — passed
- `npm run lint` — passed
- `npm test` — 50/50 passed
- `npm run build` — passed; `/[venueSlug]/menu` remains 1-minute ISR
- `npm run test:integration` — 8 tests skipped as designed without local
  sandbox credentials/`KL_INTEGRATION=1`; earlier real-instance results remain
  documented, but were not rerun in this worktree
- `npm audit --json` — 0 vulnerabilities
- `git diff --check` — passed
- Public read-only smoke: `https://kitchenlink.luneq.eu/alte-muehle/menu`
  returned HTTP 200 via Hostinger/Next.js cache and contained the expected
  Alte Muehle menu. No live order was submitted during this cleanup.

## Remaining / Recommended Next Step

1. Product decisions for the network-side venue hub, PWA/offline behavior,
   anonymous-user retention and production hosting remain open.
