# Claude Design Round 03 - Review

**Stand:** 15. Juli 2026
**Quelle:** Claude-Design-Export mit Turn 5 zur Verdichtung von 4a `Ruhe`
**Entscheidungsstatus:** 4a bleibt die ausgewaehlte Arbeitsrichtung; Turn 5 ist
noch keine finale Freigabe von Palette, Statussystem oder Typografie

## Kurzfazit

Turn 5 erfuellt den Auftrag strukturell und verbessert die Richtung sichtbar.
Zitrone ist aus `beliebt` und `LIVE` entfernt, helle und dunkle Tokens sind
nachvollziehbar, und die Primaeraktion besitzt unterscheidbare Interaktionszustaende.
Die vier Anwendungen wirken dadurch ruhiger und konsistenter als in Turn 4.

Die Palette ist trotzdem noch nicht freigabefaehig. Das Statussystem verwechselt
teilweise Vorgangsart und Dringlichkeit, zwei bedeutungstragende Statusformen sind
auf Hell zu kontrastarm, und die Konturtokens unterscheiden noch nicht zwischen
Dekoration und notwendiger Bedienelementgrenze.

## Verifiziert

- Der Export wurde als eigenstaendige Runde gerendert und visuell mit Turn 4
  verglichen.
- `README.md` im Export ist bytegleich mit dem Working-v1-Asset im Repository.
- `kitchenlink-lockup.svg` und `kitchenlink-app-icon.svg` sind nach kanonischer
  XML-Normalisierung exakt identisch mit den Repository-Assets. Claude hat nur
  die SVG-Serialisierung veraendert, nicht Geometrie, Pfade oder Farben.
- Die zentralen Textkontraste wurden unabhaengig nach WCAG-Formel nachgerechnet.
  Claudes Werte sind, abgesehen von unkritischen Rundungen, korrekt und liegen
  oberhalb von `4,5:1`.

## Was traegt

- Traube, Tief, Sprudel und Licht bilden eine zusammenhaengende helle und dunkle
  Flaechenlogik.
- Zitrone funktioniert auf Traube als klarer, frischer Belohnungs- und
  Handlungsimpuls.
- Fokus, gedrueckt, deaktiviert und ladend unterscheiden sich nicht nur ueber
  eine kleine Helligkeitsaenderung.
- Der Fokusindikator ist auf Hell Traube und auf Dunkel Licht; Zitrone wird dafuer
  richtigerweise nicht verwendet.
- `beliebt` und `LIVE` konkurrieren nicht mehr mit der Primaeraktion.

## Korrekturbedarf

### 1. Zahlung und Fehler sind farblich nicht getrennt

`Zahlung` verwendet Koralle `#E5533F`, `Fehler` verwendet `#B3261E`. Ihre
Farbwinkel liegen nur ungefaehr vier Grad auseinander. Auf dunklen Flaechen sind
auch `#F0705C` und `#EF6E64` nahezu derselbe Rotton. Form und Verb unterscheiden
die Zustaende, der behauptete Unterschied ueber den Farbton jedoch nicht.

Grundsaetzlicher ist `Zahlung offen` eine Vorgangsart und nicht automatisch ein
Fehler. Das System braucht zwei getrennte Achsen:

- Vorgangsart: Bestellung, Zahlung, Verbindung oder anderer Arbeitsvorgang
- Dringlichkeit: neutral, wartet, kritisch oder fehlgeschlagen

Eine offene Zahlung darf neutral sein, eine lange wartende Zahlung Aufmerksamkeit
fordern und erst eine fehlgeschlagene Zahlung den Fehlerstatus tragen. Rot sollte
nicht pauschal jede Zahlung als Problem markieren.

### 2. Statusformen sind auf Hell teilweise zu kontrastarm

Die Statuswoerter bestehen den Textkontrast. Zwei zugehoerige Formen auf Sprudel
erreichen jedoch nicht `3:1`:

| Form auf `#F4F2F8` | Kontrast |
| --- | ---: |
| Neu `#3FA96D` | `2,66:1` |
| Verspaetet `#D79A2A` | `2,21:1` |
| Zahlung `#E5533F` | `3,35:1` |
| Fehler `#B3261E` | `5,88:1` |
| Offline `#8B8598` | `3,20:1` |

Wenn Kreis, Dreieck und Ring die semantische Redundanz fuer eingeschraenktes
Farbsehen liefern sollen, muessen auch diese kleinen Zeichen klar wahrnehmbar
sein. Neu und verspaetet brauchen auf Hell einen dunkleren Flaechenton, eine
kontraststarke Kontur oder eine robustere Form. Der hohle Offline-Ring ist bei
10 px zudem zu nah am gefuellten Neu-Kreis.

### 3. Konturen brauchen semantisch getrennte Tokens

Die hellen Konturen aus Traube mit `.12` und `.28` erreichen gegen Sprudel nur
ungefaehr `1,26:1` und `1,75:1`. Die dunklen Licht-Konturen mit `.14` und `.28`
erreichen gegen Traube ungefaehr `1,51:1` und `2,34:1`.

Das ist fuer dekorative Trenner in Ordnung, aber nicht fuer eine Kontur, die zum
Erkennen eines Eingabefelds oder Bedienelements erforderlich ist. Die Architektur
muss `border-subtle` fuer Dekoration und `border-control` fuer notwendige
Bedienelementgrenzen auseinanderhalten. Fokus bleibt ein eigener Token.

### 4. Die Zitronenmenge ist noch nicht unter realer Dichte getestet

