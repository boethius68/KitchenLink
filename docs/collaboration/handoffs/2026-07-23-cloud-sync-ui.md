# Handoff: Cloud-Sync UI & Item Availability (23 July 2026)

## Completed

### Migration `20260723150000_operator_item_availability.sql`
- Added `available_from`/`available_until` (nullable `timestamptz`) to `menu_items`
- Staff-gated RPC `operator_set_item_availability(p_venue_slug, p_item_slug, p_available, p_available_from, p_available_until)` with venue check, auth check, and window validation
- Updated `guest_web_submit_order_v2` to reject items with `available_from` in the future or `available_until` in the past

### Swift: Transport protocol extension
- `KitchenLinkMenuEditTransport.setItemAvailability(...)` in `KitchenLinkMenuPublishClient.swift`
- `URLSessionKitchenLinkCloudTransport` implementation (ISO8601 with fractional seconds for Date→string)
- Test spy + 3 new tests: set with schedule, set without schedule, error propagation

### UI: `MenuEditorItemEditor` Cloud & Verfügbarkeit section
- Section appears in the item editor with:
  - "In Cloud speichern" button (upsert via `URLSessionKitchenLinkCloudTransport`)
  - "Aus Cloud löschen" button (with confirmation dialog)
  - Availability toggle (`@Binding` to `MenuItemData.available`)
  - Optional schedule button revealing `DatePicker` for `availableFrom`/`availableUntil`
  - "In Cloud speichern" button for availability (calls `setItemAvailability`)
  - Feedback label (hourglass → checkmark/xmark)
- Controls are session-gated (grayed-out hint if no session stored)
- Slug auto-generated from item name via `KitchenLinkMenuPublishPayload.slugify`

### `MenuItemData` extension
- Added `available: Bool` (default `true`), `availableFrom: Date?`, `availableUntil: Date?`
- Backward-compatible decoder via `decodeIfPresent`

## Files changed/modified
- `supabase/migrations/20260723150000_operator_item_availability.sql` (new)
- `kitchenlink/Features/CloudOperations/KitchenLinkMenuPublishClient.swift` (transport protocol + implementation)
- `kitchenlinkTests/KitchenLinkMenuPublishTests.swift` (spy + 3 test methods)
- `kitchenlink/ContentView.swift` (MenuItemData fields)
- `kitchenlink/Features/MenuEditor/MenuManualEditorView.swift` (cloud section UI)
- `docs/collaboration/CURRENT.md` (state update)

## Verification
- Migration `20260723150000` applied to remote Supabase instance
- Build green (0 errors, 1 pre-existing warning)
- All KitchenLinkMenuPublishTests pass (original 12 + 3 new = 15)

## Remaining risk
- No integration test against real Supabase for the new RPC -> relies on the existing integration pattern
- Cloud operations in the UI use `URLSessionKitchenLinkCloudTransport()` directly per call instead of a shared model; feedback is ephemeral (not state-backed)
- The "In Cloud löschen" button does NOT remove the item from the local editor — only from the cloud — which is intentional (local editor is the local sandbox)
- The availability save requires a separate button press (doesn't auto-save on toggle)
