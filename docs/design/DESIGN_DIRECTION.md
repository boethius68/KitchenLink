# KitchenLink Design Direction

**Stand:** 14. Juli 2026
**Status:** Nicht freigegebener Ausgangsentwurf

> **Review vom 14. Juli 2026:** Die Richtung ist sauber, aber noch nicht eigenständig
> und freundlich genug. Weder Logo noch visuelles System sind freigegeben. Die
> vorhandenen Boards dienen der nächsten Exploration als Referenz dafür, was nicht
> lediglich weiter poliert werden soll.

## 1. Ausgangspunkt

KitchenLink soll Einfachheit vermitteln, frisch wirken, aber nie aufgesetzt erscheinen. Das Produkt tritt mit Selbstverständlichkeit auf. Es soll sich im täglichen Betrieb nicht erst erklären müssen.

Die Designthese lautet deshalb:

> **KitchenLink bringt Ruhe und Klarheit in einen lebendigen Betrieb, ohne sich selbst in den Vordergrund zu stellen.**

Der bisherige scan-first Bildschirm und das bestehende Pfannen-/Kochsymbol sind technische beziehungsweise historische Prototypen. Sie sind nicht das angestrebte Enddesign.

## 2. Markencharakter

### KitchenLink ist

- klar, ohne steril zu sein
- frisch, ohne Trendfarben und Effekte vorzuführen
- freundlich, ohne verspielt zu werden
- schnell erfassbar, ohne banal zu wirken
- professionell, ohne wie Unternehmenssoftware auszusehen
- präsent, wenn eine Entscheidung nötig ist, sonst zurückhaltend

### KitchenLink ist nicht

- eine klassische Kassensystem-Marke
- ein Fintech mit Gastronomie-Dekoration
- eine App voller Erklärtexte, Assistenten und Tutorialkarten
- ein austauschbares grünes SaaS-Dashboard
- eine Sammlung gleich gewichteter Module
- eine Marke aus Kochmütze, Besteck, Teller oder QR-Code

## 3. Positionierung im visuellen Markt

