-- KL-INV-001: Warenwirtschaft, Lagerorte, Rezepte & unveränderliche Lagerbewegungen (Blueprint §11 & Meilenstein 4).
--
-- Implementiert den Warenwirtschaftskern mit striktem Append-Only Ledger:
-- 1. Lagerorte (`inventory_stock_locations`), Zutaten (`inventory_ingredients`), Rezepte & Komponenten (`inventory_recipes`, `inventory_recipe_components`).
-- 2. Unveränderliche Lagerbewegungen (`inventory_stock_movements`) mit Kategorien:
--    - Wareneingang (`receipt`), Verbrauch (`consumption`), Verderb/Bruch (`waste`)
--    - Korrekturen (`correction_increase`, `correction_decrease`)
--    - Lagerorttransfers (`transfer_out`, `transfer_in`)
--    - Vorbestellungs-Reservierungen (`reservation`, `release`)
--    - Stornos/Gegenbuchungen (`reversal`)
-- 3. Lieferanten & Einkauf (`inventory_suppliers`, `inventory_purchase_orders`).
-- 4. Betreiber RPCs:
--    - `operator_get_inventory_levels`: Berechnet physischen, reservierten und verfügbaren Bestand je Zutat & Ort.
--    - `operator_record_stock_movement`: Verbucht eine unveränderliche Bewegung mit Idempotenz-Prüfung.
--    - `operator_book_inventory_audit`: Inventur-Abgleich (Soll/Ist-Vergleich mit automatischer Korrekturbuchung).
--    - `operator_get_replenishment_suggestions`: Bestellvorschläge bei Unterschreitung von Mindestbeständen.

begin;

-- ============================================================================
-- 1. Lagerorte
-- ============================================================================

