-- KL-TABLE-001: Tischkontext aktivieren.
--
-- `tables`, `qr_tokens` und `table_sessions` existieren seit dem Kernschema
-- (20260318011000), wurden aber nie benutzt — und nie geschuetzt: als einzige
-- Tabellen des Gastschemas hatten sie keinerlei Row Level Security, waehrend
-- Supabase `anon`/`authenticated` per Default-Privileg Schreibrechte gibt.
-- Diese Migration schliesst das und macht die Schicht produktiv nutzbar:
--
--   1. RLS auf allen drei Tabellen; Lesen nur fuer Personal, Schreiben
--      ausschliesslich ueber SECURITY-DEFINER-RPCs.
--   2. `tables` bekommt Bereich und Sortierung (Blueprint §6.1, Meilenstein 1.4).
--   3. Staff-RPCs zum Anlegen, Aendern, Stilllegen und Token-Rotieren.
--   4. `guest_web_resolve_table` fuer die Tischanzeige im Gast-Web.
--   5. `guest_web_submit_order_v2` nimmt zusaetzlich ein Tisch-Token entgegen
--      und haengt die Bestellung an Tisch **und** offene Tisch-Session.
--
-- Additiv: ohne Token verhaelt sich die Bestell-RPC exakt wie bisher.

begin;

-- ============================================================================
-- 1. Bisher ungeschuetzte Tischtabellen absichern
-- ============================================================================

alter table public.tables enable row level security;
alter table public.qr_tokens enable row level security;
alter table public.table_sessions enable row level security;

drop policy if exists "tables_staff_read" on public.tables;
create policy "tables_staff_read" on public.tables
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

drop policy if exists "qr_tokens_staff_read" on public.qr_tokens;
create policy "qr_tokens_staff_read" on public.qr_tokens
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

drop policy if exists "table_sessions_staff_read" on public.table_sessions;
create policy "table_sessions_staff_read" on public.table_sessions
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

-- Bewusst keine insert/update/delete-Policy: jeder Schreibweg laeuft ueber die
-- RPCs weiter unten, wie bei Menue und Bestellung auch.

-- ============================================================================
-- 2. Bereich und Sortierung
-- ============================================================================

alter table public.tables
  add column if not exists area text not null default '',
  add column if not exists sort_order int not null default 0;

create index if not exists tables_venue_sort_idx
  on public.tables(venue_id, sort_order, label);

-- Ein Tisch hat hoechstens eine offene Session. Diese Invariante traegt die
-- gemeinsame Tisch-Session (Blueprint §6.1): mehrere Gaeste und der Kellner
-- schreiben in denselben offenen Vorgang, nicht in je einen eigenen.
create unique index if not exists table_sessions_one_open_per_table
  on public.table_sessions(table_id)
  where status = 'open';

-- Ein Tisch hat hoechstens einen gueltigen QR-Code. Rotieren heisst: den alten
-- stilllegen, den neuen anlegen — gedruckte alte Codes verlieren ihre Wirkung.
create unique index if not exists qr_tokens_one_active_per_table
  on public.qr_tokens(table_id)
  where active and mode = 'table';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'qr_tokens_table_mode_requires_table'
  ) then
    alter table public.qr_tokens
      add constraint qr_tokens_table_mode_requires_table
      check (mode <> 'table' or table_id is not null);
  end if;
end;
$$;

-- ============================================================================
-- 3. Token-Erzeugung
-- ============================================================================

-- Bewusst `gen_random_uuid()` (pg_catalog seit PG13) statt pgcrypto: KL-WEB-003
-- hat gezeigt, dass pgcrypto auf Supabase im Schema `extensions` liegt und
-- nicht im `search_path` der Funktionen steht.
create or replace function public.kitchenlink_new_table_token()
returns text
language sql
volatile
as $$
  select replace(gen_random_uuid()::text, '-', '');
$$;

-- ============================================================================
-- 4. Staff-RPCs
-- ============================================================================

