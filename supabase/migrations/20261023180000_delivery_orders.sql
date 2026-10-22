-- KL-DELIVERY-001: Eigener Lieferbetrieb, Fahrerzuweisung & Tourenstatus (Blueprint §12 & Meilenstein 3).
--
-- Unterstützt den Lieferbetrieb für Betreiber und Fahrer:
-- 1. Liefergebiete (Postleitzahlen, Mindestbestellwert, Liefergebühr).
-- 2. Lieferattribute auf Bestellungen (Adresse, Empfänger, Telefon, Fahrer, Zeitstempel, Zahlungsart bei Lieferung).
-- 3. Betreiber-RPCs:
--    - `operator_list_deliveries`: Liefert offene, aktive Touren und zugestellte Lieferungen inkl. Speisen.
--    - `operator_assign_delivery_driver`: Weist einer Bestellung einen Fahrer zu.
--    - `operator_update_delivery_status`: Statuswechsel (pending -> assigned -> out_for_delivery -> delivered / failed).
--    - `operator_list_delivery_areas` & `operator_upsert_delivery_area`: Liefergebiete pflegen.

begin;

-- ============================================================================
-- 1. Liefergebiete
-- ============================================================================

create table if not exists public.delivery_areas (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  postal_code text not null,
  city text not null,
  min_order_cents int not null default 1500 check (min_order_cents >= 0),
  delivery_fee_cents int not null default 250 check (delivery_fee_cents >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (venue_id, postal_code)
);

create index if not exists delivery_areas_venue_idx on public.delivery_areas(venue_id);

alter table public.delivery_areas enable row level security;

drop policy if exists "delivery_areas_public_read" on public.delivery_areas;
create policy "delivery_areas_public_read" on public.delivery_areas
  for select to anon, authenticated using (true);

drop policy if exists "delivery_areas_staff_write" on public.delivery_areas;
create policy "delivery_areas_staff_write" on public.delivery_areas
  for all to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. Bestellungen um Lieferdaten erweitern
-- ============================================================================

alter table public.orders
  add column if not exists delivery_street text,
  add column if not exists delivery_house_number text,
  add column if not exists delivery_postal_code text,
  add column if not exists delivery_city text,
  add column if not exists delivery_recipient_name text,
  add column if not exists delivery_phone text,
  add column if not exists delivery_status text check (delivery_status is null or delivery_status in ('pending', 'assigned', 'out_for_delivery', 'delivered', 'failed')),
  add column if not exists delivery_driver_id uuid,
  add column if not exists delivery_driver_name text,
  add column if not exists delivery_assigned_at timestamptz,
  add column if not exists delivery_dispatched_at timestamptz,
  add column if not exists delivery_delivered_at timestamptz,
  add column if not exists delivery_failed_reason text,
  add column if not exists delivery_payment_method text not null default 'online' check (delivery_payment_method in ('online', 'cash_on_delivery', 'card_on_delivery')),
  add column if not exists delivery_fee_cents int not null default 0;

create index if not exists orders_delivery_status_idx on public.orders(venue_id, delivery_status)
  where delivery_status is not null;

-- ============================================================================
-- 3. Betreiber RPC: Lieferbestellungen auflisten
-- ============================================================================

create or replace function public.operator_list_deliveries(
  p_venue_id uuid,
  p_status_filter text default null
)
returns table (
  order_id uuid,
  order_number text,
  delivery_status text,
  recipient_name text,
  phone text,
  street text,
  house_number text,
  postal_code text,
  city text,
  customer_note text,
  total_cents int,
  delivery_fee_cents int,
  payment_method text,
  driver_id uuid,
  driver_name text,
  created_at timestamptz,
  assigned_at timestamptz,
  dispatched_at timestamptz,
  delivered_at timestamptz,
  failed_reason text,
  items_summary text,
  item_count int
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  return query
  select
    o.id as order_id,
    upper(substring(o.id::text from 1 for 6)) as order_number,
    coalesce(o.delivery_status, 'pending') as delivery_status,
    coalesce(o.delivery_recipient_name, 'Gast') as recipient_name,
    o.delivery_phone as phone,
    coalesce(o.delivery_street, '') as street,
    coalesce(o.delivery_house_number, '') as house_number,
    coalesce(o.delivery_postal_code, '') as postal_code,
    coalesce(o.delivery_city, '') as city,
    o.customer_note,
    o.total_cents,
    o.delivery_fee_cents,
    o.delivery_payment_method as payment_method,
    o.delivery_driver_id as driver_id,
    o.delivery_driver_name as driver_name,
    o.created_at,
    o.delivery_assigned_at as assigned_at,
    o.delivery_dispatched_at as dispatched_at,
    o.delivery_delivered_at as delivered_at,
    o.delivery_failed_reason as failed_reason,
    coalesce(
      (
        select string_agg(concat(oi.quantity, 'x ', oi.item_name), ', ')
        from public.order_items oi
        where oi.order_id = o.id
      ),
      'Speisen'
    ) as items_summary,
    coalesce(
      (
        select sum(oi.quantity)::int
        from public.order_items oi
        where oi.order_id = o.id
      ),
      1
    ) as item_count
  from public.orders o
  where o.venue_id = p_venue_id
    and (o.service_mode = 'delivery' or o.delivery_status is not null)
    and (p_status_filter is null or o.delivery_status = p_status_filter)
  order by o.created_at desc;
end;
$$;

-- ============================================================================
-- 4. Betreiber RPC: Fahrer zuweisen
-- ============================================================================

create or replace function public.operator_assign_delivery_driver(
  p_venue_id uuid,
  p_order_id uuid,
  p_driver_id uuid,
  p_driver_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  select true into v_exists
  from public.orders
  where id = p_order_id and venue_id = p_venue_id;

  if not found then
    raise exception 'not_found: Bestellung nicht gefunden';
  end if;

  update public.orders
  set
    delivery_driver_id = p_driver_id,
    delivery_driver_name = trim(p_driver_name),
    delivery_status = 'assigned',
    delivery_assigned_at = now()
  where id = p_order_id and venue_id = p_venue_id;
end;
$$;

-- ============================================================================
-- 5. Betreiber RPC: Lieferstatus aktualisieren
-- ============================================================================

create or replace function public.operator_update_delivery_status(
  p_venue_id uuid,
  p_order_id uuid,
  p_new_status text,
  p_failure_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  if p_new_status not in ('pending', 'assigned', 'out_for_delivery', 'delivered', 'failed') then
    raise exception 'invalid_status: %', p_new_status;
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and venue_id = p_venue_id;

  if not found then
    raise exception 'not_found: Bestellung nicht gefunden';
  end if;

  update public.orders
  set
    delivery_status = p_new_status,
    delivery_dispatched_at = case
      when p_new_status = 'out_for_delivery' and delivery_dispatched_at is null then now()
      else delivery_dispatched_at
    end,
    delivery_delivered_at = case
      when p_new_status = 'delivered' then now()
      else delivery_delivered_at
    end,
    delivery_failed_reason = case
      when p_new_status = 'failed' then coalesce(p_failure_reason, 'Lieferung fehlgeschlagen')
      else null
    end
  where id = p_order_id and venue_id = p_venue_id;
end;
$$;

-- ============================================================================
-- 6. Betreiber RPC: Liefergebiete verwalten
-- ============================================================================

create or replace function public.operator_list_delivery_areas(
  p_venue_id uuid
)
returns setof public.delivery_areas
language sql
security definer
set search_path = public
stable
as $$
  select * from public.delivery_areas
  where venue_id = p_venue_id
  order by postal_code asc;
$$;

create or replace function public.operator_upsert_delivery_area(
  p_venue_id uuid,
  p_postal_code text,
  p_city text,
  p_min_order_cents int,
  p_delivery_fee_cents int,
  p_is_active boolean default true
)
returns public.delivery_areas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.delivery_areas;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  insert into public.delivery_areas (
    venue_id, postal_code, city, min_order_cents, delivery_fee_cents, is_active
  )
  values (
    p_venue_id, trim(p_postal_code), trim(p_city), p_min_order_cents, p_delivery_fee_cents, p_is_active
  )
  on conflict (venue_id, postal_code) do update
  set
    city = excluded.city,
    min_order_cents = excluded.min_order_cents,
    delivery_fee_cents = excluded.delivery_fee_cents,
    is_active = excluded.is_active
  returning * into v_result;

  return v_result;
end;
$$;

commit;
