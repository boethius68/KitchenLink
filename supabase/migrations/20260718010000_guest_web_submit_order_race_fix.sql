-- KL-WEB-003: Schließt das dokumentierte, nicht behobene Restrisiko aus
-- KL-WEB-002 (siehe ORDER_GATE.md / CURRENT.md): eine enge Race Condition bei
-- zwei nahezu gleichzeitigen Sendungen mit demselben Idempotenz-Key wurde
-- bisher nur vom DB-Unique-Constraint aufgefangen und vom Verlierer als
-- generisches rpc_error wahrgenommen. Die Kerngarantie (nie zwei Bestellungen
-- für einen Key) hielt; dieser Fix mappt die Concurrent-Race sauber auf das
-- bestehende Replay-/Konflikt-Ergebnis.
--
-- Mechanismus: der INSERT in orders (4.7) wird in einen Subblock mit
-- `EXCEPTION WHEN unique_violation` gesetzt. Trifft ein zweiter Concurrent-
-- Request denselben Key, fängt der Verlierer 23505 ab, liest die inzwischen
-- persistierte Order und gibt das determinierte Ergebnis zurück:
--   - gleicher Payload-Hash -> sauberes Replay (idempotent_replay = true),
--   - anderer Payload-Hash    -> sauberer guest_web_idempotency_conflict.
--
-- Additiv: redefiniert nur die Funktion guest_web_submit_order. Keine Tabellen-
-- oder Policy-Änderung. Die Basisschema-Datei und die Migration
-- 20260717120000_guest_web_order_gate.sql bleiben unangetastet.
--
-- ZWEI weitere echte Fixes (durch die Integrationstests von KL-WEB-003 gegen
-- eine echte Supabase-Instanz aufgedeckt; die KL-WEB-002-Unit-Tests konnten
-- sie nicht finden, weil sie nie gegen echtes PostgreSQL liefen):
--   1. digest() liegt bei Supabase im Schema "extensions", nicht public; der
--      search_path der Funktion (public,pg_temp) schließt extensions nicht
--      ein. Schema-qualifizierter Aufruf extensions.digest() statt search_path
--      zu erweitern (sicherer gegen Schema-Spoofing). Sonst: SQLSTATE 42883.
--   2. Die SELECT-INTO-Blöcke referenzieren status/total_cents/currency
--      ohne Tabellen-Alias; da dies auch RETURN-Spalten der Funktion sind,
--      ist die Spaltenreferenz mehrdeutig (SQLSTATE 42702). Alias o. fest.
-- Beide Bugs verhinderten jede reale Bestellung; die Race-Fix-Migration muss
-- sie enthalten, damit frische Instanzen sofort laufen.

begin;