-- Legt einen Tisch an oder aendert ihn. Ohne `p_table_id` ist die Bezeichnung
-- der Schluessel (Anlegen/Aktualisieren), mit `p_table_id` ist Umbenennen
-- moeglich. Ein aktiver Tisch-Token wird bei Bedarf miterzeugt.
create or replace function public.operator_upsert_table(
  p_venue_slug text,
  p_label text,
  p_area text default '',
  p_sort_order int default 0,
  p_active boolean default true,
  p_table_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_label text := btrim(coalesce(p_label, ''));
  v_area text := btrim(coalesce(p_area, ''));
  v_table_id uuid;
  v_token text;
begin
  if v_user is null then
    raise exception 'table_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'table_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'table_forbidden: kein Personal dieser Venue';
  end if;

  if v_label = '' or char_length(v_label) > 64 then
    raise exception 'table_invalid_label: 1 bis 64 Zeichen';
  end if;
  if char_length(v_area) > 64 then
    raise exception 'table_invalid_area: hoechstens 64 Zeichen';
  end if;

  if p_table_id is not null then
    update public.tables t
    set label = v_label,
        area = v_area,
        sort_order = coalesce(p_sort_order, 0),
        active = coalesce(p_active, true)
    where t.id = p_table_id and t.venue_id = v_venue_id
    returning t.id into v_table_id;
    if v_table_id is null then
      raise exception 'table_unknown: %', p_table_id;
    end if;
  else
    insert into public.tables (venue_id, label, area, sort_order, active)
    values (v_venue_id, v_label, v_area, coalesce(p_sort_order, 0), coalesce(p_active, true))
    on conflict (venue_id, label) do update
      set area = excluded.area,
          sort_order = excluded.sort_order,
          active = excluded.active
    returning id into v_table_id;
  end if;

  select q.token into v_token
  from public.qr_tokens q
  where q.table_id = v_table_id and q.active and q.mode = 'table';

  if v_token is null then
    v_token := public.kitchenlink_new_table_token();
    insert into public.qr_tokens (token, venue_id, table_id, mode, active)
    values (v_token, v_venue_id, v_table_id, 'table', true);
  end if;

  return jsonb_build_object(
    'table_id', v_table_id,
    'label', v_label,
    'area', v_area,
    'sort_order', coalesce(p_sort_order, 0),
    'active', coalesce(p_active, true),
    'token', v_token
  );
end;
$$;

revoke all on function public.operator_upsert_table(text, text, text, int, boolean, uuid)
  from public, anon;
grant execute on function public.operator_upsert_table(text, text, text, int, boolean, uuid)
  to authenticated;

-- Loescht einen Tisch nur, solange keine Bestellung und keine Session an ihm
-- haengt. Sonst waere die Historie still entwertet (`orders.table_id` faellt
-- per FK auf NULL) — dann ist Stilllegen die richtige Aktion.
create or replace function public.operator_delete_table(
  p_venue_slug text,
  p_table_id uuid
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_deleted int;
begin
  if v_user is null then
    raise exception 'table_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'table_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'table_forbidden: kein Personal dieser Venue';
  end if;

  if exists (select 1 from public.orders o where o.table_id = p_table_id) then
    raise exception 'table_in_use: Tisch hat Bestellungen, bitte stilllegen';
  end if;
  if exists (select 1 from public.table_sessions s where s.table_id = p_table_id) then
    raise exception 'table_in_use: Tisch hat Sitzungen, bitte stilllegen';
  end if;

  -- Zuerst die QR-Codes: der FK auf `qr_tokens` ist `on delete set null`, ein
  -- tischloser Token mit `mode = 'table'` waere widerspruechlich (und
  -- verletzt `qr_tokens_table_mode_requires_table`).
  delete from public.qr_tokens q where q.table_id = p_table_id;

  delete from public.tables t
  where t.id = p_table_id and t.venue_id = v_venue_id;
  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end;
$$;

revoke all on function public.operator_delete_table(text, uuid) from public, anon;
grant execute on function public.operator_delete_table(text, uuid) to authenticated;

-- Legt den bisherigen QR-Code still und gibt einen neuen aus.
create or replace function public.operator_rotate_table_token(
  p_venue_slug text,
  p_table_id uuid
) returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_token text;
begin
  if v_user is null then
    raise exception 'table_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'table_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'table_forbidden: kein Personal dieser Venue';
  end if;

  if not exists (
    select 1 from public.tables t where t.id = p_table_id and t.venue_id = v_venue_id
  ) then
    raise exception 'table_unknown: %', p_table_id;
  end if;

  update public.qr_tokens q
  set active = false
  where q.table_id = p_table_id and q.active and q.mode = 'table';

  v_token := public.kitchenlink_new_table_token();
  insert into public.qr_tokens (token, venue_id, table_id, mode, active)
  values (v_token, v_venue_id, p_table_id, 'table', true);

  return v_token;
end;
$$;

revoke all on function public.operator_rotate_table_token(text, uuid) from public, anon;
grant execute on function public.operator_rotate_table_token(text, uuid) to authenticated;

-- ============================================================================
-- 5. Tischauskunft fuer das Gast-Web
-- ============================================================================

-- Der Gast soll vor dem Bestellen sehen, fuer welchen Tisch er bestellt. Die
-- Funktion gibt nur die sichtbare Bezeichnung zu einem gueltigen Token heraus,
-- keine IDs und keine Liste — ohne Token gibt es keine Auskunft.
create or replace function public.guest_web_resolve_table(
  p_venue_slug text,
  p_token text
) returns table (
  label text,
  area text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token text := btrim(coalesce(p_token, ''));
begin
  if v_token = '' or char_length(v_token) > 128 then
    raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
  end if;

  return query
  select t.label, t.area
  from public.qr_tokens q
  join public.tables t on t.id = q.table_id
  join public.venues v on v.id = t.venue_id
  where q.token = v_token
    and q.active
    and q.mode = 'table'
    and (q.expires_at is null or q.expires_at > now())
    and t.active
    and v.slug = p_venue_slug;

  if not found then
    raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
  end if;
end;
$$;

revoke all on function public.guest_web_resolve_table(text, text) from public;
grant execute on function public.guest_web_resolve_table(text, text) to anon, authenticated;

-- ============================================================================
-- 6. Bestell-Gate mit Tisch
-- ============================================================================

-- `create or replace` kann die Parameterliste nicht erweitern; ein zweiter
-- Name (v3) wuerde 470 Zeilen Bestelllogik duplizieren. Deshalb: in derselben
-- Transaktion droppen und mit dem zusaetzlichen, vorbelegten Parameter neu
-- anlegen. Aufrufer mit fuenf benannten Argumenten bleiben gueltig.
drop function if exists public.guest_web_submit_order_v2(text, text, jsonb, text, text);

create or replace function public.guest_web_submit_order_v2(
  p_venue_slug text,
  p_idempotency_key text,
  p_items jsonb,
  p_service_mode text default 'dine_in',
  p_customer_note text default '',
  p_table_token text default null
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
  v_table_token text := nullif(btrim(coalesce(p_table_token, '')), '');
  v_table_id uuid;
  v_session_id uuid;
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

  -- Tisch aufloesen, bevor irgendetwas geschrieben wird. Ein abgelaufener oder
  -- stillgelegter QR-Code fuehrt bewusst zu einer Absage statt zu einer
  -- tischlosen Bestellung: eine Bestellung, die niemand zuordnen kann, ist im
  -- Restaurant teurer als eine abgewiesene.
  if v_table_token is not null then
    if char_length(v_table_token) > 128 then
      raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
    end if;
    select t.id into v_table_id
    from public.qr_tokens q
    join public.tables t on t.id = q.table_id
    where q.token = v_table_token
      and q.active
      and q.mode = 'table'
      and (q.expires_at is null or q.expires_at > now())
      and t.active
      and t.venue_id = v_venue.id;
    if not found then
      raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
    end if;
    if p_service_mode = 'pickup' then
      raise exception 'guest_web_invalid_service_mode: Tischbestellung ist keine Abholung';
    end if;
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

  -- Der Tisch geht in den Hash ein: derselbe Schluessel mit anderem Tisch ist
  -- ein Konflikt, nicht stillschweigend derselbe Vorgang.
  select encode(
    extensions.digest(
      jsonb_build_object(
        'venue_id', v_venue.id,
        'idempotency_key', p_idempotency_key,
        'service_mode', p_service_mode,
        'customer_note', coalesce(p_customer_note, ''),
        'table_id', v_table_id,
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

  -- Gemeinsame Tisch-Session: die erste Bestellung eroeffnet sie, jede weitere
  -- haengt sich an dieselbe. Der Partial-Unique-Index entscheidet das Rennen
  -- zwischen zwei gleichzeitig bestellenden Gaesten.
  if v_table_id is not null then
    select s.id into v_session_id
    from public.table_sessions s
    where s.table_id = v_table_id and s.status = 'open'
    limit 1;

    if v_session_id is null then
      begin
        insert into public.table_sessions (venue_id, table_id)
        values (v_venue.id, v_table_id)
        returning id into v_session_id;
      exception
        when unique_violation then
          select s.id into v_session_id
          from public.table_sessions s
          where s.table_id = v_table_id and s.status = 'open'
          limit 1;
          if v_session_id is null then
            raise exception 'guest_web_table_session_unresolved';
          end if;
      end;
    end if;
  end if;

  begin
    insert into public.orders (
      venue_id, source_device, total_cents, status, service_mode,
      customer_note, currency, idempotency_key, idempotency_payload_hash, created_by,
      table_id, table_session_id
    ) values (
      v_venue.id, 'guest_web', v_total::int, v_status, p_service_mode,
      coalesce(p_customer_note, ''), 'EUR', p_idempotency_key, v_payload_hash, v_user,
      v_table_id, v_session_id
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
  text, text, jsonb, text, text, text
) from public, anon;
grant execute on function public.guest_web_submit_order_v2(
  text, text, jsonb, text, text, text
) to authenticated;

-- ============================================================================
-- 7. Sandbox-Seed
-- ============================================================================

-- Nur fuer die Sandbox-Venue und bewusst mit **vorhersagbaren** Tokens, damit
-- Doku, Tests und Vorfuehrung eine feste URL haben. In einem echten Betrieb
-- vergibt `operator_upsert_table` zufaellige Tokens; `operator_rotate_table_token`
-- ersetzt die Sandbox-Tokens jederzeit.
do $$
declare
  v_venue_id uuid;
  v_table_id uuid;
  v_seed record;
begin
  select id into v_venue_id from public.venues where slug = 'alte-muehle';
  if v_venue_id is null then
    return;
  end if;

  for v_seed in
    select *
    from (values
      ('1', 'Gastraum', 10, 'sandbox-tisch-1'),
      ('2', 'Gastraum', 20, 'sandbox-tisch-2'),
      ('3', 'Gastraum', 30, 'sandbox-tisch-3'),
      ('4', 'Terrasse', 40, 'sandbox-tisch-4'),
      ('5', 'Terrasse', 50, 'sandbox-tisch-5'),
      ('Theke', 'Bar', 60, 'sandbox-theke')
    ) as seed(label, area, sort_order, token)
  loop
    insert into public.tables (venue_id, label, area, sort_order, active)
    values (v_venue_id, v_seed.label, v_seed.area, v_seed.sort_order, true)
    on conflict (venue_id, label) do update
      set area = excluded.area,
          sort_order = excluded.sort_order
    returning id into v_table_id;

    insert into public.qr_tokens (token, venue_id, table_id, mode, active)
    values (v_seed.token, v_venue_id, v_table_id, 'table', true)
    on conflict (token) do nothing;
  end loop;

  -- Der Platzhalter `Sandbox-Tisch` aus dem Bestell-Gate-Seed (20260717120000)
  -- hat keinen QR-Code und keine Bedeutung mehr, seit es echte Tische gibt. Er
  -- wird stillgelegt statt geloescht, damit vorhandene Bestellungen ihre
  -- Zuordnung behalten.
  update public.tables
  set active = false
  where venue_id = v_venue_id and label = 'Sandbox-Tisch';
end;
$$;

commit;
