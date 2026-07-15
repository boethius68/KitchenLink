# KitchenLink Product Plan (Legacy)

> Historischer Plan. Die aktuelle, gemeinsam beschlossene Produktdefinition steht in `docs/PRODUCT_BLUEPRINT.md`.

Last updated: 2026-03-17

## 1. Product vision

KitchenLink helps restaurants, bars, and cafes launch QR-based ordering fast, without needing a full POS integration project.

The product promise for V1 is simple:

- A venue can go from setup to first live order quickly.
- Guests can scan, browse, and order with low friction.
- Staff can fulfill orders with clear table and session context.
- Wrong-table orders are prevented by product design, not by staff guesswork.

## 2. Product thesis

KitchenLink should win on operational clarity, not feature volume.

The strongest product advantages for V1 are:

- Fast venue onboarding, especially menu import from photos/scans.
- Reliable QR context with table-aware ordering.
- A simple staff order board that works during live service.
- A focused scope that is easier to ship and support than an all-in-one hospitality suite.

## 3. Chosen V1 product decisions

These decisions are now treated as defaults for V1 unless we explicitly change them later.

- Customer surface: mobile web / PWA first, opened from QR.
- Operator surface: native iOS / iPad app first, optimized for tablet but usable on phone.
- Payment: no in-app card payment in V1. Orders are "pay at counter/table".
- Table capture: per-table QR is preferred; shared venue QR plus manual table code is the fallback.
- Service modes: dine-in, bar, and pickup are supported.
- Table map: post-V1. V1 uses table labels/codes only.
- Realtime: polling is acceptable for beta; push/realtime should be added before wider rollout.
- Branding: simple logo + primary color in V1, not a full theme system.

## 4. Target users

### Owner / Admin

Needs to:

- create a venue
- upload or import a menu
- manage tables
- generate QR codes
- see if orders are flowing

### Staff

Needs to:

- see new orders immediately
- know the correct table or service mode
- move orders through the lifecycle fast
- avoid illegal or confusing status transitions

### Customer

Needs to:

- scan one QR and land in the right ordering context
- understand the menu quickly
- place an order with confidence
- track what happens next without asking staff

## 5. V1 release goal

KitchenLink V1 is ready when all of the following are true:

- A venue owner can complete setup and publish a live QR flow without developer help.
- A customer can scan, order, and see status updates on a phone.
- Staff can receive, accept, prepare, mark ready, and mark served orders.
- Dine-in orders cannot be placed without validated table/session context.
- Shared QR flows do not create wrong-table orders.
- Invalid or revoked QR codes fail safely with a human-readable screen.

## 6. V1 product scope

### Customer scope

- QR landing page with venue context
- Menu browsing by category
- Item detail page with modifiers
- Cart with quantity editing and customer note
- Service mode + table confirmation step
- Order success screen with order number
- Order tracking screen with live status
- Empty/error states for invalid QR, no internet, failed order, and empty menu

### Owner and staff scope

- Login and role-based access
- Venue setup
- Menu editor
- Menu import from photos/scans with review before publish
- Item availability toggle
- Table manager
- QR generator for shared venue QR and per-table QR
- Live order board with status transitions
- Basic branding settings

### Platform scope

- Venue, menu, table, QR token, table session, order, and order item data model
- Auth and venue membership
- Role-based permissions
- Order audit timestamps
- Revocable QR tokens
- Basic analytics counters for early operational insight

## 7. Out of scope for V1

- Full POS integration
- Native payment terminal integrations
- Loyalty or rewards
- Advanced analytics suite
- Complex floor plan editor
- Deep CRM features
- Marketplace/discovery features

## 8. Core user journeys

### Owner setup journey

1. Owner creates a venue.
2. Owner imports or builds the menu.
3. Owner configures supported service modes.
4. Owner creates tables.
5. Owner generates shared and/or per-table QR codes.
6. Owner does a test order and confirms the operator board works.

### Customer order journey

1. Customer scans a QR code.
2. KitchenLink resolves venue and optional table context.
3. Customer browses the menu and adds items.
4. Customer confirms service mode and table if needed.
5. Customer places an order.
6. Customer sees a success screen and order tracking.

### Staff fulfillment journey

1. Staff sees a new pending order.
2. Staff accepts the order.
3. Staff moves it to preparing.
4. Staff marks it ready.
5. Staff marks it served.
6. Staff can cancel with reason if needed.

## 9. Current prototype snapshot

### Already working in the current app

