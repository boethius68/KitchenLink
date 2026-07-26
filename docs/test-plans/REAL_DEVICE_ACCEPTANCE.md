# Real Device Acceptance Checklist

**Updated:** 23 July 2026
**P0:** Sandbox-Beta-Abschluss

All migrations applied, operator account exists (`boethius68@gmail.com`),
guest web live on `kitchenlink.luneq.eu`. What hasn't been done is running
the flows **on a physical iPhone** (not simulator) against the real live
guest web and a real WLAN.

---

## Prerequisites

- [ ] Xcode project builds for physical device
  - Automatic signing with team `5PB6PP494U`, bundle `sf.kitchenlink`
  - iOS 17.0+, iPhone + iPad
  - No special capabilities/entitlements
- [ ] Physical iPhone connected to Mac, selected as run target
- [ ] Both iPhone and Mac on the same WLAN (for local hub test)

---

## 1. Scan → Publish (KL-MENU-005)

| Step | Expected | Result |
|------|----------|--------|
| App start → "Karte erfassen" tap | Scan/Import sheet opens | |
| Photo of any menu or "Demo importieren" tap | Scanned items appear in draft review | |
| In draft review: verify items, resolve all open entries | "Veröffentlichen" button enabled | |
| Tap "Online veröffentlichen" | Sheet: email/password prompt (if no session) or direct publish | |
| If prompted: `boethius68@gmail.com` / `test` | Session saved, publish starts | |
| Success card appears | "Karte ist online" with live URL | |
| Open `kitchenlink.luneq.eu/alte-muehle/menu` in Safari | Scanned menu visible within 60s (ISR) | |
| Tap an item → add to cart → submit order | ACK with `accepted: true` | |

**Expected:** full loop from paper menu → scan → live guest web → order.

---

## 2. Cloud Order Loop (KL-CLOUD-001)

| Step | Expected | Result |
|------|----------|--------|
| App → Service tab | Service view loads | |
| "Online-Service aktivieren" tap | If session missing: email/password prompt | |
| Sign in: `boethius68@gmail.com` / `test` | Session saved, orders load | |
| On a separate device: open `kitchenlink.luneq.eu/alte-muehle/menu` | Menu loads | |
| Order 2+ items and submit | ACK received | |
| iPhone Service view (Küche) | The new order appears in the list | |
| Tap "Bestellung zubereiten" | Status changes to `preparing` | |
| Switch to "Kellner" filter | Order appears here | |
| Tap "Bestellung serviert" | Status changes to `served` | |
| Check `https://kitchenlink.luneq.eu/alte-muehle/menu` | Order no longer pending (guest see served) | |

**Expected:** Guest web → Supabase → iPhone push/poll → full lifecycle.

### Heartbeat + Fallback

| Step | Expected | Result |
|------|----------|--------|
| While Service view is open → check `venue_hub_presence` | row with `local_guest_url` and recent `last_seen` | |
| Kill Wi-Fi on iPhone for >45s | Guest web shows "Online-Bestellung nicht möglich" banner | |
| Reconnect Wi-Fi | Hub heartbeat resumes, banner disappears | |

---

## 3. Additive Menu Edit (Cloud-Sync UI)

| Step | Expected | Result |
|------|----------|--------|
| App → Karte bearbeiten | Editor loads with current sections | |
| Tap a category → tap an existing item | Item editor opens | |
| Scroll to "Cloud & Verfügbarkeit" section | Cloud controls visible | |
| Change name/price → tap "In Cloud speichern" | Green checkmark: "Gespeichert (ID: ...)" | |
| Open guest web after 60s | Item change visible | |
| Back in editor: tap "Aus Cloud löschen" | Confirm dialog appears | |
| Confirm | "Gelöscht" feedback | |
| Guest web after 60s | Item gone from menu | |
| Toggle "Verfügbar" off → "In Cloud speichern" (Verfügbarkeit) | Item hidden on guest web | |
| Set "Sichtbar ab" to 5 min from now → save | Item not visible until that time | |

---

## 4. Local Venue Hub (Wi-Fi)

| Step | Expected | Result |
|------|----------|--------|
| App → Service | Service view loads | |
| "Lokaler Service" section → tap Start | Hub starts, QR code appears | |
| On second device: scan the QR code | Second device opens hub HTTP page | |
| Select items → submit order | ACK received | |
| iPhone Service: order appears in Kitchen | Status `pending` | |
| Advance through preparing → ready → served | Lifecycle works end-to-end | |
| Kill Wi-Fi on both devices → reorder via QR page | Order stored locally, committed when Wi-Fi returns | |

### AP Isolation

| Router config | Expected | Result |
|------|----------|--------|
| Guest Wi-Fi with client isolation ON | Hub unreachable via Bonjour/IP | |
| Staff/main Wi-Fi (isolation OFF) | Hub reachable | |
| iPhone hotspot (devices connect to phone) | Hub reachable | |

**P0 Note:** AP isolation on guest Wi-Fi will break local ordering. The
current architecture has no mitigation. See
`docs/discovery/offline-venue-hub/LOCAL_NETWORK_POC.md`.

---

## 5. Cleanup & Regressions

- [ ] Reset menu: "Auf Demo-Karte zurücksetzen" in editor
- [ ] Verify guest web shows the original 8-item card after reset + publish
- [ ] Verify manual order without network (Airplane Mode) still works
- [ ] Verify manual order with network (cloud) also works
