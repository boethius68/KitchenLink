begin;

create extension if not exists pgcrypto;

create table if not exists public.venues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  timezone text not null default 'Europe/Berlin',
  created_at timestamptz not null default now()
);

create table if not exists public.tables (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  label text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (venue_id, label)
);

create index if not exists tables_venue_id_idx on public.tables(venue_id);

create table if not exists public.menus (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null default 'Standard',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists menus_venue_id_idx on public.menus(venue_id);

create table if not exists public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  menu_id uuid not null references public.menus(id) on delete cascade,
  name text not null,
  subtitle text,
  kind text not null default 'food' check (kind in ('food', 'drink')),
  sort_order int not null default 0,
  allergen_legend jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists menu_categories_menu_id_idx on public.menu_categories(menu_id);

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.menu_categories(id) on delete cascade,
  name text not null,
  description text not null default '',
  price_cents int not null check (price_cents >= 0),
  currency char(3) not null default 'EUR',
  kind text not null default 'food' check (kind in ('food', 'drink')),
  allergen_codes text[] not null default '{}',
  variant_options jsonb not null default '[]'::jsonb,
  available boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists menu_items_category_id_idx on public.menu_items(category_id);

create table if not exists public.qr_tokens (
  token text primary key,
  venue_id uuid not null references public.venues(id) on delete cascade,
  table_id uuid references public.tables(id) on delete set null,
  mode text not null check (mode in ('table', 'venue_shared')),
  active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists qr_tokens_venue_id_idx on public.qr_tokens(venue_id);
create index if not exists qr_tokens_table_id_idx on public.qr_tokens(table_id);

create table if not exists public.table_sessions (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  table_id uuid not null references public.tables(id) on delete cascade,
  pin text,
  status text not null default 'open' check (status in ('open', 'closed')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz
);

create index if not exists table_sessions_venue_id_idx on public.table_sessions(venue_id);
create index if not exists table_sessions_table_id_idx on public.table_sessions(table_id);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  source_device text not null default 'unknown',
  total_cents int not null default 0 check (total_cents >= 0),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'preparing', 'ready', 'served', 'canceled'))
);

alter table public.orders
  add column if not exists venue_id uuid references public.venues(id) on delete set null,
  add column if not exists table_id uuid references public.tables(id) on delete set null,
  add column if not exists table_session_id uuid references public.table_sessions(id) on delete set null,
  add column if not exists service_mode text check (service_mode in ('dine_in', 'bar', 'pickup')),
  add column if not exists customer_note text not null default '',
  add column if not exists currency char(3) not null default 'EUR',
  add column if not exists accepted_at timestamptz,
  add column if not exists preparing_at timestamptz,
  add column if not exists ready_at timestamptz,
  add column if not exists served_at timestamptz,
  add column if not exists canceled_at timestamptz;

create index if not exists orders_venue_id_idx on public.orders(venue_id);
create index if not exists orders_table_id_idx on public.orders(table_id);
create index if not exists orders_status_idx on public.orders(status);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  name text not null,
  quantity int not null check (quantity > 0),
  unit_price_cents int not null check (unit_price_cents >= 0),
  kind text not null default 'food' check (kind in ('food', 'drink'))
);

alter table public.order_items
  add column if not exists menu_item_id uuid references public.menu_items(id) on delete set null,
  add column if not exists created_at timestamptz not null default now();

create index if not exists order_items_order_id_idx on public.order_items(order_id);

commit;
