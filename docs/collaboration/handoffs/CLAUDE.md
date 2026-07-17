# Claude Code Handoff

**Updated:** 17 July 2026
**Branch:** `claude/guest-web-foundation` (KL-WEB-001); Integrationsarbeit auf `main`
**Status:** KL-WEB-001-Fundament umgesetzt, gegen die visuelle Claude-Design-
Referenz korrigiert und erneut verifiziert; Branch bereit fuer Review/PR.
Zuvor am selben Tag: PR #5/#6/#9 reviewt und integriert sowie die vier
KL-WEB-001-Entscheidungen des Nutzers in `DECISIONS.md` dokumentiert.

## Session-Teil 3: Visuelle Korrektur gegen Claude-Design Round 04

### Anlass

Der Nutzer verglich die erste Fassung der Gastkarte mit dem tatsaechlichen
visuellen Referenzscreen
(`docs/design/claude-design/round-04/export/territories.html`, Abschnitt 6c,
Screen 2 "Gast-Web · 390 px · dichte Karte") und stellte eine strukturelle
Abweichung fest, nicht nur eine Farbnuance. Die erste Fassung war aus
`DESIGN_SYSTEM.md` (der abgeleiteten, plattformneutralen Spezifikation)
implementiert worden, ohne den zugrunde liegenden visuellen Export noch
einmal direkt zu pruefen.

### Vorgehen

Sechs konkrete Abweichungen identifiziert und einzeln mit dem Nutzer
geklaert (nicht pauschal "an die Referenz angleichen"), da nicht jede
Abweichung gleich zu bewerten war:

| Punkt | Referenz | Erste Fassung | Nutzerentscheidung |
| --- | --- | --- | --- |
| Preiszeile | inline in Sekundaerzeile | eigene fette Zeile | **eigene Zeile beibehalten** (bewusste Abweichung von der Referenz) |
| Controls | umrandet (border-control) | gefuellt (Traube/grau) | umrandet uebernehmen |
| Bestellleiste | gesamte Leiste = Zitrone | neutrale Leiste + Button | gesamte Leiste uebernehmen |
| Venue-Kopf | buendig, Tisch-Kontext + Badge | abgesetzte Karte + Tagline | Kontext + Badge uebernehmen |
| Tag-Badges | "beliebt"/"vegetarisch" Pills | keine | uebernehmen |
| Dichte | kompakt | grosszuegiger | Referenzdichte uebernehmen |

### Umgesetzt

- `venue-data.ts`: `tagline` durch `isOpen: boolean` ersetzt; optionales
  `tag?: string` pro Artikel ("beliebt", "vegetarisch").
- `GuestMenuCard.tsx`: Venue-Kopf jetzt randlos (ausserhalb von `kl-page`),
  mit geoeffnet/geschlossen-Badge und Kontextzeile "Speisekarte" (bewusst
  **kein** erfundener Tischname — es gibt noch keine echte QR-/Tisch-Session;
  das waere irrefuehrend gewesen). Add-Button und Stepper auf
  `border-control`-Umrandung umgestellt. Bestellleiste ist jetzt ein
  einzelnes `<button>`-Element, das die gesamte Leiste als Zitronenflaeche
  einnimmt (Artikelzahl+Label links, Summe rechts), statt einer neutralen
  Leiste mit eingebettetem Button.
- `globals.css`: Abstaende in Menuezeilen und Section-Titeln verdichtet;
  `.kl-badge`-Varianten (hell/dunkel) ergaenzt.
- `tokens.css`: Den unabgestimmten Seiten-weiten Dark-Mode-Wechsel entfernt
  (vorher kippten `--kl-surface-page/-card/-control` unter
  `prefers-color-scheme: dark` auf Traube-Flaechen). Kein verifizierter
  Referenzscreen zeigt ein durchgehend dunkles Gast-Web — nur die Kueche ist
  laut Designsystem "immer Tief". Die Dringlichkeits-Tokens behalten ihre
  Dunkel-Variante (unbenutzt, aber vorwaertskompatibel fuer eine spaetere
  Bestellverfolgung).

