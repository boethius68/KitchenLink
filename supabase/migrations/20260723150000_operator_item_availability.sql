-- KL-MENU-010: Artikel-Verfügbarkeit (vorübergehend ausblenden / zeitgesteuert).
--
-- Erweitert `menu_items` um planmäßige Sichtbarkeit und ergänzt eine
-- staff-gated RPC zum Setzen der Verfügbarkeit.

begin;

-- ============================================================================
-- 1. Zeitfenster für planmäßige Verfügbarkeit
-- ============================================================================

alter table public.menu_items
  add column if not exists available_from timestamptz,
  add column if not exists available_until timestamptz;

-- ============================================================================
-- 2. RPC: Verfügbarkeit eines Artikels setzen
-- ============================================================================

create or replace function public.operator_set_item_availability(
  p_venue_slug text,
  p_item_slug text,
  p_available boolean default true,
  p_available_from timestamptz default null,
  p_available_until timestamptz default null
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_updated int;
begin
  if v_user is null then
    raise exception 'avail_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'avail_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'avail_forbidden: kein Personal dieser Venue';
  end if;

  if p_available_from is not null and p_available_until is not null
     and p_available_from >= p_available_until then
    raise exception 'avail_invalid_window: available_from >= available_until';
  end if;

  update public.menu_items mi
  set
    available = p_available,
    available_from = p_available_from,
    available_until = p_available_until
  where mi.slug = p_item_slug
    and mi.category_id in (
      select mc.id
      from public.menu_categories mc
      join public.menus m on m.id = mc.menu_id
      where m.venue_id = v_venue_id and m.active = true
    );

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.operator_set_item_availability(text, text, boolean, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.operator_set_item_availability(text, text, boolean, timestamptz, timestamptz)
  to authenticated;

-- ============================================================================
-- 3. Bestell-Gate: Zeitfenster prüfen
-- ============================================================================

create or replace function public.guest_web_submit_order_v2(
  p_venue_slug text,
  p_idempotency_key text,
  p_items jsonb,
  p_service_mode text default 'dine_in',
  p_customer_note text default ''
) returns table (
  order_id uuid,
  status text,
  total_cents int,
  currency char(3),
  idempotent_replay boolean,
  accepted boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue record;
  v_item record;
  v_total bigint := 0;
  v_order_id uuid;
  v_status text := 'pending';
  v_payload_hash text;
  v_existing record;
  v_clean_items jsonb := '[]'::jsonb;
  v_priced_items jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_item_slug text;
  v_qty int;
  v_index int := 0;
  v_option_ids jsonb;
  v_option_count int;
  v_row record;
  v_options jsonb;
  v_selected jsonb;
  v_selected_options jsonb;
  v_selected_count int;
  v_fixed_count int;
  v_fixed_price bigint;
  v_delta_total bigint;
  v_group record;
  v_unit_price bigint;
  v_option_names text;
  v_now timestamptz := clock_timestamp();
begin
  if v_user is null then
    raise exception 'guest_web_unauthenticated: Anonymous Sign-in erforderlich';
  end if;
  if not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'guest_web_not_anonymous: anonyme Identität erforderlich';
  end if;
  if p_idempotency_key is null
     or btrim(p_idempotency_key) = ''
     or char_length(p_idempotency_key) > 512 then
    raise exception 'guest_web_invalid_idempotency_key: leer';
  end if;
  if char_length(coalesce(p_customer_note, '')) > 2000 then
    raise exception 'guest_web_invalid_items: Hinweis zu lang';
  end if;
  p_service_mode := coalesce(p_service_mode, 'dine_in');
  if p_service_mode not in ('dine_in', 'bar', 'pickup') then
    raise exception 'guest_web_invalid_service_mode: %', p_service_mode;
  end if;

  select id into v_venue from public.venues where slug = p_venue_slug;
  if not found then
    raise exception 'guest_web_unknown_venue: %', p_venue_slug;
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'guest_web_invalid_items: kein Array';
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_elem) is distinct from 'object' then
      raise exception 'guest_web_invalid_item: Position ist kein Objekt';
    end if;
    v_item_slug := nullif(btrim(v_elem ->> 'slug'), '');
    if jsonb_typeof(v_elem -> 'slug') is distinct from 'string'
       or v_item_slug is null
       or char_length(v_item_slug) > 160 then
      raise exception 'guest_web_invalid_item: slug ungültig';
    end if;
    if jsonb_typeof(v_elem -> 'quantity') is distinct from 'number'
       or coalesce(v_elem ->> 'quantity', '') !~ '^\d{1,2}$' then
      raise exception 'guest_web_invalid_item: quantity fehlt';
    end if;
    v_qty := (v_elem ->> 'quantity')::int;
    if v_qty <= 0 or v_qty > 99 then
      raise exception 'guest_web_invalid_item: slug oder quantity ungültig';
    end if;
    if v_elem ? 'option_ids'
       and jsonb_typeof(v_elem -> 'option_ids') is distinct from 'array' then
      raise exception 'guest_web_invalid_selection: option_ids ist kein Array';
    end if;

    if exists (
      select 1
      from jsonb_array_elements(coalesce(v_elem -> 'option_ids', '[]'::jsonb))
        as selected(value)
      where jsonb_typeof(selected.value) is distinct from 'string'
        or btrim(selected.value #>> '{}') = ''
        or char_length(selected.value #>> '{}') > 128
    ) then
      raise exception 'guest_web_invalid_selection: option_id ungültig';
    end if;

    select count(*) into v_option_count
    from jsonb_array_elements_text(coalesce(v_elem -> 'option_ids', '[]'::jsonb))
      as selected(value);
    if v_option_count > 64 then
      raise exception 'guest_web_invalid_selection: zu viele option_ids';
    end if;

    select coalesce(jsonb_agg(to_jsonb(selected.value) order by selected.value), '[]'::jsonb)
      into v_option_ids
    from jsonb_array_elements_text(coalesce(v_elem -> 'option_ids', '[]'::jsonb))
      as selected(value);

    v_clean_items := v_clean_items || jsonb_build_array(
      jsonb_build_object(
        'slug', v_item_slug,
        'quantity', v_qty,
        'option_ids', v_option_ids
      )
    );
    v_index := v_index + 1;
    if v_index > 100 then
      raise exception 'guest_web_invalid_items: zu viele Positionen';
    end if;
  end loop;

  if v_index = 0 then
    raise exception 'guest_web_empty_order: keine Positionen';
  end if;

  select coalesce(
    jsonb_agg(line.value order by line.value ->> 'slug', (line.value -> 'option_ids')::text),
    '[]'::jsonb
  ) into v_clean_items
  from jsonb_array_elements(v_clean_items) as line(value);

  if exists (
    select 1
    from jsonb_array_elements(v_clean_items) as line(value)
    group by line.value ->> 'slug', line.value -> 'option_ids'
    having count(*) > 1
  ) then
    raise exception 'guest_web_invalid_selection: doppelte Konfiguration';
  end if;

  select encode(
    extensions.digest(
      jsonb_build_object(
        'venue_id', v_venue.id,
        'idempotency_key', p_idempotency_key,
        'service_mode', p_service_mode,
        'customer_note', coalesce(p_customer_note, ''),
        'items', v_clean_items
      )::text,
      'sha256'
    ),
    'hex'
  ) into v_payload_hash;

  select o.id, o.status, o.total_cents, o.currency,
         o.idempotency_payload_hash, o.created_by
    into v_existing
  from public.orders o
  where o.venue_id = v_venue.id
    and o.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.created_by is distinct from v_user then
      raise exception 'guest_web_idempotency_conflict: Key gehört zu anderem Gast';
    end if;
    if v_existing.idempotency_payload_hash is distinct from v_payload_hash then
      raise exception 'guest_web_idempotency_conflict: gleicher Key, anderer Inhalt';
    end if;
    return query select
      v_existing.id,
      v_existing.status,
      v_existing.total_cents,
      v_existing.currency,
      true,
      true;
    return;
  end if;

  for v_row in
    select
      line.value ->> 'slug' as slug,
      (line.value ->> 'quantity')::int as quantity,
      line.value -> 'option_ids' as option_ids
    from jsonb_array_elements(v_clean_items) as line(value)
  loop
    select mi.id, mi.name, mi.price_cents, mi.available, mi.kind,
           mi.variant_options, mi.available_from, mi.available_until
      into v_item
    from public.menu_items mi
    join public.menu_categories mc on mc.id = mi.category_id
    join public.menus m on m.id = mc.menu_id
    where mi.slug = v_row.slug
      and m.venue_id = v_venue.id
      and m.active = true
    for update of mi;

    if not found then
      raise exception 'guest_web_unknown_item: %', v_row.slug;
    end if;
    if v_item.available is not true then
      raise exception 'guest_web_unavailable_item: %', v_row.slug;
    end if;
    if v_item.available_from is not null and v_now < v_item.available_from then
      raise exception 'guest_web_not_yet_available: %', v_row.slug;
    end if;
    if v_item.available_until is not null and v_now > v_item.available_until then
      raise exception 'guest_web_expired_item: %', v_row.slug;
    end if;

    v_options := public.kitchenlink_normalize_variant_options(v_item.variant_options);

    if exists (
      select 1
      from jsonb_array_elements(v_options) as option(value)
      group by option.value ->> 'group_id'
      having count(distinct (option.value ->> 'minimum_selections')::int) <> 1
        or count(distinct (option.value ->> 'maximum_selections')::int) <> 1
        or count(distinct option.value ->> 'selection_mode') <> 1
        or count(distinct (option.value ->> 'free_selection_count')::int) <> 1
        or count(distinct (option.value ->> 'allows_repeats')::boolean) <> 1
        or min((option.value ->> 'minimum_selections')::int)
           > min((option.value ->> 'maximum_selections')::int)
        or min((option.value ->> 'free_selection_count')::int)
           > min((option.value ->> 'maximum_selections')::int)
        or (
          min(option.value ->> 'selection_mode') = 'single'
          and max((option.value ->> 'maximum_selections')::int) <> 1
        )
        or (
          min(option.value ->> 'selection_mode') = 'single'
          and bool_or((option.value ->> 'allows_repeats')::boolean)
        )
        or (
          not bool_or((option.value ->> 'allows_repeats')::boolean)
          and max((option.value ->> 'maximum_selections')::int) > count(*)
        )
    ) then
      raise exception 'guest_web_invalid_selection: inkonsistente Optionsgruppen für %', v_row.slug;
    end if;

    if exists (
      select 1
      from jsonb_array_elements_text(v_row.option_ids) as selected(value)
      where not exists (
        select 1
        from jsonb_array_elements(v_options) as option(value)
        where option.value ->> 'id' = selected.value
      )
    ) then
      raise exception 'guest_web_unknown_option: %', v_row.slug;
    end if;

    if (
      select count(*) <> count(distinct option.value ->> 'id')
      from jsonb_array_elements(v_options) as option(value)
    ) then
      raise exception 'guest_web_invalid_selection: doppelte Optionsdefinition für %', v_row.slug;
    end if;

    if exists (
      select 1
      from jsonb_array_elements_text(v_row.option_ids) as chosen(value)
      join jsonb_array_elements(v_options) as option(value)
        on option.value ->> 'id' = chosen.value
      group by chosen.value
      having count(*) > 1
        and not bool_and((option.value ->> 'allows_repeats')::boolean)
    ) then
      raise exception 'guest_web_invalid_selection: Auswahl nicht wiederholbar für %', v_row.slug;
    end if;

    for v_group in
      select
        option.value ->> 'group_id' as group_id,
        min((option.value ->> 'minimum_selections')::int) as minimum_selections,
        min((option.value ->> 'maximum_selections')::int) as maximum_selections
      from jsonb_array_elements(v_options) as option(value)
      group by option.value ->> 'group_id'
    loop
      select count(*) into v_selected_count
      from jsonb_array_elements_text(v_row.option_ids) as selected(value)
      join jsonb_array_elements(v_options) as option(value)
        on option.value ->> 'id' = selected.value
      where option.value ->> 'group_id' = v_group.group_id;
      if v_selected_count < v_group.minimum_selections then
        raise exception 'guest_web_selection_required: % / %', v_row.slug, v_group.group_id;
      end if;
      if v_selected_count > v_group.maximum_selections then
        raise exception 'guest_web_selection_limit: % / %', v_row.slug, v_group.group_id;
      end if;
    end loop;

    with selected as (
      select
        option.ordinality as option_ordinality,
        chosen.ordinality as chosen_ordinality,
        option.value ->> 'group_id' as group_id,
        option.value ->> 'price_kind' as price_kind,
        (option.value ->> 'price_cents')::bigint as price_cents,
        option.value ->> 'selection_mode' as selection_mode,
        (option.value ->> 'free_selection_count')::int as free_selection_count
      from jsonb_array_elements_text(v_row.option_ids) with ordinality
        as chosen(value, ordinality)
      join jsonb_array_elements(v_options) with ordinality
        as option(value, ordinality)
        on option.value ->> 'id' = chosen.value
    ), ranked as (
      select
        selected.*,
        count(*) filter (where selected.price_kind in ('included', 'free'))
          over (partition by selected.group_id) as included_count,
        count(*) filter (where selected.price_kind = 'delta') over (
          partition by selected.group_id
          order by
            selected.price_cents,
            selected.option_ordinality,
            selected.chosen_ordinality
          rows between unbounded preceding and current row
        ) as delta_rank
      from selected
    )
    select
      count(*) filter (where ranked.price_kind = 'fixed'),
      max(ranked.price_cents) filter (where ranked.price_kind = 'fixed'),
      coalesce(sum(
        case
          when ranked.price_kind = 'delta'
            and (
              ranked.selection_mode = 'single'
              or ranked.delta_rank > greatest(
                ranked.free_selection_count - ranked.included_count,
                0
              )
            )
            then ranked.price_cents
          else 0
        end
      ), 0)
      into v_fixed_count, v_fixed_price, v_delta_total
    from ranked;
    if v_fixed_count > 1 then
      raise exception 'guest_web_invalid_selection: mehrere fixe Preise';
    end if;

    v_unit_price := coalesce(v_fixed_price, v_item.price_cents) + v_delta_total;
    v_selected_options := '[]'::jsonb;
    for v_selected in
      select option.value
      from jsonb_array_elements_text(v_row.option_ids) with ordinality
        as selected(value, ordinality)
      join jsonb_array_elements(v_options) as option(value)
        on option.value ->> 'id' = selected.value
      order by selected.ordinality
    loop
      if v_selected ->> 'price_kind' in ('included', 'free')
         and (v_selected ->> 'price_cents')::int <> 0 then
        raise exception 'guest_web_invalid_selection: inklusive Auswahl mit Preis';
      end if;
      v_selected_options := v_selected_options || jsonb_build_array(v_selected);
    end loop;

    if v_unit_price < 0 or v_unit_price > 2147483647 then
      raise exception 'guest_web_invalid_selection: Preis außerhalb des Bereichs';
    end if;
    v_total := v_total + v_unit_price * v_row.quantity;
    if v_total > 2147483647 then
      raise exception 'guest_web_invalid_items: Gesamtsumme außerhalb des Bereichs';
    end if;

    select string_agg(option.value ->> 'name', ' · ' order by option.ordinality)
      into v_option_names
    from jsonb_array_elements(v_selected_options) with ordinality
      as option(value, ordinality);

    v_priced_items := v_priced_items || jsonb_build_array(
      jsonb_build_object(
        'menu_item_id', v_item.id,
        'name', v_item.name,
        'display_name', v_item.name || case
          when coalesce(v_option_names, '') = '' then ''
          else ' · ' || v_option_names
        end,
        'quantity', v_row.quantity,
        'unit_price_cents', v_unit_price::int,
        'kind', v_item.kind,
        'selected_options', v_selected_options
      )
    );
  end loop;

  begin
    insert into public.orders (
      venue_id, source_device, total_cents, status, service_mode,
      customer_note, currency, idempotency_key, idempotency_payload_hash, created_by
    ) values (
      v_venue.id, 'guest_web', v_total::int, v_status, p_service_mode,
      coalesce(p_customer_note, ''), 'EUR', p_idempotency_key, v_payload_hash, v_user
    ) returning id into v_order_id;
  exception
    when unique_violation then
      select o.id, o.status, o.total_cents, o.currency,
             o.idempotency_payload_hash, o.created_by
        into v_existing
      from public.orders o
      where o.venue_id = v_venue.id
        and o.idempotency_key = p_idempotency_key;
      if not found then
        raise exception 'guest_web_idempotency_race_unresolved';
      end if;
      if v_existing.created_by is distinct from v_user then
        raise exception 'guest_web_idempotency_conflict: Key gehört zu anderem Gast (race)';
      end if;
      if v_existing.idempotency_payload_hash is distinct from v_payload_hash then
        raise exception 'guest_web_idempotency_conflict: gleicher Key, anderer Inhalt (race)';
      end if;
      return query select
        v_existing.id,
        v_existing.status,
        v_existing.total_cents,
        v_existing.currency,
        true,
        true;
      return;
  end;

  for v_row in
    select item.value
    from jsonb_array_elements(v_priced_items) as item(value)
  loop
    insert into public.order_items (
      order_id, menu_item_id, name, quantity, unit_price_cents, kind, selected_options
    ) values (
      v_order_id,
      (v_row.value ->> 'menu_item_id')::uuid,
      v_row.value ->> 'display_name',
      (v_row.value ->> 'quantity')::int,
      (v_row.value ->> 'unit_price_cents')::int,
      v_row.value ->> 'kind',
      v_row.value -> 'selected_options'
    );
  end loop;

  return query select
    v_order_id,
    v_status,
    v_total::int,
    'EUR'::char(3),
    false,
    true;
end;
$$;

revoke all on function public.guest_web_submit_order_v2(
  text, text, jsonb, text, text
) from public, anon;
grant execute on function public.guest_web_submit_order_v2(
  text, text, jsonb, text, text
) to authenticated;

commit;
