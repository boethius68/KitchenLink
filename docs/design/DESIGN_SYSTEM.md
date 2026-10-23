# KitchenLink Design System

**Stand:** 23. Oktober 2026 (aktualisiert nach Nutzerentscheidung)
**Status:** Technische Arbeitsgrundlage fuer den Sandbox-Prototyp
**Visuelle Quelle:** Claude Design Turn 3b / 4b `Zitrus` ("Frisch")

`Zitrus` ist die verbindliche Designrichtung. Sie loest die zu melancholische,
gedaempfte Richtung 4a "Ruhe" ab und bringt echte gastronomische Energie, Frische,
Appetit und Klarheit in das Produkt. Dieses Dokument ueberfuehrt sie in
plattformneutrale Regeln fuer SwiftUI und Web.

## 1. Designthese

KitchenLink ist das frische, wache Restaurantbetriebssystem.
*„Zitronenschale und Sprudel — wach, prickelnd, unkompliziert. Die Belohnung nach einem
langen Arbeitstag: Frische, Genuss und Verbindung.“*

Die Oberflaeche beantwortet zuerst:

1. Was passiert gerade?
2. Was braucht meine Aufmerksamkeit?
3. Was kann ich als Naechstes tun?

## 2. Markenrollen

- In Business, Service und Kueche fuehrt KitchenLink mit einem klaren, kraftvollen
  Dunkel (Carbon `#17171B` / Tief `#0D0D10`) und dynamischem Zitrone-Akzent (`#B6CC1B`).
- Im Gast-Web fuehrt das Restaurant auf hellem, warmem Papier (`#F4F4F1`). KitchenLink
  erscheint nur als dezente Vertrauenssignatur.
- Traube (`#2C2438`) bleibt als charakteristische Markenflaeche erhalten, dominiert
  aber nicht mehr als lila Schleier ueber allen Flaechen.
- Das Working-v1-Zeichen bleibt geometrisch unveraendert.
- Die Wortmarke ist immer einfarbig. `Kitchen` und `Link` werden nicht getrennt
  eingefaerbt.
- Nunito erscheint ausschliesslich als in Pfade umgewandelte Wortmarke, nicht als
  allgemeine Produktschrift.

## 3. Grundfarben

| Token | Wert | Aufgabe |
| --- | --- | --- |
| `brand.lemon` | `#B6CC1B` | Zitrus-Leitakzent: Uebergabe, aktive Handlungen und Primaeraktionen |
| `brand.lemonPressed` | `#9FB014` | gedrueckter Zustand von Zitrone |
| `brand.grape` | `#2C2438` | Markenbasis fuer ausgewaehlte Akzente |
| `brand.deep` | `#0D0D10` | tiefste Flaeche, Kuechenmonitor-Basis ("Kueche ist Tief") |
| `surface.base` | `#F4F4F1` | warmes, frisches Papier statt aschigem Grau |
| `surface.raised` | `#FFFFFF` | reine, erhoehte Arbeitsflaeche und Karten |
| `surface.recessed` | `#EAEAE5` | Mulde, Auswahl, Mengensteuerung |
| `surface.darkRaised` | `#1E1E24` | neutral erhoehte Flaeche im Dunkelkontext |
| `content.light` | `#F4F4F1` | Primaertext auf dunkler Flaeche |

## 4. Inhalt und Kontur

### Auf Hell

| Token | Wert |
| --- | --- |
| `text.primary` | `#17171B` (klares Carbon/Neutral) |
| `text.secondary` | `#52525C` |
| `text.muted` | `#71717D` |
| `border.subtle` | `rgba(23, 23, 27, 0.09)` |
| `border.control` | `#7E7E8A` |
| `focus.ring` | `#17171B` |

### Auf Dunkel

| Token | Wert |
| --- | --- |
| `text.primaryInverse` | `#F4F4F1` |
| `text.secondaryInverse` | `#B0B0BC` |
| `text.mutedInverse` | `#888896` |
| `border.subtleInverse` | `rgba(244, 244, 241, 0.12)` |
| `border.controlInverse` | `#888896` |
| `focus.ringInverse` | `#B6CC1B` |

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
| Speisename | Source Sans 3 | 20 | 700 |
| Speisekartenpreis | Source Sans 3 | 16 | 600 |
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
- Der Speisename ist das dominante Element jeder Menuezeile. Der Preis bleibt
  sofort auffindbar, ist aber kleiner und leichter als der Name;
  Deklarationssymbole sind die dritte Hierarchiestufe. Alle Kennzeichnungen
  eines Gerichts werden vollstaendig gezeigt — die Symbolzeile bricht bei
  Platzmangel um, statt Angaben hinter einem Sammelindikator wie `+N` zu
  verbergen. Das ist eine rechtliche Anforderung der Lebensmittel-
  kennzeichnung, keine gestalterische Option.
- Die Kennzeichnungen sind bewusst zurueckhaltend: monochrome Umriss-Symbole
  in der gedaempften Textfarbe, ohne farbige Badges, gefuellte Kaesten oder
  Rahmen. Gruppenfarbe (Allergen, Zusatzstoff …) erscheint erst in den
  Detailansichten. Die Symbole sind sichtbar, ziehen aber keine
  Aufmerksamkeit von Name, Preis und Bestellaktion ab.
- Die Symbole stehen im Fluss der Beschreibung, nicht in einer eigenen Zeile:
  sie schliessen als leiser Nachsatz an den Beschreibungstext an und brechen
  mit ihm gemeinsam um. Fehlt eine Beschreibung, bilden sie eine kurze
  gedaempfte Zeile unter dem Namen. Ein abgesetzter Icon-Streifen unter dem
  Gericht ist ausdruecklich unerwuenscht (penetrant und formwidrig).
- Der gesamte Symbol-Nachsatz ist ein einziges Tap-Ziel und oeffnet eine
  gruppierte Klartextliste aller Kennzeichnungen des Gerichts; ein
  Listeneintrag fuehrt zur ausfuehrlichen Erklaerung. Einzelne Symbole sind in
  der Gastzeile nicht separat antippbar. Betreiberansichten (Review, Editor)
  behalten die farbigen Badges mit Einzel-Tap. Die Mengensteuerung sitzt bei
  belegtem Warenkorb in einer eigenen rechtsbuendigen Zeile.
- Im Nullzustand sitzt nur ein klein gezeichneter runder Plus-Button neben dem
  Preis; Varianten oeffnen sich erst nach dessen Aktivierung und erzeugen keine
  eigene `Auswaehlen`-Zeile. Plus und Minus reagieren jeweils auf ihre gesamte
  rechteckige 44-Punkt-Touchflaeche, nicht nur auf das sichtbare Zeichen.
- Deklarationssymbole zeigen nur das Piktogramm. Interne Quellcodes bleiben aus
  Icon, Detail, Sammelliste und Sprachausgabe entfernt; der Tap zeigt
  stattdessen Bedeutung, Gruppe und kurze Erlaeuterung.
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
