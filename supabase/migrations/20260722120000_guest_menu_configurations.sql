-- KL-MENU-008: bestellbare Portions-/Varianten-/Extra-Auswahl.
--
-- Die bisherige Gast-RPC ignoriert unbekannte Felder absichtlich. Deshalb
-- entsteht eine V2 statt einer stillen Redefinition: Ein neuer Client kann so
-- nie versehentlich Optionen an eine alte, nur den Grundpreis berechnende RPC
-- senden. Preise, Gruppenregeln und Namen stammen ausschließlich aus
-- menu_items.variant_options; der Browser sendet nur opaque option_ids.

begin;

alter table public.order_items
  add column if not exists selected_options jsonb not null default '[]'::jsonb;

-- Kanonisiert sowohl neue Publish-Nutzlasten als auch historische Einträge.
-- Legacy: Nicht-Extras bilden eine optionale Einfachauswahl, Extras eine
-- optionale Mehrfachauswahl. Preise > 0 sind bei Extras Deltas, sonst fixe
-- Gesamtpreise; 0 bedeutet inklusive.
create or replace function public.kitchenlink_normalize_variant_options(
  p_options jsonb
) returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  with source_base as (
    select
      opt.value,
      opt.ordinality,
      case lower(coalesce(opt.value ->> 'kind', 'variant'))
        when 'portion' then 'portion'
        when 'extra' then 'extra'
        else 'variant'
      end as kind,
      coalesce(
        nullif(btrim(opt.value ->> 'group_id'), ''),
        case
          when lower(coalesce(opt.value ->> 'kind', 'variant')) = 'extra'
            then 'legacy-extra'
          else 'legacy-choice'
        end
      ) as group_id,
      case
        when coalesce(opt.value ->> 'price_cents', '') ~ '^\d{1,10}$'
          then case
            when (opt.value ->> 'price_cents')::numeric <= 2147483647
              then (opt.value ->> 'price_cents')::int
            else 0
          end
        else 0
      end as price_cents
    from jsonb_array_elements(
      case when jsonb_typeof(p_options) = 'array' then p_options else '[]'::jsonb end
    ) with ordinality as opt(value, ordinality)
    where jsonb_typeof(opt.value) = 'object'
      and btrim(coalesce(opt.value ->> 'name', '')) <> ''
  ), source as (
    select
      source_base.*,
      case lower(coalesce(source_base.value ->> 'selection_mode', ''))
        when 'single' then 'single'
        when 'multiple' then 'multiple'
        when 'quantity' then 'quantity'
        else case when source_base.kind = 'extra' then 'multiple' else 'single' end
      end as selection_mode,
      count(*) over (partition by source_base.group_id) as group_option_count
    from source_base
  )
  select coalesce(
    jsonb_agg(
      jsonb_strip_nulls(
        jsonb_build_object(
          'id', coalesce(
            nullif(btrim(source.value ->> 'id'), ''),
            'legacy-' || (source.ordinality - 1)::text
          ),
          'name', btrim(source.value ->> 'name'),
          'kind', source.kind,
          'price_cents', source.price_cents,
          'price_kind', case lower(coalesce(source.value ->> 'price_kind', ''))
            when 'fixed' then 'fixed'
            when 'delta' then 'delta'
            when 'included' then 'included'
            when 'free' then 'free'
            else case
              when source.price_cents = 0 then 'included'
              when source.kind = 'extra' then 'delta'
              else 'fixed'
            end
          end,
          'group_id', source.group_id,
          'group_title', nullif(btrim(source.value ->> 'group_title'), ''),
          'selection_mode', source.selection_mode,
          'minimum_selections', case
            when coalesce(source.value ->> 'minimum_selections', '') ~ '^\d{1,3}$'
              then least((source.value ->> 'minimum_selections')::int, 100)
            else 0
          end,
          'maximum_selections', case
            when coalesce(source.value ->> 'maximum_selections', '') ~ '^[1-9]\d{0,2}$'
              then least((source.value ->> 'maximum_selections')::int, 100)
            when source.selection_mode = 'single' then 1
            else greatest(1, source.group_option_count)
          end,
          'free_selection_count', case
            when coalesce(source.value ->> 'free_selection_count', '') ~ '^\d{1,3}$'
              then least((source.value ->> 'free_selection_count')::int, 100)
            else 0
          end,
          'allows_repeats', case
            when jsonb_typeof(source.value -> 'allows_repeats') = 'boolean'
              then (source.value ->> 'allows_repeats')::boolean
            else false
          end
        )
      )
      order by source.ordinality
    ),
    '[]'::jsonb
  )
  from source;