### Verifikation

- Typecheck, ESLint, 18/18 Vitest-Tests, SSG-Build erneut gruen.
- Im Browser (375×812, hell und dunkel) erneut interaktiv geprueft: Klick auf
  "+" oeffnet den umrandeten Stepper, die Bestellleiste fuellt sich
  vollstaendig gelb mit korrekter Summe (6,90 € + 14,90 € = 21,80 € im Test),
  das Sheet zeigt dieselbe Summe. Dunkelmodus zeigt jetzt durchgehend die
  helle Karte mit Traube-Kopf statt eines page-weiten Farbwechsels.

### Risiken und offene Punkte (zusaetzlich zu Teil 2)

- Die Kontextzeile "Speisekarte" im Kopf ist ein bewusster Platzhalter ohne
  echten Tisch-/Kanalbezug; sobald ein QR-/Tisch-Fluss existiert, sollte
  `GuestVenue`/die Route einen echten Kontext (Tischlabel oder Kanal)
  mitfuehren statt des statischen Textes.
- Die Preiszeile weicht bewusst von der Referenz ab (Nutzerentscheidung);
  falls spaeter eine dichtere Variante gewuenscht wird, ist das eine reine
  CSS-/Markup-Aenderung ohne Datenmodelländerung.

## Session-Teil 2: KL-WEB-001 Gast-Web-Fundament

### Scope

Erster Umsetzungsschritt nach der Nutzer-Stack-Entscheidung (siehe
`DECISIONS.md`, Guest Web): Next.js-Fundament unter `guest-web/` mit der
mobilen Gastkarte. Bewusst nicht enthalten: Bestelluebermittlung,
autoritative Bestellgrenze, Supabase-Anbindung, PWA-Stufe.

### Umgesetzt

- Next.js 16 (App Router, TypeScript, `create-next-app`-Scaffold ohne
  Tailwind), hosting-neutral; Google-Font-Import des Scaffolds entfernt,
  System-Font-Fallbacks bis zur Freigabe von Bricolage/Source Sans 3.
- `src/styles/tokens.css`: alle Farb-, Radius- und Abstands-Tokens aus
  `DESIGN_SYSTEM.md` als CSS-Variablen mit identischen semantischen Namen
  (`brand.grape` -> `--kl-brand-grape`); hell/dunkel via
  `prefers-color-scheme`. `src/lib/design-tokens.ts` ist die typisierte
  Referenz; ein Vitest haelt beide Quellen konsistent und prueft, dass
  Zitrone in keinem Urgency-Token vorkommt.
- SSG-Menueroute `/[venueSlug]/menu` (`generateStaticParams`,
  `dynamicParams = false`, async `params` gemaess Next-16-Konvention) auf
  lokaler Sandbox-Venue "Gasthaus Alte Muehle" mit acht Gerichten
  (`src/lib/venue-data.ts` als bewusste Naht fuer den spaeteren
  Supabase-Pfad).
- Gastkarte (`src/components/GuestMenuCard.tsx`): venue-gefuehrter Kopf mit
  Traube-Fallback und kleiner KitchenLink-Vertrauenssignatur,
  traubenbasierte Mengensteuerung (>= 44 px, nie Zitrone), fixierte
  Bestellaktion als einzige dauerhafte Zitronenflaeche (gefuellt,
  Traube-Text, disabled neutral), Bestelluebersicht als Sheet (radius.sheet,
  Reduce-Motion-Guard) mit explizitem Sandbox-Hinweis statt Uebermittlung.
- Reine, getestete Cart-Logik (`src/lib/cart.ts`): Mengen 0..99, Summen nur
  aus Menuedaten (Serverseite rechnet spaeter ohnehin neu), de-DE
  Euro-Formatierung.
- Sandbox-Banner im Root-Layout auf jeder Seite (Blueprint §20).

