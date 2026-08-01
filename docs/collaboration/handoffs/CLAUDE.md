# Claude Code Handoff

**Updated:** 1 August 2026 (Session-Teil 41: Abwesenheiten)
**Zuvor:** 1 August 2026 (Session-Teil 40: Dienstplan)
**Zuvor:** 1 August 2026 (Session-Teil 39: Zeiterfassung)
**Zuvor:** 31 July 2026 (Session-Teil 38: Manager-PIN)
**Zuvor:** 31 July 2026 (Session-Teil 37: Rollen und Rechte)
**Zuvor:** 31 July 2026 (Session-Teil 36: Betriebsschicht und Kassenabschluss)
**Zuvor:** 31 July 2026 (Session-Teil 35: Migrationen selbst angewendet)
**Zuvor:** 31 July 2026 (Session-Teil 34: Meilenstein 1 abgeschlossen)
**Zuvor:** 31 July 2026 (Session-Teil 33: Stationen und Annahmeregel)
**Zuvor:** 31 July 2026 (Session-Teil 32: KL-PAY-001, Rechnung und Zahlung)
**Zuvor:** 31 July 2026 (Session-Teil 31: KL-TABLE-002, Kellnerbestellung)
**Zuvor:** 30 July 2026 (Session-Teil 30: KL-TABLE-001, Tischkontext)
**Zuvor:** 30 July 2026 (Session-Teil 29: Staffelregel belegt, drei Fehlerklassen geschlossen)
**Zuvor:** 30 July 2026 (Session-Teil 28: Layoutstufe an einem starken Modell belegt)
**Zuvor:** 30 July 2026 (Session-Teil 27: Layoutstufe und erzwungenes Dekodieren)
**Zuvor:** 29 July 2026 (Session-Teil 26: Kostenloser Pfad repariert, Seitenrettung, Zeitlimit)
**Zuvor:** 28 July 2026 (Session-Teil 25: Vier deterministische Reparaturen, Guthaben erschöpft)

## Session-Teil 41: Abwesenheiten (1. August 2026)

### Anlass

Die Luecke, die Session-Teil 40 selbst benannt hatte: **es liess sich jemand
einteilen, der Urlaub hat.** Blueprint §9.2, „Urlaubs- und Krankmeldungen".

### Die tragende Entscheidung

Eine **Asymmetrie**, und sie folgt aus dem Betrieb, nicht aus der Technik:

- In eine **genehmigte** Abwesenheit hinein zu planen wird **abgewiesen**.
- Eine Abwesenheit auf **bereits geplante** Schichten zu genehmigen wird
  **erlaubt** und meldet die Schichten nur zurueck. Eine Krankmeldung kommt
  nach dem Dienstplan, nicht davor. Alles andere waere absurd: wer krank ist,
  ist krank.

Beide Haelften klingen einzeln plausibel und bilden erst zusammen den Betrieb
ab — der SQL-Test prueft deshalb ausdruecklich beide.

Ein **Antrag** blockiert noch nichts. Zwei **genehmigte** Abwesenheiten
derselben Person koennen sich nicht ueberschneiden; Antraege duerfen es, sonst
liesse sich ein Zeitraum nie umplanen. Beantragen braucht kein Recht,
entscheiden verlangt `schedule.manage` — kein siebtes Recht.

### Ein Befund, der teuer haette werden koennen

Das Modell bekam den Abwesenheits-Transport als neue Abhaengigkeit, mit dem
ueblichen **Netzwerk-Standardwert**. `KitchenLinkScheduleTests` reichte ihn
nicht durch — also telefonierten **48 Unit-Tests** plötzlich gegen die echte
Instanz und wurden rot, ohne dass an ihnen etwas falsch war.

Die Diagnose war unangenehm, weil die Ausgabe nichts hergab: `failed
(0.000 seconds)`, kein Text, und die **Menge der roten Tests wechselte von Lauf
zu Lauf**. Das sah nach einem Haenger aus. Erst ein serialisierter Lauf
(`-maximum-parallel-testing-workers 1`) zeigte, dass der Lauf sauber zu Ende
lief und die Fehler echt waren.

Lehre fuer die naechste Abhaengigkeit: ein Standardwert, der ins Netz greift,
macht aus Unit-Tests stillschweigend Integrationstests. Die Testfabrik reicht
ihn jetzt durch, mit einem Kommentar, der den Fall benennt.

### Verifikation

10 SQL-Tests gruen, 23 Migrationen wiederholbar, 567 iOS-Unit-Tests.
Simulator-Durchlauf: Antrag mit Kollisionswarnung, Genehmigung mit der Meldung
„Eine geplante Schicht faellt in den Zeitraum und muss neu besetzt werden".
Migration angewendet und geprueft — beide Ausschluss-Constraints vorhanden,
`operator_plan_shift` **ersetzt** statt dupliziert (eine Version), keine Tabelle
in `public` ohne RLS.

### Offen

Ein realer Durchlauf mit einem zweiten Konto (`SANDBOX_SETUP.md` §6.13).

**Der UI-Flake breitet sich aus.** Neben dem vorbestehenden
`MenuManualEditorUITests` fiel diesmal
`testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish` — ein **zweiter**
Gast-Vorschau-Test, isoliert gruen in 48 Sekunden. Zusammen mit
`testGuestPreviewUsesCountersAndCompactQuantityControl` (Session-Teil 39) sind
es jetzt zwei aus derselben Familie: langsame Tests, die im Parallellauf um den
Simulator konkurrieren. Das stuetzt die Diagnose der laufenden Flake-Sitzung —
es ist kein Einzeltest, sondern die Auslastung.

### Empfohlener naechster Schritt

