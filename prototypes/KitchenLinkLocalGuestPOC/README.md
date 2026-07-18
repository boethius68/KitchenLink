# KitchenLink Local Guest Ordering PoC

Isolierter Stage-2-Nachweis für lokale Gastbestellungen. Der Prozess liefert
eine lokale, gleich-originige Webseite aus und bestätigt Bestellungen erst,
nachdem Event und Cloud-Outbox atomar im bestehenden SQLite-Event-Log
gespeichert wurden.

```bash
cd prototypes/KitchenLinkLocalGuestPOC
swift run kitchenlink-local-guest \
  --public-host 192.168.1.23 \
  --port 8080 \
  --database /tmp/kitchenlink-local-orders.sqlite
```

Danach `http://192.168.1.23:8080/` als QR-Ziel verwenden. `--public-host`
ändert nur die ausgegebene URL; der Server bindet an alle Interfaces.

## Nachweis und Grenzen

- `GET /` liefert die lokale Gastseite, `GET /bootstrap` die lokale Karte.
- `POST /orders` validiert Artikel und Mengen und berechnet Preise serverseitig.
- HTTP 201/200 wird erst nach erfolgreichem Commit zurückgegeben.
- Wiederholungen sind idempotent; ein abweichender Payload mit gleichem Key
  ergibt HTTP 409.
- Es gibt keine Zahlung und keine Cloud-Synchronisation; die Outbox bleibt
  lokal `pending`.
- Das ist ein macOS-Hostsurrogat und noch kein iOS-Hub. Bonjour, QR-Erzeugung,
  AP-Isolation, echte Geräte, App-Lifecycle und TLS/Trust sind nicht bewiesen.
- HTTP ist hier absichtlich eine direkt geöffnete Top-Level-Seite. Eine
  HTTPS-Cloudseite darf diesen lokalen HTTP-Endpunkt nicht per `fetch` aufrufen.

Tests: `swift test`