create table if not exists public.inventory_stock_locations (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null,
  kind text not null default 'storage' check (kind in ('kitchen', 'bar', 'cellar', 'storage', 'receiving')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (venue_id, name)
);

create index if not exists inventory_locations_venue_idx on public.inventory_stock_locations(venue_id);

alter table public.inventory_stock_locations enable row level security;

create policy "inventory_locations_staff_all" on public.inventory_stock_locations
  for all to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. Zutaten
-- ============================================================================

create table if not exists public.inventory_ingredients (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null,
  base_unit text not null check (base_unit in ('g', 'ml', 'count')),
  minimum_stock numeric(12, 3) not null default 0 check (minimum_stock >= 0),
  target_stock numeric(12, 3) not null default 0 check (target_stock >= minimum_stock),
  cost_cents_per_base_unit numeric(12, 4) not null default 0 check (cost_cents_per_base_unit >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (venue_id, name)
);

create index if not exists inventory_ingredients_venue_idx on public.inventory_ingredients(venue_id);

alter table public.inventory_ingredients enable row level security;

create policy "inventory_ingredients_staff_all" on public.inventory_ingredients
  for all to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 3. Rezepte & Komponenten
-- ============================================================================

create table if not exists public.inventory_recipes (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null,
  sales_item_id uuid,
  yield_servings int not null default 1 check (yield_servings > 0),
  created_at timestamptz not null default now(),
  unique (venue_id, name)
);

create index if not exists inventory_recipes_venue_idx on public.inventory_recipes(venue_id);

alter table public.inventory_recipes enable row level security;

create policy "inventory_recipes_staff_all" on public.inventory_recipes
  for all to authenticated using (public.is_venue_staff(venue_id));

create table if not exists public.inventory_recipe_components (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.inventory_recipes(id) on delete cascade,
  ingredient_id uuid not null references public.inventory_ingredients(id) on delete cascade,
  quantity numeric(12, 3) not null check (quantity > 0),
  unit text not null check (unit in ('g', 'kg', 'ml', 'l', 'count')),
  note text,
  unique (recipe_id, ingredient_id)
);

create index if not exists inventory_components_recipe_idx on public.inventory_recipe_components(recipe_id);

alter table public.inventory_recipe_components enable row level security;

create policy "inventory_components_staff_all" on public.inventory_recipe_components
  for all to authenticated using (
    exists (
      select 1 from public.inventory_recipes r
      where r.id = inventory_recipe_components.recipe_id
        and public.is_venue_staff(r.venue_id)
    )
  );

-- ============================================================================
-- 4. Append-Only Bestandsledger
-- ============================================================================

create table if not exists public.inventory_stock_movements (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  ingredient_id uuid not null references public.inventory_ingredients(id) on delete restrict,
  location_id uuid not null references public.inventory_stock_locations(id) on delete restrict,
  kind text not null check (kind in (
    'receipt', 'consumption', 'waste', 'correction_increase', 'correction_decrease',
    'transfer_out', 'transfer_in', 'reservation', 'release', 'reversal'
  )),
  quantity numeric(12, 3) not null check (quantity > 0),
  unit text not null check (unit in ('g', 'ml', 'count')),
  reference text,
  idempotency_key text,
  reversal_of_id uuid references public.inventory_stock_movements(id),
  transfer_group_id uuid,
  note text,
  created_by uuid,
  created_at timestamptz not null default now()
);

create index if not exists inventory_movements_venue_idx on public.inventory_stock_movements(venue_id, ingredient_id);
create index if not exists inventory_movements_loc_idx on public.inventory_stock_movements(venue_id, location_id);
create unique index if not exists inventory_movements_idempotency_idx on public.inventory_stock_movements(venue_id, idempotency_key)
  where idempotency_key is not null;

alter table public.inventory_stock_movements enable row level security;

create policy "inventory_movements_staff_select" on public.inventory_stock_movements
  for select to authenticated using (public.is_venue_staff(venue_id));

create policy "inventory_movements_staff_insert" on public.inventory_stock_movements
  for insert to authenticated with check (public.is_venue_staff(venue_id));

-- ============================================================================
-- 5. Lieferanten & Einkauf
-- ============================================================================

create table if not exists public.inventory_suppliers (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null,
  contact text,
  lead_time_days int not null default 2 check (lead_time_days >= 0),
  created_at timestamptz not null default now(),
  unique (venue_id, name)
);

create index if not exists inventory_suppliers_venue_idx on public.inventory_suppliers(venue_id);

alter table public.inventory_suppliers enable row level security;

create policy "inventory_suppliers_staff_all" on public.inventory_suppliers
  for all to authenticated using (public.is_venue_staff(venue_id));

create table if not exists public.inventory_purchase_orders (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  supplier_id uuid not null references public.inventory_suppliers(id) on delete restrict,
  order_number text not null,
  status text not null default 'draft' check (status in ('draft', 'sent', 'received', 'cancelled')),
  expected_delivery_date date,
  total_cents int not null default 0 check (total_cents >= 0),
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (venue_id, order_number)
);

create index if not exists inventory_purchase_orders_venue_idx on public.inventory_purchase_orders(venue_id);

alter table public.inventory_purchase_orders enable row level security;

create policy "inventory_purchase_orders_staff_all" on public.inventory_purchase_orders
  for all to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 6. Betreiber RPC: Aktuelle Bestandsstufen berechnen
-- ============================================================================

create or replace function public.operator_get_inventory_levels(
  p_venue_id uuid,
  p_location_id uuid default null
)
returns table (
  ingredient_id uuid,
  ingredient_name text,
  base_unit text,
  location_id uuid,
  location_name text,
  physical_stock numeric,
  reserved_stock numeric,
  available_stock numeric,
  minimum_stock numeric,
  target_stock numeric,
  status text
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
  with movement_sums as (
    select
      m.ingredient_id,
      m.location_id,
      coalesce(sum(
        case
          when m.kind in ('receipt', 'correction_increase', 'transfer_in') then m.quantity
          when m.kind in ('consumption', 'waste', 'correction_decrease', 'transfer_out') then -m.quantity
          else 0
        end
      ), 0) as physical_qty,
      coalesce(sum(
        case
          when m.kind = 'reservation' then m.quantity
          when m.kind = 'release' then -m.quantity
          else 0
        end
      ), 0) as reserved_qty
    from public.inventory_stock_movements m
    where m.venue_id = p_venue_id
      and (p_location_id is null or m.location_id = p_location_id)
    group by m.ingredient_id, m.location_id
  )
  select
    i.id as ingredient_id,
    i.name as ingredient_name,
    i.base_unit,
    l.id as location_id,
    l.name as location_name,
    coalesce(ms.physical_qty, 0) as physical_stock,
    coalesce(ms.reserved_qty, 0) as reserved_stock,
    (coalesce(ms.physical_qty, 0) - coalesce(ms.reserved_qty, 0)) as available_stock,
    i.minimum_stock,
    i.target_stock,
    case
      when (coalesce(ms.physical_qty, 0) - coalesce(ms.reserved_qty, 0)) <= (i.minimum_stock * 0.5) then 'critical'
      when (coalesce(ms.physical_qty, 0) - coalesce(ms.reserved_qty, 0)) <= i.minimum_stock then 'warning'
      else 'ok'
    end as status
  from public.inventory_ingredients i
  cross join public.inventory_stock_locations l
  left join movement_sums ms on ms.ingredient_id = i.id and ms.location_id = l.id
  where i.venue_id = p_venue_id
    and l.venue_id = p_venue_id
    and i.is_active
    and l.is_active
    and (p_location_id is null or l.id = p_location_id)
  order by i.name asc, l.name asc;
end;
$$;

-- ============================================================================
-- 7. Betreiber RPC: Bewegung erfassen (Append-Only)
-- ============================================================================

create or replace function public.operator_record_stock_movement(
  p_venue_id uuid,
  p_ingredient_id uuid,
  p_location_id uuid,
  p_kind text,
  p_quantity numeric,
  p_unit text,
  p_reference text default null,
  p_note text default null,
  p_idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_movement_id uuid;
  v_existing_id uuid;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  if p_quantity <= 0 then
    raise exception 'invalid_quantity: Menge muss groesser 0 sein';
  end if;

  if p_idempotency_key is not null then
    select id into v_existing_id
    from public.inventory_stock_movements
    where venue_id = p_venue_id and idempotency_key = p_idempotency_key;

    if found then
      return v_existing_id;
    end if;
  end if;

  insert into public.inventory_stock_movements (
    venue_id, ingredient_id, location_id, kind, quantity, unit,
    reference, note, idempotency_key, created_by
  ) values (
    p_venue_id, p_ingredient_id, p_location_id, p_kind, p_quantity, p_unit,
    p_reference, p_note, p_idempotency_key, auth.uid()
  ) returning id into v_movement_id;

  return v_movement_id;
end;
$$;

-- ============================================================================
-- 8. Betreiber RPC: Inventur-Abgleich (Soll/Ist-Vergleich)
-- ============================================================================

create or replace function public.operator_book_inventory_audit(
  p_venue_id uuid,
  p_location_id uuid,
  p_counts jsonb,
  p_audit_note text default 'Inventur-Zaehlung'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_ingredient_id uuid;
  v_counted_qty numeric;
  v_current_qty numeric;
  v_diff numeric;
  v_unit text;
  v_corrections_count int := 0;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  for v_item in select * from jsonb_array_elements(p_counts) loop
    v_ingredient_id := (v_item->>'ingredient_id')::uuid;
    v_counted_qty := (v_item->>'counted_quantity')::numeric;

    select base_unit into v_unit
    from public.inventory_ingredients
    where id = v_ingredient_id and venue_id = p_venue_id;

    if found and v_counted_qty >= 0 then
      -- Aktuellen physischen Bestand an diesem Lagerort ermitteln
      select coalesce(sum(
        case
          when m.kind in ('receipt', 'correction_increase', 'transfer_in') then m.quantity
          when m.kind in ('consumption', 'waste', 'correction_decrease', 'transfer_out') then -m.quantity
          else 0
        end
      ), 0) into v_current_qty
      from public.inventory_stock_movements m
      where m.venue_id = p_venue_id
        and m.location_id = p_location_id
        and m.ingredient_id = v_ingredient_id;

      v_diff := v_counted_qty - v_current_qty;

      if v_diff > 0 then
        insert into public.inventory_stock_movements (
          venue_id, ingredient_id, location_id, kind, quantity, unit, note, created_by
        ) values (
          p_venue_id, v_ingredient_id, p_location_id, 'correction_increase', v_diff, v_unit,
          concat(p_audit_note, ': Ist ', v_counted_qty, ' > Soll ', v_current_qty), auth.uid()
        );
        v_corrections_count := v_corrections_count + 1;
      elsif v_diff < 0 then
        insert into public.inventory_stock_movements (
          venue_id, ingredient_id, location_id, kind, quantity, unit, note, created_by
        ) values (
          p_venue_id, v_ingredient_id, p_location_id, 'correction_decrease', abs(v_diff), v_unit,
          concat(p_audit_note, ': Ist ', v_counted_qty, ' < Soll ', v_current_qty), auth.uid()
        );
        v_corrections_count := v_corrections_count + 1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'corrections_booked', v_corrections_count
  );
end;
$$;

-- ============================================================================
-- 9. Betreiber RPC: Bestellvorschläge (Replenishment)
-- ============================================================================

create or replace function public.operator_get_replenishment_suggestions(
  p_venue_id uuid
)
returns table (
  ingredient_id uuid,
  ingredient_name text,
  base_unit text,
  current_available numeric,
  minimum_stock numeric,
  target_stock numeric,
  suggested_order_quantity numeric
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
  with total_stocks as (
    select
      m.ingredient_id,
      coalesce(sum(
        case
          when m.kind in ('receipt', 'correction_increase', 'transfer_in') then m.quantity
          when m.kind in ('consumption', 'waste', 'correction_decrease', 'transfer_out') then -m.quantity
          when m.kind = 'reservation' then -m.quantity
          when m.kind = 'release' then m.quantity
          else 0
        end
      ), 0) as available_qty
    from public.inventory_stock_movements m
    where m.venue_id = p_venue_id
    group by m.ingredient_id
  )
  select
    i.id as ingredient_id,
    i.name as ingredient_name,
    i.base_unit,
    coalesce(ts.available_qty, 0) as current_available,
    i.minimum_stock,
    i.target_stock,
    (i.target_stock - coalesce(ts.available_qty, 0)) as suggested_order_quantity
  from public.inventory_ingredients i
  left join total_stocks ts on ts.ingredient_id = i.id
  where i.venue_id = p_venue_id
    and i.is_active
    and coalesce(ts.available_qty, 0) <= i.minimum_stock
  order by (i.minimum_stock - coalesce(ts.available_qty, 0)) desc;
end;
$$;

commit;
