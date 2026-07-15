# KitchenLink Design System

**Stand:** 15. Juli 2026
**Status:** Technische Arbeitsgrundlage fuer den Sandbox-Prototyp
**Visuelle Quelle:** Claude Design Round 04, Turn 6

4a `Ruhe` ist die ausgewaehlte Designrichtung. Dieses Dokument ueberfuehrt sie in
plattformneutrale Regeln, die Codex ohne weitere Claude-Runden in SwiftUI und Web
umsetzen kann. Exakte Tonwerte, Typografie und das Working-v1-Logo sind noch keine
finale Markenfreigabe. Neue Umsetzung bleibt deshalb vom bestehenden
Sandbox-Prototyp trennbar und schaltbar.

## 1. Designthese

KitchenLink bringt Ruhe in einen lebendigen Betrieb. Traube schafft einen
eigenstaendigen, verlaesslichen Raum; Zitrone markiert nur den Moment, an dem etwas
uebergeben oder verbindlich ausgeloest wird.

Die Oberflaeche beantwortet zuerst:

1. Was passiert gerade?
2. Was braucht meine Aufmerksamkeit?
3. Was kann ich als Naechstes tun?

## 2. Markenrollen

- In Business, Service und Kueche darf KitchenLink sichtbar fuehren.
- Im Gast-Web fuehrt das Restaurant. Traube ist nur der sichere Fallback, wenn die
  Venue keine eigene visuelle Identitaet hinterlegt hat.
- Das Working-v1-Zeichen bleibt geometrisch unveraendert.
- Die Wortmarke ist immer einfarbig. `Kitchen` und `Link` werden nicht getrennt
  eingefaerbt.
- Nunito erscheint ausschliesslich als in Pfade umgewandelte Wortmarke, nicht als
  allgemeine Produktschrift.

## 3. Grundfarben

| Token | Wert | Aufgabe |
| --- | --- | --- |
| `brand.grape` | `#2C2438` | Markenbasis, dunkle Hauptflaeche, Text auf Zitrone |
| `brand.deep` | `#221B2E` | tiefste Flaechen, App-Icon, Kuechenhintergrund |
| `brand.lemon` | `#B6CC1B` | Logo-Uebergabe und eine Primaeraktion |
| `brand.lemonPressed` | `#9FB014` | ausschliesslich gedrueckter Primaerzustand |
| `surface.base` | `#F4F2F8` | helle Produkt- und Papierflaeche |
| `surface.raised` | `#FCFBFE` | erhoehte helle Flaeche |
| `surface.recessed` | `#ECEAF3` | Auswahl, Mulde, Mengensteuerung |
| `surface.darkRaised` | `#383048` | erhoehte Flaeche auf Traube oder Tief |
| `content.light` | `#F1EFF7` | Primaertext und Logo auf dunkler Flaeche |

## 4. Inhalt und Kontur

### Auf Hell

| Token | Wert |
| --- | --- |
| `text.primary` | `#2C2438` |
| `text.secondary` | `#56506A` |
| `text.muted` | `#6E6880` |
| `border.subtle` | `rgba(44, 36, 56, 0.12)` |
| `border.control` | `#7E7890` |
| `focus.ring` | `#2C2438` |

### Auf Dunkel

| Token | Wert |
| --- | --- |
| `text.primaryInverse` | `#F1EFF7` |
| `text.secondaryInverse` | `#B4AEC6` |
| `text.mutedInverse` | `#9A94AE` |
| `border.subtleInverse` | `rgba(241, 239, 247, 0.14)` |
| `border.controlInverse` | `#9A94AE` |
| `focus.ringInverse` | `#F1EFF7` |

`border.subtle` ist rein dekorativ. Wenn eine Grenze zum Erkennen oder Bedienen
eines Controls notwendig ist, muss `border.control` verwendet werden. Fokus ist
immer ein eigener, mindestens zwei Punkte breiter Ring.

## 5. Zitronenregel

Zitrone darf verwendet werden fuer:

