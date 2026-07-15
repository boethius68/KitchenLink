# KitchenLink in Claude Design entwickeln

**Stand:** 14. Juli 2026
**Ziel:** Eine eigenständige, freundlichere Designsprache entwickeln, bevor sie in
SwiftUI und Web umgesetzt wird.

## 1. Warum wir neu explorieren

Der bisherige Entwurf ist ordentlich und klar, besitzt aber noch keine ausreichend
erkennbare eigene Designsprache. Er wirkt zu kontrolliert und nicht freundlich
genug. Claude Design soll ihn deshalb nicht verschönern, sondern drei neue,
tatsächlich unterschiedliche visuelle Territorien entwickeln.

Dabei bedeutet **freundlich** nicht niedlich, verspielt oder illustrativ. Die
Freundlichkeit soll aus Typografie, Rhythmus, Sprache, Form, Farbe und Verhalten
entstehen. **Eigenständig** bedeutet eine wiedererkennbare Gestaltungslogik, die
sich durch Logo, Layout, Komponenten, Icons und Bewegung zieht.

## 2. Claude Design öffnen

1. Claude im Browser öffnen und `https://claude.ai/design` aufrufen. Alternativ in
   Claude Desktop links **Design** wählen.
2. Ein neues Designprojekt mit dem Namen **KitchenLink Product Design** anlegen.
3. Noch kein GitHub-Repository und nicht den vollständigen Code importieren.
4. Zuerst nur die vier Dateien aus Abschnitt 3 anhängen.

Claude Design befindet sich in der Beta und ist derzeit in Pro-, Max-, Team- und
Enterprise-Tarifen verfügbar. Falls **Design** nicht erscheint, zuerst Tarif und
Workspace-Freigabe prüfen.

## 3. Dateien für die erste Runde

Diese Dateien hochladen:

1. `docs/PRODUCT_BLUEPRINT.md` - verbindlicher Produktumfang und Rollen
2. `docs/design/DESIGN_DIRECTION.md` - Prinzipien plus klar markierter Fehlversuch
3. `docs/design/app-direction.png` - bisheriger App-Entwurf als Negativreferenz
4. `docs/design/logo-directions.png` - bisherige Logoideen als Negativreferenz

Den kompletten Quellcode zunächst bewusst nicht hochladen. Der aktuelle Prototyp
enthält provisorische Designentscheidungen und würde die Exploration unnötig
verengen. Code und GitHub kommen erst nach der Richtungsentscheidung hinzu.

## 4. Erster Prompt: drei Designterritorien

Den folgenden Text unverändert als erste Nachricht senden:

```text
Du arbeitest als Senior Product Designer und Brand Designer an KitchenLink.

KitchenLink ist ein smartphone-first Betriebssystem für einfache Restaurants,
Bars und Cafes. Gäste bestellen und bezahlen im Browser oder später in der App.
Mitarbeiter führen Service, Küche, Kasse und Schichten. Betreiber verwalten den
gesamten Betrieb bis hin zu Warenwirtschaft und später Abrechnung. Ein Restaurant
soll grundsätzlich mit iPhones und iPads statt mit einem teuren Hardwarepaket
betrieben werden können.

Lies zuerst alle angehängten Dateien. Der Product Blueprint ist inhaltlich
verbindlich. DESIGN_DIRECTION.md und die beiden PNGs sind KEINE freigegebene
Designrichtung. Sie zeigen einen sauberen, aber zu kontrollierten, zu generischen
und noch nicht freundlichen Entwurf. Bitte poliere oder kopiere ihn nicht.

Zielgefühl:
- einfach und selbstverständlich, ohne sich erklären zu müssen
- frisch, aber nicht aufgesetzt oder trendgetrieben
- freundlich und menschlich, aber weder niedlich noch verspielt
- professionell im hektischen Betrieb, aber nicht wie Unternehmenssoftware
- als eigene Marke erkennbar, ohne dem Restaurant im Gasterlebnis die Show zu stehlen

Bevor du entwirfst, stelle mir hoechstens drei praezise Fragen, deren Antworten
die visuelle Richtung wirklich veraendern. Keine allgemeinen Workshopfragen.

Entwickle danach drei klar voneinander getrennte visuelle Territorien. Es duerfen
nicht nur drei Farbvarianten desselben Systems sein. Zeige fuer jedes Territorium:
- eine kurze Markenthese und einen passenden Arbeitsnamen
- eine eigene typografische Stimme
- Farb- und Materiallogik
- eine wiedererkennbare Form- und Layoutgrammatik
- Icon- und Illustrationsprinzip
- eine charakteristische Interaktion oder Bewegung
- eine Logoidee als Zeichen plus Wortmarke
- dieselben drei Screens: Speisekarte scannen, Betreiber-Startseite "Heute",
  mobile Gast-Speisekarte eines Restaurants
- je einen kleinen Ausschnitt fuer einen hektischen Betriebszustand, etwa neue
  Bestellung, Warnung oder ausstehende Zahlung

Die drei Screens muessen pro Territorium denselben Inhalt verwenden, damit sie
vergleichbar bleiben. Zeige iPhone zuerst; beruecksichtige aber, dass das System
spaeter auch auf iPad und im Web funktionieren muss.

Vermeide:
- typische gruene SaaS-Dashboards und Fintech-Aesthetik
- lila Verlaeufe, Glassmorphism und dekorative Effekte
- Karten um jeden Inhalt, Pillen fuer jedes Label und uebermaessige Rundungen
- Kochmuetzen, Besteck, Teller, QR-Codes oder Kettenglieder als offensichtliches Logo
- austauschbare Stock-Illustrationen und freundliche Maskottchen als Abkuerzung
- lange Erklaertexte in der Produktoberflaeche

Baue noch keine vollstaendige App und vermische die Territorien noch nicht.
Erstelle zuerst ein gut vergleichbares Exploration Board und erklaere knapp,
welche konkrete Gestaltungsregel jedes Territorium unverwechselbar macht.
```

## 5. Die Rueckfragen beantworten

Claude soll vor dem Entwurf maximal drei Fragen stellen. Antworten immer konkret
und aus dem Bauch heraus geben. Hilfreiche Formulierungen sind zum Beispiel:

- "Eher vertraut und warm als technisch, aber ohne Retro-Gastronomie."
- "Die Business-App darf KitchenLink deutlich tragen; beim Gast fuehrt das Restaurant."
- "Ich will Charakter ueber Typografie und Komposition, nicht ueber Dekoration."

Wenn eine Frage keinen echten Einfluss auf den Entwurf hat, antworten:
"Triff dafuer selbst eine begruendete Annahme und halte sie sichtbar fest."

## 6. Territorien richtig vergleichen

Nicht sofort einzelne Farben oder Buttons kommentieren. Zuerst pruefen:

1. Welche Richtung fuehlt sich ohne Erklaerung am ehesten nach KitchenLink an?
2. Welche bleibt bei Scan, Management und Gast glaubwuerdig?
3. Welche ist freundlich, ohne im Betriebsstress weich oder langsam zu wirken?
4. Welche besitzt eine Regel, die auch nach 50 weiteren Screens noch erkennbar ist?
5. Welche gibt der Restaurantmarke im Gastmodus genug Raum?

Danach diesen Prompt senden:

```text
Vermische die drei Territorien noch nicht. Bewerte sie zuerst streng anhand dieser
fuenf Kriterien: Selbstverstaendlichkeit, Eigenstaendigkeit, Freundlichkeit,
Betriebstauglichkeit und Flexibilitaet fuer Restaurantmarken. Nenne pro Richtung
den staerksten Beleg im Entwurf, das groesste Risiko und was bei einer Skalierung
auf 50 Screens wahrscheinlich generisch werden wuerde. Gib keine Siegerempfehlung,
bevor ich meine eigene Praeferenz genannt habe.
```

## 7. Praezises Feedback geben

Kommentare sollten die Wirkung und nicht vorschnell die Loesung benennen.

Gut:

- "Dieser Screen fuehlt sich noch wie Fintech an, nicht wie ein lebendiger Betrieb."
- "Die Freundlichkeit kommt nur aus der Farbe. Sie muss auch in Typografie und
  Anordnung spuerbar sein."
- "Die Formensprache ist angenehm, aber noch nicht exklusiv fuer KitchenLink."
- "Im Gastmodus ist KitchenLink zu laut; das Restaurant muss zuerst wahrnehmbar sein."
- "Teste dieselbe Logik mit sechs gleichzeitig eintreffenden Bestellungen."

Zu ungenau:

- "Mach es moderner."
- "Mach es freundlicher."
- "Ich mag das Gruen nicht."
- "Mach noch eine Variante."

Vor groesseren Aenderungen in Claude Design immer schreiben:

```text
Speichere den aktuellen Stand als eigene Richtung und erstelle die naechste
Iteration separat. Ueberschreibe die bisherige Version nicht.
```

## 8. Gewaehlte Richtung ausarbeiten

Erst wenn ein Territorium gewaehlt ist, diesen Prompt senden:

```text
Richtung [NAME] ist die Arbeitsgrundlage. Entwickle sie jetzt zu einem belastbaren
KitchenLink-System, ohne Elemente der anderen Richtungen automatisch einzumischen.

Arbeite in dieser Reihenfolge:
1. Markenprinzip und wiedererkennbare Gestaltungsregel schaerfen.
2. Logo als App-Icon, Wortmarke, monochrom und in 20 px testen.
3. Typografie, Farbe, Abstaende, Radien, Linien, Flaechen und Icons als Tokens festlegen.
4. Zustaende fuer neu, aktiv, bereit, bezahlt, Warnung, Fehler und offline definieren.
5. Die drei Kernscreens in iPhone-Breite finalisieren.
6. Einen Kitchen-Display-Screen auf iPad und einen Management-Screen im Web zeigen.
7. Barrierefreiheit, grosse Schrift, Kontrast und einhaendige Bedienung pruefen.

Zeige bei jeder Entscheidung, wie sie aus dem Markenprinzip folgt. Wenn eine
Komponente nur deshalb so aussieht, weil sie bei anderen Apps ueblich ist, markiere
sie als noch ungeloest.
```

## 9. Wann Code hinzukommt

Erst nach Freigabe von Logo, Typografie, Farbe, Formgrammatik und den drei
Kernscreens wird der Code verbunden. Dann gibt es zwei Wege:

### Einfacher Weg

In Claude Design **Export** beziehungsweise **Handoff to Claude Code** waehlen und
das erzeugte Paket in einem neuen Implementierungs-Task verwenden.

### Direkte Verbindung mit Claude Code

Im Terminal einmalig ausfuehren:

```bash
claude mcp add --scope user --transport http claude-design https://api.anthropic.com/v1/design/mcp
```

Danach Claude Code starten und anmelden:

```text
/design-login
```

Der Code-Handoff ist kein Ersatz fuer die Designfreigabe. Vorher bleibt der
funktionierende Sandbox-Prototyp unangetastet; die neue Oberflaeche wird danach
schrittweise und testbar uebertragen.

## 10. Ergebnis der Designphase

Die Designphase ist erst abgeschlossen, wenn folgende Artefakte vorliegen:

- freigegebene Markenthese und Gestaltungsregel
- finales Logo mit Klein-, Monochrom- und App-Icon-Test
- definierte Design-Tokens fuer iPhone, iPad und Web
- Status- und Offline-System fuer den Restaurantbetrieb
- freigegebene Kernscreens fuer Scan, Heute und Gastkarte
- je ein belastbarer Screen fuer Service, Kueche, Kasse und Schichtplanung
- Komponentenuebersicht mit normalen, aktiven, leeren, fehlerhaften und
  deaktivierten Zustaenden
- exportierbarer Handoff fuer die Implementierung

## Offizielle Hilfe

- Produkt: `https://claude.com/product/design`
- Einstieg: `https://support.claude.com/en/articles/14604416-get-started-with-claude-design`