$$;

revoke all on function public.kitchenlink_normalize_variant_options(jsonb)
  from public, anon, authenticated;

-- V2 der Publish-Grenze: Die bewährte V1 erledigt Staff-Gate und atomaren
-- Menüüberschreibweg; anschließend werden innerhalb derselben Transaktion die
-- reicheren, streng validierten Auswahlmetadaten ergänzt.
create or replace function public.operator_publish_menu_v2(
  p_venue_slug text,
  p_menu jsonb
) returns table (
  menu_id uuid,
  category_count int,
  item_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_receipt record;
  v_category jsonb;
  v_item jsonb;
  v_slug text;
  v_raw_options jsonb;
  v_options jsonb;
  v_duplicate_ids boolean;
  v_invalid_groups boolean;
  v_required_fixed_groups int;
begin
  select * into v_receipt
  from public.operator_publish_menu(p_venue_slug, p_menu);

  for v_category in
    select value from jsonb_array_elements(p_menu -> 'categories')
  loop
    for v_item in
      select value from jsonb_array_elements(v_category -> 'items')
    loop
      v_slug := btrim(v_item ->> 'slug');
      if v_item ? 'variant_options'
         and jsonb_typeof(v_item -> 'variant_options') is distinct from 'array' then
        raise exception 'publish_invalid_variant: %', v_slug;
      end if;
      v_raw_options := case
        when jsonb_typeof(v_item -> 'variant_options') = 'array'
          then v_item -> 'variant_options'
        else '[]'::jsonb
      end;

      if exists (
        select 1
        from jsonb_array_elements(v_raw_options) as raw(value)
        where jsonb_typeof(raw.value) <> 'object'
          or jsonb_typeof(raw.value -> 'name') is distinct from 'string'
          or btrim(coalesce(raw.value ->> 'name', '')) = ''
          or char_length(raw.value ->> 'name') > 160
          or jsonb_typeof(raw.value -> 'price_cents') is distinct from 'number'
          or coalesce(raw.value ->> 'price_cents', '') !~ '^\d{1,10}$'
          or case
            when coalesce(raw.value ->> 'price_cents', '') ~ '^\d{1,10}$'
              then (raw.value ->> 'price_cents')::numeric > 2147483647
            else false
          end
          or (
            raw.value ? 'id'
            and (
              jsonb_typeof(raw.value -> 'id') is distinct from 'string'
              or btrim(coalesce(raw.value ->> 'id', '')) = ''
              or char_length(raw.value ->> 'id') > 128
            )
          )
          or (
            raw.value ? 'kind'
            and (
              jsonb_typeof(raw.value -> 'kind') is distinct from 'string'
              or lower(raw.value ->> 'kind') not in ('variant', 'portion', 'extra')
            )
          )
          or (
            raw.value ? 'price_kind'
            and (
              jsonb_typeof(raw.value -> 'price_kind') is distinct from 'string'
              or lower(raw.value ->> 'price_kind') not in ('fixed', 'delta', 'included', 'free')
            )
          )
          or (
            raw.value ? 'group_id'
            and (
              jsonb_typeof(raw.value -> 'group_id') is distinct from 'string'
              or btrim(coalesce(raw.value ->> 'group_id', '')) = ''
              or char_length(raw.value ->> 'group_id') > 128
            )
          )
          or (
            raw.value ? 'group_title'
            and (
              jsonb_typeof(raw.value -> 'group_title') is distinct from 'string'
              or char_length(raw.value ->> 'group_title') > 80
            )
          )
          or (
            raw.value ? 'minimum_selections'
            and (
              jsonb_typeof(raw.value -> 'minimum_selections') is distinct from 'number'
              or coalesce(raw.value ->> 'minimum_selections', '') !~ '^\d{1,3}$'
              or case
                when coalesce(raw.value ->> 'minimum_selections', '') ~ '^\d{1,3}$'
                  then (raw.value ->> 'minimum_selections')::int > 100
                else false
              end
            )
          )
          or (
            raw.value ? 'maximum_selections'
            and (
              jsonb_typeof(raw.value -> 'maximum_selections') is distinct from 'number'
              or coalesce(raw.value ->> 'maximum_selections', '') !~ '^[1-9]\d{0,2}$'
              or case
                when coalesce(raw.value ->> 'maximum_selections', '') ~ '^[1-9]\d{0,2}$'
                  then (raw.value ->> 'maximum_selections')::int > 100
                else false
              end
            )
          )
          or (
            raw.value ? 'selection_mode'
            and (
              jsonb_typeof(raw.value -> 'selection_mode') is distinct from 'string'
              or lower(raw.value ->> 'selection_mode') not in ('single', 'multiple', 'quantity', 'unknown')
            )
          )
          or (
            raw.value ? 'free_selection_count'
            and (
              jsonb_typeof(raw.value -> 'free_selection_count') is distinct from 'number'
              or coalesce(raw.value ->> 'free_selection_count', '') !~ '^\d{1,3}$'
              or case
                when coalesce(raw.value ->> 'free_selection_count', '') ~ '^\d{1,3}$'
                  then (raw.value ->> 'free_selection_count')::int > 100
                else false
              end
            )
          )
          or (
            raw.value ? 'allows_repeats'
            and jsonb_typeof(raw.value -> 'allows_repeats') is distinct from 'boolean'
          )
      ) then
        raise exception 'publish_invalid_variant: %', v_slug;
      end if;

      if jsonb_array_length(v_raw_options) > 100 then
        raise exception 'publish_invalid_variant: zu viele Optionen für %', v_slug;
      end if;

      v_options := public.kitchenlink_normalize_variant_options(v_raw_options);

      select count(*) <> count(distinct option.value ->> 'id')
        into v_duplicate_ids
      from jsonb_array_elements(v_options) as option(value);
      if v_duplicate_ids then
        raise exception 'publish_duplicate_option_id: %', v_slug;
      end if;

      if exists (
        select 1
        from jsonb_array_elements(v_options) as option(value)
        where option.value ->> 'price_kind' in ('included', 'free')
          and (option.value ->> 'price_cents')::int <> 0
      ) then
        raise exception 'publish_invalid_included_price: %', v_slug;
      end if;

      select exists (
        select 1
        from jsonb_array_elements(v_options) as option(value)
        group by option.value ->> 'group_id'
        having count(distinct (option.value ->> 'minimum_selections')::int) > 1
          or count(distinct (option.value ->> 'maximum_selections')::int) > 1
          or count(distinct option.value ->> 'selection_mode') > 1
          or count(distinct (option.value ->> 'free_selection_count')::int) > 1
          or count(distinct (option.value ->> 'allows_repeats')::boolean) > 1
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
      ) into v_invalid_groups;
      if v_invalid_groups then
        raise exception 'publish_invalid_option_group: %', v_slug;
      end if;

      select count(*) into v_required_fixed_groups
      from (
        select option.value ->> 'group_id'
        from jsonb_array_elements(v_options) as option(value)
        group by option.value ->> 'group_id'
        having min((option.value ->> 'minimum_selections')::int) > case
          when bool_or((option.value ->> 'allows_repeats')::boolean)
               and count(*) filter (where option.value ->> 'price_kind' <> 'fixed') > 0
            then 100
          else count(*) filter (where option.value ->> 'price_kind' <> 'fixed')
        end
      ) as requires_fixed;
      if v_required_fixed_groups > 1 then
        raise exception 'publish_invalid_fixed_price_groups: %', v_slug;
      end if;

      update public.menu_items mi
      set variant_options = v_options
      from public.menu_categories mc
      where mi.category_id = mc.id
        and mc.menu_id = v_receipt.menu_id
        and mi.slug = v_slug;
    end loop;
  end loop;

  return query select
    v_receipt.menu_id,
    v_receipt.category_count,
    v_receipt.item_count;
end;
$$;

revoke all on function public.operator_publish_menu_v2(text, jsonb)
  from public, anon;
grant execute on function public.operator_publish_menu_v2(text, jsonb)
  to authenticated;

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
    select mi.id, mi.name, mi.price_cents, mi.available, mi.kind, mi.variant_options
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