### Verifikation

- `npm run typecheck`, `npm run lint`: sauber.
- `npm test`: 18/18 Vitest-Tests gruen (Cart-Invarianten,
  Fixture-Invarianten inkl. Acht-Gerichte-Anforderung, Token-Abgleich).
- `npm run build`: SSG erfolgreich, `/alte-muehle/menu` wird statisch
  vorgerendert.
- Visuell im Browser (375x812, hell und dunkel): Karte, Stepper-Zustaende,
  Zitronenaktivierung, Sheet mit korrekter Summe (18,40 EUR fuer
  6,90 + 11,50). Ein Dark-Mode-Befund wurde dabei gefunden und behoben:
  Venue-Kopf und Hinzufuegen-Button verschmolzen mit der Traube-Seite;
  beide liegen auf Dunkel jetzt auf `surface.darkRaised` (der erste Fix
  scheiterte an der CSS-Kaskadenreihenfolge, Override steht jetzt nach den
  Basisregeln).

### Risiken und offene Punkte

- Die Zitronen-CTA oeffnet nur die Uebersicht; verbindliche Uebermittlung
  folgt mit der autoritativen Bestellgrenze (Edge Function oder RPC, D6).
- Scaffold-generierte `guest-web/AGENTS.md`/`CLAUDE.md` (Next-16-Warnung,
  verweist auf gebuendelte Docs in `node_modules/next/dist/docs/`) wurden
  bewusst behalten.
- `npm audit` meldet Findings in Dev-Dependencies des Scaffolds; fuer die
  Sandbox unkritisch, vor Produktion zu pruefen.
- Kein venue-eigenes Logo-/Bild-Slot-Modell; der Kopf nutzt den
  dokumentierten Traube-Fallback.
- Vercel-Deployment selbst ist noch nicht eingerichtet (nur lokal
  gebaut/gestartet); eigener Schritt nach Merge.

## Session-Teil 1: Integration PR #6/#5/#9 und KL-WEB-001-Entscheidung

- Reviews und konfliktfreie Integration: PR #6 (Doku-Sync; zwei bereits
  ueberholte Angaben im Folge-Update korrigiert), PR #5 (Kitchen-Haertung;
  gated Screenshot-Harness real ausgefuehrt), PR #9 (KL-QA-002
  Offline-Smoke; Review ohne Befunde).
- Verifikation auf dem gemergten Stand (iPhone 17 Pro Simulator):
  Unit-Suite 60/60 inkl. der 8 neuen Offline-Tests, Standard-UI-Suite
  gruen, Capture-Harness passed (~29 s; `TEST_RUNNER_`-Variablen muessen
  als Umgebungsvariablen vor `xcodebuild` stehen), Scanner-Benchmark
  passed auf Baseline. `main` nach Push byte-identisch mit dem
  verifizierten Pruefstand.
- Die vier KL-WEB-001-Entscheidungen des Nutzers sind in `DECISIONS.md`
  (Guest Web) dokumentiert; CURRENT.md/WORK_QUEUE nachgezogen.
- Bekannte offene Punkte ausserhalb dieses Scopes: toter
  `PARALLEL_MISSIONS`-Verweis im DeepSeek-Handoff (P3),
  `codex/post-merge-hardening` weitgehend redundant, hartkodierter
  Supabase-Anon-Key im Relay (vorbestehend), PR #7/#8 ungereviewt,
  KL-INVENTORY-001 unbesetzt.

## Recommended Next Step

`claude/guest-web-foundation` reviewen (Peer oder Nutzer; visuelle
Produktflaeche -> Nutzerblick sinnvoll) und nach Abnahme mergen. Danach in
getrennten Scopes: autoritative Bestellgrenze (D6-Entscheidung faellt dort),
Vercel-Sandbox-Deployment, sowie Reviews von PR #7 (KL-OFFLINE-003) und
PR #8 (KL-WORKFORCE-001). KL-INVENTORY-001 neu vergeben oder streichen.
