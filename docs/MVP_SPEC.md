# Kitchenlink MVP Spec (Legacy)

> Historische Spezifikation. Die aktuelle, gemeinsam beschlossene Produktdefinition steht in `docs/PRODUCT_BLUEPRINT.md`.

## 1. Goal
Kitchenlink enables restaurant/bar guests to scan a QR code, browse a venue menu, and place orders that are routed to staff with correct table/session context.

## 2. MVP Scope
### In scope
- Venue owner onboarding (basic profile + menu upload/create)
- Menu browsing for customers (mobile web or in-app web view)
- Cart + order placement
- Table/session matching with hybrid strategy:
  - Per-table QR (preferred)
  - Shared venue QR + table confirmation
  - No-table mode (bar/pickup)
- Order management dashboard for staff (incoming, accepted, preparing, ready, served, canceled)

### Out of scope (post-MVP)
- Full POS integration
- Loyalty programs
- Advanced analytics
- Complex floor plan editor
- Native payment terminal integrations

## 3. User Roles
- Owner/Admin: manages venue, tables, menu, QR settings.
- Staff: manages order lifecycle.
- Customer: scans QR, browses menu, orders.

## 4. Core Product Decisions
- Every order requires `venue_id`.
- `table_id` is optional at DB level but required for dine-in orders.
- QR token resolves context:
  - `venue_id` always present
  - `table_id` optional
- If QR has no table context, checkout enforces a table/session step.

## 5. End-to-End Flows
## 5.1 Owner setup
1. Owner creates venue.
2. Owner creates menu categories/items.
3. Owner configures service modes:
   - Dine-in
   - Bar seat
   - Pickup
4. Owner creates tables (`A1`, `A2`, `B1`, etc.).
5. Owner generates QR:
   - Per-table QR batch, and/or
   - Shared venue QR.

## 5.2 Customer order flow
1. Customer scans QR.
2. App resolves QR token and loads venue/menu.
3. Customer adds items to cart.
4. Context step before checkout:
   - If table resolved from QR: confirm table.
   - If shared QR: choose service mode; if dine-in, enter/select table code.
5. Place order.
6. Customer sees order status updates.

## 5.3 Staff flow
1. Staff sees incoming order queue.
2. Accept/reject order.
3. Move status: `accepted -> preparing -> ready -> served`.
4. Optional cancel with reason.

## 6. Functional Requirements
### Menu
- Categories, items, price, availability, modifiers (MVP: single-choice or multi-choice options).
- Owner can mark items unavailable in real time.

### Table/session matching
- Dine-in orders must include one of:
  - Table from QR
  - Manual table code validated against venue tables
  - Staff-issued short PIN linked to active table session
- Bar/pickup orders can omit `table_id`, but must include `service_mode`.

### QR handling
- QR encodes opaque `token` only (not raw IDs).
- Token lookup maps to venue/table context.
- Token can be rotated/revoked by owner.

### Order lifecycle
- Statuses: `pending`, `accepted`, `preparing`, `ready`, `served`, `canceled`.
- Audit timestamps per status transition.

## 7. Non-Functional Requirements (MVP)
- Mobile-first UI.
- P95 menu load < 2s on typical 4G.
- Basic auth + role-based access.
- Soft-delete for menu items/tables/orders not required in MVP (hard delete restricted by foreign keys).

