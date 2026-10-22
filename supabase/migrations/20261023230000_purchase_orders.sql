-- KL-PURCHASE-001: Lieferantenbestellungen & automatischer Wareneingang (Blueprint §11 & Meilenstein 4).
--
-- Unterstützt den Bestell- und Beschaffungszyklus für Gastronomen:
-- 1. Tabelle `inventory_purchase_order_lines` für Bestellpositionen.
-- 2. Zeitstempel `received_at` und `sent_at` auf `inventory_purchase_orders`.
-- 3. Betreiber RPCs:
--    - `operator_list_purchase_orders`: Liefert Bestellungen inkl. Lieferanteninfo und Positionen.
--    - `operator_create_purchase_order`: Erstellt eine Lieferantenbestellung mit Positionen.
--    - `operator_send_purchase_order`: Markiert die Bestellung als an den Lieferanten versendet ('sent').
--    - `operator_receive_purchase_order`: Bucht bei Warenanlieferung alle Positionen automatisch als
--      'receipt' in das Bestandsledger und schließt die Bestellung ab ('received').

begin;

-- ============================================================================
-- 1. Schema-Erweiterungen
-- ============================================================================

alter table public.inventory_purchase_orders
  add column if not exists sent_at timestamptz,
  add column if not exists received_at timestamptz,
  add column if not exists notes text;

create table if not exists public.inventory_purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.inventory_purchase_orders(id) on delete cascade,
  ingredient_id uuid not null references public.inventory_ingredients(id) on delete restrict,
  quantity numeric(12, 3) not null check (quantity > 0),
  unit text not null check (unit in ('g', 'kg', 'ml', 'l', 'count')),
  price_per_unit_cents int not null default 0 check (price_per_unit_cents >= 0),
  created_at timestamptz not null default now()
);

create index if not exists inventory_po_lines_po_idx on public.inventory_purchase_order_lines(purchase_order_id);

alter table public.inventory_purchase_order_lines enable row level security;

create policy "inventory_po_lines_staff_all" on public.inventory_purchase_order_lines
  for all to authenticated using (
    exists (
      select 1 from public.inventory_purchase_orders po
      where po.id = inventory_purchase_order_lines.purchase_order_id
        and public.is_venue_staff(po.venue_id)
    )
  );

-- ============================================================================
-- 2. Betreiber RPC: Lieferantenbestellungen auflisten
-- ============================================================================

create or replace function public.operator_list_purchase_orders(
  p_venue_id uuid,
  p_status_filter text default null
)
returns table (
  order_id uuid,
  order_number text,
  supplier_id uuid,
  supplier_name text,
  supplier_contact text,
  status text,
  total_cents int,
  expected_delivery_date date,
  created_at timestamptz,
  sent_at timestamptz,
  received_at timestamptz,
  notes text,
  line_count int,
  lines jsonb
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
    po.id as order_id,
    po.order_number,
    po.supplier_id,
    s.name as supplier_name,
    s.contact as supplier_contact,
    po.status,
    po.total_cents,
    po.expected_delivery_date,
    po.created_at,
    po.sent_at,
    po.received_at,
    po.notes,
    coalesce(
      (
        select count(*)::int
        from public.inventory_purchase_order_lines pol
        where pol.purchase_order_id = po.id
      ),
      0
    ) as line_count,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'line_id', pol.id,
            'ingredient_id', pol.ingredient_id,
            'ingredient_name', i.name,
            'quantity', pol.quantity,
            'unit', pol.unit,
            'price_per_unit_cents', pol.price_per_unit_cents
          )
        )
        from public.inventory_purchase_order_lines pol
        join public.inventory_ingredients i on i.id = pol.ingredient_id
        where pol.purchase_order_id = po.id
      ),
      '[]'::jsonb
    ) as lines
  from public.inventory_purchase_orders po
  join public.inventory_suppliers s on s.id = po.supplier_id
  where po.venue_id = p_venue_id
    and (p_status_filter is null or po.status = p_status_filter)
  order by po.created_at desc;
end;
$$;

-- ============================================================================
-- 3. Betreiber RPC: Lieferantenbestellung erstellen
-- ============================================================================

