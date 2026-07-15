# Claude Design Round 02 - Review

**Stand:** 15. Juli 2026
**Quelle:** Claude-Design-Export mit Logo- und Farbexploration aus Turn 3 sowie
Zitrus-Rollenvergleich aus Turn 4
**Entscheidungsstatus:** Turn 4a `Ruhe` ist fuer die Vertiefung ausgewaehlt;
exakte Farbwerte, Typografie und Logo sind noch nicht final freigegeben

## Entscheidung

Der Nutzer bevorzugt **4a `Ruhe`**. Ab der naechsten Runde wird nur diese
Rollenverteilung weiterentwickelt. 4b `Frisch` bleibt als Vergleich archiviert,
wird aber nicht weiterverfolgt.

4a passt besser zur bisherigen Logoentscheidung: Die dunkle Traubenbasis traegt
die Marke ruhig und geschlossen, waehrend die Zitrone den Moment der Uebergabe
und die wichtigste Handlung markiert. So entsteht mehr Eigenstaendigkeit als bei
4b, ohne dass die Oberflaeche wie ein allgemeines Signal- oder SaaS-System wirkt.

Die Auswahl ist eine **Richtungsentscheidung**, noch keine finale Freigabe aller
Hexwerte oder Anwendungsdetails.

## Ausgewaehlte Arbeitsrollen

| Rolle | Arbeitswert | Verwendung |
| --- | --- | --- |
| Traube | `#2C2438` | Markenbasis, dunkle Hauptflaechen, dunkler Text auf Zitrone |
| Tief | `#221B2E` | vertiefte dunkle Flaechen, insbesondere App-Icon |
| Zitrone | `#B6CC1B` | Logo-Uebergabe und primaere Aktion |
| Sprudel | `#F4F2F8` | helle Papier- und Produktoberflaechen |
| Licht | `#F1EFF7` | heller Text und helles Logo auf Traube oder Tief |

Das Logo bleibt geometrisch unveraendert. Die Wortmarke bleibt einfarbig;
`Kitchen` und `Link` werden nicht verschieden eingefaerbt. Statusfarben bleiben
markenunabhaengig und werden immer mit Farbe und Form codiert.

## Visuelle Pruefung

### Stark

- Traube gibt App-Icon, Einstieg und Kueche einen zusammenhaengenden,
  wiedererkennbaren Markenraum.
- Zitrone wirkt auf Traube frisch und belohnend, ohne die Ruhe des bevorzugten
  Logos zu verlieren.
- Gast-, Betriebs- und Kuechenkontext gehoeren sichtbar zusammen, waehrend das
  Restaurant im Gastmodus weiterhin fuehrt.
- Die getrennten Statusfarben fuer neu, verspaetet und Zahlung bleiben gegen die
  Markenfarben lesbar.

### Zu korrigieren

- Zitrone wird im Board neben Uebergabe und primaeren Aktionen auch fuer
  Informationslabels wie `beliebt` und `LIVE` verwendet. Das verwischt ihre
  vereinbarte Bedeutung und verbraucht den Akzent zu schnell.
- Typografie und Komponentenformen sind in diesem Board nur Darstellungsrahmen.
  Space Grotesk und Figtree sind damit nicht freigegeben.
- Die exakten Tonwerte muessen noch fuer Fokus, gedrueckt, deaktiviert, ladend
  sowie fuer helle und dunkle Flaechen definiert werden.

## Kontrastgrenzen

Die zentralen Kombinationen wurden unabhaengig nach WCAG-Kontrastformel geprueft:

- Zitrone auf Traube: `8,22:1`
- Traube auf Sprudel: `13,34:1`
- Licht auf Traube: `13,01:1`
- Licht auf Tief: `14,58:1`
- Zitrone auf Sprudel: nur `1,62:1`

Zitrone darf deshalb auf hellen Flaechen nicht allein als Text, feine Linie,
kleines Icon oder Fokusindikator funktionieren. Sie kann dort als gefuellte
Flaeche mit Traube-Text eingesetzt werden. Relevante Zustaende brauchen zusaetzlich
Form, Text oder eine kontraststarke Kontur.