- branded start screen and native shell
- camera QR scanning
- demo QR to demo menu flow
- menu browsing and cart flow
- order submission to Supabase
- operator login with a hardcoded test account
- basic live order list for incoming orders
- strong menu import prototype using OCR and optional OpenAI-assisted structuring

### Not yet product-ready

- no real multi-venue data model in the app flow
- no production auth or role system
- no real QR token resolution flow
- no table manager or QR generator UI
- no enforced service-mode/table confirmation in checkout
- no real item detail flow with required modifier validation
- no staff status workflow beyond passive order display
- no customer order tracking tied to actual order status
- no secure production secret handling
- almost no test coverage

## 10. Product gap from prototype to V1

The current prototype is strongest in menu presentation, operator demo flow, and menu import. The biggest gap is not UI polish. The biggest gap is domain correctness.

The following domain rules must become real before V1:

- every order must belong to a venue
- dine-in orders must have validated table or table session context
- shared QR codes must trigger a confirmation step
- order status transitions must be controlled server-side
- staff and owner permissions must be enforced
- QR tokens must be revocable

## 11. Recommended product architecture

- Customer experience: web/PWA, launched from QR, no app install required
- Operator experience: native iOS/iPad app for staff and owners
- Backend: Supabase/Postgres/Auth/Storage/Realtime is a reasonable base
- Public QR resolution and critical order mutations should be server-managed, not client-trusted
- Order placement must be idempotent to prevent duplicate tap orders
- Menu import can remain a premium differentiator, but production OpenAI usage should move server-side before launch

## 12. V1 screen map

### Customer screens

- QR landing / menu
- Item detail
- Cart
- Service mode / table confirmation
- Order success
- Order tracking
- Error and empty states

### Owner and staff screens

- Login
- Venue setup
- Menu editor
- Menu import review
- Table manager
- QR generator
- Live order board
- Branding / settings

## 13. Acceptance criteria for V1

- Valid QR always resolves to the correct venue context.
- Revoked or expired QR never opens a valid ordering flow.
- Dine-in checkout is blocked until table/session validation succeeds.
- Bar and pickup checkout can continue without table context.
- One tap creates one order.
- Staff cannot jump from `pending` directly to `ready`.
- Customer status updates are visible without rescanning.
- Item availability updates reach the customer side quickly.
- Owner can create first venue, first menu, first table, and first QR without developer assistance.
- Core happy-path flows have automated coverage.

## 14. Release phases

### Phase 1: Product foundation

- finalize schema and API contracts
- add auth, venue membership, and role permissions
- split app state/domain logic out of the current single-file prototype

Exit criteria:

- one real venue can exist in staging
- owner login works against real backend
- menu, tables, and QR tokens have persistent models

### Phase 2: Customer ordering flow

- implement QR resolve
- build customer menu, item detail, cart, and confirmation flow
- create order success and tracking screens
- add invalid QR and failed order states

Exit criteria:

- a real QR can produce a real order with correct venue/service/table context

### Phase 3: Staff operations

- implement live order board with grouped statuses
- add allowed status actions
- add cancel reasons
- add item availability controls

Exit criteria:

- staff can run the full order lifecycle in staging

### Phase 4: Owner setup and publish flow

- build venue setup
- build table manager
- build QR generator
- harden menu import and publish review
- add branding settings

Exit criteria:

- owner can fully onboard a venue without manual database work

### Phase 5: Beta hardening

- add smoke tests and critical-path UI tests
- improve resilience for slow or unstable network
- move production secrets and sensitive logic off-device
- prepare TestFlight / pilot rollout

Exit criteria:

- KitchenLink can be tested with pilot venues under real service conditions

## 15. Highest-risk product areas

- wrong-table orders from weak QR or confirmation logic
- duplicate orders from retries or impatient taps
- stale order status during busy service
- menu import inaccuracies causing wrong prices or modifiers
- weak operator permissions or public data leakage

## 16. Immediate build order from the current codebase

1. Extract domain models, services, and screens out of `ContentView.swift`.
2. Replace the demo QR and demo order payload with real backend-backed venue/order context.
3. Implement venue setup, tables, and QR generation.
4. Complete the customer checkout confirmation and order tracking flow.
5. Complete the operator status workflow.
6. Add automated tests for the critical happy path and key validation rules.

## 17. Post-V1 backlog

- card payments
- POS integrations
- floor map / visual table plan
- advanced analytics
- loyalty / repeat customer features
- multi-location administration
