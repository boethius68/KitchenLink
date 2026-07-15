# Kitchenlink Screen-by-Screen Tickets (Legacy)

> Historische Tickets. Neue Arbeit wird aus `docs/PRODUCT_BLUEPRINT.md` und den neuen Meilensteinen abgeleitet.

This is a build checklist for your first app version.  
Each ticket is a screen or a small feature slice you can review visually.

## How to use this file
1. Start from Priority 1 and move down.
2. Approve each ticket after you see a working version.
3. If a ticket needs changes, add notes under "Owner Notes".

---

## Priority 1: Customer ordering flow (most important)

### T1 - QR Landing Screen
- Purpose: Customer scans QR and lands on the correct restaurant menu.
- Must show:
- Venue name/logo
- Service mode options if needed (Dine-in, Bar, Pickup)
- Menu categories
- "View Cart" button
- Rules:
- If QR is table-specific, table is auto-detected.
- If QR is shared, ask user to confirm table/mode before checkout.
- Acceptance check:
- Scanning a valid QR always opens the right venue page.
- Invalid QR shows a friendly error page.
- Owner Notes:

### T2 - Menu List Screen
- Purpose: Customer browses available food/drinks quickly.
- Must show:
- Category tabs/sections (e.g., Starters, Drinks)
- Item name, short description, price
- Availability badge (Available / Sold out)
- Acceptance check:
- Unavailable items cannot be added to cart.
- Category navigation works on phone-size screens.
- Owner Notes:

### T3 - Item Detail Screen
- Purpose: Customer sees item details before adding.
- Must show:
- Item image (optional for MVP)
- Name, description, price
- Modifier choices (size, extras) if configured
- Quantity stepper
- Add to Cart button
- Acceptance check:
- Correct total updates as quantity/modifiers change.
- Required options must be selected before adding.
- Owner Notes:

### T4 - Cart Screen
- Purpose: Customer reviews order before checkout.
- Must show:
- Selected items with quantity and line total
- Edit/remove item controls
- Subtotal and total
- Customer note field (optional)
- Continue to Checkout button
- Acceptance check:
- Cart totals are always correct after edits.
- Empty cart state is clear and has return-to-menu action.
- Owner Notes:

### T5 - Table / Service Confirmation Screen
- Purpose: Prevent wrong-table orders.
- Must show:
- Current service mode
- Table info if already detected
- If no table detected: enter table code (example: A12)
- Option for Bar/Pickup when venue allows it
- Acceptance check:
- Dine-in checkout is blocked until valid table is selected.
- Bar/Pickup can continue without table.
- Owner Notes:

### T6 - Place Order + Success Screen
- Purpose: Customer confirms payment method (if enabled later) and places order.
- Must show:
- Final item summary and total
- Place Order button
- Success state with order number
- Acceptance check:
- One tap places one order (no duplicates on slow network tap spam).
- Success screen shows order ID and next step.
- Owner Notes:

### T7 - Order Tracking Screen
- Purpose: Customer can see order progress.
- Must show:
- Order number
- Status timeline: Pending, Accepted, Preparing, Ready, Served
- Estimated wait note (simple text for MVP)
- Acceptance check:
- Status updates appear without needing to rescan QR.
- Canceled order shows clear reason/message.
- Owner Notes:

---

## Priority 2: Owner and staff core operations

### T8 - Staff Login Screen
- Purpose: Secure access for owner/staff.
- Must show:
- Email/password login
- Basic "forgot password" placeholder link
- Acceptance check:
- Wrong credentials show clear error.
- Logged-in staff are routed to order board.
- Owner Notes:

### T9 - Live Order Board Screen
- Purpose: Staff manage incoming orders fast.
- Must show:
- Columns or grouped list by status
- Each card: order number, time, items, table/service mode
- Quick actions: Accept, Start Preparing, Mark Ready, Mark Served, Cancel
- Acceptance check:
- Status changes are immediate and visible.
- Illegal status jump is blocked (example: Pending -> Ready).
- Owner Notes:

### T10 - Menu Management Screen
- Purpose: Owner adds and updates menu items.
- Must show:
- Category list
- Item create/edit form (name, description, price, available toggle)
- Sort order controls (simple up/down is enough for MVP)
- Acceptance check:
- New items appear in customer menu quickly.
- "Sold out" toggle updates customer side without app restart.
- Owner Notes:

### T11 - Table Management Screen
- Purpose: Owner manages table codes.
- Must show:
- Table list (A1, A2, B1...)
- Add/edit/deactivate table
- Active/inactive state
- Acceptance check:
- Duplicate table labels are blocked.
- Inactive tables cannot be selected in new customer checkouts.
- Owner Notes:

### T12 - QR Generator Screen
- Purpose: Owner creates printable QR codes.
- Must show:
- Generate shared venue QR
- Generate per-table QR batch
- Download/export buttons
- Revoke/regenerate option
- Acceptance check:
- Revoked QR no longer opens ordering flow.
- Printed QRs are scannable at normal phone distance.
- Owner Notes:

---

## Priority 3: Setup and polish

### T13 - Venue Setup Screen
- Purpose: First-time owner onboarding.
- Must show:
- Venue name
- Timezone
- Supported service modes
- Save button
- Acceptance check:
- Owner can complete setup in under 5 minutes.
- Cannot proceed with empty required fields.
- Owner Notes:

### T14 - Empty/Error States Pack
- Purpose: App stays usable during failures.
- Must cover:
- No internet
- Invalid QR
- No menu items yet
- Order failed retry
- Acceptance check:
- Every major screen has a human-readable fallback message.
- Retry actions work where appropriate.
- Owner Notes:

### T15 - Basic Branding Screen/Settings
- Purpose: Owner adds simple brand identity.
- Must show:
- Upload logo
- Primary brand color
- Preview of customer menu header
- Acceptance check:
- Branding appears on customer-facing screens.
- Default style remains clean if no branding set.
- Owner Notes:

---

## Decision checklist for you (owner)
- Do you want the customer app as web pages first, native app first, or both?
- Do you want payment in MVP or "pay at counter/table" only?
- Do you want staff to use tablet only, or also phone?
- Do you want table code input only, or also a visual table map later?

## Recommended build order
1. T1-T7 (customer flow)
2. T8-T12 (owner/staff operations)
3. T13-T15 (setup and polish)

## Definition of "MVP done"
- Customer can scan, order, and track.
- Staff can receive and progress orders.
- Owner can manage menu, tables, and QR codes.
- Wrong-table errors are prevented by confirmation logic.
