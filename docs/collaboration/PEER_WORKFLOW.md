# KitchenLink Peer Workflow

**Stand:** 16. Juli 2026
**Status:** Verbindlicher Ablauf fuer Claude Code, Codex und weitere Agenten

## Rollen

- Der Nutzer entscheidet Produktumfang, Designfreigaben und Produktionsgrenzen.
- Claude Code, Codex und weitere Coding-Agenten arbeiten technisch auf
  Augenhoehe.
- Kein Agent besitzt `main`, die Work Queue oder die Arbeit eines anderen
  Agenten.
- Es gibt keinen dauerhaften Chef, Integrator oder Freigabe-Gatekeeper.

## Arbeitsbereiche

| Zweck | Ordner | Branch |
| --- | --- | --- |
| gemeinsame Integration | `/Users/test/Developments/kitchenlink` | `main` |
| Claude-Arbeit | `/Users/test/Developments/kitchenlink-claude` | aufgabenbezogener `claude/*`-Branch |
| Codex-Arbeit | `/Users/test/Developments/kitchenlink-codex` | aufgabenbezogener `codex/*`-Branch |

Der Integrationsordner ist kein dauerhafter Arbeitsplatz eines Agenten. Beide
Agenten beginnen neue Aufgaben von demselben aktuellen `origin/main`.

## Ticket uebernehmen

1. Verbindliche Quellen und die neuesten relevanten Handoffs lesen.
2. In `WORK_QUEUE.md` pruefen, ob Ticket und Schreibbereich frei sind.
3. Eigenen Branch und eigenen Worktree verwenden.
4. Status und exklusiven Schreibbereich im Ticket festhalten.
5. Bei Ueberschneidung direkt mit dem anderen aktiven Agenten oder dem Nutzer
   abstimmen; nicht still konkurrierende Aenderungen erzeugen.

## Arbeit liefern

1. Kleine, nachvollziehbare Commits erstellen.
2. Tests, visuelle Pruefung und bekannte Risiken im eigenen Handoff festhalten.
3. Eigenen Branch pushen und einen Draft Pull Request gegen `main` anlegen.
4. Findings und offene Entscheidungen im Pull Request sichtbar machen.
5. Neue Produkt- oder Designentscheidungen dem Nutzer vorlegen.

## Review und Integration

- Claude und Codex duerfen gegenseitig reviewen; beide duerfen auch fruehere
  Arbeit des anderen sachlich verwerfen oder verbessern.
- Kein Review muss zwingend von einem bestimmten Agenten kommen.
- Der Autor darf technische Korrekturen selbst einarbeiten und den Pull Request
  aktualisieren.
- Produkt- und Designaenderungen werden erst nach Nutzerfreigabe integriert.
- P0-/P1-Risiken werden vor dem Merge behoben oder dem Nutzer zur bewussten
  Entscheidung vorgelegt.
- Nach erfuellter Abnahme darf Claude, Codex oder der Nutzer den Pull Request
  mergen. Fuer alle gelten dieselben Kriterien.
- Wer merged, aktualisiert `CURRENT.md`, prueft `main` und dokumentiert das
  Ergebnis. Diese Rolle endet mit dem Merge.

## Konflikte

- Git-Konflikte werden inhaltlich geloest, nicht durch pauschales Bevorzugen
  eines Agenten.
- Bei unterschiedlichen technischen Vorschlaegen werden Belege, Tests,
  Wartbarkeit und Produktrisiko verglichen.
- Bei gleichwertigen Alternativen oder Produktfolgen entscheidet der Nutzer.
- Kein Agent darf fremde uncommittete Arbeit zuruecksetzen oder ueberschreiben.
