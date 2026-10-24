export interface HospitalityMoment {
  id: "dining" | "kitchen" | "terrace" | "bar";
  time: string;
  act: string;
  tagline: string;
  title: string;
  headline: string;
  description: string;
  quote: string;
  quoteAuthor: string;
  quoteRole: string;
  gifSrc: string;
  mp4Src: string;
  posterSrc: string;
  badge: string;
  badgeColorClass: string;
  bulletPoints: string[];
  ctaText: string;
  ctaHref: string;
}

export const hospitalityMoments: HospitalityMoment[] = [
  {
    id: "dining",
    time: "12:30 Uhr",
    act: "Akt I · Mittagstisch & Gastraum",
    tagline: "GÄSTE IM MITTELPUNKT",
    title: "Service auf Augenhöhe & Lachen am Tisch",
    headline: "Gäste genießen, Service gewinnt Zeit für Herzlichkeit.",
    description:
      "Wenn zur Mittagszeit die Tische voll werden, zählt jedes Lächeln. Gäste scannen den Tisch-QR-Code und bestellen ohne App-Installation in Sekunden auf einer ruhigen Naturpapier-Speisekarte. Das Serviceteam tippt nicht mehr minutenlang in sperrige Kassenblöcke, sondern hat die Hände frei für echte Zuwendung, Weinempfehlungen und ein persönliches Gespräch.",
    quote:
      "Endlich tippe ich nicht mehr minutenlang auf starre Kassenbildschirme, sondern habe Zeit, meinen Gästen den Tagesfisch persönlich zu erzählen.",
    quoteAuthor: "Anna",
    quoteRole: "Serviceleitung, Gasthaus Alte Mühle",
    gifSrc: "/media/animated/hospitality-dining-table.gif",
    mp4Src: "/media/animated/hospitality-dining-table.mp4",
    posterSrc: "/media/animated/hospitality-dining-table-poster.jpg",
    badge: "Tisch 12 · 4 Gäste · QR-Bestellung aktiv",
    badgeColorClass: "bg-kl-terracotta text-white",
    bulletPoints: [
      "Sofortige Bestellung direkt am Gast-Smartphone ohne App-Download",
      "Maximale Entlastung der Servicekräfte bei vollem Gastraum",
      "Ruhige Quiet-UI-Speisekarte mit 14 dezenten EU-Allergenen",
    ],
    ctaText: "Speisekarte der Alten Mühle öffnen",
    ctaHref: "/alte-muehle/menu",
  },
  {
    id: "kitchen",
    time: "19:15 Uhr",
    act: "Akt II · Rush Hour am Pass",
    tagline: "KULINARISCHES HANDWERK",
    title: "Ruhe, Takt & Präzision am Pass",
    headline: "Fokus auf das Gericht, nicht auf Zettelwirtschaft.",
    description:
      "Samstagabend, 19:15 Uhr. Aus der Küche duftet es nach geschmorter Roter Bete, Röstaromen steigen auf, die Pfannen zischen. Am Pass montiert, zeigt das digitale KDS-Display jede Bestellung sofort nach Stationen und Gängen sortiert. Keine verlorenen Papierbons, kein Anschreien durch die Durchreiche – das Küchenteam kocht synchron und serviert auf den Punkt.",
    quote:
      "Die Küche bleibt ruhig, weil jeder Posten sofort sieht, wann der nächste Gang gefeuert werden muss. Ein echter Segen für das Handwerk.",
    quoteAuthor: "Markus",
    quoteRole: "Küchenchef & Gastronom",
    gifSrc: "/media/animated/hospitality-kitchen-pass.gif",
    mp4Src: "/media/animated/hospitality-kitchen-pass.mp4",
    posterSrc: "/media/animated/hospitality-kitchen-pass-poster.jpg",
    badge: "KDS-Station Pass · Gang 2 aktiv · 18 Gerichte im Takt",
    badgeColorClass: "bg-amber-500/20 text-amber-200 border border-amber-400/30",
    bulletPoints: [
      "Präzise Gangsteuerung (Vorspeise, Hauptgang, Dessert)",
      "Verzögerungsfreie Bons direkt an den richtigen Küchenposten",
      "Gäste-Extrawünsche und Allergien unübersehbar hervorgehoben",
    ],
    ctaText: "Gericht mit Wahlmöglichkeiten ansehen",
    ctaHref: "/alte-muehle/menu",
  },
  {
    id: "terrace",
    time: "20:45 Uhr",
    act: "Akt III · Sommerterrasse im Abendlicht",
    tagline: "ATMOSPHÄRE & RHYTHMUS",
    title: "Der Herzschlag einer vollen Sommerterrasse",
    headline: "Gläserklirren, Lichterketten und unerschütterlicher Funk.",
    description:
      "Draußen unter den Lichterketten füllen sich 40 Tische. Es wird gelacht, Gläser klingen aneinander, der Sommerabend pulsiert. Das Serviceteam nimmt Runden direkt am Gast auf dem iPhone auf. Und wenn das WLAN im hinteren Gartenwinkel abreißt? Kein Stillstand: Das integrierte lokale Bonjour-Mesh synchronisiert die Geräte direkt untereinander – kein Bon geht verloren.",
    quote:
      "Im Garten hatten wir früher ständig Funklöcher und doppelte Bestellungen. Mit KitchenLink läuft der Service einfach unterbrechungsfrei durch.",
    quoteAuthor: "Lena & Tim",
    quoteRole: "Betreiber, Restaurant Mauerwerk",
    gifSrc: "/media/animated/hospitality-evening-terrace.gif",
    mp4Src: "/media/animated/hospitality-evening-terrace.mp4",
    posterSrc: "/media/animated/hospitality-evening-terrace-poster.jpg",
    badge: "Außenbereich · 100% Offline-Mesh · 0ms Verzögerung",
    badgeColorClass: "bg-emerald-950/70 text-kl-emerald border border-emerald-800/60",
    bulletPoints: [
      "Vollständige Offline-Resilienz für Biergärten und Gewölbekeller",
      "Schneller Rundenservice ohne Zurücklaufen zum stationären Terminal",
      "Tischübersicht und Bon-Status immer griffbereit in der Tasche",
    ],
    ctaText: "Tischreservierung ansehen",
    ctaHref: "/alte-muehle/reserve",
  },
  {
    id: "bar",
    time: "23:30 Uhr",
    act: "Akt IV · Bar & Feierabend",
    tagline: "HARMONISCHER ABSCHLUSS",
    title: "Harmonie von der Vorbereitung bis zum Feierabend",
    headline: "Gute Gespräche, geteilte Rechnungen und stressfreier Feierabend.",
    description:
      "Der letzte Gast prostet dem Team zu. Rechnungen wurden am Tisch mit wenigen Fingertipps aufgeteilt – nach Personen oder Artikeln, bar oder kontaktlos. Zum Schichtende stimmt das Kassenbuch centgenau auf Knopfdruck. Keine nächtliche Zettelwirtschaft, kein Rechenstress: Das Zählprotokoll ist TSE-signiert und DATEV-fertig. Nach Hause gehen mit einem guten Gefühl.",
    quote:
      "Feierabend heißt jetzt wirklich Feierabend. Das digitale Zählprotokoll spart uns jeden Tag fast eine Stunde Zeit.",
    quoteAuthor: "David",
    quoteRole: "Barchef & Restaurantbetreiber",
    gifSrc: "/media/animated/hospitality-closing-bar.gif",
    mp4Src: "/media/animated/hospitality-closing-bar.mp4",
    posterSrc: "/media/animated/hospitality-closing-bar-poster.jpg",
    badge: "Bar-Terminal · Rechnungs-Split OK · DATEV 700 bereit",
    badgeColorClass: "bg-kl-terracotta/20 text-kl-terracotta border border-kl-terracotta/40",
    bulletPoints: [
      "Rechnungs-Splitting nach Artikeln oder Köpfen direkt am Tisch",
      "Revisionssichere KassenSichV § 146a AO TSE-Signatur im Hintergrund",
      "Automatisierter DATEV- und DSFinV-K 2.3-Export für die Kanzlei",
    ],
    ctaText: "Rechnungs-Split & Trinkgeld testen",
    ctaHref: "/alte-muehle/menu",
  },
];
