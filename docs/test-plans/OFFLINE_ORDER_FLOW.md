# Offline Order Flow — Test Plan (KL-QA-002)

**Stand:** 16. Juli 2026
**Status:** Abgeschlossen (Branche `deepseek/offline-e2e-smoke`)
**Testtyp:** Integration/E2E auf Basis des bestehenden lokalen Demo-Backends

## Testumfang (was wird geprüft)

Die Tests validieren den lokalen Bestellablauf ohne Cloudzugriff über die
vorhandene `OrderRelayService`- und `LocalDemoRepository`-Domäne auf
`UserDefaults`-Basis.

| Test | Beschreibung |
|------|-------------|
| `guestSendsOrder_ownerSeesPending` | Gast erzeugt Bestellung via Relay; Owner empfängt sie als `pending` über Polling |
| `fullLifecycleChainViaOwner` | Owner durchläuft die vollständige Valide-Kette `pending → accepted → preparing → ready → served` |
| `guestTracksFullChain` | Gast-Tracker beobachtet alle Statuswechsel in der Owner-Kette per Polling |
| `invalidTransitionsDontChangeState` | 10 verbotene Übergänge werden abgelehnt; der gespeicherte Status bleibt unverändert |
| `tableDrivenTransitionCoverage` | 36 parametrisierte Fälle decken alle 6×6-Kombinationen explizit ab |
| `persistenceAcrossRelayRecreation` | Bestelldaten (Items, Betrag, Tisch, Notiz, Status) überleben Relay-/Repo-Neuerzeugung; Status wird über die reguläre Relay-Kette gesetzt |
| `relayTeardownClearsObservableState` | `stopNetworking` wird aufgerufen, Cache und persistierte Daten werden gelöscht |
| `eventuallyCancellationSkipsConditionAfterSleepThrow` | Synchronisationsbasierter Test: Condition wird genau einmal evaluiert; nach Task-Cancellation wird sie nicht erneut aufgerufen; `eventually` gibt `false` zurück, Counter bleibt bei 1 |

## Architektur der Testinfrastruktur

- Zwei isolierte `LocalDemoRepository`-Instanzen auf **derselben** isolierten
  `UserDefaults`-Suite → gemeinsame Datenbasis ohne Seiteneffekte
- Zwei `OrderRelayService`-Instanzen (Gast = `.customer`, Owner = `.owner`)
- `eventually`-Helfer mit 8s-Timeout und 200ms-Polling-Intervall via cancellablem `Task.sleep` (keine blinde feste Wartezeit)
- Jeder Test erzeugt eine UUID-eindeutige Suite; `defer` bzw. explizites
  `cleanup()` räumt Tasks und Daten vollständig weg

## Was getestet ist

- Vollständiger Bestelleingang und Statusdurchlauf im lokalen Relay/Repository
- Gültigkeitsprüfung aller 36 möglichen Statusübergänge
- Gast-Tracker beobachtet Owner-Statuswechsel (polling-basiert, maximal 8s)
- Persistenz: Relay/Repo-Neuerzeugung erhält sämtliche Bestellfelder
- Stop-Networking wird aufgerufen; beobachtbarer Zustand (Cache + Persistenz) wird gelöscht

## Was dieser Test nicht beweist (braucht den echten Venue Hub)

| Lücke | Grund |
|-------|-------|
| Echte SQLite-Persistenz | `LocalDemoRepository` speichert in `UserDefaults` – kein WAL, keine Transaktionen, kein Stromausfallschutz |
| Netzwerk-Trennung | Simulation über getrennte Relay-Instanzen auf derselben UserDefaults-Suite; echter Gästegerät-zu-Venue-Hub-Abgleich fehlt |
| Idempotenz-Sicherung | Weder `idempotency_key` noch `request_fingerprint` oder Konfliktbehandlung sind implementiert |
| Event-Log / Outbox | Ereignisprotokoll und Outbox mit Lease-Mechanismus existieren nur als GLM-Prototyp |
| Mehrgeräte-Synchronisation | Kein Multipeer, kein Venue-Hub-Wahlverfahren, kein Split-Brain-Schutz |
| ACK-Vertrag | Kein Bestätigungsprotokoll „gespeichert erst nach Commit“ |
| Geräte-Neustart / Stromausfall | `UserDefaults` überlebt App-Neustart, aber nicht korrupte Datenbank oder verlorenes WAL |
| Supabase-Konflikte | Cloud-Konflikte, RLS oder Offline-Queue wurden nicht getestet |

## Ausführung

```bash
# Nur diesen Test
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:kitchenlinkTests/KitchenLinkOfflineOrderFlowTests

# Gesamte Unit-Suite
xcodebuild test -project kitchenlink.xcodeproj -scheme kitchenlink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Grenzen des Prototyps

Die Tests nutzen ausschließlich das bestehende `LocalDemoRepository` (UserDefaults)
und die `OrderRelayService`-API. Der spätere Venue Hub benötigt eigene E2E-Tests
mit SQLite-Outbox, ACK-Vertrag, Lease-Mechanismus und echtem Multipeer-Transport.
Diese Suite ist eine Regression-Smoke, kein Ersatz für jene Integrationstests.