create or replace function public.guest_web_submit_order(
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
  v_is_anonymous boolean;
  v_venue record;
  v_item record;
  v_total int := 0;
  v_order_id uuid;
  v_status text := 'pending';
  v_payload_hash text;
  v_existing record;
  v_clean_items jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_item_slug text;
  v_qty int;
  v_index int := 0;
  v_row record;
begin
  -- 1) Anonyme Identität: nur ein (anonym) eingelogter User darf bestellen.
  -- Die bloße anon-Rolle hat keinen auth.uid() und scheitert hier.
  if v_user is null then
    raise exception 'guest_web_unauthenticated: Anonymous Sign-in erforderlich';
  end if;

  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
    into v_is_anonymous;

  -- In dieser Sandbox akzeptieren wir auch dauerhafte authentifizierte Nutzer
  -- (z. B. Mitarbeiter-Test). Die gastseitige Verdrahtung verwendet
  -- ausschließlich Anonymous Sign-in.

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'guest_web_invalid_idempotency_key: leer';
  end if;

  if p_service_mode is null then
    p_service_mode := 'dine_in';
  end if;

  if p_service_mode not in ('dine_in', 'bar', 'pickup') then
    raise exception 'guest_web_invalid_service_mode: %', p_service_mode;
  end if;

  -- 2) Venue-Lookup über Slug.
  select id into v_venue from public.venues where slug = p_venue_slug;
  if not found then
    raise exception 'guest_web_unknown_venue: %', p_venue_slug;
  end if;

  -- 3) Öffnungszeit / Kapazität: bewusst simuliert als „immer offen, unbegrenzt"
  -- (siehe ORDER_GATE.md §5).

  -- 4) Payload normalisieren und deterministischen Hash bilden. Sortierung nach
  -- slug macht den Hash unabhängig von der Client-Reihenfolge.
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'guest_web_invalid_items: kein Array';
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_slug := v_elem ->> 'slug';
    v_qty := coalesce((v_elem ->> 'quantity')::int, 0);
    if v_item_slug is null or v_qty is null or v_qty <= 0 then
      raise exception 'guest_web_invalid_item: slug oder quantity fehlt';
    end if;
    v_clean_items := v_clean_items || jsonb_build_array(
      jsonb_build_object('slug', v_item_slug, 'quantity', v_qty)
    );
    v_index := v_index + 1;
  end loop;

  if v_index = 0 then
    raise exception 'guest_web_empty_order: keine Positionen';
  end if;

  -- digest()/encode() liegen in Supabase im Schema "extensions" (nicht public);
  -- der search_path der Funktion ist public,pg_temp. Daher schema-qualifiziert
  -- aufrufen, statt dem search_path "extensions" hinzuzufügen (sicherer gegen
  -- Schema-Spoofing). encode() ist pg-intern (pg_catalog), immer sichtbar.
  select encode(
    extensions.digest(
      v_venue.id::text || '|' || p_idempotency_key || '|' ||
      coalesce(p_service_mode, '') || '|' ||
      coalesce(p_customer_note, '') || '|' ||
      coalesce(v_clean_items::text, ''),
      'sha256'
    ),
    'hex'
  ) into v_payload_hash;

  -- 5) Idempotenz (erwarteter Fall): gleicher Key + gleicher Payload ->
  -- gespeicherte Order als Replay. Vor dem INSERT als schnellem Pfad.
  -- Alias o. enteignet: status/total_cents/currency sind auch RETURN-Spalten
  -- der Funktion; ohne Alias waere die Spaltenreferenz mehrdeutig (SQLSTATE 42702).
  select o.id, o.status, o.total_cents, o.currency, o.idempotency_payload_hash
    into v_existing
  from public.orders o
  where o.venue_id = v_venue.id
    and o.idempotency_key = p_idempotency_key;

  if found then
    if v_existing.idempotency_payload_hash is distinct from v_payload_hash then
      raise exception 'guest_web_idempotency_conflict: gleicher Key, anderer Inhalt';
    end if;
    return query
      select
        v_existing.id,
        v_existing.status,
        v_existing.total_cents,
        v_existing.currency,
        true,
        true;
    return;
  end if;

  -- 6) Serverseitige Neubepreisung aus menu_items.price_cents mit row-lock.
  for v_row in
    select t.slug, t.quantity
    from (
      select
        (je ->> 'slug') as slug,
        coalesce((je ->> 'quantity')::int, 0) as quantity
      from jsonb_array_elements(v_clean_items) as je
    ) t
  loop
    select mi.id, mi.price_cents, mi.available, mc.menu_id
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

    v_total := v_total + v_item.price_cents * v_row.quantity;
  end loop;

  -- 7) Race-safe Persistierung. Der INSERT kann bei einem Concurrent-Duplikat
  -- am unique(venue_id, idempotency_key) scheitern (SQLSTATE 23505). Wird der
  -- Subblock betreten, fängt EXCEPTION die Verletzung ab; wir lesen die vom
  -- Gewinner geschriebene Order und entscheiden deterministisch (Replay vs.
  -- Konflikt), statt den Fehler als generisches rpc_error nach oben reichen zu
  -- lassen. Das schließt das KL-WEB-002-Restrisiko sauber ab.
  begin
    insert into public.orders (
      venue_id, source_device, total_cents, status, service_mode,
      customer_note, currency, idempotency_key, idempotency_payload_hash, created_by
    )
    values (
      v_venue.id, 'guest_web', v_total, v_status, p_service_mode,
      coalesce(p_customer_note, ''), 'EUR', p_idempotency_key, v_payload_hash, v_user
    )
    returning id into v_order_id;
  exception
    when unique_violation then
      -- Concurrent-Race: ein anderer Request hat denselben Key zuerst committet.
      select o.id, o.status, o.total_cents, o.currency, o.idempotency_payload_hash
        into v_existing
      from public.orders o
      where o.venue_id = v_venue.id
        and o.idempotency_key = p_idempotency_key;

      if not found then
        -- Sollte nicht vorkommen (Constraint verletzte sich gerade); defensiv.
        raise exception 'guest_web_idempotency_race_unresolved';
      end if;

      if v_existing.idempotency_payload_hash is distinct from v_payload_hash then
        raise exception 'guest_web_idempotency_conflict: gleicher Key, anderer Inhalt (race)';
      end if;

      return query
        select
          v_existing.id,
          v_existing.status,
          v_existing.total_cents,
          v_existing.currency,
          true,
          true;
      return;
  end;

  -- 8) Positionen aus DB-Preisen schreiben (nur nach erfolgreichem INSERT).
  for v_row in
    select t.slug, t.quantity
    from (
      select
        (je ->> 'slug') as slug,
        coalesce((je ->> 'quantity')::int, 0) as quantity
      from jsonb_array_elements(v_clean_items) as je
    ) t
  loop
    select mi.id, mi.name, mi.price_cents, mi.kind
      into v_item
    from public.menu_items mi
    join public.menu_categories mc on mc.id = mi.category_id
    join public.menus m on m.id = mc.menu_id
    where mi.slug = v_row.slug
      and m.venue_id = v_venue.id
      and m.active = true;

    insert into public.order_items (order_id, menu_item_id, name, quantity, unit_price_cents, kind)
    values (v_order_id, v_item.id, v_item.name, v_row.quantity, v_item.price_cents, v_item.kind);
  end loop;

  -- 9) ACK: die tatsächlich gespeicherte Order.
  return query
    select
      v_order_id,
      v_status,
      v_total,
      'EUR'::char(3),
      false,
      true;

  return;
end;
$$;

-- Privilegien wie im Original: revoke von public/anon, grant execute an
-- authenticated. Die Redefinition ändert nichts an den Grants.
revoke all on function public.guest_web_submit_order(
  text, text, jsonb, text, text
) from public, anon;
grant execute on function public.guest_web_submit_order(
  text, text, jsonb, text, text
) to authenticated;

commit;