Restaurant-Systeme positionieren sich überwiegend über Kasse, Hardware, Fiskalkonformität und Stressreduktion. Beispiele sind [orderbird](https://www.orderbird.com/de/), [Lightspeed Restaurant](https://www.lightspeedhq.com/pos/restaurant/), [Toast](https://pos.toasttab.com/) und [Square Restaurants](https://squareup.com/us/en/restaurants).

KitchenLink setzt sich davon ab:

- Das Smartphone ist das normale Werkzeug, nicht die kleine Variante einer Kasse.
- Die Oberfläche zeigt den aktuellen Betrieb, nicht den Produktkatalog.
- Der Gast erlebt zuerst das Restaurant, nicht KitchenLink.
- Komplexität wird durch Rollen und Kontext reduziert, nicht durch das Weglassen fachlicher Tiefe.
- Die Marke signalisiert Verbindung und Fluss, nicht Küchentechnik.

## 4. Markenarchitektur

Die sichtbare Hauptmarke lautet immer **KitchenLink**.

- **KitchenLink Business** ist die Mitarbeiter- und Betreiberoberfläche.
- **KitchenLink** im Gastkontext bleibt dezent und steht hinter der Venue-Marke.
- Rollen wie Service, Küche, Management oder Fahrer sind Betriebsmodi, keine Untermarken.
- Funktionsnamen wie Pay, Inventory oder Staff werden nicht als eigene Logos aufgebaut.

## 5. Logoanforderungen

Das neue Logo muss:

- in 20 bis 24 Punkten noch eindeutig sein
- monochrom funktionieren
- als App-Icon, Wortmarke und kleine Signatur funktionieren
- Verbindung oder Übergabe ausdrücken, ohne ein gewöhnliches Kettenglied zu kopieren
- nicht ausschließlich Küche oder Essen darstellen
- ohne Farbverlauf, Schatten oder feine Binnenlinien auskommen
- neben einer Restaurantmarke zurückhaltend genug sein

### Ungeprüfte Ausgangsidee: Link Aperture

Zwei offene, ineinandergreifende Formen bilden einen gemeinsamen Durchgang. Das Zeichen steht gleichzeitig für:

- Gast und Betrieb
- Service und Küche
- lokal und Cloud
- Übergabe statt isolierter Module
- eine offene Plattform statt geschlossener Hardware

Die Öffnung ist wichtiger als das einzelne Element. Dadurch wirkt das Zeichen ruhig, funktional und nicht illustrativ.

Die Alternativen **Pass** und **KL Monogram** werden als historische Vergleiche
erhalten. Keine der drei Richtungen ist aktuell bevorzugt oder freigegeben.

## 6. Bisheriges visuelles Experiment

Die folgenden Werte dokumentieren den ersten Entwurf. Sie sind keine verbindlichen
Design-Tokens und dürfen in der nächsten Exploration vollständig ersetzt werden.

### Farbe

| Token | Wert | Aufgabe |
| --- | --- | --- |
| Ink | `#17332E` | Primärtext, App-Icon, starke Flächen |
| Leaf | `#2F765C` | aktive Zustände und primäre Aktionen |
| Celery | `#DCE9C9` | frische, zurückhaltende Hervorhebung |
| Linen | `#F3F0E8` | warme Grundfläche |
| Paper | `#FCFBF7` | Arbeitsflächen |
| Graphite | `#27302E` | neutraler Fließtext |
| Clay | `#D96F45` | Aufmerksamkeit, nicht Dekoration |
| Signal Red | `#B74235` | Fehler und kritische Betriebszustände |

Die Frische entsteht aus dem Verhältnis von warmem Neutralraum und gezieltem Grün, nicht aus großen grünen Verläufen. Clay und Rot sind semantische Signalfarben.

### Typografie

Erste Produktrichtung: **Instrument Sans** als gemeinsame Schrift für Native App
und Web. Sie ist sachlich und offen, kann aber ein Grund dafür sein, dass der
Entwurf noch zu kontrolliert und generisch wirkt. Sie ist daher nicht festgelegt.

- klare Größenhierarchie statt vieler Schriftschnitte
- Zahlen und Beträge erhalten stabile, tabellarische Ziffern
- keine Versalien für längere Labels
- keine dekorative Zweitschrift im operativen Produkt
- die Wortmarke wird optisch angepasst und nicht nur als gesetzter Text exportiert

### Form und Fläche

- wenige echte Flächen statt einer Karte um jeden Inhalt
- Radien nach Funktion: 12 Punkte für Controls, 18 Punkte für große Arbeitsflächen
- Linien und Weißraum strukturieren Listen
- Schatten nur für räumliche Ebenen wie Sheets oder schwebende Kassenaktionen
- keine Glasoptik als allgemeines Gestaltungsmittel
- keine Pillen für gewöhnliche Texte oder jede Statusanzeige

### Icons

- einfache, einfarbige Linienicons
- Textlabel, wenn die Funktion nicht universell verständlich ist
- keine Lebensmittelillustrationen für Systemmodule
- Stations- und Statussymbole müssen in hektischer Nutzung unterscheidbar bleiben

### Bewegung

- Bewegung erklärt Zustandswechsel: Bestellung eingegangen, Ticket verschoben, Zahlung abgeschlossen
- keine dauerhaften Pulse oder dekorativen Loops
- Übergänge kurz und räumlich nachvollziehbar
- haptisches Feedback für operative Abschlussaktionen

## 7. UX-Grundsätze

### Zustand statt Erklärung

Ein Bildschirm beantwortet zuerst: Was passiert gerade? Was muss ich tun? Was ist abgeschlossen?

Marketingtexte gehören vor den Produkteinstieg. Im Produkt stehen konkrete Verben wie **Scannen**, **Annehmen**, **Zubereiten**, **Servieren** oder **Zahlen**.

### Kontext statt Modulmenü

KitchenLink besitzt viele Funktionen, zeigt aber nicht jedem Menschen alle gleichzeitig.

- Service sieht Tische, offene Bestellungen und Zahlungen.
- Küche und Bar sehen Tickets, Zeiten und Übergaben.
- Management sieht Tageslage, Ausnahmen, Team und Betrieb.
- Fahrer sieht Tour, Übergabe und Zustellung.
- Gäste sehen Karte, Warenkorb, Bestellung und Rechnung.

Die aktive Rolle und Station bestimmen die Hauptnavigation. Alle berechtigten Funktionen bleiben über **Betrieb** beziehungsweise **Mehr** erreichbar.

### Restaurant vor Plattform

Im Gast-Web führt die Restaurantmarke. KitchenLink erscheint nur als kleine Vertrauenssignatur. Die Business-App trägt dagegen klar die KitchenLink-Marke.

### Progressive Tiefe

Häufige Aktionen liegen direkt im aktuellen Kontext. Seltene Konfigurationen öffnen eine zweite Ebene. Ein Kellner muss keine Warenwirtschaft durchqueren; ein Betreiber kann sie trotzdem vollständig auf dem iPhone erreichen.

## 8. Informationsarchitektur

### Business: Management

Primäre Bereiche:

1. **Heute**: Schicht, Umsatz, Ausnahmen, aktuelle Last
2. **Bestellungen**: alle Kanäle und Status
3. **Betrieb**: Tische, Karte, Bestand, Reservierungen, Lieferung
4. **Team**: Planung, Zeiten, Abwesenheiten
5. **Mehr**: Finanzen, Standorte, Einstellungen, Exporte

### Business: Service

Primäre Bereiche:

1. **Service**: Tischplan und laufende Tische
2. **Bestellungen**: offene und neue Vorgänge
3. **Kasse**: Rechnungen, Teilungen und Zahlungen
4. **Mehr**: Reservierungen, Schicht, erlaubte Zusatzfunktionen

### Business: Küche/Bar

Primäre Bereiche:

1. **Tickets**
2. **Bereit**
3. **Verlauf**
4. **Station**

### Gast

Primärer Ablauf:

1. Venue und Tisch sind bereits aufgelöst
2. Karte öffnen
3. Artikel direkt hinzufügen oder konfigurieren
4. gemeinsamen Warenkorb sehen
5. bestellen
6. Status und Rechnung verfolgen
7. vollständig oder geteilt bezahlen

## 9. Erste visuelle Kernentwürfe

Die erste Designrunde zeigt bewusst nur drei Zustände:

- **Scan:** Einstieg ohne Werbetext und ohne Registrierungshürde
- **Heute:** Betreiber sieht den laufenden Betrieb statt eine Modulliste
- **Gastkarte:** Restaurantmarke, Artikel und Warenkorb stehen vor KitchenLink

Diese drei Zustände prüfen, ob die Richtung über sehr unterschiedliche Nutzer hinweg trägt. Erst danach werden Service, Küche, Kasse, Schichtplanung, Warenwirtschaft und Finanzen detailliert ausgearbeitet.

## 10. Freigabereihenfolge

1. Markencharakter und Logo-Grundform
2. Farbe und Typografie
3. Navigation je Rolle
4. Scan-, Heute- und Gastkarten-Screen
5. operative Komponenten und Statussystem
6. vollständige Screenbibliothek
7. Umsetzung in SwiftUI und Web

Bis Punkt 4 freigegeben ist, bleibt das bestehende App-Icon unverändert und der neue Entwurf wird getrennt vom funktionierenden Sandbox-Prototyp geführt.