§9.2 hat noch: Verfuegbarkeiten („ich kann dienstags abends"), Schichtvorlagen
und Wiederholungen, Sollbesetzung mit Unterbesetzungswarnung, Benachrichtigung,
Tauschanfragen. Davon traegt **Sollbesetzung** am meisten: sie beantwortet die
Frage, die eine Planende beim Blick auf die Woche wirklich hat — „reicht das?".
Die Domaene hat dafuer bereits `targetHeadcount` auf der Schichtvorlage.

## Session-Teil 40: Dienstplan (1. August 2026)

### Anlass

Blueprint §9.2 — das Gegenstueck zu Session-Teil 39. Dort steht, wer
**tatsaechlich** gearbeitet hat; hier, wer arbeiten **soll**. Ohne diese Scheibe
hat der Soll-/Ist-Vergleich aus §9.3 nichts, wogegen er vergleichen koennte.

### Umgesetzt (KL-PLAN-001)

- `planned_shifts` mit dem Lebenszyklus der seit KL-WORKFORCE-001 getesteten
  Domaene (`WorkforceShiftLifecycle.swift`): Entwurf → veroeffentlicht →
  angenommen oder abgelehnt. `swap_requested` fehlt bewusst — ein Status, den
  nichts erreichen kann, ist Ballast.
- Tragende Zusage als **Ausschluss-Constraint** (`btree_gist`): niemand ist
  zweimal gleichzeitig verplant. Eine abgelehnte Schicht blockiert nicht mehr.
- **Ein Entwurf ist fuer den Betroffenen unsichtbar** (RLS) — der ganze Sinn
  der Trennung.
- Sechstes Recht `schedule.manage`; nicht per Manager-PIN freigebbar. Die
  eigene Schicht zu beantworten braucht kein Recht.
- App: Bereich `Dienstplan`.

### Drei Befunde unterwegs

- Eine **Zaehlung** der Rechte brach im SQL- wie im Swift-Test, sobald ein
  sechstes dazukam. Beide pruefen jetzt inhaltlich, was eine Rolle
  **abgrenzt** — das ist ohnehin die Aussage, um die es geht.
- Der Demo-Team-Transport kannte das neue Recht nicht und liess die
  Wochenansicht im Simulator stillschweigend verschwinden, obwohl er die
  Datenbank spiegeln soll. Genau die Drift, die diese Transporte verhindern
  sollen.
- Die Absage bei einer Ueberlappung war **unsichtbar**: der Hinweis lag auf dem
  Bildschirm hinter dem Bearbeitungsbogen, wer speicherte sah nichts geschehen.
  `plan(...)` gibt den Grund jetzt zurueck, der Bogen zeigt ihn selbst.

### Verifikation

9 SQL-Tests gruen, 22 Migrationen wiederholbar, 550 iOS-Unit-Tests, 14 UI-Tests
(weiterhin nur der vorbestehende `MenuManualEditorUITests`-Fehlschlag).
Simulator-Durchlauf ueber Veroeffentlichen und eine abgewiesene Doppelbelegung.
Migration angewendet und geprueft: Ausschluss-Constraint vorhanden, drei Rollen
tragen das Recht, per PIN **nicht** freigebbar, keine Tabelle in `public` ohne
RLS.

### Offen

Ein realer Durchlauf mit einem zweiten Konto (`SANDBOX_SETUP.md` §6.12).

### Empfohlener naechster Schritt

§9.2 ist damit im Kern da, aber nicht vollstaendig: Verfuegbarkeiten und
Abwesenheiten, Schichtvorlagen und Wiederholungen, Sollbesetzung und
Unterbesetzungswarnung, Benachrichtigung, Tauschanfragen, Urlaub und Krankheit.
Die Domaene modelliert das alles bereits in `WorkforceTimeModels.swift`;
persistiert ist es nicht. Die naechste sinnvolle Scheibe ist **Verfuegbarkeit
und Abwesenheit**, weil sie die Planung erst schuetzt: heute laesst sich jemand
einteilen, der Urlaub hat.

## Session-Teil 39: Zeiterfassung (1. August 2026)

### Anlass

Meilenstein 2, §9.3. Und der Anlass, die tote Workforce-Domaene endlich
anzuschliessen: seit KL-WORKFORCE-001 (17. Juli) liegen unter
`kitchenlink/Features/Workforce/` 1850 Zeilen Code und Tests mit **null
Referenzen** aus der App. Ihr fehlten Persistenz und Oberflaeche — diese
Scheibe liefert beides fuer das Stempeln.

Bewusst **nicht** der Manager-PIN: der lief zeitgleich in einer eigenen
Sitzung und fasst dasselbe Rechtesystem an.

### Umgesetzt (KL-TIME-001)

- `time_entries`, `time_breaks`, beide Invarianten als Index: **niemand steht
  zweimal gleichzeitig auf der Uhr**, hoechstens eine Pause je Eintrag.
- `kitchenlink_time_entry_seconds` als *eine* Quelle fuer brutto/Pause/netto.
- RPCs: `operator_clock_in`, `operator_clock_out`, `operator_break_start`,
  `operator_break_end`, `operator_my_time_status`, `operator_team_time`,
  `operator_correct_time_entry`.
- App: Bereich `Zeiterfassung` mit laufender Uhr, Pausensteuerung, Tagessumme,
  Team-Stand und Korrekturbogen.

**Die Trennung der drei Fachobjekte bleibt** (Blueprint §9): ein Zeiteintrag
haengt ausdruecklich nicht an einer Betriebsschicht.

**Kein sechstes Recht.** Die eigene Zeit zu stempeln braucht keines — die
Kueche muss auf die Uhr kommen, ohne zu fragen. Fremde Zeiten zu sehen und zu
korrigieren verlangt das bestehende `staff.manage`. Ein Recht, das nur an einer
Stelle wirkt, waere eine Zeile mehr in jeder Rollenliste ohne Gewinn — und die
parallele PIN-Arbeitslinie fasst genau diese Stelle an.

### Zwei Fehler unterwegs

- Der SQL-Test hing an der **Uhrzeit des Laufs**: er startete um 01:57, „zwei
  Stunden zurueckdatieren" fiel damit auf den Vortag, und die Tagesliste
  enthielt einen Eintrag statt zwei. Der Code war richtig (ein Nachtdienst
  gehoert zum Starttag) — der Test hat die Regel uebersehen, die er haette
  pruefen sollen. Er prueft sie jetzt ausdruecklich.
- Der Constraint `ended_at > started_at` wies einen Eintrag ohne Dauer ab. Wer
  sich vergreift und sofort wieder ausstempelt, erzeugt genau den — im Test wie
  im Betrieb. Jetzt `>=`: eine Null-Dauer ist ehrliche Datenlage, ein roher
  Constraint-Fehler waere schlechter. Eine Korrektur **von Hand** verlangt
  weiterhin ein Ende nach dem Beginn, weil es dort ein Tippfehler waere.

### Verifikation

- SQL gegen echtes PostgreSQL in einer eigenen Testvenue; alle sieben Tests des
  Verzeichnisses bestehen, auch **zusammen mit der PIN-Migration** aus der
  parallelen Sitzung (temporaer eingelegt, danach wieder entfernt).
- 498 iOS-Unit-Tests gruen, erster Anlauf.
- Simulator: einstempeln, Pause (Arbeitszeit steht still, Pausenuhr laeuft),
  Korrektur eines seit 20 Stunden offenen Eintrags.

### Nachtrag: Integration mit der PIN-Arbeitslinie (1. August)

`supabase db push` verweigerte zunaechst: auf der Instanz lag bereits
`20260731230000_manager_pin.sql` aus der parallelen Sitzung, deren Datei noch
nicht auf `main` war. Die CLI verlangt eine lueckenlose lokale Historie.

Der von der CLI vorgeschlagene Weg (`migration repair --status reverted
20260731230000`) waere **falsch** gewesen: er markiert eine tatsaechlich
angewendete Migration als zurueckgenommen.

Ich habe daraufhin zuerst **lokal gemergt** — und dabei uebersehen, dass fuer
dieselbe Arbeit bereits **PR #37 offen** war. Auf Nachfrage des Nutzers wurde
der lokale Merge verworfen, PR #37 ueber GitHub gemergt und der Stand von dort
geholt. Lehre: vor einem Merge aus einem fremden Arbeitsbaum erst `gh pr list`.

**Ein echter Befund beim Zusammenfuehren:** `manager-pin.sql` und
`time-clock.sql` belegten dieselben Konto-UUIDs (`…f1` ff.) fuer verschiedene
E-Mails. Alle SQL-Tests laufen nacheinander auf **derselben** Datenbank, also
liess `on conflict (id) do nothing` die Konten des spaeter laufenden Tests
still fallen — und der Fehler tauchte weit entfernt als „kein Konto" auf.
`time-clock` hat jetzt einen eigenen Block (`…9901` ff.); der Kopf von
`scripts/verify-supabase-migrations.sh` listet die belegten Bereiche, damit der
naechste Test nicht in dieselbe Falle laeuft.

Verifikation auf dem gemergten Stand: 8 SQL-Tests gruen, 21 Migrationen
wiederholbar, 526 iOS-Unit-Tests gruen. Migration angewendet und geprueft:
`migration list` deckungsgleich, nichts offen, weiterhin keine Tabelle in
`public` ohne RLS.

**Zwei UI-Tests im vollen Lauf rot, beide kein Inhaltsfehler:**
`MenuManualEditorUITests.testManualMenuEditorCoreFlow` schlaegt weiterhin
vorbestehend fehl. Neu dazu kommt
`testGuestPreviewUsesCountersAndCompactQuantityControl`, das im vollen
Parallellauf zweimal rot war und **isoliert beide Male bestand** — mit der
PIN-Arbeit sind zehn UI-Tests dazugekommen, und die Klone konkurrieren
sichtbar um den Simulator. Das ist ein Flake der Testumgebung, kein Befund am
Produkt, sollte aber behoben werden, bevor jemand ihn fuer echt haelt.

### Empfohlener naechster Schritt

Nach dem Push: **§9.2 Schichtplanung** — Verfuegbarkeiten, Wochenplanung,
Vorlagen, Veroeffentlichung, Annahme/Ablehnung/Tausch, Urlaub und Krankheit.
Das ist der groesste verbleibende Block von Meilenstein 2 und die Voraussetzung
fuer Soll-/Ist und Ueberstunden (§9.3), die ohne Planung nichts haben, wogegen
sie vergleichen koennten. Die Domaene dafuer liegt in
`Features/Workforce/WorkforceTimeModels.swift` und
`WorkforceShiftLifecycle.swift` bereits vollstaendig und getestet vor.

## Session-Teil 38: Manager-PIN (31. Juli 2026)

### Anlass

Die zweite Haelfte von Blueprint §9.1. Der Satz lautet „sensible Aktionen per
besonderem Recht **oder** Manager-PIN"; Session-Teil 37 hat nur das Recht
gebaut. Damit musste eine Servicekraft, die am Tisch eine Zahlung stornieren
soll, den Manager physisch holen — oder der Betrieb vergibt `payments.refund`
reihum an alle und macht die Rechte wertlos.

### Die tragende Entscheidung: die PIN gehoert einer Person

Naheliegend waere eine PIN je Venue gewesen — eine Zahl, die im Haus bekannt
ist. Sie scheitert an Blueprint §8.2: jeder Zahlungsvorgang ist auditiert, und
eine Haus-PIN kann die Frage „wer hat das freigegeben?" prinzipiell nicht
beantworten. Sie beweist nur, dass irgendwer sie kannte.

Also hinterlegt jede Fuehrungskraft ihre eigene PIN, und die Freigabe traegt
ihren Namen. Zwei Dinge fallen daraus von selbst heraus:

- **Was eine PIN darf, ist, was ihr Inhaber selbst duerfte.** Kein Recht wird
  erfunden. Die PIN einer Schichtleitung gibt einen Storno frei, weil
  Schichtleitung `payments.refund` traegt.
- **Eine Herabstufung wirkt sofort.** Der Rechtecheck laeuft beim Freigeben
  *und* beim Verbrauchen gegen die aktuelle Rolle; niemand muss daran denken,
  eine PIN zu loeschen.

**Vier der fuenf Rechte sind ueberbrueckbar, `staff.manage` nicht.** Wer per
geliehener PIN Personal verwalten duerfte, koennte sich in derselben Minute
selbst zum Inhaber machen — das waere keine Freigabe fuer eine Aktion mehr,
sondern eine dauerhafte Rechteerhoehung.

**Kein Namensauswahl-Schritt.** Die Fuehrungskraft tippt nur ihre PIN; das ist
der Handgriff, den der Betrieb erwartet, und er verraet der Servicekraft nicht
die Liste der Vorgesetzten. Der Preis: fuehren zwei Personen dieselbe PIN, wird
**nichts** freigegeben (`pin_ambiguous`) statt geraten. Eine Freigabe, die
niemandem zuzuordnen ist, waere fuer §8.2 wertlos. Doppelte PINs beim Setzen
abzuweisen habe ich verworfen — das waere ein Orakel gewesen, mit dem jemand
alle PINs der Venue haette durchprobieren koennen.

### Umgesetzt

- `manager_pins`, `manager_pin_attempts`, `manager_overrides` — alle drei mit
  RLS **ohne Policy** und ohne Grants. Kein Client liest dort je eine Zeile;
  der Hash einer vierstelligen PIN waere auf einem Geraet in Sekunden
  zurueckgerechnet. Gelesen wird nur ueber `operator_recent_overrides`, das den
  Token-Hash gar nicht erst herausgibt.
- `operator_set_manager_pin` / `operator_clear_manager_pin` /
  `operator_manager_pin_status` / `operator_authorize_with_pin` /
  `operator_recent_overrides`.
- `kitchenlink_require_permission_or_pin` — bewusst ein **eigener Name** statt
  einer Ueberladung von `kitchenlink_require_permission`: stuenden `(text,text)`
  und `(text,text,text default)` nebeneinander, waere jeder zweistellige Aufruf
  mehrdeutig und PostgreSQL wuerde ihn abweisen.
- Die vier Geldfunktionen bekommen **einen** vorbelegten Parameter am Ende
  (Drop + Create in derselben Transaktion, wie bei `guest_web_submit_order_v2`
  in `20260730120000`). Aufrufer ohne Freigabe aendern sich nicht.
- App: ein geteiltes Freigabe-Blatt fuer Kasse und Rechnung, die eigene PIN und
  das Freigabeprotokoll unter `Team`.

**Warum die Freigabe ein Token ist und nicht einfach „gilt fuer die naechste
Aktion":** eine schwebende Erlaubnis, die still auf irgendeine spaetere
passende Aktion faellt, ist genau die Sorte Verhalten, aus der ein Vorfall wird
(„ich habe abgeschlossen und es ging, ich weiss nicht warum"). Der Token bindet
die Freigabe an den Aufruf.

### Drei Details, bei denen Sorgfalt noetig war

- **Eine falsche PIN wirft keinen Fehler**, sondern gibt `granted = false`
  zurueck. Eine Exception rollt die Transaktion zurueck und mit ihr den
  hochgezaehlten Fehlversuch — die Sperre haette nie gegriffen.
- **Gezaehlt wird am anfragenden Zugang**, nicht am Manager: eine falsche PIN
  gehoert zu niemandem. Am Geraet der Servicekraft gezaehlt, trifft die Sperre
  den, der probiert, und legt nicht das Lokal lahm (ein Test belegt beides).
- **`extensions.crypt`, schema-qualifiziert**, wie `digest()` seit KL-WEB-003.
  Der Testharness legt pgcrypto in `extensions` an, die Migrationen laufen mit
  `set search_path = public, pg_temp`. Auf der Instanz nachgeprueft: der Hash
  beginnt mit `$2a$`.

### Verifikation

- **SQL gegen echtes PostgreSQL** (`scripts/tests/manager-pin.sql`, eigene
  Testvenue, 17 gepruefte Abschnitte): Service darf keine PIN hinterlegen,
  `0000`/`1234` werden abgewiesen, falsche PIN zaehlt hoch statt zu werfen,
  Storno geht mit Freigabe durch und der Token ist danach verbraucht, er gilt
  nicht fuer eine andere Aktion, nicht fuer einen anderen Zugang und nicht nach
  Ablauf, `staff.manage` ist nicht ueberbrueckbar, eine herabgestufte
  Fuehrungskraft gibt nichts mehr frei, fuenf Fehlversuche sperren nur diesen
  Zugang, zwei gleiche PINs geben nichts frei, das Protokoll nennt beide Seiten
  und keinen Token-Hash, RLS mit `set role`. Alle sieben SQL-Tests und die
  Wiederholbarkeit aller 20 Migrationen gruen.
- **512 iOS-Unit-Tests gruen** (29 neu), **10 UI-Tests gruen**, darunter ein
  neuer, der die Sperre und das Freigabe-Blatt wirklich durchklickt.
- **Simulator, beide Wege:** Kasse mit Anfangsbestand 150,50 per PIN geoeffnet;
  am Tisch kassiert, dann storniert — „Zahlung storniert — freigegeben und
  protokolliert", Rechnung wieder bei 44,60. Team-Bildschirm: PIN hinterlegt,
  Karte wechselt auf „Deine PIN ist hinterlegt".
- **Migration angewendet und auf der Instanz geprueft:** drei Tabellen, alle
  mit RLS, **null** Policies und **null** Grants darauf, weiterhin keine
  Tabelle in `public` ohne RLS, alle acht Funktionen vorhanden, die vier
  Geldfunktionen mit je einem Argument mehr, bcrypt erreichbar.

### Zwei Fehler unterwegs

- Der Satz lautete „Als Service darfst du schicht oeffnen nicht" — `label`
  kleingeschrieben in eine Schablone gesteckt. Das kam aus KL-ROLE-001 und fiel
  erst im Simulator auf. Jetzt traegt jedes Recht seinen fertig verneinten
  Satzteil (`deniedClause`), weil das „nicht" im Deutschen je nach Objekt an
  eine andere Stelle gehoert.
- Im UI-Test hing der Identifier auf einer `KitchenLinkV2Card`, die gar kein
  Accessibility-Element ist. Jetzt sitzt er auf dem Text.

### Offen

Ein realer Durchlauf mit einem zweiten Konto (`SANDBOX_SETUP.md` §6.10) —
zusammen mit dem noch offenen Durchlauf aus Session-Teil 37, es ist derselbe
Handgriff. Im Simulator ist der gesperrte Zustand seit dieser Scheibe
vorfuehrbar (`--kitchenlink-demo-service-role`), aber ein zweites echtes Konto
ersetzt das nicht.

Aus dieser Scheibe bewusst nicht enthalten: eine Freigabe an ein bestimmtes
Objekt zu binden (der Bezug wird protokolliert, aber nicht erzwungen),
PIN-Rotationsfristen, und die Freigabe aus der Ferne (das Geraet der
Fuehrungskraft bestaetigt, statt dass sie ihre PIN fremd eintippt).

Weiterhin offen und unabhaengig: `MenuManualEditorUITests.testManualMenuEditorCoreFlow`
schlaegt vorbestehend fehl.

### Empfohlener naechster Schritt

Meilenstein 2 hat jetzt nur noch §9.2 und §9.3 offen: Schichtplanung,
Zeiterfassung, Soll-/Ist. Dafuer liegt seit KL-WORKFORCE-001 eine
vollstaendige, getestete Domaene unter `Features/Workforce/` mit **null
Referenzen** aus der App; ihr fehlen Persistenz und Oberflaeche. Das ist die
groesste noch offene Scheibe des Meilensteins und faengt sinnvoll bei der
Persistenz an, nicht beim Bildschirm.

> **Nachtrag bei der Integration (1. August):** die Zeiterfassung (§9.3) ist mit
> Session-Teil 39 inzwischen umgesetzt; offen bleibt die **Planung** (§9.2).

## Session-Teil 37: Rollen und Rechte (31. Juli 2026)

### Anlass

Zweiter Punkt von Meilenstein 2 (Blueprint §9.1). Bis hierher galt: **wer
angemeldet ist, darf alles.** `is_venue_staff` prueft die Mitgliedschaft, nicht
die Befugnis — jede Servicekraft konnte die Kasse abschliessen, stornieren und
Geld entnehmen. Also genau die drei Handgriffe, die Session-Teil 36 gerade
gebaut hatte.

### Die eigentliche Entscheidung war der Zuschnitt

Es gibt 25 `operator_`-RPCs. Sie alle mit einer Rechtepruefung zu versehen haette
bedeutet, 25 Funktionsrumpfe zu kopieren — ein Wartungsalbtraum und eine
Drift-Quelle. Ausserdem *sollen* die meisten jedem Personal offenstehen: die
Kueche braucht `operator_mark_station_ready`, der Service
`operator_record_payment`.

Deshalb: **fuenf Rechte, alle fuenf erzwungen.** `shift.open`, `shift.close`,
`cash.movement`, `payments.refund`, `staff.manage`. Kein Recht steht in der
Liste, das nirgends geprueft wird — sonst zeigte der Team-Bildschirm Rollen mit
Rechten an, die niemanden an irgendetwas hindern. Eine Rolle mit leerer
Rechteliste heisst „darf alles Alltaegliche, nichts Sensibles"; das steht auch
so auf dem Bildschirm.

Verworfene Alternative: die Originalfunktionen per `alter function ... rename to`
umbenennen und Wrapper davorsetzen. Kuerzer, aber ein Footgun — eine spaetere
Migration mit `create or replace` auf den Originalnamen wuerde die Pruefung
still entfernen.

### Umgesetzt

- `venue_roles` je Venue (nicht als Aufzaehlung im Code) mit den neun
  Standardrollen aus §9.1; ein Trigger auf `venues` legt sie an. „Eigene Rollen
  mit granularen Rechten" ist damit spaeter ein Datensatz, kein Umbau.
- `venue_staff.role`: CHECK auf `'operator'` raus, Fremdschluessel auf
  `venue_roles(venue_id, key)` rein.
- `kitchenlink_require_permission` — ein Aufruf statt vier Zeilen je RPC.
- Die vier Geldfunktionen ersetzt (nur die Gate-Zeile getauscht),
  `operator_create_venue` vergibt `owner` statt `operator`.
- `operator_my_permissions`, `operator_venue_team`, `operator_venue_roles`,
  `operator_add_staff`, `operator_set_staff_role`, `operator_remove_staff`.
- App: Bereich `Team`; die Kasse sperrt und **erklaert**.

### Zwei Dinge, bei denen Sorgfalt noetig war

- **Bestandspersonal:** `operator` wird zu `owner`, nicht zu `service`. Diese
  Zeilen durften bis heute alles; ihnen per Migration Rechte zu nehmen waere
  eine stille Entrechtung. Der Spaltendefault fuer *neue* Zeilen steht dagegen
  auf `service`.
- **`operator_create_venue` musste ersetzt werden** (wegen des
  Fremdschluessels). Ich hatte den Rumpf zuerst aus dem Gedaechtnis nachgebaut
  und dabei an fuenf Stellen abweichend geschrieben — unter anderem fehlte die
  Slug-Obergrenze von 60 Zeichen, und drei Fehlerkennungen lauteten anders, auf
  die `venue-onboarding.sql` prueft. Jetzt ist der Rumpf wortgleich mit dem
  Original; geaendert ist genau ein Wort.

### Verifikation

- SQL gegen echtes PostgreSQL in einer **eigenen Testvenue**: Service wird bei
  allen fuenf Aktionen abgewiesen und darf den Alltag weiterhin; Schichtleitung
  darf die Kasse, aber kein Personal; alle drei Sperren belegt (Selbstaenderung,
  Inhaberschutz, letzter Inhaber); Bestandspersonal behaelt seine Rechte; RLS
  mit `set role`. Dazu ein `auth.users`-Stub (zwei Spalten, ohne Grants).
- 483 iOS-Unit-Tests gruen, 13 UI-Tests gruen.
- Simulator: Team-Bildschirm, Rollenwechsel, Liste sortiert sich neu.
- Migration angewendet und auf der Instanz geprueft: neun Rollen, **null**
  Zeilen auf der abgeschafften Rolle, das Bestandskonto ist Inhaber, weiterhin
  keine Tabelle in `public` ohne RLS.

### Zwei Fehler unterwegs

- Das Modell prueft das Recht in den `can…`-Eigenschaften fuer die Knoepfe,
  feuerte die Anfrage aber trotzdem — ein Test hat es aufgedeckt. Jetzt brechen
  `openShift`, `bookMovement` und `closeShift` selbst ab.
- E-Mail-Platzhalter wurden blau statt grau gezeichnet: `Text("…@…")` laeuft als
  `LocalizedStringKey` durch die Markdown-Verarbeitung und verlinkt die
  Adresse. Betraf **fuenf** Stellen (Team, Restaurant, Tische, Service,
  Publish-Sheet); jetzt ueberall `Text(verbatim:)`.

### Offen

Ein realer Durchlauf mit einem zweiten Konto (`SANDBOX_SETUP.md` §6.9). Der
gesperrte Zustand ist im Simulator nicht vorfuehrbar, weil der Demo-Zugang
Inhaber ist — er ist durch vier Unit-Tests und den SQL-Test belegt.

Weiterhin offen und unabhaengig: `MenuManualEditorUITests.testManualMenuEditorCoreFlow`
schlaegt vorbestehend fehl.

### Empfohlener naechster Schritt

Meilenstein 2 hat noch §9.2 und §9.3 offen: Schichtplanung, Zeiterfassung,
Soll-/Ist. Dafuer liegt seit KL-WORKFORCE-001 eine vollstaendige, getestete
Domaene unter `Features/Workforce/` mit **null Referenzen** aus der App; ihr
fehlen Persistenz und Oberflaeche. Kleinere Alternative davor: der Manager-PIN
aus §9.1, damit eine Servicekraft am Tisch eine Freigabe holen kann, statt den
Manager zu suchen.

## Session-Teil 36: Betriebsschicht und Kassenabschluss (31. Juli 2026)

### Anlass

Start von Meilenstein 2. Der Blueprint listet fuenf Teile (§8.3 Betriebsschicht,
§9.1 Rollen, §9.2 Planung, §9.3 Zeit, Soll-/Ist). Gewaehlt wurde §8.3 zuerst,
weil Meilenstein 1 den Geldkreis geoeffnet, aber nicht geschlossen hat: es wurde
kassiert, storniert und Trinkgeld genommen — und am Abend gab es nichts, wogegen
jemand haette zaehlen koennen.

### Befund vorab

`Features/Workforce/` (1200 Zeilen Domaene, 650 Zeilen Tests, 38 Tests gruen aus
KL-WORKFORCE-001) hat **null Referenzen** aus der App. Getestet und komplett
tot. Das ist Meilenstein 2, Teil 3 bis 5 — eine Grundlage, der Persistenz und
Oberflaeche fehlen.

### Umgesetzt (KL-SHIFT-001)

- `business_shifts` (Anfangsbestand, gezaehlt, erwartet, Abweichung, Z-Nummer)
  mit partiellem Unique-Index: je Venue hoechstens **eine** offene Schicht.
- `cash_movements` fuer Entnahme, Ausgabe, Einlage.
- `kitchenlink_shift_totals` als *eine* Quelle fuer Bericht, Abschluss und
  Live-Anzeige — dreifach getrennt gerechnet wuerde der erwartete Bestand
  irgendwann von dem abdriften, was der Abschluss festhaelt.
- `payments.shift_id` per `before insert`-Trigger statt per Aenderung an
  `operator_record_payment`: so greift die Zuordnung auch fuer jeden spaeteren
  Zahlungsweg, ohne dass ihn jemand daran erinnern muss.
- RPCs: `operator_open_shift`, `operator_record_cash_movement`,
  `operator_shift_report`, `operator_recent_shifts`, `operator_close_shift`.
- App: neuer Bereich `Kasse`.

**Zwei Produktentscheidungen**, beide bewusst und im Code begruendet:

1. Eine **Zahlung** ohne offene Schicht wird nicht blockiert (Geld annehmen darf
   nie an einem vergessenen Knopfdruck scheitern); sie bleibt ohne `shift_id`
   und erscheint im Bericht als „ausserhalb der Schicht". Eine **Entnahme**
   verlangt dagegen eine offene Kasse.
2. Die Abweichung wird festgehalten, nicht verhindert. Offene Rechnungen werden
   vor dem Abschluss gewarnt, nicht erzwungen.

### Verifikation

- SQL gegen echtes PostgreSQL: zweite offene Schicht abgewiesen, Karte zaehlt
  nicht in die Schublade, Bar-Trinkgeld schon, Storno senkt den Bestand wieder,
  geschlossene Schicht bleibt eingefroren, Z-Nummern lueckenlos, RLS mit
  `set role` belegt (als Eigentuemer waere der Abschnitt gruen gewesen, ohne
  irgendetwas zu belegen).
- 462 iOS-Unit-Tests gruen, 13 UI-Tests gruen.
- Simulator: oeffnen mit 150,50, Ausgabe 12,50 buchen, mit Fehlbetrag -0,50
  abschliessen (Z-Bericht 1), danach erneut oeffnen und ohne Abweichung
  abschliessen.
- `supabase db push` angewendet und auf der Instanz geprueft: beide Tabellen,
  alle RPCs, der Trigger und `payments.shift_id` vorhanden, weiterhin keine
  Tabelle in `public` ohne RLS.

### Zwei Fehler unterwegs

- Der SQL-Test legte einen eigenen Tisch an und brach damit `table-context`,
  das genau sechs aktive Tische und sechs aktive Tokens erwartet. Der Test
  raeumt jetzt beides auf (der Token wird nicht mit dem Tisch stillgelegt).
- Die Ansicht war die einzige Stelle im Projekt mit `.dateTime` und zeigte auf
  einem englisch eingestellten Geraet „Jul 31 at 17:11" in einer durchgehend
  deutschen App. Jetzt fest auf `de_DE`, wie ueberall sonst im Projekt.

### Offen

Ein realer Tagesdurchlauf am Geraet (`SANDBOX_SETUP.md` §6.8) — sowie die
Abnahmen aus Session-Teil 35, die alle keine Datenbankarbeit mehr brauchen.

Weiterhin offen und unabhaengig: `MenuManualEditorUITests.testManualMenuEditorCoreFlow`
schlaegt vorbestehend fehl.

### Empfohlener naechster Schritt

Meilenstein 2 weiter: **Rollen und Rechte (§9.1)**. `venue_staff.role` existiert
schon als Spalte, wird aber nirgends ausgewertet — jedes angemeldete Personal
darf derzeit alles, auch abschliessen und stornieren. Blueprint §9.1 verlangt
Standardrollen und „sensible Aktionen per besonderem Recht oder Manager-PIN";
Kassenabschluss und Storno sind die ersten beiden Kandidaten. Danach die tote
Workforce-Domaene sichtbar machen (§9.2/§9.3).

## Session-Teil 35: Migrationen selbst angewendet, Ledger-Drift geschlossen (31. Juli 2026)

### Anlass

Rückfrage des Nutzers: „Was meinst du eigentlich genau mit Abnahme? Warum soll
ich die durchführen? Du solltest in Supabase eigentlich alles selbst
erledigen." Er hatte recht. Ich hatte zwei Dinge unter einem Wort vermischt:

- das **Anwenden** der Migrationen — mechanisch, und über die lokal
  eingeloggte, verknüpfte Supabase-CLI von hier aus machbar. Das ist Agentenarbeit.
- die **Abnahme** im eigentlichen Sinn — sein Produkturteil, ob sich eine
  Funktion auf einem echten Gerät richtig anfühlt. Das bleibt bei ihm.

Alle bisherigen Handoffs haben das erste als „Nutzerabnahme steht aus" an ihn
zurückgegeben. `SANDBOX_SETUP.md` §0 hat das mit „die Agenten legen keine
Cloud-Ressourcen an" sogar als Regel festgeschrieben — die Regel meinte
Projekte, Keys und Auth-Einstellungen, nicht Migrationen.

### Befund: Ledger-Drift zwischen SQL-Editor und CLI

`supabase migration list` zeigte **sieben** offene Migrationen, nicht die vier
dieser Sitzung — auch `20260724000000` und die beiden Tischmigrationen, für die
der Nutzer „Abnahme ist durch" gemeldet hatte. Ursache: der SQL-Editor im
Dashboard trägt nichts in `supabase_migrations.schema_migrations` ein. Die
`NOTICE`-Zeilen des Pushs (`policy … does not exist, skipping`) haben dann
gezeigt, dass die Tischmigration tatsächlich noch gar nicht auf der Instanz war.

Damit der Drift folgenlos bleibt, muss **jede** Migration wiederholbar sein.
`scripts/verify-supabase-migrations.sh` spielt jetzt jede Migration ein zweites
Mal ein und lässt den Lauf scheitern, sobald eine sich nicht wiederholen lässt.
Ergebnis: alle 17 sind bereits wiederholbar (`drop … if exists` vor
`create policy`/`create trigger`, `if not exists`, `on conflict` in den Seeds).
Erst dieser Beweis hat den Push gegen die Instanz mit echten Daten vertretbar
gemacht.

### Durchgeführt

- `supabase db push` gegen `rjxlzqtaxqstctrrlqre`: sieben Migrationen
  angewendet, `migration list` danach deckungsgleich über alle 17.
- Verifikation auf der Instanz: keine Tabelle in `public` ohne RLS, sechs aktive
  Tische, die RPCs `operator_table_check`, `operator_record_payment`,
  `operator_mark_station_ready`, `operator_reject_order`,
  `operator_create_venue` vorhanden.
- Vorher mit dem Nutzer geklärt: der Seed setzt Bereich und Sortierung der
  Demo-Tische 1–5 und „Theke" auf die Seed-Werte zurück (Labels, QR-Tokens,
  Sessions und Bestellungen bleiben unberührt). Er hat zugestimmt.

### Dateien

- `scripts/verify-supabase-migrations.sh` — zweiter Durchlauf (Wiederholbarkeit).
- `docs/architecture/guest-web/SANDBOX_SETUP.md` — §0 korrigiert, §2 um
  `migration list`, den Ledger-Drift-Hinweis und den Stand der Instanz ergänzt.
- `docs/collaboration/CURRENT.md` — fünf „Pending: applying …" auf „Applied"
  gezogen; offen bleibt jeweils nur der reale Gerätedurchlauf.

### Offen

Nur noch echte Abnahmen am Gerät, keine Datenbankarbeit: eine Bestellung über
den Tisch-QR (§6.3), eine Kellnerbestellung (§6.4), eine getrennte Zahlung
(§6.5), ein Durchlauf über zwei Stationen (§6.6), ein selbst angelegtes
Restaurant (§6.7).

Weiterhin offen und unabhängig: `MenuManualEditorUITests.testManualMenuEditorCoreFlow`
schlägt vorbestehend fehl.

## Session-Teil 34: Eigenes Restaurant — Meilenstein 1 abgeschlossen (31. Juli 2026)

### Anlass

Der letzte offene Punkt von Meilenstein 1: „Konto und Restaurant aus dem
Scan-Ergebnis anlegen" (1.3). Bis hierher gab es genau eine Venue,
`alte-muehle`, im Seed angelegt und in der App fest verdrahtet. Wer das Produkt
für ein zweites Lokal sehen wollte, musste `venue_staff` von Hand per SQL
setzen — der Kern-Pitch endete an der Stelle, an der er anfangen sollte.

### Umgesetzt

- **Migration `20260731180000`:** `operator_create_venue` (legt Venue an, macht
  den Anleger zum Personal, erzeugt eine leere aktive Karte),
  `operator_suggest_venue_slug` (weicht auf eine freie Variante aus) und
  `operator_my_venues`. Ein anonymer Gast darf ausdrücklich kein Restaurant
  eröffnen; Sandbox-Grenze fünf Lokale je Konto.
- **App:** neuer Bereich `Restaurant` — Konto anlegen oder anmelden, Name
  eingeben, fertig. Die Gast-Adresse steht live unter dem Namensfeld, damit
  sichtbar ist, was der Name bewirkt.

### Die eigentliche Änderung ist eine Zeile

`KitchenLinkCloudConfig.sandboxDefault` war eine Konstante mit
`venueSlug: "alte-muehle"` und ist der Standardwert **jedes** Cloud-Modells
(19 Stellen). Jetzt ist es eine berechnete Eigenschaft, die der aktiven Venue
folgt. Damit arbeiten Scan-Publish, Tische, Bestellungen, Stationen und
Rechnung ohne weitere Änderung auf dem eigenen Lokal — jede dieser RPCs prüft
ohnehin über `is_venue_staff`. Instanz und Anon-Key bleiben eingebacken; die
Sandbox hat genau eine Instanz, aber nicht mehr genau ein Restaurant.

Ein Test sichert genau das ab (`dieGeteilteKonfigurationFolgtDerAktivenVenue`):
folgt der Standardwert nicht, arbeitet die halbe App weiter im Demo-Lokal, ohne
dass es jemand merkt.

### Verifikation

- **SQL gegen echtes PostgreSQL, und zwar der ganze Weg im neuen Lokal:** Venue
  anlegen → Karte veröffentlichen → Tisch anlegen → Gast bestellt über den
  Tisch-QR → Betreiber liest die Rechnung (20,70 €). Dazu: fremdes Konto
  abgewiesen, anonymer Gast darf nichts anlegen, Name und Slug werden geprüft
  statt zurechtgebogen, Slug-Vorschlag weicht aus, Obergrenze greift.
- **iOS-Unit-Tests grün**, darunter die Umlautbehandlung
  („Gasthaus Zur Mühle" → `gasthaus-zur-muehle`) und der bewusste Verzicht auf
  einen Notnagel-Slug: ein unbrauchbarer Name legt nichts an, statt ein Lokal
  namens `artikel` zu erzeugen.
- **Simulator:** Restaurant angelegt, es wurde sofort das aktive, erscheint in
  „Meine Restaurants", Rückweg ins Demo-Lokal funktioniert.

### Damit ist Meilenstein 1 abgeschlossen

Scan → Prüfung → Live-Gastkarte → Tisch-QR → Gast- **und** Kellnerbestellung →
Annahmeregel → Küche und Bar als getrennte Stationen → serviert → getrennte
Rechnung, Trinkgeld und simulierte Zahlung. Und seit dieser Scheibe für ein
Lokal, das der Betreiber selbst anlegt.

### Offen / nächster Schritt

1. **Nutzerabnahme** der vier Migrationen dieser Sitzung
   (`20260731100000`, `140000`, `160000`, `180000`), Anleitung in
   `SANDBOX_SETUP.md` §6.5 bis §6.7.
2. **Meilenstein 2:** Betriebsschicht und Tagesabschluss (§8.3), Rollen und
   Rechte (§9.1), die getestete Schichtplanungs-Domäne sichtbar machen.
3. Aus dieser Scheibe offen: der Scan legt noch kein Restaurant *automatisch*
   an — der Betreiber macht es einmal unter `Restaurant`. Eine Verknüpfung
   direkt aus dem Import-Review wäre der nächste Schliff.

## Session-Teil 33: Stationen und Annahmeregel (31. Juli 2026)

### Anlass

Auf die Frage nach dem weiteren Vorgehen habe ich zuerst eine eigene Aussage
korrigiert: Meilenstein 1 war nach der Zahlung **nicht** geschlossen. Offen
waren Punkt 8 (Annahmeregel), Punkt 9 (Küchen-/Bar-Routing) und Punkt 3
(Restaurant aus dem Scan). Der Nutzer hat 8 und 9 gewählt.

### Umgesetzt

- **Stationen (§7):** `order_items.station` (aus `kind` per Trigger) und
  `ready_at`, dazu `operator_mark_station_ready`. `Service` hat jetzt
  `Küche | Bar | Kellner`; jede Station sieht nur ihre Positionen und gibt nur
  ihre frei. **Die Bestellung wird erst `ready`, wenn keine Station mehr offen
  ist** — das entscheidet die Datenbank. Die Karte nennt die noch arbeitende
  Station.
- **Annahmeregel (§6.3):** `venues.order_confirmation_channels`, dazu
  `operator_set_confirmation_channels` und `operator_reject_order`. Leer bleibt
  der dokumentierte Standard „automatisch angenommen". Betroffene Bestellungen
  stehen in einer eigenen Liste über der Stationsliste.
- **`rejected` fehlte in der Datenbank**, obwohl Blueprint §6.4 es führt. Ohne
  den Wert hätte eine abgelehnte Bestellung als `canceled` verbucht werden
  müssen — das ist etwas anderes: storniert wird, was schon lief. Jetzt mit
  Grund und Zeitstempel, und nur vor der Annahme möglich.

### Eine Lehre aus der vorigen Scheibe angewandt

Bei KL-TABLE-001 hatte ich `tables(area)` in den Bestell-Lesepfad genommen und
damit die Bestellliste auf einer Instanz ohne Migration lahmgelegt (im
Simulator aufgefallen). Diesmal habe ich das vorweggenommen: `loadOrders`
versucht die Abfrage mit `ready_at` und fällt bei „Spalte gibt es nicht"
einmalig auf die alte Spaltenliste zurück. Ein Betrieb, der die App
aktualisiert hat, aber die Migration noch nicht, sieht seine Bestellungen
weiter — und sobald die Migration steht, greift wieder der erste Weg.

### Bewusste Grenze

Der Stationsstatus wird in der Cloud geführt. Rein lokale Bestellungen
behalten den Bump über die ganze Bestellung. Begründung: Stationstrennung löst
ein Mehrgeräteproblem (Küche am iPhone, Bar am iPad), und der reine
Offline-Fall ist per Definition ein Gerät. Sobald eine lokal aufgenommene
Bestellung synchronisiert ist, gilt für sie der Stationsweg.

### Verifikation

- **SQL gegen echtes PostgreSQL:** Station aus `kind` abgeleitet, erst beide
  Stationen machen `ready`, zweiter Tap ohne Wirkung, reine Getränkebestellung
  braucht nur die Bar, unbekannte Station und fremde Identität abgewiesen,
  Regel nur für ihren Kanal, unbekannter Kanal abgelehnt ohne etwas zu
  überschreiben, Ablehnen nur vor der Annahme, Storno-Replay.
- **iOS: 438 Testfälle bestanden, 1 Fehlschlag** — weiterhin der vorbestehende
  `MenuManualEditorUITests`.
- **Simulator:** Bar zeigt nur Getränke, meldet „Küche arbeitet noch" und
  schaltet mit „Getränke fertig". Dabei drei Reste der alten Zwei-Modi-Logik
  gefunden und behoben (Abschnittstitel, Knopftext, Kartenfarbe hatten `Bar`
  wie den Kellner behandelt).

### Offen / nächster Schritt

1. **Nutzerabnahme:** beide Migrationen anwenden, einmal über zwei Stationen
   abarbeiten (`SANDBOX_SETUP.md` §6.6).
2. **Meilenstein 1 hat noch Punkt 3:** Konto und Restaurant aus dem
   Scan-Ergebnis anlegen. Es gibt weiterhin genau eine fest verdrahtete
   Sandbox-Venue.
3. Danach Meilenstein 2: §8.3 Betriebsschicht und Tagesabschluss, Rollen und
   Rechte, die Schichtplanung sichtbar machen.

## Session-Teil 32: KL-PAY-001 — Rechnung und Zahlung (31. Juli 2026)

### Anlass

Der Nutzer hat die Abnahme der beiden Tisch-Migrationen bestätigt und
Blueprint §8 als nächstes gesetzt. Geschnitten auf Meilenstein 1.11
(„Split-Rechnung, Trinkgeld und Sandbox-Zahlung") — damit ist Meilenstein 1
geschlossen. §8.3 (Betriebsschicht, Tagesabschluss) bleibt eine eigene Scheibe.

### Umgesetzt

- **Migration `20260731100000`:** `payments` und `payment_items` mit RLS
  (Lesen nur für Personal, kein Schreibweg für Clients), dazu
  `operator_table_check`, `operator_record_payment` und
  `operator_refund_payment`.
- **Der Betrag kommt nie vom Gerät.** Bei ausgewählten Positionen rechnet die
  Datenbank ihn aus den Zeilensummen; ein mitgeschickter Betrag wird nur
  gegengeprüft (`payment_amount_mismatch`). Dieselbe Regel wie bei der
  Gastbestellung.
- **Die tragende Zusage steht als Index, nicht als App-Logik:**
  `payment_items_one_open_payment_per_item`. Zwei gleichzeitig kassierende
  Geräte können denselben Gang nicht zweimal abrechnen; der Verlierer bekommt
  `payment_item_unavailable` statt eines rohen Datenbankfehlers.
- **Storno** lässt die Zahlung als `refunded` stehen (auditiert, §8.2), setzt
  ihre Positionszuordnung inaktiv und öffnet die Rechnung wieder — aber nur,
  wenn am Tisch nicht längst eine neue Session offen ist. Sonst bliebe der
  Storno an der Index-Invariante „eine offene Session je Tisch" hängen; die
  Ansicht meldet den Fall über `session_reopened`.
- **Provider-Naht (§8.2):** `KitchenLinkPaymentProviding` +
  `KitchenLinkSandboxPaymentProvider`. Karte und Tap to Pay laufen darüber,
  Bar und Gutschein nicht. Eine abgelehnte Autorisierung erzeugt **keine**
  Buchung — dafür gibt es einen eigenen Test. Die Referenz des Anbieters wandert
  in die Zahlung; ein echter PSP schreibt später seine Autorisierung an dieselbe
  Stelle.
- **Oberfläche:** `Service → Rechnung kassieren`. Positionen antippen ist
  „getrennt zahlen", ohne Auswahl wird der offene Betrag kassiert. Trinkgeld
  liegt neben der Zahlart statt in einem eigenen Schritt; der Beleg nennt
  Betrag, Trinkgeld, Restbetrag und Sandbox-Referenz.
- **Demo-Transport** hinter dem bestehenden Launch-Argument
  `--kitchenlink-demo-tables`, damit der Ablauf ohne Cloud vorführ- und
  prüfbar bleibt. Er rechnet bewusst wie die Datenbank (Auswahl bestimmt den
  Betrag, bezahlte Position gesperrt, Storno gibt frei), damit die Demo nichts
  anderes zeigt als der echte Weg.

### Zwei Dinge, die ich beim Schreiben korrigiert habe

1. **Endlosschleife im Fehlerfall.** Der 401-Pfad rief `pay()` rekursiv auf.
   Erneuert sich die Sitzung erfolgreich, während die RPC weiter 401 liefert,
   hätte das ohne Ende gedreht. Jetzt genau ein Refresh (`allowRefresh`).
2. **Idempotenz-Schlüssel aus `hashValue`.** Swifts Hashing ist pro Prozess
   zufällig; als Bestandteil eines Schlüssels, der einen Zahlungsvorgang
   identifiziert, ist das eine schlechte Idee. Der Schlüssel ist jetzt eine
   UUID, die über Wiederholungen desselben Vorgangs gehalten und bei geänderter
   Auswahl verworfen wird.

### Verifikation

- **SQL gegen echtes PostgreSQL** (`scripts/tests/payments.sql`): Rechnung über
  zwei Gastbestellungen desselben Tisches, serverseitig gerechneter Betrag,
  behaupteter Falschbetrag abgewiesen, doppelte Position abgewiesen, Replay
  ohne zweite Buchung, Teilbetrag über dem offenen Betrag abgewiesen, Rechnung
  schließt sich, geschlossene Rechnung nimmt nichts mehr an, Storno gibt die
  Position frei und sie ist erneut kassierbar, `anon` sieht nichts.
- **iOS: 427 Testfälle bestanden, 1 Fehlschlag** — weiterhin der vorbestehende
  `MenuManualEditorUITests`.
- **Simulator:** eine Position gewählt (13,80 €), 10 % Trinkgeld (1,38 €),
  Zahlart Karte über den simulierten Anbieter, Beleg mit Restbetrag 30,80 €,
  bezahlte Position gesperrt, danach Storno — Position wieder offen, Rechnung
  zurück auf 44,60 €.

### Offen / nächster Schritt

1. **Nutzerabnahme:** Migration anwenden und einmal echt getrennt kassieren
   (`SANDBOX_SETUP.md` §6.5).
2. **§8.3 Betriebsschicht und Tagesabschluss:** gemeinsame Schicht, Bargeld-
   Anfangsbestand, Einnahmen/Trinkgeld/Stornos gesammelt, Bargeldzählung,
   Tagesbericht und Sandbox-Z-Bericht. Die Zahlungen dafür liegen jetzt vor.
3. Offen aus dieser Scheibe: Onlinezahlung im Gast-Web (der Gast zahlt selbst),
   Gutschein-/Guthabenkonten (die Zahlart existiert, das Konto dahinter nicht),
   Beleg als Dokument (`ReceiptProvider`).

## Session-Teil 31: KL-TABLE-002 — Kellnerbestellung (31. Juli 2026)

### Anlass

Die zweite tragende Lücke aus Teil 30. `DECISIONS.md` (Local-First, 23. Juli)
macht „Gäste bestellen verbal, der Kellner erfasst auf dem Service-iPhone" zum
Offline-Pfad der Sandbox-Beta — und genau diesen Weg gab es im Produkt nicht.

### Umgesetzt

- **Reihenfolge ist die Aussage** (`KitchenLinkWaiterOrderModel`): erst der
  dauerhafte Commit im lokalen Ereignisprotokoll, dann die Bestätigung, dann
  die Cloud. Schlägt der lokale Schreibvorgang fehl, gibt es **keine**
  Bestätigung und die aufgenommenen Positionen bleiben stehen; die Cloud wird
  in dem Fall gar nicht erst gefragt (ein Test sichert genau das ab).
  Der Kellner sieht ausdrücklich, ob die Cloud die Bestellung schon kennt.
- **Migration `20260730160000`:** `operator_create_order` bekommt `p_table_id`,
  öffnet bzw. verwendet die gemeinsame Tisch-Session (neue Funktion
  `kitchenlink_open_table_session`) und weist stillgelegte Tische ab.
- **Echter Idempotenzfehler behoben.** Die bisherige Fassung hielt die
  Bestellung per `on conflict (id) do nothing` einmalig, fügte die
  **Positionen** bei einer Wiederholung aber erneut ein. Der Outbox-Versand
  wiederholt nach jedem Zustellfehler — die Bestellung hätte doppelte
  Positionen und einen falschen Betrag gehabt. Jetzt bekommt nur die wirklich
  neu eingefügte Bestellung Positionen; die Antwort meldet `replayed`.
- **Oberfläche:** `Service → Bestellung aufnehmen` mit Kanal, Tischraster,
  der eigenen Karte (nur verfügbare Artikel) und Küchenhinweis.

### Drei Fehler, die erst das Durchspielen im Simulator zeigte

1. **Die Bestätigung war unsichtbar.** Sie stand am Ende des Scrollbereichs —
   hinter über hundert Artikeln der echten Karte. Der Kellner hätte nach dem
   Tippen nur einen leeren Warenkorb gesehen. Jetzt steht sie direkt über der
   Aktion.
2. **Die Kellnerbestellung tauchte in keiner Liste auf.** Die lokale Liste
   filterte auf `preparing` (so startet der Hub), eine Kellnerbestellung
   startet aber `pending` (Blueprint §6.3: automatische Annahme). Beide Quellen
   werden jetzt gleich behandelt.
3. **Der Merge entdoppelte nicht.** Nach der Cloud-Synchronisation kennt die
   App dieselbe Bestellung aus zwei Quellen — sie hätte zweimal auf dem Pass
   gelegen. Jetzt gewinnt die Online-Fassung (für sie funktioniert der
   Status-Schreibweg).

Dazu ein Nebenbefund aus Teil 30, ebenfalls im Simulator sichtbar geworden:
die Bestell-Abfrage holte `tables(label,area)`. `area` kommt erst mit der
Tisch-Migration — ein Betrieb mit neuer App und noch nicht angewendeter
Migration hätte seine **komplette Bestellliste** verloren (im Screenshot:
`column tables_1.area does not exist`). Die Abfrage holt jetzt nur `label`,
das seit dem Kernschema existiert.

### Architektur-Notiz für die nächste Scheibe

Es gibt zwei lokale Ereignisprotokolle: `KitchenLinkOrders/orders.sqlite`
(App-Repository, an der Cloud-Outbox) und `KitchenLinkVenueHub/events.sqlite`
(Foreground-Hub, Quelle der lokalen Gastbestellungen). Die Service-Liste liest
jetzt beide. Das ist ehrlich, aber kein Zielzustand — der autoritative lokale
Knoten sollte einer sein. Nicht in dieser Scheibe zusammengelegt, weil das den
Hub-Pfad (KL-OFFLINE-004 bis 007, auf echten Geräten abgenommen) anfassen
würde. Nebenwirkung heute: die Outbox des Hubs wird von niemandem geleert,
lokale **Gast**bestellungen erreichen die Cloud also nicht — vorbestehend und
konsistent damit, dass lokale Gastbestellung laut Entscheidung vom 23. Juli
keine Pflichtfähigkeit ist.

### Verifikation

- **SQL gegen echtes PostgreSQL:** Kellnerbestellung hängt am Tisch und teilt
  die offene Session der Gäste, Wiederholung erzeugt keine zweiten Positionen
  (`replayed = true`), Bestellung ohne Tisch bleibt möglich, stillgelegter
  Tisch und fehlende Personalrolle werden abgewiesen.
- **iOS:** Unit- und Standard-UI-Suite grün, **410 Testfälle bestanden, 1
  Fehlschlag** — weiterhin der vorbestehende `MenuManualEditorUITests`
  (separater Task).
- **Vollständiger Ablauf im Simulator:** aufnehmen → „Angenommen · dauerhaft
  gespeichert" → Küchenliste zeigt `Tisch 1` → „Bestellung zubereitet" →
  Kellner-Modus zeigt sie am Pass mit „Bestellung serviert".

### Offen / nächster Schritt

1. **Nutzerabnahme** beider Tisch-Migrationen auf der echten Instanz
   (`SANDBOX_SETUP.md` §6.3 und §6.4). Erst dort lässt sich prüfen, ob die
   Kellnerbestellung tatsächlich in der Cloud ankommt — im Simulator meldet die
   App korrekt „noch nicht in der Cloud", weil die RPC dort fehlt.
2. **Rechnung und Zahlung** (Blueprint §8) — die Tisch-Session, auf der ein
   Splitten aufsetzt, existiert jetzt.
3. Offen aus dieser Scheibe: Zusammenführung der zwei lokalen Ereignis-
   protokolle, Tisch-Token im lokalen Hub-Gastpfad, Bestellung im Nachhinein
   korrigieren/stornieren.

## Session-Teil 30: KL-TABLE-001 — Tischkontext (30. Juli 2026)

### Anlass

Der Menü-Import ist weit ausgebaut; der Nutzer fragte, womit es weitergeht. Aus
Blueprint-Abgleich und Codebefund ergaben sich vier Lücken in Meilenstein 1.
Der Nutzer hat aus vier Vorschlägen den **Tisch- und Bestellkern** gewählt.

Die zwei tragenden Befunde, die zu dieser Wahl geführt haben:

1. **Kein Tischbegriff im Produktpfad.** Kein Treffer für `table_number`/
   `tableId` in `kitchenlink/`, `guest-web/src/` oder `supabase/migrations/` —
   obwohl `tables`, `qr_tokens`, `table_sessions` und `orders.table_id` seit dem
   Kernschema (20260318011000) existieren. Eine Bestellung gehörte dem Lokal.
2. **Der Kellner kann keine Bestellung aufnehmen.** Die Local-First-Entscheidung
   vom 23. Juli macht „Gast bestellt mündlich, Kellner tippt ein" zum
   Offline-Pfad der Sandbox-Beta. Im Produktpfad gibt es das nicht: `Service`
   schaltet nur Status. Die Bestellaufnahme liegt im stillgelegten
   Legacy-Checkout und als ungenutzte RPC `operator_create_order`.

Diese Scheibe schließt (1). (2) ist der nächste Schritt und braucht (1).

### Sicherheitsbefund (behoben, belegt)

`tables`, `qr_tokens` und `table_sessions` waren die **einzigen** Tabellen des
Gastschemas ohne Row Level Security — KL-WEB-002 hatte sechs Tabellen
abgesichert, diese drei lagen als ungenutzt daneben. Supabase vergibt
`anon`/`authenticated` per Default-Privileg Tabellenrechte, also war das keine
Theorie. Lokal auf dem Stand **vor** dieser Migration reproduziert:
`relrowsecurity = f` für alle drei, und `set role anon; insert into qr_tokens …`
ging durch. Nach der Migration: RLS aktiv, nur Staff-Lese-Policies, kein
einziger Schreibweg für Clients.

### Umgesetzt

- **Migration `20260730120000_table_context.sql`** (additiv): RLS + Policies,
  `tables.area`/`sort_order`, zwei Partial-Unique-Indizes als tragende
  Invarianten (**genau eine offene Session je Tisch**, **genau ein aktives
  Token je Tisch**), die Staff-RPCs `operator_upsert_table`,
  `operator_delete_table`, `operator_rotate_table_token`, die Gastauskunft
  `guest_web_resolve_table` und ein zusätzlicher, vorbelegter Parameter
  `p_table_token` an `guest_web_submit_order_v2`.
  **Warum kein v3:** `create or replace` kann die Parameterliste nicht
  erweitern, und ein zweiter Name hätte 470 Zeilen Bestelllogik dupliziert.
  Stattdessen Drop + Create in derselben Transaktion; Aufrufer mit fünf
  benannten Argumenten bleiben gültig.
  Der Tisch geht in den Payload-Hash ein: gleicher Schlüssel, anderer Tisch ist
  ein Konflikt, nicht stillschweigend derselbe Vorgang.
- **`scripts/verify-supabase-migrations.sh` + `scripts/tests/`** (neu): fährt
  eine Wegwerf-PostgreSQL-Instanz hoch, legt die drei Supabase-Stubs an
  (`anon`/`authenticated`, pgcrypto im Schema `extensions`, `auth.uid()`/
  `auth.jwt()` aus `request.jwt.claims`), spielt **alle zwölf Migrationen** ein
  und lässt SQL-Assertions laufen. Das schließt die Lücke, die bei KL-WEB-003
  zwei echte Fehler erst auf der öffentlichen Instanz sichtbar machte.
  **Der Lauf hat sofort zwei echte Fehler gefunden:** `operator_delete_table`
  verletzte über den `on delete set null`-FK die neue Token-Bedingung, und ein
  mehrdeutiger Spaltenverweis in meinem eigenen Test. Beide behoben.
- **Gast-Web:** `table-context.ts` (Token lesen, auflösen, Bezeichnung bilden,
  Gast-URL bauen), Token durch `order-submit`/`order-backend-supabase` bis in
  die RPC, Anzeige im Kartenkopf und im Bestell-Sheet, eigener Fehlerzustand.
  **Warum das Token clientseitig gelesen wird:** die Menüseite ist ISR
  (`revalidate = 60`). `searchParams` serverseitig zu lesen macht die Route
  dynamisch und kostet jeder Karte den CDN-Cache; `useSearchParams` zwingt den
  Baum bis zur nächsten Suspense-Grenze ins clientseitige Rendern, was hier die
  ganze Karte wäre. Der Build meldet weiterhin `Revalidate 1m`.
- **iOS:** `Features/Tables/` mit Transport (PostgREST-Lesen + drei RPCs),
  Modell (Sitzung, genau-einmaliger 401-Refresh, Neuladen nach jeder Änderung
  statt erfundenem lokalem Ergebnis) und Ansicht (Gruppierung nach Bereich,
  QR-Code, Teilen/Drucken, Umbenennen, Stilllegen, Rotieren). Cloud-Bestellungen
  tragen ihren Tisch jetzt bis in `Service` und `Heute`.
- **Eine gemeinsame Bezeichnungsregel** (`KitchenLinkTableLabel.headline`,
  gespiegelt in `tableHeadline`): ein zusammenhängendes Kürzel mit Ziffer ist
  eine Tischnummer („Tisch 3", „Tisch A1"), alles andere ein Name („Theke",
  „Terrasse 1"). Vorher stand app-weit „Tisch \(label)" — „Tisch Theke".
  Die Regel `erstes Zeichen ist Ziffer` war mein erster Versuch; ein
  **bestehender** Test (`Tisch A1`) hat sie widerlegt, bevor sie einzog.

### Produktentscheidung, die noch offen ist

Ein unbekannter, abgelaufener oder stillgelegter QR-Code führt zu einer
**Absage** statt zu einer tischlosen Bestellung. Meine Begründung: eine
Bestellung, die niemand zuordnen kann, kostet im Betrieb mehr als eine
abgewiesene. Das ist eine Produktentscheidung, keine technische — sie steht
bewusst **nicht** in `DECISIONS.md` und ist an einer Stelle umschaltbar
(`tableUnknown` in `GuestMenuCard.tsx` plus die Abweisung in der RPC).

### Verifikation

- **SQL gegen echtes PostgreSQL 16:** alle zwölf Migrationen + `table-context`
  bestanden (Tischauflösung, Session-Zusammenlegung über zwei Gäste,
  Bestellung ohne Token unverändert, Abholung mit Tisch abgewiesen, Idempotenz
  inkl. Tischwechsel-Konflikt, Token-Rotation, Löschschutz bei Bestellungen,
  RLS-Sperre für `anon`).
- **iOS:** Unit-Suite und Standard-UI-Suite grün, 398 Testfälle bestanden,
  **1 Fehlschlag: `MenuManualEditorUITests.testManualMenuEditorCoreFlow` —
  vorbestehend.** Auf ungeändertem Stand (`git stash`) reproduziert und auf
  einem zweiten, sauberen Simulator ebenfalls rot. Nicht von dieser Scheibe
  verursacht und nicht in ihrem Schreibbereich.
- **Gast-Web:** typecheck und ESLint sauber, 105 Vitest-Tests (21 neu), Build
  mit `Revalidate 1m` intakt.
- **Visuell:** Gastkarte mobil (375×812) in beiden Zuständen — „Tisch 3 ·
  Gastraum" im Kopf und „Für Tisch 3 · Gastraum" im Sheet gegen einen
  Wegwerf-Mock, „Tisch nicht erkannt" gegen die echte Instanz ohne angewendete
  Migration. iPhone 17 Pro hell und dunkel: Tischliste nach Bereichen,
  QR-Detail mit Gast-URL.
- Zwei eigene UI-Fehler dabei gefunden und behoben: die Farbe für „Tisch
  löschen" lag außerhalb des Button-Styles und blieb wirkungslos, und der
  app-weite Legacy-Tint (dunkles Petrol aus `KitchenTheme`) machte „Fertig" im
  Dunkelmodus fast unlesbar (lokal überschrieben; **app-weit besteht das
  weiter** — eigener Folgepunkt).

### Offen / nächster Schritt

1. **Nutzerabnahme:** Migration `20260730120000` auf der echten Instanz
   anwenden und einmal über einen Tisch-QR bestellen (`SANDBOX_SETUP.md` §6.3).
   Ohne sie zeigt die App ehrlich `column tables.area does not exist`.
2. **KL-TABLE-002 — Kellnerbestellung am iPhone** auf eine Tisch-Session. Das
   ist die zweite tragende Lücke und macht den beschlossenen Offline-Pfad
   erstmals wirklich durchführbar. `operator_create_order` existiert bereits
   und braucht den Tischparameter.
3. Danach Rechnung/Zahlung (Blueprint §8) — sinnvolles Splitten setzt die
   Tisch-Session voraus, die jetzt existiert.
4. Kleinere Punkte: Tisch-Token im lokalen Hub-Gastpfad (heute nur Cloud),
   app-weiter Legacy-Tint im Dunkelmodus, der vorbestehende
   `MenuManualEditorUITests`-Fehlschlag.

## Session-Teil 22: Menu-Import launch-fähig gemacht (26. Juli 2026)

### Anlass

Der Nutzer bat um eine Zweckmäßigkeitsanalyse des von Codex neu aufgesetzten
Phase-1-Imports, eine belastbare Antwort zur Frage lokaler Modelle, eine
Bewertung eines kostengünstigen bezahlten Modells über OpenCode — und dann den
Import launch-fähig zu machen.

### Analyse des Codex-Stands (Befunde)

Codex' Messinstrument (Vertrag `1.0.0`, Draft `0.3.0`, Ground Truth über 10
Seiten/68 Einträge, `evaluate-menu-quality-gate.py`) ist gut und bleibt. Zwei
Kalibrierungsfehler blockierten aber den Launch:

1. **Das Gate war für ein Produkt kalibriert, das es nicht gibt.** Die Ziele
   (`entryF1 0.98`, `relationF1 0.95`, 0 erfundene Einträge, exakte semantische
   Wiederholbarkeit `≥ 0.98`) beschreiben einen unbeaufsichtigten,
   deterministischen Extraktor. Das Produkt hat aber einen **verpflichtenden
   Human-Review** (`MenuImportDraftReviewModel.canConvert`). Mit jedem LLM ist
   exakte Wiederholbarkeit strukturell ≈ 0 (für mimo `0.000` gemessen) — das
   Gate war von der vorgesehenen Architektur nie bestehbar.
2. **Der Regel-Parser wurde als Kandidat gemessen, ist aber Fallback.** Seine
   `relationF1`/`translationF1`/`noticeF1` sind 0, weil er diese Felder nie
   implementiert hat.

Zur Frage lokaler Modelle: **eigene Messung**, nicht Codex' Aussage übernommen.
`qwen3.5:9b-32k` auf M5/16 GB, absichtlich *schlankes* Schema, temp 0, Denken
aus, `format=json`, eine Prüfküche-Seite (53 OCR-Zeilen): **62,2 s**, 1.162
Output-Tokens ≈ 19 tok/s (generation-bound → dichte Seiten 4+ min, was Codex'
150-s-Timeouts vollständig erklärt). Qualität trug nicht: zwei Spalten zu einer
Sektion verschmolzen, `Geröstetes Bauernbrot` verloren, zwei Preise in ein Feld,
eine OCR-Doppellesung als zwei Gerichte. Entscheidend ist aber die Architektur:
Import läuft auf dem iPhone, Deployment-Target iOS 17, Testgerät iPhone XR ohne
On-Device-Modell, `FoundationModels` nirgends im Code. **Lokal ist kein
Launch-Pfad.**

### Umgesetzt

- **OCR-Doppelerkennungen kollabiert** (`ContentView.swift`). Ursache gefunden:
  `recognizeLines` fährt OCR **zweimal** (enhanced + normalized) und
  `mergeOCRLines` deduplizierte nur bei *exakt* gleichem Text. Neu:
  `collapseDuplicateOCRLines` mit Levenshtein-Ähnlichkeit (`≥ 0.82`) **und**
  Boxüberlappung in beiden Achsen (`≥ 50 %` der kleineren Box; die horizontale
  Prüfung schützt zweispaltige Karten). Auswahlregel: **ausgewogene Delimiter
  vor Konfidenz** — Vision ist oft *zuversichtlich* bei verstümmelten
  Codegruppen (`Wiener Schnitzel IA,C,G,J]` schlug die korrekte Lesung), und der
  Parser verlor das Gericht dann komplett. `mergeOCRLines` entfernt.
- **Provider-Konfiguration reparariert** (`ContentView.swift`). Vorher schaltete
  *jeder* eigene Key fest auf `api.openai.com` + `gpt-4.1`; ein bezahlter Zugang
  bei einem anderen Anbieter war in einer ausgelieferten App **überhaupt nicht
  einstellbar**. Neu: Gateway-URL und Modell sind gespeicherte Einstellungen
  (UserDefaults; nur der Key bleibt im Keychain), mit URL-Validierung, die bei
  Unsinn nichts speichert. UI anbieterneutral mit drei Feldern.
- **Gemini-native Adapter** (`MenuImportGeminiProtocol.swift`, neu). Die Zen-
  Gemini-Route akzeptiert **keine** OpenAI-Bodies — ein Probe-Aufruf gab Googles
  eigenen Fehler zurück (`Missing key at ["contents"]`). Der Adapter übersetzt
  Request und Response; die Aufrufkette bleibt protokollagnostisch. Zwei
  gemessene, tragende Details: Auth muss **`x-goog-api-key`** sein (`Bearer`
  ergab `AuthError: Missing API key.`) und **`thinkingBudget: 0`** ist Pflicht
  (mit Denken kam `finishReason: MAX_TOKENS` und Prosa statt JSON).
- **Launch-Profil im Gate** (`policy.json` → `1.3.0`, Evaluator, Runner).
  Zwei Profile (`launch` freigabewirksam, `strict` als Diagnose), Auswahl per
  `--profile` / `KITCHENLINK_QUALITY_PROFILE`, neue abgeleitete Metriken
  `entryRecall` und `correctionsPerPage`, neuer `maximumTargets`-Block, und jeder
  Lauf berichtet **alle** Profile (`profileComparison`), damit ein späteres
  Anziehen keinen zweiten Lauf braucht.
- **Offline-Fallback gehärtet** (`MenuImportDraftAdapter.swift`). Gate-Befund:
  `expectedReviewRecall 0.000` bei 8,5 Korrekturen/Seite — der Regel-Parser
  erzeugte stillschweigend falsche Karten. Neu leitet er die Prüfhinweise ab,
  die er *ehrlich* kennt: `missing_visible_price`,
  `source_declaration_meaning_unknown` (Code ohne Legende),
  `selection_rule_unknown` (Optionen ohne abgeleitete Regel) plus einmal pro
  Draft `rule_parser_semantics_unverified`. Die vier semantischen Codes, die er
  nicht erkennen kann, werden **bewusst nicht erfunden** (ein Fake-Hinweis wäre
  schlimmer: er erzieht Betreiber dazu, Hinweise zu ignorieren) — ein Test
  sichert das ab. `0.000 → 0.429`.
- **Prompt `1.0.2 → 1.0.4`** (`MenuImportExtractionContract.swift`). `1.0.3`
  bleibt verbrannt (Codex' zurückgerollte Regression). Schließt die drei Lücken,
  die der bezahlte Lauf zeigte: Review-Code-Vokabular war nie genannt (Modell
  erfand eigene Codes), `currency_code` blieb bei sichtbaren Euro-Preisen leer,
  und nachgestellte Codegruppen blieben im Artikelnamen.

### Verifikation

- **Neue Testdateien, alle grün:** `MenuImportOCRDeduplicationTests` (17),
  `MenuImportProviderConfigurationTests` (8, `@Suite(.serialized)` — die Tests
  teilen prozessweite `UserDefaults`), `MenuImportGeminiProtocolTests` (21),
  `MenuImportFallbackReviewFindingsTests` (9).
- **Komplettes `kitchenlinkTests`-Target auf iPhone 17 Pro: TEST SUCCEEDED,
  329 Testfälle, 0 Fehlschläge**; nur die zwei bewusst gegateten Harness-Tests
  übersprungen. Die in Teil 21 notierten vorbestehenden Keychain-Fehler traten
  nicht mehr auf.
- **Python-Gate-Tests: 17/17** (9 bestehende + 8 neue für Profile und
  abgeleitete Metriken).
- **Lokaler Gate-Lauf über die 10 Seiten** (deterministisch, kostenlos), Wirkung
  der OCR-Kollaps- und Auswahlregel:

  | Metrik | Codex-Baseline | nachher |
  |---|---|---|
  | Einträge F1 | 0,592 | **0,679** |
  | Namen exakt | 0,397 | **0,486** |
  | Beschreibungen F1 | 0,328 | **0,448** |
  | Deklarationen F1 | 0,272 | **0,345** |
  | fehlende Einträge | 18 | **14** |
  | erfundene Einträge | 51 | **37** |
  | erfundene Preise | 50 | **34** |
  | P95-Seitenlatenz | 7.145 ms | **3.715 ms** |

- **Ein bezahlter Lauf `gemini-3.5-flash` über die 10 Gate-Seiten** (vom Nutzer
  freigegeben; Key aus der lokalen Datei, nie in Log oder Transkript):

  | Metrik | lokale Regeln | **Gemini 3.5 Flash** |
  |---|---|---|
  | Korrekturen/Seite | 8,50 | **1,00** (Budget 3,0) |
  | Bereiche F1 | 0,718 | **1,000** |
  | Einträge F1 | 0,679 | **0,971** |
  | Eintrags-Recall | 0,794 | **0,971** |
  | Beziehungen F1 | 0,000 | **0,411** |
  | Namen exakt | 0,486 | **0,889** |
  | Beschreibungen F1 | 0,448 | **0,915** |
  | Übersetzungen F1 | 0,000 | **0,902** |
  | Belegabdeckung | 0,902 | **0,993** |
  | fehlende / erfundene Einträge | 14 / 37 | **2 / 2** |
  | erfundene Preise | 34 | **6** |
  | P95-Seitenlatenz | 3.715 ms | 33.749 ms |

  Gemessener Verbrauch: **81.366 Input- und 71.655 Output-Tokens für 17 Seiten**
  (≈ 4.786 in / 4.215 out pro Seite). Bei Flash-Listenpreisen sind das grob
  10–15 Cent für eine 10-seitige Karte; der tatsächliche Zen-Tarif ist nicht
  verifiziert.

### Offen / nächster Schritt

- **Die zwei „fehlenden" Einträge sind keine Verluste.** Es sind
  `Bunter Marktsalat WI` und `Veganes Kokoscurry [FI]` — das Modell ließ die
  verstümmelte Codegruppe im Namen. Prompt `1.0.4` adressiert genau das, ist aber
  **noch nicht nachgemessen**: der Nutzer hatte genau einen bezahlten Lauf
  freigegeben, und der lief mit `1.0.2`.
- ~~Codex' deterministische Mapping-Korrektur verschiebt nur *einbuchstabige*
  geklammerte Gruppen.~~ **Erledigt in Session-Teil 23** (siehe unten): die
  Zerlegung ist jetzt legendenbasiert und deckt beide beobachteten Formen ab.
- **`expectedReviewRecall` bleibt der größte Hebel.** Im bezahlten Lauf `0.143`:
  das Modell lieferte `evidence_missing`, `missing_visible_price` und ein selbst
  erfundenes `normalized_trailing_declaration_codes`, weil der Prompt das
  Vokabular nie nannte. `1.0.4` nennt es jetzt.
- Für eine Freigabe fehlen die **drei Wiederholungsläufe** (`minimumRepeatRuns`),
  ebenfalls kosten- und freigabepflichtig.
- Alles aus dieser Session ist **uncommitted**, gemeinsam mit dem
  uncommitteten Codex-Stand im gleichen Working Tree.
**Zuvor:** 23 July 2026 (Session-Teil 20: Piktogramme im Beschreibungsfluss)
**Branch:** `main` (Main-Only-Modus seit 19. Juli 2026, `DECISIONS.md`)
**Status:** Session-Teil 21: Bestellungen liegen jetzt dauerhaft im Event-Log
(KL-OFFLINE-003) statt in UserDefaults — ein einzelnes Gerät ist damit
local-first und crash-fest. `DurableOperatorOrderStore` (Paket) +
`EventLogOrderRepository` (App), Demo-Pfade unverändert. Paket 21/21 grün, App
baut, Regressionscheck grün bis auf **vorbestehende** Keychain-Testfehler (per
Baseline bestätigt). Details unten in Teil 21.
Session-Teil 20: Der eigene Piktogramm-Streifen unten ist entfernt.
Die Symbole stehen jetzt im Fluss der Beschreibung (leiser Nachsatz, bricht
mit dem Text um; ohne Beschreibung kurze Zeile unter dem Namen). Der
Symbol-Nachsatz bleibt ein Tap-Ziel → Klartextliste. Die Mengensteuerung sitzt
bei belegtem Warenkorb in einer eigenen rechtsbündigen Zeile. Entscheidung
„Quiet Declaration Row" in `DECISIONS.md` entsprechend aktualisiert. Details
unten in Teil 20.

Teil 19: Die Deklarationszeile wurde ruhig/monochrom (keine farbigen
Badges/Kästen), Einzel-Tap je Symbol nur noch in Betreiberansichten. Teil 20
baut darauf auf und verschiebt die Symbole in den Beschreibungsfluss.

Teil 18: Die Zwei-Symbol-Kürzung der Deklarationen ist
aus iOS und Gast-Web entfernt (gesetzliche Vorgabe, jetzt Entscheidung in
`DECISIONS.md`); die Symbolzeile bricht um und zeigt alle Kennzeichnungen.
Demokarte und Web-Fixture decken den vollen Speisekarten-Funktionsumfang ab.

Zur Vorsession (Teil 10–17): (1) Scan-zu-Publish-Bruecke
(KL-MENU-005) implementiert — Migration, Publish-Client/-Model/-Sheet,
11 neue Tests, komplette Suite gruen; offen ist nur die reale Abnahme
(SANDBOX_SETUP.md §6.2). (2) Nach dem Nutzerbefund zur Erkennungsqualitaet
(„Namen passen groesstenteils, aber nicht alle") die Import-Review-Umgebung
KL-SCAN-002 gebaut: `scripts/run-import-review.sh` erzeugt einen
Seite-an-Seite-HTML-Report ueber alle Karten mit Fundstellen-Overlays,
automatischen Markierungen und Feedback-Export. Erster Lauf verifiziert;
er bestaetigt die Nutzerbeobachtung mit konkreten Befunden (Legende-Codes
in Beschreibungen und Namen, doppelte Fragmente, OCR-Verwechslungen).
Qualitaetsziele verbindlich in
`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`. **Runde 1 ist am
20. Juli ausgewertet** (Session-Teil 12): Nutzer-Feedback + nachgeholte
vollstaendige Eigenverifikation in `ROUND_01_FINDINGS.md`; Kernbefund: die
OCR ist nicht der Engpass, der Regel-Parser ist es; die Review-Umgebung
kann jetzt lokal vs. KI-Pfad umschaltbar vergleichen. Offen fuer den
Nutzer: API-Key/Anbieter-Entscheidung fuer den Runde-2-Vergleichslauf;
ausserdem weiterhin die realen Abnahmen KL-CLOUD-001 (§6.1) und
KL-MENU-005 (§6.2). Details in Session-Teil 10 bis 12.

Zur Vorsession (Session-Teil 9): KL-CLOUD-001 und KL-OFFLINE-008 sind in
`main` gemergt; nicht gemergte Branch-Staende liegen als `archive/*`-Tags,
das Loeschen der Remote-Branches wartet auf Nutzerbestaetigung.

## Session-Teil 26: Kostenloser Standardpfad und Seitenrettung (29. Juli 2026)

### Anlass

Der Nutzer will kein Geld mehr für API-Nutzung ausgeben und fragte, ob der
Import auch ohne fertig wird. Auf Rückfrage präzisiert: es geht um die
**eigenen Messläufe**, nicht um das Produkt. Die Entscheidung vom 26. Juli
(bezahltes Modell als Standard) bleibt damit gültig.

### Der kostenlose Standardpfad war komplett tot

Ohne hinterlegten Schlüssel liefert die App laut Code den keylosen Zen-Pfad.
Der hat **nie** eine semantische Erfassung produziert — jede Seite fiel still
auf die lokalen Regeln zurück. Beide Ursachen direkt am Gateway per `curl`
nachgewiesen, nicht vermutet:

1. **Das freie Modell nimmt keine Bilder an.** Jede Vision-Anfrage an
   `big-pickle` beantwortet das Gateway mit `HTTP 400 · Upstream request
   failed` — auf jeder Seite jeder Karte. Ohne eigenen Schlüssel läuft der Pfad
   jetzt im Textmodus (der OCR-Dump trägt Seite und Koordinaten). Mit eigenem,
   bildfähigem Zugang bleibt Vision aktiv.
2. **`big-pickle` ist ein Reasoning-Modell** und rechnet sein Nachdenken gegen
   dasselbe Ausgabebudget wie die Antwort. Belegt: "Antworte nur mit OK" kostet
   82 Reasoning-Token; mit `max_tokens: 20` kommt `content: ""` und
   `finish_reason: length`, mit 2000 kommt `OK`. Eine dichte Speisekartenseite
   hat die bisherigen 10 000 restlos verbraucht. Budget jetzt 32 000 — das
   Gateway akzeptiert auch 60 000.

Damit die nächste Ursache dieser Art nicht wieder unsichtbar bleibt: der
Abbruchgrund des Anbieters wird gemeldet, `reasoning_content` wird zusätzlich
zu `reasoning` gelesen, und eine Antwort ohne JSON nennt Länge und Auszug.

### Leerer sichtbarer Text verwarf den ganzen Entwurf

Der Validator lehnt leeren sichtbaren Text ab, und ein abgelehnter Entwurf
kostet die **ganze** Karte. Gemessen am freien Modell hat genau ein leerer
`sections[2].title.value` das ausgelöst. Der Text wird jetzt aus seiner eigenen
Belegzeile geholt; gibt es keine, bleibt die Lücke als `—` sichtbar markiert
statt erfunden. Beide Fälle erzeugen einen Befund.

### Seitenrettung (Nutzerentscheidung, in DECISIONS.md aufgenommen)

Bisher galt "no partial semantic draft accepted": EINE gescheiterte Seite
verwarf die semantische Erfassung der ganzen Karte. Gemessen ist das kein
Randfall — ein bezahlter Lauf verlor zwei von vier Karten, ein freier Lauf alle
vier, jedes Mal wegen genau einer Seite.

Jetzt bleibt erhalten, was erfasst wurde. `parseDraftWithLLM` baut den Entwurf
aus den vorhandenen Extraktionen; `MenuImportService.mergingLocalPages` füllt
die Lücken aus dem lokalen Regelentwurf, seitengenau gefiltert über
`entry.name.evidence.pageIndex`. Jeder übernommene Bereich geht als
`needsReview` hinein, ein Befund `page_filled_from_local_rules` nennt die
Seite, und die Bereiche stehen in Seitenreihenfolge. Vier Tests in
`kitchenlinkTests/MenuImportPageSalvageTests.swift`.

Der 401-Abbruch bleibt erhalten, hängt aber nicht mehr an einer
Textsuche in der Sammelmeldung, sondern an `failedOnAuthentication` — wahr nur,
wenn **alle** Seiten an Authentifizierung scheiterten.

### Offen

- **Wiederholbarkeit weiterhin ungemessen.** `minimumRepeatRuns 3` braucht drei
  bezahlte Läufe; das Zen-Guthaben ist leer und soll nicht aufgefüllt werden.
  Die Zahlen aus Teil 25 stehen auf einem sauberen Lauf.
- **Der freie Pfad ist langsam.** 19 Minuten für 17 Seiten in einem Lauf, in
  einem zweiten nach über einer Stunde ohne Fortschritt abgebrochen. Als
  Fallback brauchbar, als Standard nicht — die Entscheidung vom 26. Juli bleibt
  richtig.
- **Die Seitenrettung ist unit-getestet, aber nicht am echten Anbieter
  gemessen.** Der nächste bezahlte Lauf sollte prüfen, ob eine gescheiterte
  Seite jetzt tatsächlich nur diese Seite kostet.
- P95-Latenz, `expectedReviewRecall` und das sporadisch unlesbare JSON aus
  Teil 25 bleiben unverändert offen.

### Session-Teil 29: Staffelregel belegt (30. Juli 2026)

Zweite eingesammelte Antwort für dieselbe Seite, diesmal mit Prompt `1.0.5`
(Delta `portion_tiers`). Ausgewertet über den Abspielpfad, wieder ohne bezahlten
Aufruf.

### Ergebnis

| Prüfpunkt | Ergebnis |
|---|---|
| Optionsgruppe `Größen` | ✓ mit `kind=size` und geparster Menge (`0,3 l` → 0.3 l) |
| Kopfpreis bleibt am Eintrag | ✓ |
| `headline_price_unmapped_to_portion_choice` | ✓ viermal |
| `Variante: Haferdrink` unverändert | ✓ weiterhin als `delta` |

Die Regel verallgemeinert über ihr Beispiel hinaus: Cola Zero, Riesling und
Kellerpils bekamen dieselbe Behandlung. Für das Dokument fallen erfundene Preise
von **26 auf 18** und fehlende von **33 auf 25** — genau acht weniger, also die
vier Getränke mit je zwei Preisen. Alle verbleibenden tragen die Handschrift des
Regelparsers (`choice:variante 1`) und stammen von den nicht abgespielten
Seiten 0 und 1.

Damit sind alle drei Fehlerklassen aus Teil 28 auf den abgespielten Seiten
geschlossen.

### Offener Zielkonflikt zwischen Ground Truth und Vertrag

Die Auswahlregeln kommen als `mode=unknown, minimum=null, maximum=null` zurück,
dazu fünfmal `selection_rule_unknown`. Die Ground Truth erwartet dagegen
`minimum 1, maximum 1, mode single, allowsRepeats false`.

Das Modell hat sich **korrekt** verhalten: die Karte druckt nirgends, wie viele
Größen ein Gast wählen darf, und der Vertrag verbietet ausdrücklich, Auswahl-
grenzen zu raten. Die Ground Truth trifft hier eine menschlich naheliegende
Annahme (eine Größenliste heisst: genau eine wählen), die auf der Karte nicht
steht.

Das ist **keine Prompt-Frage**. Entweder die Ground Truth nimmt `unknown` plus
Prüfgrund als richtige Antwort an, oder der Vertrag bekommt eine ausdrückliche
Ausnahme für Größenlisten. Beides ist eine Produktentscheidung des Nutzers, und
ich habe bewusst nichts davon einseitig umgesetzt — die Nicht-Rate-Regel ist
eine der Leitplanken, die erfundene Preise verhindert.

## Session-Teil 28: Die Layoutstufe an einem starken Modell belegt (30. Juli 2026)

Der Nutzer hat drei Gate-Seiten von Hand durch ChatGPT gegeben — die exportierten
Pakete inklusive olmOCR-Transkript — und die Antworten zurückgelegt. Ausgewertet
über den Abspielpfad, ohne einen einzigen bezahlten Aufruf.

### Vorher gefunden: der Abspielpfad war nicht kartenscharf

`replayText` kannte nur den Seitenindex. Zwei Karten haben aber beide eine
Seite 2, und ein flaches Verzeichnis hätte die Prüfküchen-Antwort in die
Alexxanders-Karte gespielt — still und falsch. Aufzeichnung und Abspielen sind
jetzt über das Herkunftsdetail der Karte einem Unterordner zugeordnet; die
Zuordnung ist nachsichtig (Ordnername muss im Herkunftsdetail vorkommen), damit
niemand interne IDs kennen muss.

### Ergebnis: zwei von drei Fehlerklassen gelöst

| Seite | Fehlerklasse | Ergebnis |
|---|---|---|
| `alexxanders` S. 2 | Portionspreise landeten an Auswahloptionen statt am Gericht | **gelöst** |
| `lichtburg` S. 4 | gedruckter Name mit Gewicht, zweispaltige Beilagenliste | **gelöst** |
| `pruefkueche` S. 2 | Größenstaffel als Optionsgruppe | **nicht gelöst** |

Im Einzelnen:

- `Lotte -> ('28 €', 'Zwischengericht'), ('36 €', 'Hauptgericht')` — beide
  Portionspreise als bezeichnete Angebote **am Eintrag**. Für dieses Dokument
  fallen erfundene und fehlende Preise von je **4 auf 0**.
- `Hüftsteak(250gr)` behält den gedruckten Namen samt Gewicht. Der Defekt, der
  in Teil 25 deterministisch nachgebaut werden musste, entsteht hier nicht mehr
  an der Quelle. Die zweispaltige Beilagenliste ist sauber in Einzeleinträge
  aufgelöst (`Salat 4,90 €`, `Pfefferrahmsoße 3,90 €`), erfundene Preise **0**.
- Bei den Getränken hat das Modell die Staffel `Größen: 0,3 l 4,20 € · 0,5 l
  5,90 €` zu drei **unbezeichneten** Angeboten am Eintrag verflacht. Die Ground
  Truth erwartet eine Optionsgruppe "Größen" mit Mengen je Auswahl. Das
  Transkript enthielt die Information wortwörtlich — der Fehler liegt also in
  der **Modellierungsentscheidung**, nicht im Lesen.

### Was daraus folgt

Die Layoutstufe löst die **relationalen** Leseprobleme (welcher Preis gehört zu
welchem Gericht, welcher Portion, welcher Spalte). Sie löst **nicht** die Frage,
wann eine Staffel als Optionsgruppe zu modellieren ist. Das ist eine Prompt- und
Vertragsfrage und der nächste klar umrissene Schritt: der Vertrag kennt dafür
bereits `headline_price_unmapped_to_portion_choice`, und die Ground Truth führt
den Code für genau diese Karte.

**Die Stufe bleibt.** Damit ist auch die Verkabelung in der App wieder relevant
(offener Punkt aus Teil 27: null Anfragen im Simulator, Diagnose muss in eine
Datei statt in `print`).

### Lesehinweis zu den Zahlen

Pro Karte ist nur **eine** Gate-Seite abgespielt, die übrigen kommen aus den
lokalen Regeln mit ihrer Grundlinie von 8,5 Korrekturen pro Seite. Die
Dokumentwerte für `pruefkueche` und `lichtburg` sind deshalb nicht mit den
bezahlten Läufen vergleichbar — belastbar sind nur die Aussagen zu den
abgespielten Seiten.

## Session-Teil 27: Layoutstufe und erzwungenes Dekodieren (30. Juli 2026)

### Anlass und Korrektur einer eigenen Fehleinschätzung

Der Nutzer schlug vor, ein Dokumentmodell wie olmOCR 2 als erste Stufe
vorzuschalten und erst danach den Vertrag zu füllen. Ich hatte das zunächst
abgetan mit dem Argument, die Belegabdeckung liege schon bei 0,988. Das war
falsch begründet: 0,988 sagt, dass der **Text** gefunden wird — nicht, dass die
**räumlichen Beziehungen** aufgelöst sind. Genau dort sitzt die verbleibende
Fehlermasse (Angebote 0,731, Preisbasis 0,703, Beziehungen 0,425).

### olmOCR 2 nachgemessen — die Idee trägt

`hf.co/lmstudio-community/olmOCR-2-7B-1025-GGUF:Q4_K_M` über Ollama, 42–49 s pro
Seite, 450–710 Ausgabe-Token, an genau den Seiten, die heute scheitern:

- `28 € Zwischengericht    36 € Hauptgericht` erscheint **unter** dem Gericht
  Lotte statt als zwei eigenständige Optionen. Das war einer der zehn
  "erfundenen Preise".
- `Hüftsteak (250gr)` behält den gedruckten Namen samt Gewicht — der Defekt, den
  ich in Teil 25 deterministisch nachbauen musste, entsteht hier nicht.
- Die zweispaltige Beilagenliste kommt als HTML-Tabelle mit korrekter Paarung.
- Zweisprachige Karten behalten die Paarung Deutsch/Englisch pro Gericht.
- Der geltungsbeschränkte Hinweis ("außer Burger") steht als eigener Block.

Umgesetzt als `MenuImportLayoutPass`: austauschbar über
`KITCHENLINK_LAYOUT_BASE_URL` und `_MODEL`, läuft mit jedem Vertragsmodell auch
dem bezahlten, und ausdrücklich fehlertolerant — jeder Fehlschlag liefert `nil`
und der Seitenlauf geht ohne Layoutkontext weiter. Apple Vision bleibt die
einzige Belegquelle; ein Test hält fest, dass der Prompt das abgrenzt, sonst
erfindet das Vertragsmodell IDs für Zeilen des Transkripts.

### Erzwungenes Dekodieren — der Blocker der Vertragsstufe

Diagnose aus Teil 26 bestätigt: die 900-s-Zeitlimits waren keine Langsamkeit,
sondern eine Wiederholungsschleife (rund 17 000 Ausgabe-Token für eine Seite,
die 3 000–8 000 braucht).

`MenuImportExtractionSchema` liefert den Vertrag als JSON-Schema,
`KITCHENLINK_LLM_RESPONSE_FORMAT=json_schema` schaltet es zu. Ollama nimmt es an
und setzt es durch. Wirkung gemessen: **dieselbe Seite, die dreimal 900 s
Zeitlimit riss, antwortet in 21 s.** Zwei bewusste Abweichungen vom Vertrag sind
im Dateikopf begründet: begrenzte statt rekursiver Verschachtelung (llama.cpp
kommt mit `$ref` schlecht zurecht) und kein `required` (der Vertrag toleriert
fehlende Felder absichtlich). Fünf Tests koppeln Schema und Vertrag, unter
anderem: jeder Prüfcode des Schemas muss im Prompt-Vokabular stehen.

Standard bleibt `json_object`. Ein starres Schema gewinnt bei einem starken
Modell nichts und wird von manchen Gateways abgelehnt.

### Der harte Befund: lokale 8–9B-Modelle können den Vertrag nicht füllen

Mit Layout-Transkript **und** Schemazwang, an derselben Seite:

| Modell | Ergebnis |
|---|---|
| `qwen3.5:9b-32k` | Seite als `unknown`, **null Einträge**, 21 s |
| `gemma4:32k` | Seite als `menu`, **null Einträge**, 139 s |

Schemakonform und inhaltsleer. Der Engpass ist **Verständnis**, nicht Format,
Geschwindigkeit oder Kontext (128k–262k Fenster). Ein lokaler Server bleibt
Debugging-Werkzeug; die Vertragsstufe braucht ein starkes Modell.

### Offen

- **Der Nutzen der Layoutstufe ist noch nicht in Kennzahlen belegt.** Dazu
  braucht es einen Lauf mit einem Vertragsmodell, das die Aufgabe kann — also
  einen bezahlten. Genau eine Messung würde klären, ob Angebote 0,731 und
  Beziehungen 0,425 mit vorgeschalteter Layoutstufe steigen. Das ist die
  wertvollste einzelne Messung, die derzeit aussteht.
- Ebenso ungemessen: ob Schemazwang beim bezahlten Modell hilft oder schadet.
- Die drei Wiederholungsläufe aus Teil 25 fehlen weiterhin.

### Nachtrag: Aufzeichnen, Abspielen und Prompt-Export (30. Juli 2026)

Der Nutzer hat kein API-Modell mehr zur Verfügung und schlug vor, den Prompt
notfalls von Hand in ein Chatfenster zu geben. Das hat eine Lücke aufgedeckt,
die diese Pipeline von Anfang an teuer gemacht hat: **es gab keinen Weg, eine
Anbieterantwort aufzuzeichnen und erneut abzuspielen.** Jede Messung brauchte
einen Live-Aufruf, auch wenn nur eine Assembler-Änderung zu prüfen war. Eine
einmal bezahlte gute Antwort war nach dem Lauf verloren.

Neu:

- `MenuImportProviderTranscript` mit `KITCHENLINK_LLM_REPLAY_DIR` (abspielen)
  und `KITCHENLINK_LLM_RECORD_DIR` (mitschreiben). Eine Datei pro Seite,
  `page-<index>.json`, mit dem rohen Vertrags-JSON. Fehlt eine Datei, gilt die
  Seite als nicht erfasst und die Seitenrettung greift wie bei einem echten
  Fehlschlag.
- Der Abspielpfad umgeht ausdrücklich **nur** den Netzaufruf, nicht den
  Dekodier- und Diagnosepfad: `decodeExtraction` ist dafür aus
  `runLLMExtractionCall` herausgezogen. Eine Aufzeichnung, die der Vertrag
  ablehnt, erzeugt denselben Befund wie eine Live-Antwort, die er ablehnt.
- `scripts/export-extraction-prompts.sh` schreibt für alle zehn Gate-Seiten ein
  fertiges Paket: Systemprompt, OCR-Belegzeilen, Layout-Transkript, Seitenbild
  und eine Anweisung zum Zurückkopieren. `MenuImportService.extractionUserPrompt`
  ist dafür herausgezogen, damit der exportierte Text **wortgleich** mit dem
  Live-Aufruf ist — sonst wäre das eingesammelte Ergebnis nicht vergleichbar.

Die Pakete liegen unter `.claude/artifacts/prompts/` (nicht versioniert,
2,2 MB, zehn Seiten mit Bild und Transkript). Ablauf zum Einsammeln steht im
Kopf des Skripts.

### Abspielpfad verifiziert — und der erste belastbare Beleg für die Layoutstufe

Zwei Durchleitungsfehler gefunden: `KITCHENLINK_LLM_REPLAY_DIR` und
`_RECORD_DIR` fehlten in der `TEST_RUNNER_`-Liste von
`run-import-review.sh`. Danach lief die Kette durch.

Test: Vertrag für `alexxanders-chemnitz` Seite 2 von Hand geschrieben (mit dem
exportierten Paket als Eingabe, also OCR-Zeilen plus Layout-Transkript),
absichtlich **nur** diese eine Seite abgelegt. Ergebnis:

- Seite 2: `processed — Replayed recorded provider response for this page.`
- Seiten 0, 1, 3: `failed` → aus den lokalen Regeln gefüllt, alle als
  `needsReview`, dazu dreimal `page_filled_from_local_rules`. Vor der
  Seitenrettung hätte das die ganze Karte gekostet.
- Preiszuordnung: `Lotte -> ('28 €', 'Zwischengericht'), ('36 €',
  'Hauptgericht')` — beide Portionspreise **am Eintrag** mit Bezeichnung, genau
  wie die Ground Truth es erwartet. Der Phantom-Eintrag "Zwischengericht" des
  Regelparsers ist weg.

Gate für dieses Dokument: **erfundene Preise 0 (vorher 4), fehlende Preise 0
(vorher 4)**, Eintrags-Recall 1,000. Die verbleibenden Auffälligkeiten
(`silentPageLosses 2`, `coverFalsePositives 1`, ein erfundener Eintrag) kommen
sämtlich von den drei regelbasierten Seiten, nicht von Seite 2.

**Ehrliche Einordnung:** das zeigt, dass die Pipeline aus korrekt zugeordneten
Rohdaten das Richtige macht und dass das Layout-Transkript die richtige Antwort
verfügbar macht. Es zeigt **nicht**, dass `gemini-3.5-flash` diese Zuordnung nun
selbst trifft. Dafür braucht es einen bezahlten Lauf oder ein eingesammeltes
Ergebnis aus einem Chatfenster — beides ist jetzt ohne weitere Infrastruktur
messbar.

Die Aufzeichnung liegt als `.claude/artifacts/replay-alexxanders/page-2.json`
(nicht versioniert). Sie taugt als Ausgangspunkt für eine echte Testfixtur.

### Offener Punkt: die Layoutstufe erhält im Simulator keine Konfiguration

`MenuImportLayoutPass` funktioniert über HTTP nachweislich (per `curl`
verifiziert, auch in der OpenAI-Form mit `detail`-Feld), aber im Simulator wurde
**keine einzige** Anfrage abgesetzt — im Ollama-Log null neue POSTs, und der
Export lief zu schnell für zehn Bildaufrufe. `KITCHENLINK_PROMPT_OUTPUT` kommt
über denselben `TEST_RUNNER_`-Mechanismus an, `KITCHENLINK_LAYOUT_BASE_URL`
offenbar nicht. Ursache ungeklärt.

`print` aus dem Testprozess erreicht die xcodebuild-Ausgabe nicht — der nächste
Versuch muss die Diagnose in eine **Datei** im Ausgabeverzeichnis schreiben.
Bis dahin erzeugt `scripts/attach-layout-transcripts.py` die Transkripte
ausserhalb der App, wortgleich zum Swift-Block. Für die Produktion ist der
In-App-Pfad zu klären; für das Einsammeln jetzt ist er nicht nötig.

Nebenbefund: Ollama lehnt die grösseren Fixtures (1654x2339) mit HTTP 400 ab,
der Anfragekörper wird zu gross. Das Skript skaliert deshalb auf 1600 px
Kantenlänge herunter — dieselbe Grenze, die die App verwendet.

## Nachtrag: der Import wurde erstmals in der App selbst gefahren

Alle bisherigen Messungen liefen über `MenuImportReviewHarnessTests`, nie über
die Oberfläche. Im Simulator (Prüfküche, kostenloser Standardpfad) kam damit
die letzte fehlende Ursache ans Licht — und es war keine Modellfrage:

Das Gateway antwortete nach **154,6 s** mit Status 200, das Zeitlimit pro Seite
lag bei **150 s**. Von sechs Anfragen kam eine an, fünf brach die App selbst mit
`-999 cancelled` ab. Der Import fiel deshalb komplett auf die lokalen Regeln
zurück, obwohl der Anbieter korrekt geliefert hätte. Nachweis im Gerätelog über
`transaction_duration_ms`.

Kostenloser Pfad jetzt 300 s pro Seite, bezahlter Pfad unverändert 150 s
(gemini antwortet in 40–75 s). Die URLSession-Limits liegen darüber, sonst
schneidet die Session ab, bevor die eigene Abbruchlogik greift.

Danach im selben Weg gemessen: **null Selbstabbrüche**, drei Antworten
angekommen (2×200, 1×500). Die beantworteten Seiten tragen echte semantische
Einträge samt Allergenpiktogrammen, die 500er-Seite kommt aus den lokalen
Regeln — die Seitenrettung aus dieser Sitzung im echten Betrieb bestätigt.

**Lehre für die nächste Sitzung:** der Harness misst die Pipeline, nicht das
Produkt. Timeouts, Nebenläufigkeit und Provider-Verhalten zeigen sich erst in
der App. Ein App-Durchlauf pro grösserer Änderung ist billig (kostenloser Pfad)
und hat hier gefunden, was zehn bezahlte Harness-Läufe nicht gefunden haben.

## Session-Teil 25: Vier deterministische Reparaturen im Assembler (28. Juli 2026)

### Der offene Befund aus Teil 24 ist geklärt

Der Legendenfilter war **nicht defekt**. Die Prüfung von Teil 24 lief auf
`lichtburg-berlin:0` — auf dieser Seite stehen die gefälschten Legendennamen
(`Carpaccio Di Manzo`, `Antipasti-Vorspeisen`) gar nicht. Der Filter fand
nichts, weil nichts zu finden war. Zusätzlich waren die Reportdateien unter
`/tmp` inzwischen vom System-Cleaner geleert, weshalb der Vergleich in Teil 24
vermutlich auf einem älteren Report basierte.

Zwei Folgerungen, beide umgesetzt:

- Der Filter deckte nur **Dokumentdeklarationen** ab. Der Anbieter entscheidet
  aber, wo er eine erfundene Legende anhängt. Er greift jetzt auf Sektions-,
  Eintrags-, Auswahl- und Komponentenebene, und jeder Befund nennt seinen Pfad.
- Reportdaten gehören nicht nach `/tmp`. Die Läufe dieser Sitzung liegen unter
  `.claude/artifacts/` (nicht versioniert, ausserhalb von git).

Für das Protokoll: mit dem aktuellen Prompt erfindet `gemini-3.5-flash` keine
Legenden mehr. Der Filter feuert in **null** echten Läufen. Er bleibt als Netz.

### Vier Defekte, die kein Prompt zuverlässig löst

Alle vier sitzen jetzt im Assembler, sind unit-getestet und anbieterunabhängig:

1. **Gedruckter Name überlebt die Mengenabtrennung.** Die Karte druckt
   `Hüftsteak(250gr)`, der Anbieter lieferte `Hüftsteak` plus Menge `250gr`.
   Das Gate zählte das als fehlenden UND erfundenen Eintrag — 8 der 18
   Korrekturen. Der Name wird aus der eigenen OCR-Belegzeile wiederhergestellt,
   die Menge bleibt strukturiert erfasst. Die Rückschreibung passiert nur, wenn
   die verortete Zeile exakt aus Name plus den erfassten Mengen besteht.
2. **Währung aus Dokumentbeleg vervollständigt.** 66 von 92 Preisen kamen ohne
   `currency_code`. Ergänzt wird aus genau zwei Quellen: den Codes, die der
   Anbieter anderswo im selben Dokument genannt hat, und den auf der Karte
   gedruckten Symbolen (OCR). Zwei Währungen im Dokument oder gar keine heisst:
   nichts ergänzen.
3. **`fixed`/0 Cent ohne gedruckten Preis ist `included`.** Ein gedrucktes
   `0,00 €` bleibt ein Preis.
4. **Drei Prüfcodes werden aus dem fertigen Entwurf abgeleitet**
   (`selection_rule_unknown`, `complex_bundle_choice`,
   `source_declaration_meaning_unknown`) statt darauf zu warten, dass der
   Anbieter sie erwähnt — gemessen meldete er sie auf einer Karte und schwieg
   bei identischer Lage auf der nächsten. Einmal pro Dokument und Code.

`relationship_scope_ambiguous` wurde **bewusst nicht** abgeleitet: es gibt
keinen ehrlichen strukturellen Auslöser dafür. Ihn zu erfinden hiesse, den
Extraktor auf den Lösungsschlüssel des Gates zu tunen.

### Robustheit gegen Anbieterausfälle

- Die Abwesenheitstoleranz gilt jetzt auch für offene Klassifikatoren
  (`basis`, `kind`, `claim`, `scope`, `mode`, `page_kind`) — ein einziges
  ausgelassenes `offers[0].basis` hatte die komplette semantische Erfassung
  einer Karte verworfen. Vorhandene Felder mit falschem Typ werfen weiterhin.
- Eine Seite mit nicht abbildbarem JSON wird jetzt **zweimal** wiederholt statt
  einmal. Begründung: eine gescheiterte Seite kostet die ganze Karte ihren
  semantischen Entwurf (`parseDraftWithLLM` akzeptiert keinen Teilentwurf).
- Der Auswerter benennt jetzt, **welche** Preise er für erfunden hält
  (`diagnostics.inventedPrices` / `missingPrices`). Ohne das war die
  Kennzahl nicht handhabbar.

### Messung (10 Gate-Seiten, `gemini-3.5-flash`)

| | vorher | nachher |
|---|---|---|
| Korrekturen/Seite | 1.80 | **1.00** |
| Eintrags-Recall | 0.941 | **1.000** |
| Einträge F1 | 0.941 | **1.000** |
| Bereiche F1 | 1.000 | **1.000** |
| Kategoriezuordnung | 0.941 | **1.000** |
| Namen exakt | 0.863 | **0.971** |
| Review-Erkennung | 0.571 | **0.714** |
| fehlende / erfundene Einträge | 4 / 4 | **0 / 0** |
| verbotene Claims · stille Seitenverluste | 0 · 0 | **0 · 0** |

`declarationF1` ist **kein belastbares Signal**: über vier identische Läufe
gemessen 0.053 / 0.210 / 0.210 / 0.443. Sie hängt daran, wie viele
Allergencodes das Modell zufällig an Einträge hängt.

### Offen — und wofür ich den Nutzer brauche

- **Guthaben.** Das OpenCode-Zen-Konto war im zweiten von drei
  Wiederholungsläufen leer ("Insufficient balance", danach HTTP 401).
  `minimumRepeatRuns 3` ist damit weiter unerfüllt, und die Zahlen oben stehen
  auf **einem** sauberen Lauf. Läufe 2 und 3 sind Fehlschläge, keine Messung.
- **P95-Seitenlatenz 74 s** gegen 60 s Ziel. Das ist die Modellgeschwindigkeit
  bei Vision auf dichten Seiten, nicht die Nebenläufigkeit (die steht auf 5).
- **`expectedReviewRecall` 0.714** gegen Ziel 1.000. Der fehlende Code ist
  `relationship_scope_ambiguous`. Das ist entweder eine Prompt-Frage oder eine
  Ground-Truth-Frage, keine Assembler-Frage.
- **Sporadisch unlesbares JSON** auf einer dichten Seite (scheune Seite 1, in
  zwei von vier Läufen). Der doppelte Retry ist die Gegenmassnahme; der
  Rohtext des Fehlschlags wurde noch nicht eingefangen. Nächster Schritt:
  `KITCHENLINK_LLM_DIAGNOSTICS=1` und wiederholt genau diese Seite fahren, bis
  sie fällt.
- **Produktentscheidung, unverändert offen:** eine gescheiterte Seite verwirft
  den semantischen Entwurf der **ganzen** Karte. In einem Lauf hat das zwei von
  vier Karten gekostet. Seitenweise Rettung wäre die Alternative, erzeugt aber
  einen Entwurf gemischter Herkunft — das ist eine Produktentscheidung des
  Nutzers, keine technische.

## Session-Teil 24: Ungeklärt — Legendenfilter erreicht die Laufzeitdaten nicht (27. Juli 2026)

### Stand

`removingNameDerivedLegendEntries` (PR #33) verwirft Legendeneinträge, die nur
ein nach dem ersten Zeichen zerschnittener Gerichtname sind. Auf
Assembler-Ebene ist das durch
`testFabricatedLegendBuiltFromEntryNamesIsRejected` bewiesen: zwei Fälschungen
werden verworfen, eine echte Legendenzeile überlebt, beide Verwerfungen
erscheinen als Befund.

### Das ungelöste Problem

Im echten Lauf greift der Filter **nicht**. Reproduziert auf einer einzelnen
Lichtburg-Seite, auch nach vollständig gelöschtem `derivedDataPath` und
frischem Build (Binary 00:55, Quelle 00:36):

- `rejected_name_derived_legend_entry`: **0 Befunde**
- Dokumentdeklarationen unverändert 7, darunter `c` -> `"c arpaccio Di Manzo"`
- Auf denselben Reportdaten nachgerechnet: `compacted("c arpaccio Di Manzo")`
  = `"carpacciodimanzo"` steht **nachweislich** im Namensindex des Entwurfs.

Die Filterbedingung trifft also auf die Daten zu, die am Ende im Report stehen,
wird aber nicht ausgelöst. `MenuImportDraftAssembler.assemble` ist laut
`grep` die einzige `assemble`-Definition, und `parseDraftWithLLM`
(`ContentView.swift`) reicht deren Rückgabe unverändert weiter.

### Nächste Ansätze (ungeprüft)

1. Prüfen, ob `MenuImportService.importMenu` die Dokumentdeklarationen nach
   `assemble` erneut befüllt — Verdacht auf `mergedLegend(from: legacySections)`
   in `MenuImportDraftAdapter`, das im Report-Entwurf landen könnte.
2. Prüfen, ob der Report-Entwurf überhaupt `llmResult.draft` ist oder eine
   Rekonstruktion aus `draftSection(from:)` im Harness.
3. Erst danach wieder Geld ausgeben. Die Frage ist mit einem Unit-Test auf dem
   echten Reportinhalt klärbar, nicht mit weiteren Läufen.

### Wichtig für die Erwartung

Der Defekt "erfundene Legende aus Gerichtnamen" ist damit **nicht behoben**.
Der Mechanismus existiert und ist getestet, erreicht die Produktionsdaten aber
nicht. `declarationF1` steht unverändert bei 0.201.

## Session-Teil 23: Legendenbasierte Namens-Normalisierung (26. Juli 2026)

### Anlass

Nach PR #30 fragte der Nutzer nach dem weiteren Vorgehen. Empfehlung und
Auswahl: erst den kostenlosen deterministischen Namens-Fix, dann **ein**
bezahlter Lauf, der Prompt `1.0.4` und den Fix gemeinsam misst — spart einen
Lauf gegenüber der getrennten Messung.

### Korrektur einer eigenen Annahme

Die PR-Notiz schrieb den Fix dem Regel-Parser zu. Falsch: die beiden Namen
stammen aus dem **bezahlten Gemini-Lauf**. `AllergenCodeParser` in
`ContentView.swift` ist nicht der Pfad. Der Fix gehört in den Ingestion-Pfad
(`MenuImportDraftAssembler`), damit er **providerunabhängig** greift — auch
wenn ein Modell die Prompt-Anweisung ignoriert.

### Umgesetzt

`AssemblyContext` trägt neu `legendCodes`, gefüllt von `collectLegendCodes`
über **alle** Seiten, bevor ein Eintrag konvertiert wird. Das ist notwendig,
weil die Legende real meist auf einer eigenen Seite steht, oft *nach* den
Einträgen, die sie erklärt.

`splitTrailingCodeGroup` kennt drei Formen in absteigender Beweisstärke:

1. Geklammert mit Trennern (`Salat [F,I]`) — akzeptiert **ohne** Legende, weil
   die Trenner selbst zeigen, dass es Codes sind. Codex' bisheriges Verhalten,
   unverändert.
2. Geklammert ohne Trenner (`Curry [FI]`) — **nur** mit Legende für jeden
   Buchstaben.
3. Klammerlos (`Bunter Marktsalat WI`) — schwächste Form, strengste Schranke:
   Legende für jeden Buchstaben, Lauf ≤ 4 Zeichen, komplett Großbuchstaben,
   Restname nicht leer.

Formen 2 und 3 liefern ohne Legende `nil`. Begründung: einen Lauf im Namen zu
lassen ist sichtbar falsch, aber im Review reparabel — aus einer Größe
Deklarationen zu erfinden ist es nicht.

### Verifikation

- `kitchenlinkTests` auf iPhone 17 Pro: **TEST SUCCEEDED, 332 Fälle** (vorher
  329), dieselben zwei bewusst gegateten Skips.
- Codex' `testAssemblerMovesCompactTrailingCodesOutOfEntryNameLosslessly`
  läuft unverändert grün — inklusive seiner `[XL]`-Gegenprobe.
- Drei neue Tests: beide echten Formen mit Legende, `[XL]`-Gegenprobe **mit**
  vorhandener Legende, Nichts-tun ohne Legende, Legende auf einer *späteren*
  Seite.

### Offen / nächster Schritt

Unverändert der bezahlte Lauf: Prompt `1.0.4` + dieser Fix gemeinsam über die
zehn Gate-Seiten, danach die drei Wiederholungsläufe (`minimumRepeatRuns`).
Beides braucht Nutzerfreigabe und den Schlüssel. Ob der Fix die zwei Einträge
wirklich einsammelt, hängt daran, ob das Modell die Legende der Prüfküche als
`declarations` mit `local_code` liefert — im Lauf mit `1.0.2` tat es das nur
teilweise. Das ist die eigentliche Messfrage.

## Session-Teil 21: Local-first Event-Log fürs Einzelgerät (24. Juli 2026)

### Anlass und Scope

Ausgangspunkt war die AP-Isolations-Frage (der Gast erreicht den lokalen Hub im
Restaurant-WLAN nicht). Im Gespräch mit dem Nutzer wurde die Offline-Strategie
neu priorisiert: Gast-Offline-Selbstbestellung ist ein seltener Fall mit
akzeptablem mündlichem Rückfall; die eigentliche Anforderung ist, dass der
**Betrieb** (Organisation, Küche/Service, Kassieren) bei Cloud-/Internet-Ausfall
ohne Friktion weiterläuft und nichts verloren geht. Erster, risikoärmster
Schritt: Bestellungen dauerhaft ins Event-Log (KL-OFFLINE-003) legen statt in
UserDefaults, sodass ein **einzelnes Gerät** local-first und crash-fest ist. Das
ist die in `EVENT_LOG_V2.md` §12 als „später, freizugeben" markierte
iOS-Integrationsnaht; der Nutzer hat die Umsetzung ausdrücklich beauftragt.

### Umgesetzt

- **Paket `KitchenLinkLocalGuestCore`** (bereits vom App-Target verlinkt): neue
  app-neutrale, dauerhafte Bestell-Komponente `DurableOperatorOrderStore` +
  `StoredOperatorOrder`
  (`prototypes/KitchenLinkLocalGuestPOC/Sources/KitchenLinkLocalGuestCore/DurableOperatorOrderStore.swift`).
  Append-only Events `operator_order_placed` / `operator_order_status_changed` /
  `operator_orders_cleared` über den bestehenden `EventStore`; Projektion je
  Bestellung; Idempotenz aus `orderID` + Zielstatus; jede Bestellung erzeugt eine
  `cloud`-Outbox-Zeile für den späteren Abgleich. Bestell-Snapshot und Status
  bleiben bewusst opak, damit das Paket keine App-Typen braucht.
- **App-Target**: `EventLogOrderRepository`
  (`kitchenlink/EventLogOrderRepository.swift`) — ein `KitchenLinkRepository`,
  das Bestell-Operationen an den dauerhaften Store routet und Venue/Menü/QR an
  ein eingebettetes `LocalDemoRepository` delegiert. `makeDefault()` legt die DB
  in Application Support (`KitchenLinkOrders/orders.sqlite`) an und fällt bei
  Öffnungsfehler weich auf `LocalDemoRepository` zurück, sodass Bestellen nie
  hart an einem Speicherproblem scheitert.
- **Verdrahtung** (`kitchenlinkApp.swift`): reale Starts nutzen jetzt
  `EventLogOrderRepository.makeDefault()`; der UI-Test-Pfad bleibt auf dem
  deterministischen `LocalDemoRepository`, damit UI-Tests keinen persistierten
  Bestell-Stand erben.
- **`LocalDemoRepository` bleibt vollständig erhalten** (Blueprint §18.1,
  „alter Code wird erst entfernt, wenn ein getesteter Ersatz existiert") und
  trägt weiterhin alle Demo-/Test-Pfade.
- Tests: 10 neue Paket-Tests (`DurableOperatorOrderStoreTests`) + 5 neue
  App-Tests (`KitchenLinkEventLogOrderRepositoryTests`), inkl. Durability über
  Store-Neustart, Idempotenz und Clear-Semantik.

### Verifikation

- `swift test` im Paket `KitchenLinkLocalGuestPOC`: **21/21 grün** (10 neu +
  11 bestehend).
- `xcodebuild build-for-testing` (iOS-Simulator, ohne Signing): **TEST BUILD
  SUCCEEDED** — App-Target, Repository, Verdrahtung und neuer Test kompilieren.
  Neue Dateien werden über die synchronisierten Ordner (objectVersion 77)
  automatisch eingebunden, kein pbxproj-Edit nötig.
- `xcodebuild test` (iPhone-17-Sim): meine Order-Suites grün; das ganze
  `kitchenlinkTests` **ohne** CloudOperations = 229 Tests / 26 Suites, nur die
  Keychain-Tests schlagen fehl.
- **Vorbestehende Fehler, nicht durch diese Änderung verursacht:** die
  Fehlschläge in `KitchenLinkCloudOperationsTests` /
  `KitchenLinkMenuPublishTests` und ein `Index out of range`-Crash reproduzieren
  sich bei einer Stash-Baseline (meine Änderungen entfernt, neu gebaut)
  **identisch**. Ursache ist die laufende, noch uncommittete Keychain-Migration
  (`KitchenLinkKeychain.swift`, `KitchenLinkCloudOperations*`,
  `KitchenLinkMenuPublish*`): der Keychain-Session-Speicher liefert im
  headless-Simulator ohne Signing keine Session (`connectionState == .signedOut`).

### Offen / Nächste Schritte

- **DECISIONS.md-Anpassung nötig (nur Nutzer):** Der Eintrag „Local Guest
  Ordering" (18. Juli) macht lokale **Gast**bestellung zur Pflichtfähigkeit der
  Sandbox-Beta. Die neue Priorisierung (Personalbetrieb local-first, mündlicher
  Gast-Rückfall akzeptiert) revidiert das und gehört vom Nutzer neu formuliert.
- Weitere Bausteine der Offline-Strategie (nicht in dieser Session): (2)
  Offline-Status ruhig/sichtbar im UI, (3) Outbox → Supabase-Abgleich bei
  Internet-Rückkehr verdrahten, (4) erst danach Gerät-zu-Gerät-Abgleich fürs
  Personal (Stufe 1), beginnend mit „bei Peer-Kontakt abgleichen".
- Einzelgerät-Durability zusätzlich real am Gerät bestätigen (App killen/neu
  starten → Bestellungen + Status noch da). Ergänzt Zeile 4/§5 in
  `docs/test-plans/REAL_DEVICE_ACCEPTANCE.md`.
- Die vorbestehenden Keychain-Testfehler gehören der laufenden Keychain-Migration
  und sind separat zu prüfen (z. B. Keychain-Test-Double im Simulator).

## Session-Teil 20: Piktogramme im Beschreibungsfluss (23. Juli 2026)

### Anlass und Scope

Nutzer-Befund: Die Kennzeichnungen in einer eigenen Zeile unten wirken
„penetrant und formwidrig". Nach Vorlage eines Vergleichs (eigener Streifen
vs. im Fluss der Beschreibung, per Imagine-Widget) bestätigte der Nutzer „im
Fluss der Beschreibung passt gut". Diese Session löst den eigenen Streifen auf.

### Umgesetzt

- **iOS `AllergenBadgesRow`** (`ContentView.swift`) um `leadingDescription:
  String?` erweitert. Im `.compact`-Modus rendert `quietGuestRow` jetzt einen
  gemeinsamen `KitchenLinkV2WrappingRow` aus **Beschreibungswörtern**
  (`secondaryLine`, Content.secondary) **plus Glyphen** (Content.muted) — Text
  und Symbole teilen sich einen umbrechenden Sekundärtext. Der ganze Block
  bleibt ein Button → `FoodDeclarationListView`. Accessibility-Label =
  Beschreibung + „Kennzeichnungen: …".
- **`MenuImportGuestPreviewView.itemRow`**: den bisherigen
  Deklarations-/Accessory-Streifen (HStack mit Glyphen + Stepper) entfernt.
  Neu: wenn Deklarationen vorhanden → `AllergenBadgesRow(.compact,
  leadingDescription:)` als kombinierte Sekundärzeile; sonst reine
  Beschreibung. Die Mengensteuerung erscheint nur bei Menge>0 in einer eigenen
  rechtsbündigen `HStack`-Zeile darunter. Neuer Helper `descriptionText(for:)`.
- **Gast-Web `GuestMenuCard.tsx`**: die Glyphen sind jetzt ein inline
  `<button class="kl-declaration-inline">` **innerhalb** des Beschreibungs-`<p>`
  (direkt hinter dem Text; ohne Beschreibung ein eigenes `<p>` nur mit den
  Symbolen). Der frühere `.kl-declaration-summary`-Block und der
  `.kl-menu-row-accessories`-Streifen sind entfernt; der Stepper sitzt bei
  Menge>0 in `.kl-menu-row-stepper` (rechtsbündig).
- **`globals.css`**: `.kl-declaration-inline` (display:inline, muted,
  margin-left) + `.kl-declaration-inline-glyph` (inline-block, 1rem,
  vertical-align −0.18em, wrappt mit dem Text) + `.kl-menu-row-stepper`. Alte
  `.kl-declaration-summary*`- und `.kl-menu-accessory-spacer`-Regeln raus.

### Verifikation

- **Gast-Web:** Typecheck, Lint, **87/87 Vitest**, Build (ISR 1 m) grün;
  Konsole fehlerfrei. Browser 375 und 320 px bestätigt: die Symbole laufen
  hinter dem Beschreibungstext weiter und brechen mit ihm um (Flammkuchen bei
  320 px: „… geräucherter Speck 🌾 …" auf derselben Zeile); Käsespätzle im
  Warenkorb zeigt Beschreibung+Symbole und darunter den eigenen rechtsbündigen
  Stepper; Inline-Tap öffnet weiterhin die Klartextliste → Detail.
- **iOS:** Build grün, `kitchenlinkTests`-Suite **232/0**. Beide UI-Tests
  grün: `testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish` (prüft
  jetzt, dass das Tap-Ziel-Label sowohl die Beschreibung „Rind, Cheddar,
  Haus-Sauce" als auch alle 11 Kennzeichnungen trägt → belegt die
  Inline-Integration; Liste + Sesam-Detail wie zuvor) und
  `MenuManualEditorUITests.testManualMenuEditorCoreFlow`. Dabei eine obsolete
  Assertion korrigiert: die alte `frame.height >= 44`-Prüfung passte nicht
  mehr zum Inline-Fluss (Ist-Höhe 43,9999… bei zweizeiligem Umbruch) und wurde
  durch die Label-Prüfung ersetzt — konsistent mit dem Entscheidungsvermerk,
  dass das Tap-Ziel jetzt die Textzeile ist. Visuelle simctl-Abnahme der
  iOS-Gastvorschau weiterhin durch den Preview-Sheet-Tap-Quirk blockiert;
  dieselbe Ansicht ist per grünem UI-Test abgedeckt und im Gast-Web identisch
  visuell bestätigt.

### Offen / Risiken

- Gast-Web lokal verifiziert, nicht deployt (nächstes `main`-Deployment).
- Sehr lange Beschreibungen: die frühere `lineLimit(2)`-Begrenzung entfällt im
  Inline-Fluss (Wörter+Glyphen laufen voll aus). Bei den aktuellen Karten
  unkritisch; ggf. später Wortliste kappen.
- Tap-Ziel ist jetzt die Textzeile (kein erzwungenes 44-pt-Rechteck mehr);
  bei mehrzeiligen Deklarationen deutlich über 44 pt, bei einzeiligen knapp
  darunter — für einen sekundären Text-Affordance vertretbar.

## Session-Teil 19: Ruhige Deklarationszeile (23. Juli 2026)

### Anlass und Scope

Nutzer-Vorgabe: Inhaltsstoffe/Allergene fallen weiterhin zu sehr ins Auge.
Sie sind für die meisten Gäste nebensächlich — müssen sichtbar sein, sollen
aber keine Aufmerksamkeit auf sich ziehen. Nach Vorlage von vier Varianten
(laut → dezent, per Imagine-Widget) wählte der Nutzer **B mit Zeilen-Tap**:
monochrome Symbole ohne Farbfläche, die ganze Zeile ein Tap-Ziel → Klartext-
liste. Diese Session setzt genau das um.

### Umgesetzt

- **iOS `AllergenBadgesRow`** (`ContentView.swift`) in zwei Modi getrennt:
  - `.compact` (Gast): `quietGuestRow` — nur `FoodDeclarationGlyphView` in
    `Content.muted`, 18 pt, KEIN Badge/Box/Rahmen, `KitchenLinkV2WrappingRow`.
    Die gesamte Zeile ist EIN `Button` (44 pt hoch, `contentShape`), öffnet
    das neue `FoodDeclarationListView`. Accessibility-Label trägt alle
    Klartexte; ID `foodDeclaration.row.<itemID>`.
  - `.standard` (Betreiber): unverändert farbige `AllergenBadgeView` mit
    Einzel-Tap → `FoodDeclarationDetailView`.
- **`FoodDeclarationGlyphView`** um `color`-Parameter erweitert (Default
  `.primary`); alle Canvas-Striche und die SF-Symbol-Fälle respektieren ihn,
  damit die Gastzeile gedämpft und die Detailansicht farbig zeichnen kann.
- **`FoodDeclarationListView`** (neu): gruppierte Klartextliste (nach
  `FoodDeclarationGroup`), Eintrag → `FoodDeclarationDetailView`; ersetzt in
  der Gastzeile die frühere `AllergenLegendView` funktional. Item-IDs
  `foodDeclaration.list.<code>`.
- **`declarationVisualSize`** 22 → 18 pt (kleiner, da ohne Box).
- **Gast-Web `GuestMenuCard.tsx`:** die per-Icon-`<button>`-Liste durch EINE
  `.kl-declaration-summary`-Schaltfläche ersetzt (monochrome 18px-Glyphen in
  `--kl-text-muted`, `flex-wrap`); `FoodDeclarationListDialog` (Liste →
  Detail) wiederhergestellt. `globals.css`: neue ruhige Row-Styles, die
  Gruppenfarb-Klassen (`kl-allergen-badge-*`) gelten nur noch in Listen-/
  Detaildialog; Listen-Styles zurück.
- **UI-Tests umgestellt:** `testGuestPreviewShowsEveryDeclarationOfAFully…`
  tippt jetzt die Zeile `foodDeclaration.row.f-burger`, prüft das
  Sammel-Label und alle 11 Einträge in der geöffneten Liste plus einen
  Detail-Drilldown (Sesam). `MenuManualEditorUITests` analog auf Zeile →
  Liste → Detail.

### Verifikation

- **Gast-Web:** Typecheck, Lint, **87/87 Vitest** grün. Browser 375 und
  320 px: Zeile jetzt ruhig-monochrom (Wiener Schnitzel: 8 Symbole als eine
  Fußnotenzeile statt farbiger Kästen), Zeilen-Tap öffnet Klartextliste,
  Eintrag → Detail, Konsole fehlerfrei. Screenshot bei 320 px bestätigt die
  deutlich reduzierte Präsenz gegenüber den vorherigen farbigen Badges.
- **iOS:** Build grün; komplette `kitchenlinkTests`-Suite **233/0/2**
  (Katalog-/SF-Symbol-Tests aus Teil 18 unverändert grün). Native UI-Tests
  **beide grün**: `testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish`
  (tippt die Zeile `foodDeclaration.row.f-burger`, prüft Sammel-Label + alle
  11 Listeneinträge + Sesam-Detail) und
  `MenuManualEditorUITests.testManualMenuEditorCoreFlow` (Zeile → Liste →
  Gluten-Detail). Visuelle simctl-Abnahme der iOS-Gastzeile blieb an einem
  Tap-Quirk des Vorschau-Sheets hängen (Sheet öffnet/schließt unter direktem
  simctl-Tap); dieselbe Ansicht ist aber durch den grünen UI-Test abgedeckt,
  und die identische ruhige Zeile ist im Gast-Web visuell bestätigt.

### Offen / Risiken

- Gast-Web lokal verifiziert, nicht deployt (nächstes `main`-Deployment).
- Subjektive Geräteabnahme der ruhigen Zeile beim Nutzer.
- Betreiberansichten behalten bewusst farbige Badges (Arbeitsinformation).

## Session-Teil 18: Vollständige Deklarationsanzeige (23. Juli 2026)

### Anlass und Scope

Nutzer-Vorgabe: Die Begrenzung auf höchstens zwei Deklarationssymbole pro
Menüzeile (Codex' unkommitteter „Speise zuerst"-Stand) ist mit den
gesetzlichen Kennzeichnungsvorgaben unvereinbar und musste entfernt werden.
Zusätzlich soll die Testkarte den vollen Funktionsumfang der digitalen
Speisekarte abdecken. Diese Session baut AUF dem unkommitteten Codex-Stand
auf (dish-first-Hierarchie, 44-Punkt-Quantity-Helper bleiben erhalten) und
ersetzt nur die Kürzungslogik.

### Umgesetzt

- **iOS:** `AllergenBadgesRow` zeigt jetzt ALLE Deklarationen; neues
  `KitchenLinkV2WrappingRow`-Layout (SwiftUI `Layout`) bricht die Symbolzeile
  um, statt zu kürzen. `+N`-Button, `maxVisible`-Parameter, die Metrik
  `maximumVisibleDeclarations` und die dadurch tote `AllergenLegendView`
  sind entfernt. Jedes Symbol bleibt einzeln antippbar (44-Punkt-Ziel).
- **Gast-Web:** `slice(0, 2)` + `+N`-Button + `FoodDeclarationListDialog`
  entfernt; `.kl-allergen-row` ist `flex-wrap: wrap`. Zugehörige tote
  CSS-Blöcke (`kl-allergen-more`, `kl-declaration-list*`) entfernt.
- **Echter Fund dabei:** Das Konservierungsstoff-Piktogramm war in iOS
  unsichtbar — `jar.fill` existiert nicht als SF Symbol, `Image(systemName:)`
  rendert dann leer. Jetzt als Canvas-Einmachglas gezeichnet (spiegelt das
  Gast-Web-SVG); ein neuer Unit-Test prüft alle verwendeten SF-Symbol-Namen
  auf Existenz.
- **Zweiter Fund (Gast-Web-Konfigurationsdialog):** Bei wiederholbaren
  Optionen überlappten Optionsname und „danach +X €" bei 375 px. Name und
  Preishinweis stapeln sich jetzt vertikal (`kl-choice-counter-info`).
- **Volltest-Karten:** Die deterministische iOS-Demokarte
  (`DemoMenuFactory`) deckt jetzt den vollen Umfang ab: alle
  Deklarationsgruppen (14er-Allergene, Zusatzstoffe, Verbraucherhinweise,
  Alkohol via neuer Sektion „Bier & Wein"), ein volldeklariertes
  Referenzgericht (Cheeseburger, 11 Kennzeichnungen → erzwungener Umbruch),
  Pflicht-Einfachwahl (Schnitzel-Beilage), wiederholbare Extras
  (Burger-Extras), Portionsgröße (Limonade) und `per_person`
  (Überraschungsmenü). Gast-Web-Fixture analog angereichert (Schnitzel als
  8-Icon-Referenz, Radler `a,13`); Fixture-Test sichert das dauerhaft ab.
- **Doku:** Neue Entscheidung „Complete Declaration Display" in
  `DECISIONS.md`; `DESIGN_SYSTEM.md` und `CURRENT.md` nachgezogen.

### Verifikation

- Gast-Web: Typecheck, Lint, **87/87 Vitest**, Produktions-Build (ISR 1 m
  unverändert): **bestanden**. Browser 375×812 und 320×844: alle Symbole
  sichtbar, Umbruch auf 2–3 Zeilen, Stepper stabil rechts, Detail- und
  Konfigurationsdialog geprüft, Konsole ohne Fehler.
- iOS: Simulator-Build **bestanden**; komplette `kitchenlinkTests`-Suite auf
  dem Endstand **232 bestanden / 0 fehlgeschlagen / 2 bewusst übersprungen**
  (inkl. neuer Tests: Katalog liefert 20/20 Deklarationen ungekürzt,
  SF-Symbol-Existenz). Gezielte UI-Tests: Codex' Randtap-Smoke
  `testGuestPreviewUsesCountersAndCompactQuantityControl` **bestanden**
  (damit ist dessen offene CoreSimulator-Verifikation erledigt) und neuer
  `testGuestPreviewShowsEveryDeclarationOfAFullyDeclaredDish` **bestanden**
  (alle 11 Burger-Kennzeichnungen einzeln vorhanden). Simulator-Screenshots
  bestätigen Umbruch und das reparierte Einmachglas visuell.

### Offen / Risiken

- Das aktualisierte Gast-Web ist lokal verifiziert, aber nicht deployt; die
  öffentliche Sandbox erhält den Stand erst mit dem nächsten
  `main`-Deployment (Hostinger zieht von `main`).
- Die Demokarten-Anreicherung ist Sandbox-Testinhalt; sie behauptet keine
  rechtliche Vollständigkeit realer Karten. Betreiber bleiben für Stoff,
  Schwellenwert und Wortlaut verantwortlich.
- Subjektive Designabnahme der umbrechenden Symbolzeile auf echtem Gerät
  liegt beim Nutzer.

## Session-Teil 17: Allergen-Legende aus dem Bild + manueller Karten-Editor

Zwei zusammenhängende Stränge, beide verifiziert und in `main` (`87ccb34`
für den Fix, Editor-Commit folgt).

### A. Allergen-Legende: KI liest sie jetzt direkt aus dem Bild

Nutzer-Befund (zu Recht): die Allergen-Icons waren schlechter als in der Alpha.
Ursache im Code bestätigt: das KI-Schema hatte **kein Legenden-Feld**; die
einzige Legendenquelle war die lokale OCR-Heuristik `detectAllergenLegend`.
Scheiterte die, blieb `section.allergenLegend` leer und die Icons konnten Codes
nicht zuordnen. (Ehrliche Einordnung: Alte Kanzlei, die ich fälschlich als
„perfekt" bezeichnet hatte, druckt gar keine Legende — „Bitte fragen Sie unser
Serviceteam" —, die 0 erfassten Codes waren dort also korrekt; ich hatte es nur
nie überprüft.)

Fix in `kitchenlink/ContentView.swift`:
- Prompt/Schema um `legend` (Code→Klartext) erweitert; jeder an einem Artikel
  genutzte Code muss in der Legende erklärt sein; Per-Item-Code-Regel geschärft.
- `LLMMenuRoot` dekodiert die Legende liberal (Objekt- ODER Array-Form, gängige
  Feldnamen), normalisiert Keys auf Kleinbuchstaben.
- `mergeLegends`: KI-Legende hat Vorrang, lokale OCR-Legende füllt Lücken.
- Page-by-Page: Legende jeder Seite (auch reiner Legendenseiten OHNE Artikel →
  `.empty(legend:)`) wird karteweit vereint und auf ALLE Sektionen geschrieben.
- `AllergenCatalog.definitions`: Standard-EU-Codes (a–p, 1–14) rendern als Icon
  auch dann, wenn die erkannte Legende sie mal nicht auflistet; unbekannter
  Zeichen-Müll ohne Legendeneintrag bleibt gefiltert.

**Verifiziert:** direkter Gateway-Probe mit dem NEUEN Prompt auf einer echten
Karte (pizzeria-zum-italiener) — big-pickle liefert jetzt das `legend`-Feld
exakt mit der gedruckten Karten-Legende (A=glutenhaltiges Getreide, B=Krebstiere
…). Beweis in `/tmp/kl-legend-probe-proof.txt`. Harness-Lauf end-to-end grün
(Deklarationen tragen die karten-eigene Legendenformulierung, 56/92 Artikel mit
Codes). Build grün, Unit-Suite 208/0/2.

### B. Manueller Speisekarten-Editor (Grundlage für den Import)

Nutzer-Vorgabe: erst den Editor vollständig ausbauen, damit klar ist, was der
Import abbilden muss. Der Editor arbeitet auf demselben leichten Modell
(`MenuSectionData`), das der Import erzeugt und `MenuPublishSheet` konsumiert —
Import und Handeingabe konvergieren so auf ein Modell und denselben Publish-Weg.

- **NEU** `kitchenlink/Features/MenuEditor/MenuManualEditorView.swift`:
  Kategorien (anlegen/sortieren/löschen), Gerichte (Name, Beschreibung, Preis in
  €→Cent, Art Essen/Getränk), Varianten/Portionen/Extras, sowie Allergen-/
  Zusatzstoff-Auswahl als EINHEITLICHE App-Icons (Standardcodes a–p/1–14 aus
  `AllergenCatalog`, plus Hauscodes mit eigener Bedeutung in die karteweite
  Legende). Live-Vorschau „wie für Gäste" (dieselbe `AllergenBadgesRow`).
  Auto-Persistenz über `KitchenLinkStore`, Übergabe an `MenuPublishSheet`.
- `KitchenLinkStore.updateMenuSections(_:)` (persistiert, erlaubt leere Karte
  während der Bearbeitung).
- Einstieg im Betreiber-Home: Button „Karte von Hand bearbeiten"
  (`business.editMenuManually`).
- Zugriffsebenen in `ContentView.swift` von `private` auf intern geweitet, damit
  der Editor sie wiederverwendet: `PriceFormatter`, `AllergenCatalog`,
  `AllergenDefinition`, `AllergenBadgeView`, `AllergenLegendView`,
  `AllergenBadgesRow`, `MenuItemOptionsListView`. `MenuSectionData`,
  `MenuItemData`, `MenuItemVariant` sind jetzt `Equatable` (für Change-Tracking).
- **NEU** `kitchenlinkUITests/MenuManualEditorUITests.swift`: fährt Kategorie →
  Gericht → Name/Preis → Allergen-Code → Gäste-Vorschau real durch. Grün (1/1),
  drei Screenshots belegen die Icon-Auswahl (A ausgewählt, mit Symbol+Klartext).

### C. Publish-Vertrag um Legende + Varianten erweitert (erledigt, verifiziert)

Der Editor pflegt Legende und Varianten — jetzt überträgt der Publish-Weg sie
auch bis in die DB.

- `KitchenLinkPublishMenu`: `Category.allergen_legend` (Objekt) und
  `Item.variant_options` (Array `{name, price_cents, kind}`) ergänzt; der Builder
  füllt sie aus `MenuSectionData.allergenLegend` bzw. `MenuItemData.variants`
  (Legenden-Keys klein normalisiert, leere Varianten/Preise ausgelassen).
- Migration `20260721120000_operator_publish_menu_legend_variants.sql`: ersetzt
  additiv die RPC, sodass sie beide Felder in die bereits vorhandenen Spalten
  `menu_categories.allergen_legend` / `menu_items.variant_options` schreibt
  (typ-gesichert, Legenden-Keys klein, `kind` auf portion|extra|variant
  normalisiert, leere Varianten weg).
- **Latenter Bug gefixt:** die RPC referenzierte `menu_id` mehrdeutig (OUT-Spalte
  der RETURNS TABLE vs. Tabellenspalte). Die erste Fassung (20260719200000)
  wurde real nie ausgeführt, daher unentdeckt; sie wäre beim ersten echten
  Publish an `delete ... where menu_id = v_menu_id` gescheitert. Fix per
  `#variable_conflict use_column`.
- **Verifiziert:** neue Payload-Tests grün (Unit-Suite 211/0/2); die Migration
  FUNKTIONAL gegen ein lokales Postgres 16 geprüft (throwaway-Cluster, Stubs für
  `auth.uid()`/`is_venue_staff`): RPC schreibt Legende (Groß-Key→klein, leeres
  Paar weg) und Varianten (leere raus, ungültiges kind→variant) korrekt; Defaults
  `{}`/`[]`; Replace-Semantik und „genau eine aktive Karte" intakt.

### D. Gast-Web zeigt Legende + Varianten (erledigt, verifiziert)

Das Gast-Web (`guest-web/`, Next.js 16, liegt DOCH in diesem Repo) rendert die
neuen Felder jetzt.

- `guest-web/src/lib/allergen-catalog.ts` (neu): Standard-Code→Klartext
  (a–p, 1–14, identisch zur iOS-App) + `resolveAllergens(codes, legend)` —
  Karten-Legende hat Vorrang, Standard-Katalog füllt Lücken, Keys/Codes klein
  normalisiert.
- `menu-loader.ts`: Select um `allergen_legend` (Kategorie) sowie
  `allergen_codes` + `variant_options` (Artikel) erweitert; beim Mappen werden
  die Codes gegen die Kategorie-Legende aufgelöst und die Varianten defensiv
  (leere raus, kind normalisiert) übernommen.
- `venue-data.ts`: `GuestMenuItem` um `allergens` + `variants`; zwei
  Sandbox-Artikel angereichert (Demo).
- `GuestMenuCard.tsx` + `globals.css`: Allergen-Pillen (Code + Klartext) und
  Varianten-/Portions-/Extra-Zeilen unter der Beschreibung.
- **Verifiziert:** typecheck + lint + 71 Vitest-Tests grün (neue Loader- und
  Katalog-Tests); Dev-Render Desktop und Mobile (Badges brechen sauber um);
  Production-Build (SSG `/alte-muehle/menu`) grün. Screenshots zeigen
  „G Milch / Laktose", „A Glutenhaltiges Getreide" usw. + „Portion: Große
  Portion", „Extra: Pommes statt Salat +1,50 €".

Damit ist die Kette Editor/Import → Payload → RPC → DB → Gast-Web durchgängig.

### Offen / nächster Schritt

- **Migration anwenden:** `20260721120000` muss noch auf die Supabase-DB
  gespielt werden (Nutzer-Workflow, SANDBOX_SETUP §6.2); lokal verifiziert, real
  noch nicht angewandt. Erst danach zeigt das Gast-Web bei ECHTEN (statt Sandbox-)
  Karten Legende + Varianten.
### E. Zweisprachige Dubletten entfernt (erledigt, an echten Daten verifiziert)

Ursache aus dem realen Report (Ristorante Italia) belegt: die Karte druckt erst
den kompletten deutschen Teil, dann denselben auf Englisch. Die Sektionstitel
weichen ab („Antipasti - Vorspeisen" vs „Antipasti - Starters"), also führt
`mergeImportedSections` sie nicht zusammen — jedes Gericht doppelt (44 Sektionen,
263 Artikel, ~90 exakte Dubletten).

- Neue `MenuImportService.dropMirroredSections` (in beide LLM-Pfade eingehängt,
  nach Merge/Legende): verwirft eine Sektion, wenn sie ein Spiegel einer früheren
  ist — zwei konservative Signale: (1) exakte Namensgleichheit aller Gerichte
  (kind|Name|Preis); (2) identische Preis-Multimenge (+ kind) ab 5 Gerichten
  (fängt übersetzte Namen wie „Orange juice" = „Orangensaft"). Unter 5 Gerichten
  nur Namens-Signal, damit kleine Sektionen mit zufällig gleichen Preisen (z. B.
  Rot-/Weißweine) NICHT fälschlich verschwinden.
- **Verifiziert an den echten Report-Daten** (Simulation der exakten Logik):
  44→29 Sektionen, 263→159 Artikel (104 Dubletten entfernt), KEINE deutsche
  Sektion fälschlich verworfen (der Weißwein-False-Positive der naiven
  Preisvariante ist durch das ≥5-Gate ausgeschlossen). 5 neue Swift-Unit-Tests
  (beide Signale + Sicherheitsfälle) grün; Suite 216/0/2.
- Rest: wenige kleine (1–2-Artikel-)Übersetzungssektionen bleiben bewusst als
  Dublette stehen (sicherer als Fehl-Löschen); im Review leicht zu entfernen.

### F. Per-Item-Code-Vollständigkeit untersucht — KEIN Bug (Messartefakt)

Statt am Prompt zu drehen, erst an den echten Report-Daten gemessen (16 Karten):
- Die „~51 %" werden von Karten ohne gedruckte Codes gezogen: Alte Kanzlei (0 %),
  hafenrestaurant (4 %), zum-franziskaner (18 %) verweisen im Quelltext
  ausdrücklich auf eine separate Allergiker-Liste („liegt an der Rezeption
  bereit"). 0–4 % sind dort KORREKT.
- Bei code-DRUCKENDEN Karten ~62 %, inkl. legitim code-loser Artikel (Getränke,
  Weine, einfache Gerichte).
- Kreuz-Check an der code-dichtesten Karte (ristorante-italia, 114
  OCR-Code-Zeilen): von 89 Items ohne Code haben nur 6 einen „Code" in der
  Quelle — alle 6 sind False Positives (nachgestelltes „l" = Liter-Einheit, kein
  Allergen „l"). Die KI hat sie KORREKT nicht erfasst. → praktisch KEINE echten
  Drops.

Schluss: das Per-Item-Code-Verhalten ist korrekt und bewusst konservativ. Für ein
Allergen-Feature ist das Erfinden von Codes gefährlicher als Weglassen; ein
Prompt-Push zum Zahlen-Hochtreiben wäre ein Sicherheits-Rückschritt. KEINE
Änderung vorgenommen (Befund dokumentiert).

### G. „Beispielkarte läuft nur lokal" — diagnostiziert (Test-Bug, kein App-Fehler)

Nutzerbeobachtung: Beispielkarte-Import läuft nur lokal. Reproduziert (UI-Probe),
Ursache gefunden: der Code-Default ist korrekt KI-an — auf FRISCH deinstallierter
App zeigt der Demo-Import „KI strukturiert das Menü…" (Probe grün). Mein erstes
„lokal"-Ergebnis war Test-Verschmutzung: `MenuImportReviewHarnessTests` (Zeile
~274) machte `setLLMEnabled(true); defer { setLLMEnabled(false) }` und ließ so den
GETEILTEN UserDefaults-Schalter auf false — ein späterer App-Start im selben
Simulator sah fälschlich „KI aus". Fix: vorherigen Wert sichern und
wiederherstellen. Suite 216/0/2.

Für das Nutzergerät heißt das: entweder veralteter Build (vor `ebca8f3`, wo der
KI-Pfad einen Key brauchte) ODER der KI-Schalter steht auf aus. Lösung: frischen
Build installieren (App vorher löschen → räumt einen evtl. gespeicherten
false-Schalter mit ab); Schalter „KI-Erfassung für Import nutzen" an, Key-Feld
leer (= kostenlose KI).

## Session-Teil 16: KL-SCAN-002 Runde 5 — Vision zuverlässig gemacht

Nutzer-Korrektur (zu Recht): der KI-Pfad soll das Bild direkt analysieren;
die Vision-Timeouts aus Runde 4 waren mein Engineering-Versäumnis, kein
Grund für OCR-only. Behoben:

- **Ursache gemessen:** Vision-Aufrufe dauern real 33–37 s/Seite; die
  `URLSession`-Deckel lagen bei `timeoutIntervalForRequest = 35 s` /
  `resource = 50 s` und schnitten korrekte Antworten ab; Retry (22/26 s) war
  garantiert zu kurz; Seiten liefen seriell.
- **Fix:** URLSession auf 180 s / 300 s, Seiten-Timeouts 150 s, und Seiten
  laufen jetzt PARALLEL (`parseSingleLLMPage` + bounded TaskGroup, max 5
  gleichzeitig). Vision wieder Default im Runner; Set-Menü-Fragmente beseitigt
  (im KI-Modus keine lokalen `unpricedCandidates` mehr).
- **Verifiziert (Vision, kostenlos):** alle Karten vollständig (Lichtburg 7/7
  statt 5/7, Alexxanders 3/4 statt 1/4), Spalten komplett, Set-Menü ein
  Eintrag ohne Reste, Code-Verdacht 0; Suite 207/0. Details:
  `docs/test-fixtures/scanner-benchmark/ROUND_05_FINDINGS.md`.
- **Launch-Default (live, `ebca8f3`, nutzerfreigegeben 21. Juli 2026):** In der
  echten App läuft der Import jetzt OHNE Konfiguration über die kostenlose
  keylose Zen-Vision (big-pickle); ein eigener Key überschreibt das. Sichtbarer
  In-App-Hinweis auf die externe KI-Verarbeitung, Datenfluss in SANDBOX_SETUP
  dokumentiert, OCR-Fallback bei KI-Ausfall (Scan bricht nie ab). Für Produktion
  ist ein verlässlicher/vertraglicher Anbieter statt des anonymen Free-Gateways
  vorzusehen. Persönliche Permission-Regel `git commit`/`git push` in
  `.claude/settings.local.json` gesetzt (autonomes Pushen freigegeben).
- **Nächster Schritt (autonom fortsetzbar):** den echten Menü-Korpus des
  Nutzers über `KITCHENLINK_REVIEW_MENUS=<Ordner> KITCHENLINK_OPENCODE_FREE=1
  ./scripts/run-import-review.sh` fahren und Einzelfehler entlang echter
  Vielfalt schließen.

## Session-Teil 15: KL-SCAN-002 Runde 4 — Vision gemessen, Textmodus als Default

- **Vision funktioniert** (Kontrolltest: weißes Bild → 0 Artikel, Menüseite →
  korrekte Gerichte; `image_tokens` meldet Zen als 0, ist aber nur Reporting).
- **Voller Vergleich:** Vision-Qualität pro Seite minimal besser, aber
  Timeouts (Bild+Reasoning > 26–45 s) brechen die Abdeckung ein (Lichtburg
  5/7, Alexxanders 1/4) gegenüber Textmodus (7/7 bzw. 3/4).
- **Entscheidung:** Textmodus mit Koordinaten-OCR ist der Free-Default
  (`KITCHENLINK_OPENCODE_FREE=1` setzt jetzt `KITCHENLINK_LLM_SEND_IMAGES=0`
  vor); Vision bleibt Opt-in (`=1`). Details:
  `docs/test-fixtures/scanner-benchmark/ROUND_04_FINDINGS.md`.
- **Set-Menü-Reste eingegrenzt:** die preislosen Gang-Fragmente im Draft kommen
  im KI-Modus weiterhin aus `localParseResult.unpricedCandidates` (lokaler
  Parser), nicht aus dem KI-Ergebnis — kosmetisch (preislos, unpubliziert),
  sauberer Fix ist Runde-5-Material.
- **Empfehlung:** guter Zwischenstand nach vier Runden; abnehmender Ertrag.
  Zurück zum Produktfaden (reale Abnahmen KL-MENU-005 §6.2 / KL-CLOUD-001 §6.1,
  Tisch-Kontext im Gast-Web) ist der höherwertige nächste Schritt.

## Session-Teil 14: KL-SCAN-002 Runde 3 — KI-Pfad gehärtet

Auf „mach direkt weiter" die vier offenen Runde-2-Punkte angegangen; die zwei
größten sind gelöst, alle Karten laufen jetzt vollständig durch.

- **Set-/Gang-Menüs:** `LLMItemPayload` um `price_basis` und `courses`
  erweitert; zentraler `llmMenuSystemPrompt` (beide Prompt-Stellen teilen ihn)
  instruiert Menüs als EINEN bepreisten Eintrag mit Gangauflistung + Deckseiten
  überspringen + eine Sprache + Spalten via Koordinaten. `mapLLMSections` webt
  `courses`/`per_person` in die Beschreibung. Ergebnis: „Menü Lichtburg · 39,90
  · Preis pro Person · Vorspeise … Hauptgang (Wahl) … Dessert".
- **JSON-Robustheit:** `repairJSONStringQuotes` um deutsche Anführungspaare
  erweitert (`„…"` mit geradem Schlusszeichen, auch vor Komma) — Scheune 3/3.
  Zusätzlich Retry bei JSON-Fehler im seitenweisen Pfad (fängt die
  Nicht-Determinismus-Varianz freier Modelle; Alexxanders S4).
- **Verifikation:** alle 3 Karten vollständig (Scheune 3/3, Lichtburg 7/7,
  Alexxanders 3/4 + 1 leere Deckseite); Scheune Code-Verdacht lokal 16 → KI 0;
  5 JSON-Repair-Unit-Tests; komplette `kitchenlinkTests`-Suite 207/0.
- **Offen (Runde 4, abnehmender Ertrag):** vereinzelte preislose
  Set-Menü-Gang-Reste (needsReview, unpubliziert), Streupreise,
  Kategorienschnitt, Vision-Modus ungetestet, Rest-Nichtdeterminismus. Details
  in `docs/test-fixtures/scanner-benchmark/ROUND_03_FINDINGS.md`.

## Session-Teil 13: KL-SCAN-002 Runde 2 — KI-Pfad läuft, schlägt Regel-Parser klar

### Schlüsselbefund zum Gateway

Der Key des Nutzers war die ganze Zeit **ungültig** (`401 AuthError`), nicht
guthabenlos — Aufladen half nicht. Direkter curl-Test bewies: OpenCode Zen
bedient `/models` UND `/chat/completions` **ohne jede Auth** für die
Free-Modelle (`cost: 0`, `is_byok: true`). `big-pickle` → `xiaomi/mimo-v2.5`
kann Text und Vision. Damit braucht der Free-Vergleich gar keinen Key.

### Umgesetzt (Client + Runner)

- **Keyloser Free-Zugang:** `resolvedLLMAPIKey` gibt bei
  `KITCHENLINK_LLM_ALLOW_KEYLESS=1` einen Sentinel zurück; `runLLMMenuCall`
  sendet dann KEINEN `Authorization`-Header (falscher Key → 401, kein Key →
  freier Zugang). Runner-Ein-Schritt: `KITCHENLINK_OPENCODE_FREE=1`.
- **Reasoning-Modelle:** Antwort aus `content` mit Fallback auf `reasoning`;
  `max_tokens: 8000`.
- **JSON-Reparatur** `repairJSONStringQuotes` (Ein-Durchlauf-Automat) für
  unescapte Anführungszeichen in Werten (`"Wurstsalat „Scheune""`), nur als
  Fallback nach striktem Parse. 3 Unit-Tests.
- **Teilergebnisse:** leere Seiten (Deckseiten) verwerfen die Karte nicht mehr;
  die „alle Seiten müssen klappen"-Regel ist aufgehoben, gescheiterte
  Einzelseiten werden als Teilfehler gemeldet.

### Verifiziertes Ergebnis (Eigenverifikation gegen Roh-OCR)

KI schlägt den Regel-Parser bei allen Runde-1-Befunden: Allergen-Codes
getrennt (Scheune 16→0 Einträge mit Codes im Text), verlorene
Beschreibungszeile wieder da, Lichtburg-S5-Beilagenspalte erfasst,
Alexxanders-Deckseite übersprungen (kein Phantom „Gastgeber"),
Überraschungsmenü-Beschreibung vorhanden. Vollständige Tabelle und die
verbliebenen Lücken (Set-/Gang-Menüs, `per_person`, ein weiterer JSON-Fehler
auf Scheune S3, Bild-Modus noch ungetestet) in
`docs/test-fixtures/scanner-benchmark/ROUND_02_FINDINGS.md`. Gesamte
`kitchenlinkTests`-Suite: 206 bestanden, 0 Fehlschläge.

### Nächster Schritt

Runde 3: Prompt/Mapping um Gang-/Bundle-Menüs und Preisbasis erweitern,
Scheune-S3-JSON diagnostizieren, Vision- gegen Textmodus messen, bestätigte
Ergebnisse als Gold-Anker sichern. Nutzer kann den fertigen Report unter
`/tmp/kitchenlink-import-review/latest/index.html` selbst durchsehen und je
Pipeline (Umschalter „Lokale Regeln / KI-Pfad") Feedback exportieren.

## Session-Teil 12: KL-SCAN-002 Runde 1 — Feedback ausgewertet, KI-Vergleich vorbereitet

### Anlass

Der Nutzer lieferte den ersten Feedback-Export aus dem Review-Report und
ruegte zu Recht, dass ich die Erkennungsergebnisse nicht selbst vollstaendig
verifiziert hatte, bevor ich sie vorlegte (die Lichtburg-Menueseite und die
Alexxanders-Deckseite haette ich selbst finden muessen). Prozessaenderung ist
jetzt bindend in `QUALITY_TARGETS.md` §2: kein Lauf ohne eigene, vollstaendige
Befundliste des Agenten.

### Umgesetzt

- **Vollstaendige Eigenverifikation nachgeholt** (jede Seite gegen die
  Roh-OCR): alle Nutzerbefunde bestaetigt und mit Ursachen belegt in
  `docs/test-fixtures/scanner-benchmark/ROUND_01_FINDINGS.md`. Kernbefund:
  Die OCR verliert praktisch nichts — die „wahlweise"-Zeile, beide
  Beilagen-Spalten (mit x-Koordinaten), die komplette Menuestruktur inkl.
  „oder/or"-Wahl und „pro Person: 39,90"/„55€" stehen alle im Rohtext. Der
  Regel-Parser ist der Engpass: Spalten landen in verschleppten Sektionen,
  das Set-Menue zerfaellt in 3 Fragmente (Tiramisu bekommt einen Preis von
  einer anderen Seite), die Deckseite wird zum Phantomartikel „Gastgeber",
  EN-Zeilen werden dupliziert, `per_person` wird nie gesetzt, obwohl das
  Draft-Modell es kann.
- **QUALITY_TARGETS.md erweitert** um die neuen Anforderungen aus dem
  Feedback: Set-/Gang-Menues als Bundle, eine Sprache + optionales EN im
  Gast-Web (Folgeticket), Deckseiten ueberspringen, Warnung bei Codes ohne
  Legende, vegetarisch/vegan strukturiert + Icon-Folgeticket, Optionen bis
  ins Produkt wirklich waehlbar, `per_person`-Preisbasis.
- **KI-Vergleichsmodus in der Review-Umgebung:** Der Harness laeuft auf
  Wunsch (`runLLM` in der Request-Datei) zusaetzlich ueber den vorhandenen
  KI-Pfad (`MenuImportService.importMenu` mit aktiviertem LLM; Fehler landen
  ehrlich als `llmError` im Report statt den Lauf abzubrechen). Das
  Runner-Skript aktiviert das automatisch, wenn `KITCHENLINK_OPENAI_API_KEY`
  gesetzt ist (Key geht NUR als TEST_RUNNER_-Umgebungsvariable in den
  Testprozess, nie in eine Datei). Der Report zeigt dann pro Karte einen
  Umschalter „Lokale Regeln / KI-Pfad"; Feedback-Schluessel der KI-Ansicht
  tragen ein `llm::`-Praefix, damit die Urteile getrennt bleiben.

### Verifikation

- Harness kompiliert (build-for-testing gruen); Gate-Skip unveraendert.
- Report-Umschalter im Browser verifiziert — mangels API-Key mit simulierten
  KI-Daten per JS-Injektion: ohne KI-Daten kein Umschalter, mit Daten
  korrekte KI-Ansicht, Diagnosezeile, getrennte `llm::`-Feedback-Schluessel,
  Rueckschalten intakt. Der echte KI-Lauf selbst konnte ohne Key nicht
  ausgefuehrt werden — das ist genau der offene Runde-2-Schritt.
- Zwischenfall, behoben: Beim Testen wurde das localStorage-Feedback des
  Nutzers geloescht; es wurde sofort aus dem vorliegenden Export
  byte-genau wiederhergestellt und die Wiederherstellung im Report
  verifiziert (7×OK, 2×Falsch, 4 Notizen bei Scheune sichtbar).

### Naechster Schritt

1. **Nutzer-Entscheidung gefallen (20. Juli): OpenCode-Zen-Key, und zwar
   NUR Free-Modelle.** Der erste Lauf des Nutzers bewies: Key gueltig
   (`/models` liefert 24 Modelle inkl. big-pickle und fuenf `*-free`),
   aber `claude-sonnet-5` scheiterte mit `CreditsError: Insufficient
   balance` (Bezahlmodell ohne Guthaben; im Report als `invalidAPIKey`
   gemappt). Umsetzung der Free-Vorgabe: OpenCode-Standardmodell im Runner
   ist jetzt `big-pickle`; `KITCHENLINK_LLM_SEND_IMAGES=0` schaltet den
   Bild-Versand fuer Text-only-Modelle ab (der OCR-Dump traegt Seite +
   x/y-Koordinaten, der Primaer-Prompt weist das Modell im Textmodus
   explizit darauf hin); `check-llm-gateway.sh` testet alle Free-Modelle
   automatisch auf Text- und Vision-Faehigkeit (winziges rotes Testbild)
   und druckt den fertigen Review-Befehl. Offen: Nutzer fuehrt
   `KITCHENLINK_OPENCODE_API_KEY=… ./scripts/check-llm-gateway.sh` aus
   (Ergebnisse landen in /tmp, der Agent liest sie selbst), dann der
   empfohlene Review-Lauf.
2. Danach Vergleichslauf, Eigenverifikation (Pflicht), dann gezielte
   Haertung des KI-Pfads entlang der Zielliste; der Regel-Parser bleibt
   Offline-Fallback.
3. Unveraendert offen: reale Abnahmen KL-CLOUD-001 (§6.1) und KL-MENU-005
   (§6.2).

## Session-Teil 11: KL-SCAN-002 — Import-Review-Umgebung

### Anlass und Scope

Nach KL-MENU-005 stellte der Nutzer klar, dass die Erkennungsqualitaet selbst
nie verifiziert wurde (stimmt — mein Ticket verifizierte nur den
Publish-Transport; die Scanner-Luecken sind in `CURRENT_RESULTS.md`
dokumentiert) und forderte einen mehrstufigen Optimierungs-Workflow mit
qualifiziertem Input/Output-Vergleich ueber viele Speisekarten — plus eine
eigene Umgebung, damit die Pruefung nicht in Dutzenden Einzelimporten am
iPhone stattfinden muss. Diese Session baut die Umgebung; Parser-Fixes
beginnen bewusst erst mit dem ersten Feedback (Runde 1).

### Umgesetzt

- **`docs/test-fixtures/scanner-benchmark/QUALITY_TARGETS.md`:** die
  Nutzeranforderungen als verbindliche Zielliste — Kategorien aus
  Kartentiteln; Artikel mit Varianten/Optionen/Groessen und Beschreibungen;
  strukturierte Allergen-Zuordnung ueber die Karten-Legende (einheitliche
  Icons in der UI als eigenes Folgeticket); harte Regel: Legende-Codes nie in
  Name oder Beschreibung; Preise nur echt zugeordnet, nie erfunden. Dazu der
  Runden-Workflow (Lauf -> Nutzer-Feedback -> Parser-Fix + Gold-Anker ->
  Nachweis).
- **`kitchenlinkTests/MenuImportReviewHarnessTests.swift`:** gegateter
  Batch-Export (Gate: `ImportReviewRequest.json` im App-Bundle, gleicher
  Mechanismus wie der Benchmark). Jagt alle Demo-Fixtures und optional
  beliebige eigene Karten (PDFs per CGPDFDocument mit ~2000 px gerendert;
  Bild-Unterordner alphabetisch) durch `MenuImportService.benchmarkLocalImport`
  (LLM aus, deterministisch) und schreibt Seiten-PNGs (orientierungs-
  normalisiert) plus `report.json`: Draft-Sektionen/-Eintraege mit Name,
  Beschreibung, Offers, Evidenz (Seite, Bounding Box, located, Methode),
  Deklarationen, Optionsgruppen, Mengen; Legacy-Konvertierung (inkl.
  `displayName` zur Code-im-Namen-Erkennung); Roh-OCR-Zeilen;
  Draft-Validierungsfehler. Bewusst KEINE Qualitaets-Assertions — Regression
  bleibt Sache des Gold-Benchmarks.
- **`scripts/run-import-review.sh` + `scripts/import-review-report.html`:**
  Runner (build-for-testing, Konfiguration ins Bundle, Test, Report-Bau,
  `latest`-Symlink, oeffnet Browser; `KITCHENLINK_REVIEW_MENUS=<Ordner>` fuer
  eigene Karten) und statischer HTML-Report (Daten als `report.js`-Script,
  damit file:// ohne Server funktioniert): Karten-Tabs; pro Seite links das
  Original mit Overlays (Name durchgezogen, Preis gestrichelt; Hover hebt
  hervor), rechts die Eintraege mit automatischen Markierungen (ohne Preis,
  zu klaeren, ohne Fundstelle, Codes im Namen/Beschreibung — Heuristik fuer
  nachgestellte UND eingebettete Code-Gruppen wie `-A,G,)-` oder
  `Gulaschsuppe-A,G,l,-`, Kommapflicht schuetzt Komposita und Mengen —,
  ohne Beschreibung, erkannte Allergene); OK/Falsch + Notiz pro Eintrag und
  Fehlend-Feld pro Seite (localStorage pro Lauf); „Feedback exportieren"
  laedt `import-review-feedback.json` herunter und kopiert es in die
  Zwischenablage. Dazu Veroeffentlichungs-Vorschau (Legacy-Tabelle) und
  Roh-OCR pro Seite als Aufklapper.

### Verifikation

- Kompletter Lauf: Build + 14 Seiten echte Vision-OCR in 48 s, Test gruen,
  `report.json` mit 3 Karten / 105 Draft-Eintraegen / 0 Validierungsfehlern.
- Report im Browser (ueber lokalen HTTP-Server, da die eingebaute
  Tool-Vorschau file://-Nachbardateien nicht laedt — in echtem Safari/Chrome
  laeuft file:// direkt): Overlays sitzen auf den richtigen Zeilen, Tabs,
  Hover-Hervorhebung, OK/Falsch-Zustand + Notiz persistiert in localStorage,
  Zaehler plausibel. Querschnitt gegen den dokumentierten Stand: exakt 7
  preislose Lichtburg- und 2 Alexxanders-Kandidaten erscheinen als
  „ohne Preis"/„zu klaeren".
- **Echte Befunde aus dem ersten Lauf (bestaetigen den Nutzereindruck):**
  Scheune hat 14 Eintraege mit Legende-Codes in der Beschreibung und einen im
  Namen (`Grosse Hausgemachte Gulaschsuppe-A,G,l,-`); Beschreibungsfragmente
  werden teils doppelt angehaengt (deutsch/englisch bzw. OCR-Zeilendopplung);
  OCR verwechselt `)`/`J` und `l`/`1` in Code-Gruppen; Beschreibungen tragen
  `#`-Trennzeichen aus dem Parser. Alexxanders faellt mit 26/27
  `needsReview`-Eintraegen auf. Alles Runde-1-Material, bewusst noch nicht
  gefixt.

### Risiken / bewusste Grenzen

- Die automatischen Markierungen sind Heuristiken zur Aufmerksamkeitslenkung
  (z. B. schlagen additive Ziffern-Codes wie `1,2` derzeit nicht an); das
  Urteil faellt der Mensch im Report.
- Der Report zeigt die lokale Pipeline ohne LLM — identisch zum Benchmark,
  damit Runden vergleichbar bleiben.
- Feedback liegt in localStorage des Browsers pro Lauf; der Export ist der
  Uebergabeweg. Kein Server, keine Persistenz im Repo.

### Naechster Schritt

1. **Nutzer:** `./scripts/run-import-review.sh` ausfuehren (oder den bereits
   erzeugten Lauf unter `/tmp/kitchenlink-import-review/latest/index.html`
   oeffnen), Karten durchgehen, Feedback exportieren und uebergeben. Gern
   zusaetzlich echte Karten ueber `KITCHENLINK_REVIEW_MENUS=<Ordner>`.
2. **Agent (Runde 1):** Feedback in Parser-Fixes + Gold-Baseline-Anker
   uebersetzen; die bereits sichtbaren Befunde (Codes in Text, doppelte
   Fragmente, `#`-Artefakte) sind der erste Arbeitsvorrat.
3. Parallel bleiben die realen Abnahmen KL-CLOUD-001 (§6.1) und KL-MENU-005
   (§6.2) offen.

## Session-Teil 10: KL-MENU-005 — Scan-zu-Publish-Bruecke

### Anlass und Scope

Der Nutzer hat aus den moeglichen naechsten Schritten die Scan-zu-Publish-
Bruecke gewaehlt (Marktanalyse §5.2). Befund: Der Menuescan war bisher nur
mit dem lokalen Sandbox-Menue verdrahtet (`store.replaceMenu`); die zweite
Haelfte des Kern-Pitches — gescannte Karte wird fuer Gaeste im Gast-Web
bestellbar — fehlte. Diese Scheibe schliesst das.

### Umgesetzt

- **Migration `supabase/migrations/20260719200000_operator_publish_menu.sql`**
  (additiv, aendert keine bestehende Tabelle/Policy/Funktion): SECURITY-DEFINER-
  RPC `operator_publish_menu(p_venue_slug, p_menu jsonb)`, staff-gated ueber
  `is_venue_staff` (gespiegelt zu KL-CLOUD-001). Sie **ersetzt die aktive Karte
  der Venue vollstaendig** (kein Merge, exakt wie die lokale Uebernahme),
  garantiert genau eine aktive Karte pro Venue und lehnt doppelte
  `menu_items.slug` in der Nutzlast ab — das ist die lastende Invariante des
  Bestell-Gates (`guest_web_submit_order` loest Artikel ueber den Slug auf).
  Das Loeschen der Kategorien kaskadiert auf `menu_items`; historische
  `order_items.menu_item_id` fallen per FK auf NULL, Name/Preis bleiben als
  Snapshot in `order_items`. `tag` und `variant_options` werden bewusst nicht
  geschrieben (erster Schnitt; Gastkarte und Bestell-Gate nutzen beides derzeit
  nicht) — als Folgearbeit dokumentiert.
- **App, neu `KitchenLinkMenuPublishClient.swift`:** reiner, testbarer
  Nutzlast-Bau `KitchenLinkMenuPublishPayload.build(from: [MenuSectionData])`
  mit deutscher Slug-Erzeugung (ä→ae, Diakritika entfernt, Nicht-Alphanumerik →
  Bindestrich) und deterministischer Deduplizierung (`-2`, `-3`, …); nutzt
  `item.displayName` (Allergen-Codes werden vom Namen getrennt und separat als
  Array uebergeben). `KitchenLinkMenuPublishModel` (@MainActor) veroeffentlicht
  mit einer bestehenden Betreiber-Sitzung oder meldet mit vertrauten
  Zugangsdaten an; genau-einmaliger 401-Refresh und tote-Sitzung-Abmeldung wie
  im Cloud-Bestellmodell.
- **App, umgebaut `KitchenLinkCloudOrderClient.swift`:** schmales
  `KitchenLinkCloudAuthenticating`-Protokoll (nur signIn/refresh) aus
  `KitchenLinkCloudTransport` herausgezogen — bestehende Konformer (URLSession-
  Transport, Test-Spy) erfuellen es transparent weiter. `rpc` teilt sich jetzt
  einen `rpcData`-Helfer, damit die Publish-RPC einen verschachtelten
  `p_menu`-Encodable-Body senden kann. `URLSessionKitchenLinkCloudTransport`
  erfuellt zusaetzlich `KitchenLinkMenuPublishTransport`.
- **App, neu `MenuPublishSheet.swift` + Aktion im Draft-Review:** Im
  unlocked-Zustand des Review-Screens gibt es neben „In Sandbox-Menue
  uebernehmen" jetzt „Online veroeffentlichen" (`draftReview.publishOnline`).
  Das Sheet zeigt, was online geht, meldet bei Bedarf mit **nur** E-Mail +
  Passwort an (Usability-Leitplanke: keine technischen Verbindungsfelder),
  warnt explizit vor dem vollstaendigen Ersetzen und bestaetigt mit der
  Live-URL `kitchenlink.luneq.eu/alte-muehle/menu`.

### Verifikation

- App-Target-Build fuer iPhone-17-Pro-Simulator: **BUILD SUCCEEDED**.
- Komplettes `kitchenlinkTests`-Target: **0 Fehlschlaege** (xcodebuild meldet
  202 „passed"-Zeilen inkl. des ueblichen Swift-Testing-Doppelreportings). Die
  11 neuen Publish-Tests: Slugify (Umlaute/Diakritika/Separatoren/Fallback),
  Payload-Bau (Dedup, Kind-/Allergen-Mapping, leere Sektion faellt weg,
  displayName ohne Codes) und das Model gegen einen Transport-Spy (gespeicherte
  Sitzung, Anmeldung-dann-Publish, genau-einmaliger 401-Refresh mit Retry, tote
  Sitzung → Abmeldung, leere Zugangsdaten ohne Netz).
- **Nicht ohne Nutzer verifizierbar:** Die RPC-SQL lief nicht gegen echtes
  Postgres — dieselbe Grenze wie bei KL-WEB-002 und KL-CLOUD-001. Es gibt hier
  keine Instanz-Credentials. Aufzuloesen durch die reale Abnahme.

### Risiken / bewusste Grenzen

- **Vollstaendiger Ersatz statt Merge:** Ein veroeffentlichter Scan loest die
  gesamte aktive Karte ab, inklusive des eingebauten 8-Artikel-Sandbox-Seeds.
  Das ist bewusst (der Scan IST die Karte), aber ein spaeteres Ticket sollte
  additive Kartenpflege ermoeglichen.
- **Slug-Stabilitaet ueber Re-Publish:** Slugs werden bei jedem Publish neu aus
  den Namen erzeugt. Aendert sich ein Name, aendert sich der Slug; alte,
  bereits geoeffnete Gast-Tabs koennten dann `guest_web_unknown_item` sehen.
  Fuer die Sandbox unkritisch; vor Produktion ist stabile Slug-Zuordnung zu
  bedenken.
- **Sitzung** liegt weiter in UserDefaults (nicht Keychain), geteilt mit
  KL-CLOUD-001 — dieselbe dokumentierte Sandbox-Grenze.
- `tag`/`variant_options` gehen noch nicht mit; Allergencodes schon.

### Naechster Schritt (Nutzer)

1. Migration `20260719200000_operator_publish_menu.sql` anwenden
   (SANDBOX_SETUP.md Abschnitt 2).
2. In der App eine Karte scannen, im Draft-Review klaeren, „Online
   veroeffentlichen" waehlen (SANDBOX_SETUP.md §6.2), dann
   `kitchenlink.luneq.eu/alte-muehle/menu` im Browser pruefen.
3. Danach ist der Kern-Pitch erstmals durchgaengig vorfuehrbar; sinnvolle
   Folgeschritte: Tisch-Kontext im Gast-Web (QR mit Tischparameter) und die
   Payment/TSE-Provider-Vorentscheidung als Papieraufgabe.

## Session-Teil 9: Konsolidierung auf main + Aufraeumen (19. Juli, Abend)

- **Merge 1:** `claude/cloud-order-loop` → `main` (`f304d30`), auf
  Nutzeranweisung ohne separate Abnahme vorab; die reale Abnahme bleibt als
  offener Schritt in der Queue.
- **Merge 2:** `codex/local-hub-discovery` → `main` (`1f236a0`),
  KL-OFFLINE-008. Konflikte in `WORK_QUEUE.md` (beide Eintraege behalten)
  und `KitchenLinkV2LocalOperationsView.swift` manuell aufgeloest: Codex'
  leichter Startup-Wrapper, Bonjour-Discovery im „Anderen Hub
  verwenden"-Aufklapper und asynchrone QR-Erzeugung wurden in die
  vereinheitlichte Service-Ansicht (Cloud + Lokal) eingewoben. Codex' neuer
  UI-Test wurde auf die gemergten Titel („Service", „LOKALER FALLBACK AUF
  DIESEM IPHONE") angepasst.
- **Branch-Hygiene:** alle nicht in `main` enthaltenen Branch-Spitzen als
  `archive/<branch>`-Tags gepusht (15 Stueck). Remote-Branches wurden noch
  NICHT geloescht — bewusst erst nach expliziter Nutzerbestaetigung, weil
  fremde Branches betroffen sind.
- **Doku:** `docs/strategy/MARKET_ASSESSMENT_2026-07-19.md` neu (Analyse
  vom Sessionanfang, als Referenz fuer spaetere Priorisierung);
  `DECISIONS.md` +2 (Usability-Leitplanke, Main-Only-Modus);
  `PEER_WORKFLOW.md` als teilweise ueberholt markiert; CURRENT/WORK_QUEUE
  nachgezogen.
- **UI-Aufraeumen (Usability-Leitplanke):** V2-Home zeigt nur noch die
  Produktwege; „Bestehende Produktsandbox" und der Legacy-Design-Schalter
  liegen eingeklappt hinter „Entwicklung & Demo"
  (`business.devTools`; beide UI-Tests expandieren jetzt zuerst). In der
  Service-Ansicht stehen die Bestellungen direkt nach dem Moduswechsler;
  Cloud-/Hub-Statuskarten folgen darunter (nur der einmalige Login bleibt
  oben, solange abgemeldet).

## Session-Teil 8: KL-CLOUD-001 — Cloud-Bestellschleife + Lokal-Fallback

### Anlass und Scope

Der Nutzer bestaetigte den Befund, dass sein erfolgreicher Test auf
`kitchenlink.luneq.eu` nur die Gast-Haelfte bewies: Bestellungen landeten in
Supabase, aber keine Betreiberoberflaeche las sie (einzige Lese-Policy war
`orders_owner_read` fuer den Gast selbst; der einzige Supabase-Code der App
zeigte auf ein altes hartkodiertes Projekt und haette an RLS scheitern
muessen). Zusaetzliche Nutzeranforderung: kein manuelles Vorauswaehlen von
„Lokaler Service" mehr — der lokale Weg soll den Online-Weg automatisch
ersetzen, wenn die Verbindung fehlt, und das Gast-Web soll Gaeste dann von
sich aus auf die lokale Bestellseite verweisen („kindergartenleicht").

### Umgesetzt

- **Migration `supabase/migrations/20260719100000_operator_cloud_orders.sql`**
  (additiv, aendert keine bestehende Policy/Funktion): `venue_staff` mit
  RLS-Selbstsicht und ohne Client-Schreibpfad; `is_venue_staff()` als
  SECURITY-DEFINER-Helfer; Staff-Lese-Policies auf `orders`/`order_items`
  zusaetzlich zu den Owner-Policies; `operator_update_order_status`
  (Staff-Pflicht, Vorwaertskette `pending→accepted→preparing→ready→served`
  auch ueber mehrere Stufen — die Kueche hat einen einzigen Bump-Button —,
  Ziel==Ist und verspaetete Retries als Replay, `served→canceled` und alles
  ab `canceled` als Fehler, Zeitstempelspalten wandern mit);
  `venue_hub_presence` (eine Zeile pro Venue, oeffentlich lesbar, Schreiben
  nur ueber `operator_upsert_hub_presence` mit Staff-Pflicht).
- **App, neu `kitchenlink/Features/CloudOperations/`:**
  `KitchenLinkCloudOrderClient.swift` (Config ohne hartkodierte URL/Keys,
  GoTrue-Passwort-/Refresh-Flow, PostgREST-Reads mit embedded
  `order_items`, beide RPCs, Fehler-Mapping inkl. 401→unauthorized),
  `KitchenLinkCloudOperationsModel.swift` (3-s-Polling, genau-einmaliger
  Refresh-Retry bei 401 — ein totes Refresh-Token meldet GoTrue als 400,
  wird als Abmeldung behandelt —, 15-s-Heartbeat mit aktueller lokaler
  Hub-URL, Raeumen der URL beim geordneten Verlassen/Hintergrund),
  `KitchenLinkServiceOrderMerge.swift` (testbare Zusammenfuehrung).
  Wire-Zeilen mit unbekanntem Status/Zeitstempel werden verworfen statt
  geraten; das Mapping fuehrt in die bestehende `LiveOrderMessage`-Domaene,
  kein zweites Bestellmodell.
- **App, umgebaut:** `KitchenLinkV2LocalOperationsView.swift` heisst in der
  Navigation jetzt `Service` (Home-Zeile angepasst, Accessibility-IDs
  unveraendert): eine Kuechen-/Kellner-Liste fuer Online- und lokale
  Bestellungen (aelteste zuerst; online startet `pending`, lokal
  `preparing`), Verbindungsbadge ONLINE/LOKAL/OFFLINE, lokaler Hub laeuft
  unveraendert immer mit und traegt den Titel „Lokaler Fallback". Der
  Mac-Hub-Fallback und alle bisherigen Ablaeufe bleiben erhalten.
- **Vereinfachte Anmeldung (Nachtrag nach Nutzerfeedback „kein Nutzer will
  sich so kompliziert anmelden"):** URL, Anon-Key und Venue sind jetzt fest
  eingebacken (`KitchenLinkCloudConfig.sandboxDefault` — die oeffentlichen
  Gast-Web-Werte des Nutzer-Supabase-Projekts `rjxlzqtaxqstctrrlqre`). Das
  fruehere 5-Felder-DisclosureGroup ist weg; die Cloud-Karte zeigt im
  abgemeldeten Zustand direkt **nur E-Mail + Passwort** und einen prominenten
  Knopf „Online-Service aktivieren". `signIn` nimmt nur noch `email/password`;
  das Model haelt `config` als eingebackene Konstante, der Credential-Store
  persistiert ausschliesslich die Sitzung. Der Anon-Key ist oeffentlich
  (wird ohnehin an jeden Browser ausgeliefert), daher unbedenklich im Repo;
  ein baked-in Passwort/Service-Key wurde bewusst NICHT eingecheckt.
- **Gast-Web:** `src/lib/hub-presence.ts` (reine, getestete Auswertung:
  frisch ≤45 s → online; veraltet + sanitisierte http(s)-URL →
  `local_fallback`; alles andere → `unknown` = heutiges Verhalten, damit
  Venues ohne Presence-Zeile unveraendert funktionieren) plus Einbindung in
  `GuestMenuCard.tsx` (20-s-Poll nur im Browser): Warte-Hinweis-Karte,
  Bestellleiste wird zum Link auf die lokale Bestellseite, Sheet-Submit
  gesperrt mit Inline-Link. Neue CSS-Klassen in `globals.css` nur aus
  bestehenden Tokens; Status ohne Zitrone, die Zitronen-Leiste bleibt die
  Primaeraktion.

### Verifikation

- Gast-Web: `typecheck`, `lint` sauber; **63/63 Vitest** (13 neue
  Presence-/Sanitizing-Tests); `next build` gruen, `/[venueSlug]/menu`
  weiter `Revalidate 1m`. Browser mobil 375×812: Normalzustand
  byte-gleichem Verhalten (kein Banner, Leiste als Button), Fallback-Zustand
  temporaer erzwungen und visuell geprueft (Banner, Leisten-Link, beide
  Links auf die lokale URL), danach zurueckgesetzt und erneut 63/63.
- iOS: Test-Build gruen; **12 neue Tests** in
  `KitchenLinkCloudOperationsTests` (Wire-Mapping, Zeitstempel-Varianten,
  401-Refresh-genau-einmal, tote-Session-Abmeldung, Venue-not-found,
  Heartbeat-Inhalt inkl. Raeumen, Kuechen-/Kellner-Merge); komplettes
  `kitchenlinkTests`-Target **186 bestanden / 0 fehlgeschlagen / 1 bewusst
  uebersprungen** (iPhone-17-Pro-Simulator).
- Nicht verifizierbar ohne Nutzer: Migration und Betreiber-Konto existieren
  nur als Dateien/Anleitung — es gibt hier keine Instanz-Credentials. Die
  RPC-SQL lief nicht gegen ein echtes Postgres; dieselbe Grenze wie bei
  KL-WEB-002, aufzuloesen durch die reale Abnahme.

### Risiken / bewusste Grenzen

- Sitzung (Access-/Refresh-Token) liegt in UserDefaults, nicht Keychain —
  Sandbox-Grenze, vor Produktion zu ersetzen; das Passwort selbst wird nie
  gespeichert.
- Presence kann nicht zwischen „App offline weiterlaufend" und „App
  waehrend Offline-Phase geschlossen" unterscheiden; der lokale Verweis
  kann dann ins Leere zeigen (im Code und in SANDBOX_SETUP dokumentiert).
- Kein Realtime, bewusst Polling (3 s) analog zum lokalen Hub; kein
  Gast-Status-Web nach dem ACK (Folgeticket); `canceled` ist per RPC
  moeglich, hat aber noch keine UI.
- Der Kuechenfilter zeigt auch alte `pending`-Testbestellungen der echten
  Instanz — gewollt (Backlog sichtbar, per Bump raeumbar).

### Naechster Schritt (Nutzer)

1. Migration anwenden + Betreiber-Konto anlegen: `SANDBOX_SETUP.md` §6.1.
2. Branch `claude/cloud-order-loop` frisch aufs iPhone bauen (der Menuepunkt
   muss `Service` heissen, nicht mehr `Lokaler Service`). Dort in der
   Cloud-Karte nur E-Mail + Passwort des Betreiber-Kontos eingeben und
   „Online-Service aktivieren". Dann auf dem Handy ueber
   `kitchenlink.luneq.eu/alte-muehle/menu` bestellen → Bestellung muss in
   der Kueche erscheinen und bis `serviert` laufen.
3. Internet des iPhones trennen (WLAN ohne Uplink oder Hotspot aus) →
   Gast-Web muss nach ~1 min den lokalen Hinweis zeigen.
4. Nach bestandener Abnahme: Branch `claude/cloud-order-loop` mergen.

---

# Historie (bis 18 July 2026)

**Branch damals:** `main` (Integrationsarbeit); KL-WEB-001 gemergt aus
`claude/guest-web-foundation`
**Status damals:** Alle vier Runde-2-Missionen (KL-OFFLINE-003, KL-WORKFORCE-001,
KL-WEB-002, KL-INVENTORY-001) reviewt und in `main` integriert, keine P0/P1.
Zwei echte Funde waehrend der Integration behoben (KL-WORKFORCE-001,
KL-WEB-002), eine Design-Frage bei KL-INVENTORY-001 genau nachverfolgt statt
ungeprueft als Bug behandelt. Danach die Offline-Venue-Hub-Discovery reviewt
und mit einer Integrationslesart nach `main` gebracht. ADR-001 nachtraeglich
nach `main` gebracht, da GLMs frischer Mission-Branch sie sonst nicht im
Arbeitsbaum gehabt haette. KL-WEB-001-Fundament umgesetzt, gegen die visuelle
Claude-Design-Referenz korrigiert, verifiziert und gemergt. Zuvor am selben
Tag: PR #5/#6/#9 reviewt und integriert sowie die vier KL-WEB-001-
Entscheidungen des Nutzers in `DECISIONS.md` dokumentiert.

## Session-Teil 7: Review Offline-Venue-Hub-Discovery

### Scope

Die beiden zuletzt offenen, ungereviewten Branches
(`deepseek/offline-venue-hub-review` als Superset, `glm/offline-venue-hub`)
gelesen und als Discovery eingeordnet. Kein Produktcode, keine Freigabe.

### Vorgehen und Befund

- Alle fuenf Discovery-Dokumente vollstaendig gelesen (GLM-Architektur +
  Quellen, DeepSeek-Red-Team, Stage-1-Event-Log-Contract, Netzwerk-POC).
- Die fuenf Dokumente verbatim aus dem Branch extrahiert und unter
  `docs/discovery/offline-venue-hub/` nach `main` gebracht — nur diese
  Dateien, **nicht** den ganzen Branch (dessen Handoff-Versionen sind
  veraltet und wuerden den aktuellen Stand regressieren; gleiche Methode wie
  bei der ADR-001-Extraktion).
- Eigene Integrationslesart `INTEGRATION_REVIEW.md` geschrieben (analog zur
  Taxonomie-`INTEGRATION_REVIEW.md`), die drei Dinge festhaelt:
  1. **Stage 1 ist faktisch bereits gebaut** — der gemergte
     KL-OFFLINE-003-Prototyp deckt genau den Teil ab, dem DeepSeek als
     einzigem ein bedingtes Go gab. Die Entwuerfe konvergieren im Prinzip,
     divergieren in der Umsetzung (eigenes SQLite vs. GRDB; der Prototyp ist
     auf der Abhaengigkeitsachse die staerkere Wahl). Offen bleibt die
     iOS-Integrationsnaht (`LocalDemoRepository` hinter
     `KitchenLinkRepository` ablösen).
  2. **Der netzwerkseitige Hub-Teil kollidiert mit KL-WEB-002.** DeepSeeks
     staerkster P0: ein cloud-first per HTTPS ausgeliefertes Gast-Web kann
     einen lokalen HTTP-Hub nicht per `fetch` erreichen (Mixed Content +
     Chrome Local Network Access). Die Offline-Gastbestellung aus Blueprint
     §16.2 ist damit eine echte Produkt-/Architekturweggabelung, kein
     Implementierungsdetail.
  3. Belastbare Prinzipien (Event Sourcing statt CRDT, ACK-nach-Commit,
     Transactional Outbox, „messen statt annehmen") sind uebernehmbar; die
     P0-Netzwerkrisiken und Failover-Fragen bleiben Nutzer-/Messentscheidung.
- Keine `DECISIONS.md`-Aenderung. WORK_QUEUE und CURRENT.md nachgezogen.

## Session-Teil 6: Review und Integration KL-WEB-002 und KL-INVENTORY-001

### Scope

Nutzer meldete beide Missionen als fertig. Beide reviewt, ein Fund pro
Ticket behandelt (einer behoben, einer bewusst nicht), beide gemergt.

### Review-Ergebnis KL-WEB-002 (GLM, `glm/guest-web-order-gate`)

- Branch war 4 Commits hinter `main`; lokal konfliktfrei rebased.
- Migration gegen die tatsaechliche SQL geprueft: additive Spalten
  (`idempotency_key`, `idempotency_payload_hash`, `created_by`,
  `menu_items.slug`), deckungsgleicher Sandbox-Seed, RLS auf allen sechs
  betroffenen Tabellen (vorher keine einzige geschuetzt), `guest_web_submit_order`
  als `SECURITY DEFINER`-RPC mit `FOR UPDATE`-Sperre, Idempotenz ueber
  Payload-Hash-Vergleich plus Unique-Constraint.
- TypeScript-Verdrahtung (`order-submit.ts`, `order-ack.ts`,
  `order-backend-supabase.ts`, `supabase-client.ts`) gegen ADR-001 §6/§7
  geprueft; Status kommt nachweislich nur aus der Serverantwort.
- CSS-/Komponenten-Diff bestaetigt die Behauptung "visuelles Design
  unangetastet": nur neue Klassen, keine bestehende Regel geaendert.
- **Echter Fund, behoben:** Nach erfolgreicher Bestellung leerte
  `setCart(emptyCart)` den Warenkorb sofort; die Sheet-Summe fiel dadurch
  auf "0,00 €" zurueck, direkt neben der Bestaetigungsmeldung. Der
  tatsaechliche Server-Betrag (`ack.totalCents`) wurde berechnet, aber nie
  angezeigt. Fix: Warenkorb-Schnappschuss zum Sende-Zeitpunkt; die Summe
  zeigt nach Bestaetigung `ack.totalCents` statt des inzwischen leeren
  Live-Warenkorbs. Verifiziert mit Typecheck, Lint, 40/40 Vitest-Tests,
  Build und manueller Browser-Pruefung der ohne echte Supabase-Instanz
  erreichbaren Zustaende (Artikel hinzufuegen, Sheet oeffnen, Senden ohne
  Backend zeigt den korrekten Fehler und behaelt die Live-Summe fuer einen
  Retry). Der "accepted"-Zustand selbst liess sich ohne laufende
  Supabase-Instanz nicht live pruefen; per Code-Lektuere verifiziert.
- **Dokumentiertes Restrisiko, bewusst nicht behoben:** Eine enge Race
  Condition zwischen Idempotenz-Vorpruefung und INSERT (zwei nahezu
  gleichzeitige Sendungen mit demselben Key) wird nur vom
  DB-Unique-Constraint aufgefangen, nicht von einem gezielten
  Exception-Handler, der sie auf Konflikt/Replay abbildet — der Verlierer
  bekommt ein generisches `rpc_error`. Nicht behoben, weil ich die
  `SECURITY DEFINER`-PL/pgSQL-Funktion hier nicht gegen eine echte
  Postgres-Instanz testen kann; ein blinder Fix an sicherheitsrelevantem
  SQL waere unverantwortlich. Die Kerngarantie (nie zwei Bestellungen fuer
  einen Key) haelt trotzdem.
- Gemergt nach `main`; GLMs Remote-Branch unveraendert gelassen (nur lokal
  rebased und mit dem Fix committet).

### Review-Ergebnis KL-INVENTORY-001 (MiniMax, `minimax/inventory-domain`)

- Branch war 9 Commits hinter `main`; lokal konfliktfrei rebased.
- Ledger, Projektion, Mengeneinheiten und Rezept-Resolver gegen
  `INVENTORY_MODEL.md`s eigene Behauptungen gelesen, nicht nur die Doku.
- 52 Inventory-Tests (Vorgabe: 25+), komplette Unit-Suite gruen.
- **Vermeintlicher Fund, nach genauer Pruefung verworfen:** `record()`
  prueft den Reversal-/Transfer-Schutz vor der Idempotenzpruefung. Ein
  zweiter `reverse()` derselben Bewegung scheitert deshalb immer als
  `alreadyReversed`, obwohl der automatisch generierte
  `reversal:<originalID>`-Schluessel und der Fingerprint (der `note` und
  `timestamp` bewusst ausschliesst) wie ein identischer Retry aussehen
  wuerden. Auf den ersten Blick ein Bug (widerspricht der generellen
  "gleicher Schluessel + gleiche Signatur -> Replay"-Regel aus §5). Nach
  Nachverfolgung der tatsaechlichen Konsequenzen: das ist die sicherere
  Wahl fuer ein Ledger. Sie garantiert "genau einmal" fuer einen Storno,
  statt einen zweiten Klick still als Erfolg zu replayen — bei einem
  Bestandsledger ist das eher erwuenscht als generische
  Idempotenz-Replay-Semantik. MiniMax dokumentiert diese Abwaegung bereits
  selbst im eigenen Handoff unter "Designentscheidungen — Reversal-Schutz
  vor Idempotenz". Kein Codeeingriff.
- `INVENTORY_MODEL.md` liegt neben dem Feature-Code
  (`kitchenlink/Features/Inventory/`) statt unter `docs/domain/` wie im
  urspruenglichen Mission-Brief vorgesehen — harmlose Pfadabweichung.
- Gemergt nach `main`; MiniMax' Remote-Branch unveraendert gelassen.

## Session-Teil 4: Review und Integration PR #7 (KL-OFFLINE-003)

### Scope

Auf Nutzeranfrage Arbeit an GLM 5.2 und MiniMax/DeepSeek verteilt: zwei neue
Missionen mit frischen Branches/Worktrees von aktuellem `main` in
`docs/collaboration/PARALLEL_MISSIONS_2026-07-17.md` dokumentiert (KL-WEB-002
fuer GLM, KL-INVENTORY-001-Neuversuch fuer MiniMax oder DeepSeek). Danach PR #7
(`glm/offline-event-log-v2`) reviewt und integriert.

### Review-Ergebnis PR #7

- Branch war 21 Commits hinter `main`; lokal konfliktfrei rebased (GLMs
  Remote-Branch bewusst nicht ueberschrieben — Force-Push auf fremde
  Branches ist ohne explizite Nutzerfreigabe nicht zulaessig).
- Code gegen die Invarianten in `EVENT_LOG_V2.md` geprueft (nicht nur die
  Doku gelesen): `EventStore.append` (Pre-TX- und In-TX-Idempotenz-Check,
  Optimistic-Concurrency-Semantik), `Outbox` (Claim/NACK/ACK/Lease-Recovery,
  atomar per PK-Update statt `UPDATE ... LIMIT`), `SQLiteConnection`
  (`BEGIN IMMEDIATE`, serialisierende `DispatchQueue`, ehrliche
  Durability-Pragmas).
- `swift test`: 35/35 gruen, sowohl im Worktree als auch erneut auf dem
  gemergten `main`-Stand.
- Keine P0/P1. Drei kleine, nicht blockierende Beobachtungen (alle bereits
  von GLM selbst in Doku/Handoff offengelegt): veralteter
  AUTOINCREMENT-Kommentar auf einer `WITHOUT ROWID`-Tabelle (tatsaechlicher
  Mechanismus ist korrektes `MAX+1` unter Transaktionssperre); zwei
  Testnamen (`testClaimIsExclusive`, `testParallelDuplicateAppendsCollapse`)
  suggerieren echte Nebenlaeufigkeit, laufen aber sequentiell (Inline-
  Kommentar sagt das selbst, Limitation steht in `EVENT_LOG_V2.md` §11 und
  im GLM-Handoff); Fingerprint-Kanonisierung trennt Felder nur mit Newline
  ohne Escaping (theoretisch, nicht ausnutzbar mit den strukturierten
  internen Feldern dieses Systems).
- Vollstaendig isoliertes Swift Package unter `prototypes/`; kein
  App-/Domain-Code beruehrt. Gemergt nach `main`.

## Session-Teil 5: Review und Integration PR #8, ADR-001-Reparatur

### ADR-001 fehlte auf `main`

Waehrend GLM (in einem externen Tool, sichtbar per Nutzer-Screenshot) am
KL-WEB-002-Auftrag arbeitete, stellte sich heraus: `docs/architecture/guest-web/`
existierte auf `main` ueberhaupt nicht — ADR-001 lag nur auf dem nie gemergten
Branch `glm/guest-web-architecture`. Die Mission verwies darauf, ohne dass ich
geprueft hatte, ob die Datei tatsaechlich auf `main` ankam. Behoben:

- `ADR-001_GUEST_WEB_STACK.md` und `SOURCES.md` (Revision 2, die vom Nutzer
  als Entscheidungsgrundlage akzeptierte Fassung) unveraendert aus
  `origin/glm/guest-web-architecture` extrahiert und auf `main` committet.
- GLMs Worktree (`kitchenlink-glm-web`, Branch `glm/guest-web-order-gate`) war
  zu diesem Zeitpunkt sauber (keine unfertige Arbeit); `origin/main` dort
  konfliktfrei gemergt und gepusht, damit die Dateien sofort im tatsaechlichen
  Arbeitsverzeichnis der laufenden GLM-Session sichtbar wurden.
- Antwort mit der Loesung und der Klarstellung zur zweiten GLM-Frage
  (`signInAnonymously` soll echt verdrahtet werden, nicht nur unit-getestet)
  an den Nutzer zur Weitergabe formuliert.

### Review-Ergebnis PR #8 (KL-WORKFORCE-001)

- Branch war 24 Commits hinter `main`; lokal konfliktfrei rebased (Kimis
  Remote-Branch unveraendert gelassen, wie bei GLM).
- Code gegen `WORKFORCE_MODEL.md` geprueft: Zeitmodell (`WorkforceTimeModels.swift`,
  explizite Zeitzonen, `resolvedRange` fuer Schichtvorlagen), Zustandsautomaten
  (`WorkforceShiftLifecycle.swift`), Validatoren (`WorkforceValidators.swift`).
  Beide dokumentierten Europe/Berlin-DST-Uebergaenge 2025 im Test nachvollzogen
  und die Zieldaten (30. Maerz / 26. Oktober) als tatsaechlich letzte Sonntage
  der jeweiligen Monate verifiziert.
- Scheinbare Diskrepanz aufgeklaert statt als Befund gemeldet: `xcodebuild`
  zeigte 74 "passed"-Zeilen fuer nur 37 tatsaechliche `@Test`-Funktionen —
  ein bekanntes, harmloses Doppel-Reporting von Swift Testing unter
  `xcodebuild` (zwei Reporter-Pfade fuer denselben Lauf), keine echte
  Doppelausfuehrung. Das Handoff nannte "33" Tests, tatsaechlich waren es 37 —
  unkritische Unter-, keine Ueberberichterstattung.
- Echter Fund: `finalizeSwap(accepted: false)` liess `acceptedAt` unveraendert,
  wenn eine zuvor angenommene Schicht per abgelehnter Tauschanfrage auf
  `.published` zurueckfiel — Status und Zeitstempel widersprachen sich. Kein
  Test deckte genau diesen Pfad ab (`requestSwap` aus `.accepted` heraus,
  gefolgt von `finalizeSwap(accepted: false)`).
- Waehrend der Integration selbst behoben (beide Zweige setzen `acceptedAt`
  jetzt zurueck) plus gezielter Regressionstest; zusaetzlich ein toter
  No-Op-`if`-Block im Validator entfernt (reine Kommentar-Leiche, kein
  Verhaltensunterschied). 38/38 Workforce-Tests und die komplette Unit-Suite
  liefen auf dem lokal gefixten Branch und erneut auf dem gemergten
  `main`-Stand gruen.
- Vollstaendig isolierte neue Dateien unter `Features/Workforce/`; kein
  bestehender App-Code veraendert. Gemergt nach `main`.

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

Zwei parallele Nutzer-Abnahmen offen, beide nur mit echter Instanz/Geraet
machbar: (1) KL-CLOUD-001 (Migration `20260719100000` + Betreiber-Konto,
`SANDBOX_SETUP.md` §6.1, reale Web-zu-iPhone-Abnahme) und (2) KL-MENU-005
(Migration `20260719200000`, einmal veroeffentlichen, `SANDBOX_SETUP.md` §6.2).
Nach diesen Abnahmen ist die geschlossene Schleife *Papierkarte → Scan →
Pruefung → Live-Gastkarte → Bestellung → Kueche → serviert* erstmals
durchgaengig vorfuehrbar. Naechste Code-Schritte danach: Tisch-Kontext im
Gast-Web (QR mit Tischparameter + minimale Tisch-Session) und die
Payment/TSE-Provider-Vorentscheidung als Papieraufgabe. Als Folgetickets offen:
Gast-Statusseite nach dem ACK, additive Kartenpflege (statt Vollersatz) und
stabile Slug-Zuordnung ueber Re-Publish.