- die Schale beziehungsweise Uebergabe im Logo
- genau eine dauerhafte Primaeraktion pro sichtbarem Arbeitskontext
- einen kurzen erfolgreichen Uebergabemoment, zum Beispiel erkannte Speisekarte,
  uebermittelte Bestellung oder abgeschlossene Zahlung

Zitrone darf nicht verwendet werden fuer:

- Status, Warnung oder Fehler
- informative Labels wie `LIVE`, `beliebt` oder `offline`
- Fliesstext, feine Linien oder kleine Icons auf heller Flaeche
- jede wiederholte Plus- oder Minusaktion einer Liste
- statische Scanner-Ecken im Ruhezustand

Zitrone auf Sprudel erreicht nur `1,62:1`. Auf heller Flaeche funktioniert sie
daher nur als gefuellte Flaeche mit Traube-Text. Zitrone auf Traube erreicht
`8,22:1`.

## 6. Statusmodell

Jeder operative Status besteht aus mindestens drei Informationen:

1. Vorgangsart als Form
2. Dringlichkeit als Farbe
3. konkretes Verb oder Klartext

### Vorgangsart

| Art | Form | Beispiele |
| --- | --- | --- |
| Bestellung | gefuellter Kreis | neu, angenommen, bereit |
| Zahlung | Raute | offen, wartet, fehlgeschlagen |
| Verbindung | durchgestrichener Ring | offline, wartet auf Sync |
| Aenderung | Quadrat | geaendert, erneut zu pruefen |

Eine unbekannte Art erhaelt nicht kommentarlos ein generisches Symbol. Bis ein
eigenes Muster definiert ist, bleiben Form und Klartext gemeinsam sichtbar.

### Dringlichkeit

| Stufe | Hell: Symbol / Text | Dunkel: Symbol / Text | Bedeutung |
| --- | --- | --- | --- |
| frisch | `#2E8F5A` / `#1F7A47` | `#3FA96D` / `#5BC088` | neu, bereit, im Ziel |
| neutral | `#6E6880` / `#56506A` | `#9A94AE` / `#B4AEC6` | vorhanden, kein Alarm |
| wartet | `#A97512` / `#8A6410` | `#D79A2A` / `#E9B84A` | Aufmerksamkeit erforderlich |
| kritisch | `#B3261E` / `#A31C15` | `#EF6E64` / `#EF6E64` | fehlgeschlagen oder kritisch |

Farbe beschreibt nie allein einen Lebenszyklus. Eine offene Zahlung ist neutral;
eine wartende Zahlung ist Amber; nur eine fehlgeschlagene Zahlung ist rot.
Offline bleibt neutral, solange der lokale Betrieb weiterlaeuft, und eskaliert
erst bei wachsender Warteschlange oder Ausfall des Venue-Hubs.

## 7. Typografie

- **Bricolage Grotesque:** Display, Seiten- und Bereichsueberschriften
- **Source Sans 3:** Gasttext, Controls, Listen, Betrags- und Betriebsinformation
- **Nunito:** nur die als Pfad gelieferte KitchenLink-Wortmarke
- **Tabellarische Ziffern:** Zeit, Betrag, Menge, Tisch- und Ticketnummer

| Rolle | Schrift | Basisgroesse | Gewicht |
| --- | --- | ---: | ---: |
| Display | Bricolage | 28 | 800 |
| Bereich | Bricolage | 20 | 700 |
| Kompakter Bereich | Bricolage | 16 | 700 |
| Primaerzeile | Source Sans 3 | 17 | 600 |
| Sekundaerzeile | Source Sans 3 | 15 | 400 |
| Meta Minimum | Source Sans 3 | 13 | 600 |
| Primaerbutton | Source Sans 3 | 16 | 700 |
| Kuechentitel | Bricolage | 22 | 800 |
| Kuechenstatus | Source Sans 3 | 15 | 700 |

