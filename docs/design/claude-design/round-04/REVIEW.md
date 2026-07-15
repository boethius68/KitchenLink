# Claude Design Round 04 - Review

**Stand:** 15. Juli 2026
**Quelle:** Claude-Design-Export mit Turn 6 als Abschlussboard fuer 4a `Ruhe`
**Entscheidungsstatus:** Letzter regulaerer Claude-Design-Stand; kein
Reserve-Prompt erforderlich. Codex uebernimmt ab hier. Exakte Tonwerte,
Typografie und Logo bleiben bis zur ausdruecklichen Nutzerfreigabe eine
Arbeitsgrundlage.

## Kurzfazit

Turn 6 behebt die wesentlichen Probleme aus Turn 5. Vorgangsart und Dringlichkeit
sind getrennte Achsen, offene Zahlung ist neutral statt rot, bedeutungstragende
Statusformen tragen auf hellen und dunklen Flaechen, und notwendige
Bedienelementgrenzen sind von dekorativen Trennern getrennt.

Die vier dichten Screens zeigen erstmals eine zusammenhaengende, realistische
Anwendung der Richtung. Bricolage Grotesque und Source Sans 3 funktionieren als
charaktervolle, aber betriebstaugliche Arbeitsprobe. Der Reserve-Prompt wuerde
keinen ausreichenden Mehrwert liefern; verbleibende Details werden in der
KitchenLink-Spezifikation und Implementierung durch Codex korrigiert.

## Verifiziert

- Turn 6 wurde im Browser gerendert und in voller Boardbreite visuell geprueft.
- Der Export enthaelt Scan, dichte Gastkarte, Betreiber-Heute und sechs
  gleichzeitige Kuechentickets.
- `README.md` im Export ist bytegleich mit dem Working-v1-Asset.
- `kitchenlink-lockup.svg` und `kitchenlink-app-icon.svg` sind nach kanonischer
  XML-Normalisierung identisch mit den Repository-Assets.
- Original-ZIP und lokaler HTML-Export sind vollstaendig und reproduzierbar.

## Kontrastpruefung

Die zentralen Turn-6-Werte wurden unabhaengig nachgerechnet:

| Kombination | Gemessen | Claude |
| --- | ---: | ---: |
| Neu-Symbol auf Sprudel | `3,64:1` | `3,6:1` |
| Wartet-Symbol auf Sprudel | `3,61:1` | `3,6:1` |
| Neutral-Symbol auf Sprudel | `4,78:1` | `4,7:1` |
| Kritisch-Symbol auf Sprudel | `5,88:1` | `7,0:1` |
| `border-control` auf Sprudel | `3,80:1` | `3,8:1` |
| `border-control` auf Traube | `5,10:1` | `4,9:1` |
| Fokus auf Sprudel | `13,34:1` | `13:1` |
| Fokus auf Traube | `13,01:1` | `13:1` |

Der annotierte Wert fuer das kritische Symbol auf Sprudel ist falsch, besteht
aber weiterhin deutlich die notwendige `3:1`-Grenze. Die Werte auf Tief sind
teilweise konservativ gerundet und ebenfalls ausreichend. Es gibt keinen
Accessibility-Blocker, der einen weiteren Claude-Prompt rechtfertigt.

## Was jetzt traegt

- Vorgangsart wird durch Form codiert: Bestellung als Kreis, Zahlung als Raute,
  Verbindung als durchgestrichener Ring, Aenderung als Quadrat.
- Dringlichkeit wird getrennt durch Farbe codiert: frisch, neutral, wartet,
  kritisch.
- Eine offene Zahlung ist eine neutrale Aufgabe. Erst Warten erzeugt Amber; nur
  ein Fehlschlag oder echter kritischer Zustand wird rot.
- Zitrone ist aus wiederholten Mengenaktionen und dem Statussystem entfernt.
- Die Gastkarte behaelt bei acht Gerichten eine klare zentrale Bestellaktion.
- Typografische Pflichtinformation beginnt bei 13 px; dichte Primaerzeilen liegen
  bei 17 px und Kuecheninformation bei 15 bis 22 px.

## Codex-Korrekturen ohne weitere Claude-Runde

### Scanner

Turn 6 zeigt die vier Scanner-Ecken dauerhaft in Zitrone. In der Implementierung
bleibt der Rahmen im Ruhezustand neutral. Zitrone erscheint dort erst beim
erfolgreichen Erkennen als kurzer Uebergabemoment. Der Button `Scannen` bleibt die
eine dauerhafte Primaeraktion.

### Touch-Ziele

Die Boards sind verkleinerte Darstellungen und keine pixelgenauen Viewports.
Interaktive Ziele werden in Native App und Touch-Web mindestens `44 x 44` Punkte
gross umgesetzt. Das gilt insbesondere fuer Plus, Minus und einzelne
Zeilenaktionen.

### Restaurantmarke

Traube ist der sichere Fallback fuer den Gastkopf. Wenn eine Venue Logo, Bild oder
zugelassene Akzentfarbe besitzt, fuehrt diese Darstellung. KitchenLink-Aktionen,
Statusfarben und Kontrastregeln bleiben davon unabhaengig.

### Statusmodell

Farbe zeigt Dringlichkeit, nicht den fachlichen Lebenszyklus. Verb, Form und Text
bleiben immer sichtbar. Offline kann neutral sein, solange der lokale Betrieb
weiterlaeuft, und auf Amber oder Rot eskalieren, wenn Warteschlange oder lokaler
Hub kritisch werden.

## Entscheidung zum Claude-Kontingent

Der Reserve-Prompt wird nicht verwendet. Turn 6 ist ausreichend, um Tokens,
Komponenten und Screens eigenstaendig weiterzuentwickeln. Die abgeleitete
technische Quelle ist `docs/design/DESIGN_SYSTEM.md`.

## Gesicherte Artefakte

- `source-export.zip` - unveraenderter Originalexport, SHA-256
  `85f547107484d1a504b4cba218578a0e242ee8619dea1a6709d6428fe33e5d11`
- `export/territories.html` - lokal ausfuehrbarer Designexport
- `export/support.js` - Laufzeit des Exports
- `thumbnail.webp` - Exportvorschau
