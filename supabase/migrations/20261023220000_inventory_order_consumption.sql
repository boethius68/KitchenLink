-- KL-INV-002: Automatische Bestandsabbuchung durch Bestellungsabschluss (Blueprint §11 & Meilenstein 4).
--
-- Verbindet abgeschlossene Bestellungen mit der Rezeptauflösung:
-- 1. `operator_consume_order_inventory`: Ermittelt Rezepte für bestellte Gerichte und bucht Komponenten als 'consumption' ab.
-- 2. Bindet die Abbuchung an:
--    - `operator_update_order_status` bei Übergang zu 'served' (KDS Bump / Kellner serviert).
--    - `operator_update_delivery_status` bei Übergang zu 'delivered' (Lieferung erfolgreich).
-- 3. Strikte Idempotenz: Zusammengesetzte Schlüssel (`consume:<order_id>:<order_item_id>:<component_id>`)
--    verhindern Doppelabbuchungen auch bei Wiederholungen und Retries.

begin;

-- ============================================================================
-- 1. Kern-Funktion: Rezeptauflösung & Bestandsabbuchung
-- ============================================================================

create or replace function public.operator_consume_order_inventory(
  p_venue_id uuid,
  p_order_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_recipe record;
  v_comp record;
  v_location_id uuid;
  v_consumed_qty numeric;
  v_movements_count int := 0;
  v_idempotency_key text;
begin
  -- Standard-Lagerort ermitteln (Küche bevorzugt, Fallback auf ersten aktiven Ort)
  select id into v_location_id
  from public.inventory_stock_locations
  where venue_id = p_venue_id and is_active and kind = 'kitchen'
  limit 1;

  if v_location_id is null then
    select id into v_location_id
    from public.inventory_stock_locations
    where venue_id = p_venue_id and is_active
    limit 1;
  end if;

  if v_location_id is null then
    return 0; -- Kein Lagerort vorhanden, leise überspringen
  end if;

  for v_item in
    select oi.id as order_item_id, oi.name, oi.quantity, oi.menu_item_id
    from public.order_items oi
    where oi.order_id = p_order_id
  loop
    -- Finde passendes Rezept
    select r.id, r.yield_servings into v_recipe
    from public.inventory_recipes r
    where r.venue_id = p_venue_id
      and (
        (v_item.menu_item_id is not null and r.sales_item_id = v_item.menu_item_id)
        or lower(trim(r.name)) = lower(trim(v_item.name))
      )
    limit 1;

    if found then
      -- Jede Zutat des Rezepts abbuchen
      for v_comp in
        select rc.id as component_id, rc.ingredient_id, rc.quantity, rc.unit
        from public.inventory_recipe_components rc
        where rc.recipe_id = v_recipe.id
      loop
        v_consumed_qty := (v_item.quantity::numeric * v_comp.quantity) / coalesce(v_recipe.yield_servings, 1)::numeric;
        v_idempotency_key := concat('consume:', p_order_id, ':', v_item.order_item_id, ':', v_comp.component_id);

        insert into public.inventory_stock_movements (
          venue_id, ingredient_id, location_id, kind, quantity, unit,
          reference, note, idempotency_key
        ) values (
          p_venue_id, v_comp.ingredient_id, v_location_id, 'consumption', v_consumed_qty, v_comp.unit,
          concat('order:', p_order_id), concat('Verkauf: ', v_item.quantity, 'x ', v_item.name), v_idempotency_key
        )
        on conflict (venue_id, idempotency_key) do nothing;

        v_movements_count := v_movements_count + 1;
      end loop;
    end if;
  end loop;

  return v_movements_count;
end;
$$;

-- ============================================================================
-- 2. Hook in operator_update_order_status
-- ============================================================================

create or replace function public.operator_update_order_status(
  p_order_id uuid,
  p_target_status text
) returns table (
  order_id uuid,
  status text,
  replayed boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_order record;
  v_current_rank int;
  v_target_rank int;
begin
  if v_user is null then
    raise exception 'operator_unauthenticated: Anmeldung erforderlich';
  end if;

  if p_target_status is null
     or p_target_status not in ('accepted', 'preparing', 'ready', 'served', 'canceled') then
    raise exception 'operator_invalid_status: %', coalesce(p_target_status, '<null>');
  end if;

  select o.id, o.venue_id, o.status
    into v_order
  from public.orders o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception 'operator_unknown_order: %', p_order_id;
  end if;

  if v_order.venue_id is null or not public.is_venue_staff(v_order.venue_id) then
    raise exception 'operator_forbidden: kein Personal dieser Venue';
  end if;

  -- Replay: Ziel bereits erreicht.
  if v_order.status = p_target_status then
    return query select v_order.id, v_order.status, true;
    return;
  end if;

  if v_order.status = 'canceled' then
    raise exception 'operator_invalid_transition: canceled -> %', p_target_status;
  end if;

  if p_target_status = 'canceled' then
    if v_order.status = 'served' then
      raise exception 'operator_invalid_transition: served -> canceled';
    end if;
    update public.orders o
      set status = 'canceled', canceled_at = now()
      where o.id = v_order.id;
    return query select v_order.id, 'canceled'::text, false;
    return;
  end if;

  v_current_rank := case v_order.status
    when 'pending' then 0
    when 'accepted' then 1
    when 'preparing' then 2
    when 'ready' then 3
    when 'served' then 4
  end;
  v_target_rank := case p_target_status
    when 'accepted' then 1
    when 'preparing' then 2
    when 'ready' then 3
    when 'served' then 4
  end;

  if v_target_rank < v_current_rank then
    return query select v_order.id, v_order.status, true;
    return;
  end if;

  update public.orders o
    set status = p_target_status,
        accepted_at  = case when p_target_status = 'accepted'  then now() else o.accepted_at  end,
        preparing_at = case when p_target_status = 'preparing' then now() else o.preparing_at end,
        ready_at     = case when p_target_status = 'ready'     then now() else o.ready_at     end,
        served_at    = case when p_target_status = 'served'    then now() else o.served_at    end
    where o.id = v_order.id;

  -- Automatische Warenwirtschafts-Abbuchung bei 'served'
  if p_target_status = 'served' then
    perform public.operator_consume_order_inventory(v_order.venue_id, p_order_id);
  end if;

  return query select v_order.id, p_target_status, false;
end;
$$;

-- ============================================================================
-- 3. Hook in operator_update_delivery_status
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

  -- Automatische Warenwirtschafts-Abbuchung bei erfolgreicher Zustellung
  if p_new_status = 'delivered' then
    perform public.operator_consume_order_inventory(p_venue_id, p_order_id);
  end if;
end;
$$;

commit;