## Statussystem

Die im Export getesteten Statuswerte bleiben vorlaeufig funktional getrennt:

- neu: Kreis, `#3FA96D`
- verspaetet: Dreieck, `#D79A2A`
- Zahlung: Raute, `#E5533F`

Zitrone ist kein Statuszeichen. Ob die drei Statuswerte selbst final tragfaehig
sind, wird erst in der Status- und Accessibility-Runde entschieden.

## Prompt fuer Claude Design - Turn 5

```text
Speichere Turn 4 unveraendert als Vergleichsstand. Die Entscheidung ist gefallen:
4a "Ruhe" ist die einzige Arbeitsgrundlage fuer die naechste Vertiefung. 4b wird
nicht weiterentwickelt. Das ist eine Richtungsentscheidung; die exakten Hexwerte
sind noch nicht final freigegeben.

Bewahre unveraendert:
- das gelieferte Codex-Zeichen und seine Geometrie
- die einfarbige KitchenLink-Wortmarke
- Traube als tragende Markenbasis
- Zitrone als Fokus der Uebergabe und der primaeren Handlung
- die fuehrende Rolle der Restaurantmarke im Gast-Web
- die Trennung von Markenfarbe und formcodierten Statusfarben

Verdichte ausschliesslich 4a zu einer belastbaren Farbarchitektur:
1. Definiere semantische Farbtokens fuer Marke, Text, Flaeche, Kontur und
   Interaktion auf hellen und dunklen Hintergruenden. Begruende jeden zusaetzlich
   benoetigten Ton aus 4a; eroeffne keine neue Farbwelt.
2. Reserviere Zitrone strikt fuer die Logo-Uebergabe und primaere Aktionen.
   Entferne sie von rein informativen Labels wie "beliebt" und "LIVE" sowie von
   Statusmeldungen. Zeige fuer diese Elemente eine neutrale oder traubenbasierte
   Loesung.
3. Zeige primaere Aktionen in den Zustaenden Standard, gedrueckt, Fokus,
   deaktiviert und ladend, jeweils auf heller und dunkler Flaeche. Kein Zustand
   darf nur durch eine geringe Helligkeitsaenderung unterscheidbar sein.
4. Pruefe alle Text-, Icon-, Kontur- und Fokuspaare nach WCAG AA. Zitrone auf
   hellem Grund darf nicht als Text, feine Linie oder alleiniger Fokusindikator
   verwendet werden. Dokumentiere die gemessenen Kontrastwerte direkt am Board.
5. Behalte das Statusprinzip Farbe + Form bei und teste neu, verspaetet, Zahlung,
   Fehler und offline auf Sprudel, Traube und Tief. Zitrone bleibt dabei
   vollstaendig ausserhalb des Statussystems. Zahlung und Fehler duerfen weder
   visuell noch sprachlich dieselbe Bedeutung erhalten.
6. Zeige nach der Token-Tafel dieselben vier Anwendungen aus 4a erneut, nun mit
   der bereinigten Akzentverwendung. Aendere weder Logo noch Layoutprinzip, damit
   die Wirkung direkt vergleichbar bleibt.

Typografie bleibt in dieser Runde provisorisch. Triff keine finale
Schriftentscheidung, erstelle keine Komponentenbibliothek und keinen Code-Handoff.
Das Ergebnis dieser Runde ist eine klare Palette mit erlaubten Kombinationen,
verbotenen Kombinationen und belastbaren Interaktions- und Statuszustaenden.
```

## Gesicherte Artefakte

- `source-export.zip` - unveraenderter Originalexport, SHA-256
  `e2f218b1b271aa02a4091421788fbea1823b6b93856f8e31f7aeea96c4d0e971`
- `export/territories.html` - lokal ausfuehrbarer Designexport
- `export/support.js` - Laufzeit des Exports
- `thumbnail.webp` - Exportvorschau