## 8. Data Model (SQL-first draft)
```sql
create table venues (
  id uuid primary key,
  name text not null,
  slug text unique not null,
  timezone text not null default 'Europe/Berlin',
  created_at timestamptz not null default now()
);

create table users (
  id uuid primary key,
  email text unique not null,
  full_name text,
  created_at timestamptz not null default now()
);

create table venue_members (
  venue_id uuid not null references venues(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('owner', 'staff')),
  primary key (venue_id, user_id)
);

create table tables (
  id uuid primary key,
  venue_id uuid not null references venues(id) on delete cascade,
  label text not null,
  active boolean not null default true,
  unique (venue_id, label)
);

create table menus (
  id uuid primary key,
  venue_id uuid not null references venues(id) on delete cascade,
  name text not null,
  active boolean not null default true
);

create table menu_categories (
  id uuid primary key,
  menu_id uuid not null references menus(id) on delete cascade,
  name text not null,
  sort_order int not null default 0
);

create table menu_items (
  id uuid primary key,
  category_id uuid not null references menu_categories(id) on delete cascade,
  name text not null,
  description text,
  price_cents int not null check (price_cents >= 0),
  currency char(3) not null default 'EUR',
  is_available boolean not null default true,
  sort_order int not null default 0
);

create table qr_tokens (
  token text primary key,
  venue_id uuid not null references venues(id) on delete cascade,
  table_id uuid references tables(id) on delete set null,
  mode text not null check (mode in ('table', 'venue_shared')),
  active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table table_sessions (
  id uuid primary key,
  venue_id uuid not null references venues(id) on delete cascade,
  table_id uuid not null references tables(id) on delete cascade,
  pin text,
  status text not null check (status in ('open', 'closed')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz
);

create table orders (
  id uuid primary key,
  venue_id uuid not null references venues(id) on delete cascade,
  table_id uuid references tables(id) on delete set null,
  table_session_id uuid references table_sessions(id) on delete set null,
  service_mode text not null check (service_mode in ('dine_in', 'bar', 'pickup')),
  status text not null check (status in ('pending', 'accepted', 'preparing', 'ready', 'served', 'canceled')),
  customer_note text,
  total_cents int not null check (total_cents >= 0),
  currency char(3) not null default 'EUR',
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  preparing_at timestamptz,
  ready_at timestamptz,
  served_at timestamptz,
  canceled_at timestamptz
);

create table order_items (
  id uuid primary key,
  order_id uuid not null references orders(id) on delete cascade,
  menu_item_id uuid not null references menu_items(id),
  item_name_snapshot text not null,
  unit_price_cents_snapshot int not null,
  quantity int not null check (quantity > 0),
  line_total_cents int not null check (line_total_cents >= 0)
);
```

## 9. API Design (MVP)
### Auth & Venue
- `POST /auth/login`
- `POST /auth/register`
- `GET /me`
- `POST /venues`
- `GET /venues/:venueId`
- `POST /venues/:venueId/members`

### Menu Management
- `POST /venues/:venueId/menus`
- `GET /venues/:venueId/menus/active`
- `POST /menus/:menuId/categories`
- `POST /categories/:categoryId/items`
- `PATCH /items/:itemId`

### QR + Table Context
- `POST /venues/:venueId/qr-tokens` (create table or shared token)
- `POST /venues/:venueId/qr-tokens/batch` (per-table generation)
- `POST /qr/resolve` body: `{ "token": "..." }`
  - Returns: venue info, optional table info, service modes.
- `POST /venues/:venueId/table-sessions/open`
- `POST /venues/:venueId/table-sessions/:sessionId/close`
- `POST /venues/:venueId/table-lookup` body: `{ "label": "A12" }`

### Orders
- `POST /orders`
  - Validation:
    - `dine_in` requires `table_id` or `table_session_id`.
    - `bar`/`pickup` may omit table.
- `GET /venues/:venueId/orders?status=pending`
- `PATCH /orders/:orderId/status`
- `GET /orders/:orderId`

## 10. Key Validation Rules
- Table entered manually must belong to same venue and be active.
- QR token must be active and not expired.
- Only staff/owner can transition order statuses.
- Illegal status jumps rejected (e.g., `pending -> ready`).

## 11. Suggested MVP Screens
### Customer
- QR landing/menu
- Item detail + modifiers
- Cart
- Table/service mode confirmation
- Order tracking

### Owner/Staff
- Login
- Venue setup
- Menu editor
- Table manager
- QR generator
- Live order board

## 12. Milestones (Implementation Plan)
1. Backend foundation: auth, venues, menu CRUD, Postgres schema.
2. QR context: token generation + resolve endpoint.
3. Customer ordering flow with table confirmation logic.
4. Staff order board + status transitions.
5. Basic polish: error states, role permissions, simple analytics counters.

## 13. MVP Success Metrics
- Time from scan to placed order: median < 90s.
- Order-table mismatch rate: < 2%.
- Owner setup completion rate (create first menu + first QR): > 70%.
- Staff accepts new order within 2 minutes (median).