Notwendige UI-Information beginnt bei 13 Punkten. Native Umsetzung unterstuetzt
Dynamic Type; Web respektiert Zoom und Nutzer-Schriftgroesse. Zeilen duerfen bei
Vergroesserung wachsen statt Text abzuschneiden.

## 8. Abstand, Radius und Zielgroesse

### Abstandsskala

`4, 8, 12, 16, 24, 32`

### Radiusskala

| Token | Wert | Aufgabe |
| --- | ---: | --- |
| `radius.label` | 6 | kleine neutrale Labels |
| `radius.compact` | 9 | Mengensteuerung, kompaktes Control |
| `radius.control` | 12 | Buttons und Eingaben |
| `radius.card` | 14 | Ticket und operative Gruppe |
| `radius.sheet` | 20 | Sheet oder grosse Arbeitsflaeche |

- Touch-Ziele sind mindestens `44 x 44` Punkte gross.
- Visuelle Icons duerfen kleiner sein, ihre interaktive Flaeche nicht.
- Schatten markieren nur echte Ebenen wie fixierte Bestellaktion oder Sheet.
- Listen werden primaer mit Abstand und `border.subtle` strukturiert, nicht mit
  einer Karte um jede Zeile.

## 9. Kernkontexte

### Scan

- Ein Satz erklaert die Aktion, danach fuehrt die Kamera.
- Der Rahmen ist im Ruhezustand neutral.
- Erfolgreiche Erkennung laesst den Uebergabepunkt kurz in Zitrone erscheinen.
- `Scannen` ist primaer; `Manuell eingeben` ist sekundaer.

### Gast-Web

- Restaurantname, Logo oder Bild fuehren den Kopf.
- KitchenLink erscheint nur als kleine Vertrauenssignatur.
- Mengensteuerungen sind traubenbasiert und mindestens 44 Punkte gross.
- Die fixierte Bestellaktion ist die einzige dauerhafte Zitronenflaeche.

### Heute

- Zeigt Ereignisse und naechste Handlungen statt Modulnavigation.
- Vorgangsform, Dringlichkeitsfarbe, Verb und stabiler Wert stehen in einer Zeile.
- Offline kommuniziert explizit, ob der lokale Betrieb weiterlaeuft.

### Kueche

- Tief ist die Basis; Tickets liegen auf Traube oder `surface.darkRaised`.
- Sechs gleichzeitige Tickets muessen ohne horizontales Scrollen erfassbar sein.
- Zeit, Tisch, Zustand und wichtigste Positionen bleiben aus Distanz lesbar.
- Keine Zitronenfarbe fuer Ticketstatus.

## 10. Bewegung und Haptik

- Bewegung erklaert Uebergabe oder Zustandswechsel, nicht Dekoration.
- Scanner-Erfolg, Bestelluebergabe und Zahlungsabschluss duerfen den
  Zitronenakzent fuer 180 bis 240 ms aufnehmen.
- Neue Tickets erscheinen raeumlich nachvollziehbar; bestehende Tickets springen
  nicht ohne Ursache.
- Operative Abschlussaktionen erhalten dezentes haptisches Feedback.
- `Reduce Motion` ersetzt Bewegung durch direkten Zustandswechsel.
- Keine dauerhaften Pulse, Spinner nur waehrend realer Arbeit.

## 11. Implementierungsgrenze

- Die neue Richtung wird zuerst hinter einer Sandbox- oder Preview-Schaltung
  umgesetzt.
- Bestehende Demo-, Offline- und Simulationspfade bleiben funktionsfaehig.
- SwiftUI und Web verwenden dieselben semantischen Namen, nicht nur gleiche
  Hexwerte.
- Bricolage Grotesque und Source Sans 3 werden erst nach Lizenz- und Bundle-Pruefung
  als lokale Assets eingebunden; Laufzeit darf nicht von Google Fonts abhaengen.
- Kontrast, Dynamic Type, Touch-Ziele und Reduce Motion werden automatisiert oder
  per Preview geprueft.
- Ein Reserve-Prompt an Claude ist nicht Teil des weiteren Arbeitsplans.