create or replace function public.operator_create_purchase_order(
  p_venue_id uuid,
  p_supplier_id uuid,
  p_order_number text,
  p_expected_date date,
  p_lines jsonb,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_po_id uuid;
  v_line jsonb;
  v_total_cents int := 0;
  v_ingredient_id uuid;
  v_quantity numeric;
  v_unit text;
  v_price_cents int;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  insert into public.inventory_purchase_orders (
    venue_id, supplier_id, order_number, expected_delivery_date,
    status, total_cents, notes, created_by
  ) values (
    p_venue_id, p_supplier_id, trim(p_order_number), p_expected_date,
    'draft', 0, p_notes, auth.uid()
  ) returning id into v_po_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_ingredient_id := (v_line->>'ingredient_id')::uuid;
    v_quantity := (v_line->>'quantity')::numeric;
    v_unit := v_line->>'unit';
    v_price_cents := coalesce((v_line->>'price_per_unit_cents')::int, 0);

    if v_quantity > 0 then
      insert into public.inventory_purchase_order_lines (
        purchase_order_id, ingredient_id, quantity, unit, price_per_unit_cents
      ) values (
        v_po_id, v_ingredient_id, v_quantity, v_unit, v_price_cents
      );

      v_total_cents := v_total_cents + (v_quantity * v_price_cents)::int;
    end if;
  end loop;

  update public.inventory_purchase_orders
  set total_cents = v_total_cents
  where id = v_po_id;

  return v_po_id;
end;
$$;

-- ============================================================================
-- 4. Betreiber RPC: Bestellung versenden
-- ============================================================================

create or replace function public.operator_send_purchase_order(
  p_venue_id uuid,
  p_order_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  update public.inventory_purchase_orders
  set
    status = 'sent',
    sent_at = now()
  where id = p_order_id and venue_id = p_venue_id and status = 'draft';

  if not found then
    raise exception 'invalid_transition: Bestellung nicht gefunden oder nicht im Entwurf';
  end if;
end;
$$;

-- ============================================================================
-- 5. Betreiber RPC: Wareneingang buchen & Bestellung abschließen
-- ============================================================================

create or replace function public.operator_receive_purchase_order(
  p_venue_id uuid,
  p_order_id uuid,
  p_location_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_po record;
  v_line record;
  v_target_location uuid := p_location_id;
  v_receipts_count int := 0;
  v_base_unit text;
  v_canonical_qty numeric;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  select * into v_po
  from public.inventory_purchase_orders
  where id = p_order_id and venue_id = p_venue_id;

  if not found then
    raise exception 'not_found: Bestellung nicht gefunden';
  end if;

  if v_po.status = 'received' then
    return jsonb_build_object('ok', true, 'replayed', true, 'receipts_booked', 0);
  end if;

  -- Standard-Wareneingangslagerort ermitteln
  if v_target_location is null then
    select id into v_target_location
    from public.inventory_stock_locations
    where venue_id = p_venue_id and is_active and kind in ('receiving', 'storage', 'kitchen')
    order by case kind when 'receiving' then 1 when 'storage' then 2 else 3 end
    limit 1;
  end if;

  if v_target_location is null then
    raise exception 'no_location: Kein aktiver Lagerort für den Wareneingang vorhanden';
  end if;

  -- Alle Positionen als Wareneingang im Ledger erfassen
  for v_line in
    select pol.id as line_id, pol.ingredient_id, pol.quantity, pol.unit, i.name as ingredient_name, i.base_unit
    from public.inventory_purchase_order_lines pol
    join public.inventory_ingredients i on i.id = pol.ingredient_id
    where pol.purchase_order_id = p_order_id
  loop
    -- Umrechnung in Basiseinheit falls kg oder l angegeben wurde
    v_canonical_qty := case
      when v_line.unit = 'kg' and v_line.base_unit = 'g' then v_line.quantity * 1000
      when v_line.unit = 'l' and v_line.base_unit = 'ml' then v_line.quantity * 1000
      else v_line.quantity
    end;

    insert into public.inventory_stock_movements (
      venue_id, ingredient_id, location_id, kind, quantity, unit,
      reference, note, idempotency_key, created_by
    ) values (
      p_venue_id, v_line.ingredient_id, v_target_location, 'receipt', v_canonical_qty, v_line.base_unit,
      concat('po:', p_order_id), concat('Wareneingang Bestellung #', v_po.order_number),
      concat('po_receipt:', p_order_id, ':', v_line.line_id), auth.uid()
    )
    on conflict (venue_id, idempotency_key) do nothing;

    v_receipts_count := v_receipts_count + 1;
  end loop;

  update public.inventory_purchase_orders
  set
    status = 'received',
    received_at = now()
  where id = p_order_id and venue_id = p_venue_id;

  return jsonb_build_object(
    'ok', true,
    'receipts_booked', v_receipts_count,
    'location_id', v_target_location
  );
end;
$$;

commit;