Im Gastbeispiel gibt es nur eine Speise und damit nur einen gelben Plus-Button.
Auf einer echten Karte mit acht bis zwoelf sichtbaren Positionen koennen lokale
Plus-Aktionen den eigentlich knappen Markenakzent fluten. Eine wiederholte
Zeilenaktion ist nicht automatisch die eine Primaeraktion des Screens.

Vor der Freigabe muss eine dichte Speisekarte zeigen, dass Zitrone weiterhin den
Logo-Uebergabepunkt und die zentrale Bestellaktion markiert. Wiederholte lokale
Mengenaktionen sollten dafuer primaer traubenbasiert funktionieren.

### 5. Accessibility ist ohne Typografie noch nicht abgeschlossen

Der Farbkontrast ist weitgehend belastbar. Mehrere Labels im Board stehen jedoch
bei 8 bis 11 px. Da Typografie bewusst vertagt wurde, kann Turn 5 noch keine
vollstaendige Accessibility-Freigabe darstellen. Auch die sehr schwachen
deaktivierten Texte sollten spaeter auf echten Geraeten in heller Gastronomie
geprueft werden, obwohl inaktive Controls von WCAG-Kontrastregeln ausgenommen
sind.

## Letzter geplanter Prompt fuer Claude Design - Turn 6

```text
Dies ist die letzte geplante umfassende Claude-Design-Runde; ein weiterer Prompt
bleibt nur als Reserve fuer einen konkreten schweren Fehler. Speichere Turn 5
unveraendert und ergaenze darueber ein kompaktes Abschlussboard innerhalb von 4a
"Ruhe". Eroeffne keine neue Markenpalette und aendere weder Codex-Logo noch
Wortmarke.

Korrigiere zuerst diese vier Punkte:

1. Trenne Vorgangsart und Dringlichkeit. "Zahlung offen" ist eine Arbeitsaufgabe,
   nicht automatisch ein Fehler. Zeige mindestens: Zahlung offen neutral,
   Zahlung wartet mit Aufmerksamkeit und Zahlung fehlgeschlagen als Fehler.
   Rot bleibt Fehler oder echter Kritikalitaet vorbehalten. Form, Verb und
   Dringlichkeit muessen unabhaengig lesbar sein.
2. Bringe jede bedeutungstragende Statusform auf Sprudel, Traube und Tief auf
   mindestens 3:1 gegen ihre direkte Umgebung. Annotiere getrennt den Kontrast
   des Statusworts und des Symbols. Mache Offline bei 10 bis 12 px deutlicher
   unterscheidbar vom Neu-Kreis.
3. Teile die Konturtokens in `border-subtle` fuer rein dekorative Trennung und
   `border-control` fuer notwendige Bedienelementgrenzen. `border-control` und
   Fokusindikatoren muessen mindestens 3:1 gegen angrenzende Flaechen erreichen;
   dokumentiere die Werte auf Hell und Dunkel.
4. Reserviere Zitrone fuer Logo-Uebergabe und die eine zentrale Primaeraktion des
   Screens. Wiederholte lokale Plus-/Minus-Aktionen werden traubenbasiert geloest.

Nutze im Abschlussboard ohne weitere Schriftexploration die bereits getestete
Aufteilung als konkrete Arbeitsprobe:
- Bricolage Grotesque nur fuer charakteristische Display- und Bereichsueberschriften
- Source Sans 3 fuer Gasttext, Bedienelemente und dichte Betriebsinformation
- Nunito ausschliesslich in der gelieferten, in Pfade umgewandelten Wortmarke
- kein Figtree und kein Space Grotesk in den finalen Anwendungsbeispielen

Definiere dazu eine knappe, realistische Typenskala fuer iPhone und iPad. Verwende
keine 8- bis 11-px-Mikrotexte als notwendige Information; zeige Betriebszeilen in
13, 15 und 17 px und markiere ihre jeweilige Rolle.

Zeige danach genau vier realistisch dichte Referenzscreens, keine weiteren
Varianten:
1. iPhone Betreiber: Speisekarte scannen als schneller erster Einrichtungsschritt
2. Gast-Web bei 390 px: mindestens acht Gerichte, mehrere Mengen, lokale
   traubenbasierte Mengensteuerung und fixierte Zitronen-Bestellaktion
3. iPhone Betreiber "Heute": neue Bestellung, wartend, offene Zahlung, offline
4. iPad Kueche: sechs gleichzeitige Tickets inklusive neu, verspaetet, geaendert
   und offline wartend

Wende die korrigierte Statussemantik, Konturen, Typografie und bestehende
Aktionszustaende direkt in diesen Screens an. Stelle Restaurantmarke vor
KitchenLink im Gast-Web. Annotiere nur die entscheidenden Tokenwerte und
Kontraste; halte Erklaertexte knapp, um Kontingent zu sparen.

Keine Komponentenbibliothek, kein Code-Handoff und keine neue Logo-, Farb- oder
Schriftexploration. Das Ergebnis soll eine belastbare visuelle Referenz sein, aus
der Codex danach Tokens, Komponenten und Implementierung ohne weitere
Claude-Runden ableiten kann.
```

## Gesicherte Artefakte

- `source-export.zip` - unveraenderter Originalexport, SHA-256
  `c16c0e3310aadbc3b05272c9625b50ab345648474ae148cdd020a403008ee5d4`
- `export/territories.html` - lokal ausfuehrbarer Designexport
- `export/support.js` - Laufzeit des Exports
- `thumbnail.webp` - Exportvorschau
