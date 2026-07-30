-- Funktionstest fuer KL-TABLE-001 (Migration 20260730120000_table_context.sql)
-- gegen eine lokale Wegwerf-Instanz. Aufruf ueber
-- `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird das, was Unit-Tests der App grundsaetzlich nicht koennen: dass
-- die SQL laeuft, dass Tisch und Tisch-Session tatsaechlich an der Bestellung
-- haengen, dass ungueltige QR-Codes abgewiesen werden und dass die drei
-- Tischtabellen nach dieser Migration nicht mehr fuer `anon` offen stehen.

\set ON_ERROR_STOP on

create or replace function pg_temp.expect_error(p_sql text, p_fragment text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception
    when others then
      if position(p_fragment in sqlerrm) = 0 then
        raise exception 'Erwartet Fehler mit "%", bekommen: %', p_fragment, sqlerrm;
      end if;
      return;
  end;
  raise exception 'Erwartet Fehler mit "%", aber der Aufruf war erfolgreich: %',
    p_fragment, p_sql;
end;
$$;

create or replace function pg_temp.assert(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'FEHLGESCHLAGEN: %', p_message;
  end if;
end;
$$;

create or replace function pg_temp.act_as(p_user uuid, p_anonymous boolean)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user, 'is_anonymous', p_anonymous)::text,
    false
  );
end;
$$;

-- Personal und zwei anonyme Gaeste.
insert into public.venue_staff (user_id, venue_id)
select '00000000-0000-0000-0000-0000000000aa', id
from public.venues where slug = 'alte-muehle'
on conflict do nothing;

-- ============================================================================
-- 1. Seed
-- ============================================================================

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.tables t
      join public.venues v on v.id = t.venue_id
      where v.slug = 'alte-muehle' and t.active) = 6,
    'Sechs aktive Sandbox-Tische erwartet'
  );
  perform pg_temp.assert(
    (select count(*) from public.qr_tokens where active and mode = 'table') = 6,
    'Sechs aktive Tisch-Tokens erwartet'
  );
  perform pg_temp.assert(
    (select not active from public.tables t
      join public.venues v on v.id = t.venue_id
      where v.slug = 'alte-muehle' and t.label = 'Sandbox-Tisch'),
    'Der alte Platzhalter-Tisch soll stillgelegt sein'
  );
end;
$$;

-- ============================================================================
-- 2. Tischauskunft fuer den Gast
-- ============================================================================

do $$
declare
  v_label text;
  v_area text;
begin
  select label, area into v_label, v_area
  from public.guest_web_resolve_table('alte-muehle', 'sandbox-tisch-1');
  perform pg_temp.assert(v_label = '1', 'Tischbezeichnung 1 erwartet, war ' || coalesce(v_label, '<null>'));
  perform pg_temp.assert(v_area = 'Gastraum', 'Bereich Gastraum erwartet');

  perform pg_temp.expect_error(
    $q$select * from public.guest_web_resolve_table('alte-muehle', 'gibt-es-nicht')$q$,
    'guest_web_unknown_table'
  );
  -- Token der richtigen Venue, aber falscher Venue-Slug: keine Auskunft.
  perform pg_temp.expect_error(
    $q$select * from public.guest_web_resolve_table('andere-venue', 'sandbox-tisch-1')$q$,
    'guest_web_unknown_table'
  );
end;
$$;

-- ============================================================================
-- 3. Gastbestellung mit Tisch
-- ============================================================================

do $$
declare
  v_order_id uuid;
  v_table_id uuid;
  v_session_id uuid;
  v_second_session uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000000001', true);

  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle',
    'test-tisch-1-a',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in',
    '',
    'sandbox-tisch-1'
  );

  select o.table_id, o.table_session_id into v_table_id, v_session_id
  from public.orders o where o.id = v_order_id;

  perform pg_temp.assert(v_table_id is not null, 'Bestellung ohne Tischbezug');
  perform pg_temp.assert(v_session_id is not null, 'Bestellung ohne Tisch-Session');
  perform pg_temp.assert(
    (select label from public.tables where id = v_table_id) = '1',
    'Bestellung haengt am falschen Tisch'
  );
  perform pg_temp.assert(
    (select status from public.table_sessions where id = v_session_id) = 'open',
    'Tisch-Session sollte offen sein'
  );

  -- Zweiter Gast am selben Tisch: dieselbe offene Session (Blueprint §6.1).
  -- Die Bestellung wird bewusst in einem eigenen Statement nachgelesen: ein
  -- Join auf `orders` im selben SELECT saehe den Insert der Funktion noch nicht.
  perform pg_temp.act_as('00000000-0000-0000-0000-000000000002', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle',
    'test-tisch-1-b',
    '[{"slug":"kuerbissuppe","quantity":2}]'::jsonb,
    'dine_in',
    '',
    'sandbox-tisch-1'
  );
  select o.table_session_id into v_second_session
  from public.orders o where o.id = v_order_id;

  perform pg_temp.assert(
    v_second_session = v_session_id,
    'Zweiter Gast am selben Tisch bekam eine eigene Session'
  );
  perform pg_temp.assert(
    (select count(*) from public.table_sessions where table_id = v_table_id and status = 'open') = 1,
    'Mehr als eine offene Session je Tisch'
  );
end;
$$;

-- ============================================================================
-- 4. Bestehendes Verhalten ohne Tisch bleibt unveraendert
-- ============================================================================

do $$
declare
  v_order_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000000003', true);

  -- Aufruf mit fuenf Argumenten wie vor dieser Migration.
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle',
    'test-ohne-tisch',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'pickup',
    'ohne Tisch'
  );

  perform pg_temp.assert(
    (select table_id is null and table_session_id is null
       from public.orders where id = v_order_id),
    'Bestellung ohne Token darf keinen Tischbezug bekommen'
  );
end;
$$;

-- ============================================================================
-- 5. Ungueltige Tischangaben
-- ============================================================================

do $$
declare
  v_orders_before int;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000000004', true);
  select count(*) into v_orders_before from public.orders;

  perform pg_temp.expect_error(
    $q$select * from public.guest_web_submit_order_v2(
      'alte-muehle', 'test-unbekannter-tisch',
      '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb, 'dine_in', '', 'gibt-es-nicht')$q$,
    'guest_web_unknown_table'
  );

  perform pg_temp.expect_error(
    $q$select * from public.guest_web_submit_order_v2(
      'alte-muehle', 'test-tisch-abholung',
      '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb, 'pickup', '', 'sandbox-tisch-2')$q$,
    'guest_web_invalid_service_mode'
  );

  perform pg_temp.assert(
    (select count(*) from public.orders) = v_orders_before,
    'Abgewiesene Bestellung wurde trotzdem geschrieben'
  );
end;
$$;

-- ============================================================================
-- 6. Idempotenz beruecksichtigt den Tisch
-- ============================================================================

do $$
declare
  v_first uuid;
  v_replay uuid;
  v_replayed boolean;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000000005', true);

  select order_id into v_first
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'test-idem', '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in', '', 'sandbox-tisch-3');

  select order_id, idempotent_replay into v_replay, v_replayed
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'test-idem', '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in', '', 'sandbox-tisch-3');

  perform pg_temp.assert(v_replay = v_first and v_replayed, 'Wiederholung erzeugte keine Replay-Antwort');

  -- Gleicher Schluessel, anderer Tisch: Konflikt statt stiller Gleichsetzung.
  perform pg_temp.expect_error(
    $q$select * from public.guest_web_submit_order_v2(
      'alte-muehle', 'test-idem', '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
      'dine_in', '', 'sandbox-tisch-4')$q$,
    'guest_web_idempotency_conflict'
  );
end;
$$;

-- ============================================================================
-- 7. Staff-RPCs
-- ============================================================================

do $$
declare
  v_result jsonb;
  v_table_id uuid;
  v_token text;
  v_rotated text;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  v_result := public.operator_upsert_table('alte-muehle', 'Wintergarten 1', 'Wintergarten', 70);
  v_table_id := (v_result ->> 'table_id')::uuid;
  v_token := v_result ->> 'token';

  perform pg_temp.assert(char_length(v_token) = 32, 'Zufaelliges Token mit 32 Zeichen erwartet');
  perform pg_temp.assert(
    (select label from public.guest_web_resolve_table('alte-muehle', v_token)) = 'Wintergarten 1',
    'Neuer Tisch ist ueber sein Token nicht aufloesbar'
  );

  -- Umbenennen ueber die ID behaelt Tisch und Token.
  v_result := public.operator_upsert_table(
    'alte-muehle', 'Wintergarten A', 'Wintergarten', 70, true, v_table_id);
  perform pg_temp.assert(
    (v_result ->> 'token') = v_token,
    'Umbenennen darf den QR-Code nicht wechseln'
  );
  perform pg_temp.assert(
    (select label from public.tables where id = v_table_id) = 'Wintergarten A',
    'Umbenennen hat nicht gewirkt'
  );

  -- Rotieren legt den alten Code still.
  v_rotated := public.operator_rotate_table_token('alte-muehle', v_table_id);
  perform pg_temp.assert(v_rotated <> v_token, 'Rotieren gab dasselbe Token zurueck');
  perform pg_temp.expect_error(
    format($q$select * from public.guest_web_resolve_table('alte-muehle', %L)$q$, v_token),
    'guest_web_unknown_table'
  );
  perform pg_temp.assert(
    (select label from public.guest_web_resolve_table('alte-muehle', v_rotated)) = 'Wintergarten A',
    'Neues Token loest nicht auf'
  );
  perform pg_temp.assert(
    (select count(*) from public.qr_tokens where table_id = v_table_id and active) = 1,
    'Nach dem Rotieren darf nur ein Token aktiv sein'
  );

  -- Stillgelegter Tisch nimmt keine Bestellung mehr an.
  perform public.operator_upsert_table(
    'alte-muehle', 'Wintergarten A', 'Wintergarten', 70, false, v_table_id);
  perform pg_temp.expect_error(
    format($q$select * from public.guest_web_resolve_table('alte-muehle', %L)$q$, v_rotated),
    'guest_web_unknown_table'
  );

  -- Loeschen: ohne Bestellungen erlaubt, mit Bestellungen abgelehnt.
  perform pg_temp.assert(
    public.operator_delete_table('alte-muehle', v_table_id),
    'Tisch ohne Bestellungen sollte loeschbar sein'
  );
  perform pg_temp.expect_error(
    format($q$select public.operator_delete_table('alte-muehle', %L)$q$,
      (select t.id from public.tables t
        join public.venues v on v.id = t.venue_id
        where v.slug = 'alte-muehle' and t.label = '1')),
    'table_in_use'
  );
end;
$$;

-- Fremde Identitaet ohne venue_staff-Eintrag.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000bb', false);
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_table('alte-muehle', 'Fremd', '', 0)$q$,
    'table_forbidden'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_rotate_table_token('alte-muehle',
      '00000000-0000-0000-0000-000000000000')$q$,
    'table_forbidden'
  );
end;
$$;

-- ============================================================================
-- 8. Kellnerbestellung am Tisch (KL-TABLE-002)
-- ============================================================================

do $$
declare
  v_table_id uuid;
  v_guest_session uuid;
  v_result jsonb;
  v_items int;
begin
  select t.id into v_table_id
  from public.tables t
  join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '1';

  select o.table_session_id into v_guest_session
  from public.orders o
  where o.table_id = v_table_id
  order by o.created_at
  limit 1;

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  v_result := public.operator_create_order(
    'alte-muehle',
    'cccccccc-0000-0000-0000-000000000001',
    now(),
    'ios-waiter',
    1380,
    'dine_in',
    'ohne Zwiebeln',
    '[{"name":"Kürbissuppe","quantity":2,"unit_price_cents":690,"kind":"food"}]'::jsonb,
    v_table_id
  );

  perform pg_temp.assert(
    (v_result ->> 'table_id')::uuid = v_table_id,
    'Kellnerbestellung ohne Tischbezug'
  );
  -- Der Kellner schreibt in denselben offenen Vorgang wie die Gaeste am Tisch.
  perform pg_temp.assert(
    (v_result ->> 'table_session_id')::uuid = v_guest_session,
    'Kellner eroeffnete eine zweite Session am selben Tisch'
  );
  perform pg_temp.assert(
    (v_result ->> 'replayed')::boolean = false,
    'Erste Zustellung darf kein Replay sein'
  );

  -- Wiederholter Outbox-Versand: dieselbe Bestellung, keine zweiten Positionen.
  v_result := public.operator_create_order(
    'alte-muehle',
    'cccccccc-0000-0000-0000-000000000001',
    now(),
    'ios-waiter',
    1380,
    'dine_in',
    'ohne Zwiebeln',
    '[{"name":"Kürbissuppe","quantity":2,"unit_price_cents":690,"kind":"food"}]'::jsonb,
    v_table_id
  );
  perform pg_temp.assert(
    (v_result ->> 'replayed')::boolean = true,
    'Wiederholung wurde nicht als Replay erkannt'
  );

  select count(*) into v_items
  from public.order_items
  where order_id = 'cccccccc-0000-0000-0000-000000000001';
  perform pg_temp.assert(
    v_items = 1,
    'Wiederholter Versand hat die Positionen verdoppelt (' || v_items || ')'
  );

  -- Ohne Tisch bleibt die Kellnerbestellung wie bisher moeglich (Theke,
  -- Abholung, Telefon).
  v_result := public.operator_create_order(
    'alte-muehle',
    'cccccccc-0000-0000-0000-000000000002',
    now(),
    'ios-waiter',
    690,
    'pickup',
    '',
    '[{"name":"Kürbissuppe","quantity":1,"unit_price_cents":690,"kind":"food"}]'::jsonb
  );
  perform pg_temp.assert(
    v_result ->> 'table_id' is null,
    'Bestellung ohne Tisch bekam einen Tisch'
  );
end;
$$;

-- Stillgelegter Tisch und fremde Venue werden abgewiesen.
do $$
declare
  v_table_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select t.id into v_table_id
  from public.tables t
  join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '5';

  perform public.operator_upsert_table('alte-muehle', '5', 'Terrasse', 50, false, v_table_id);

  perform pg_temp.expect_error(
    format($q$select public.operator_create_order(
      'alte-muehle', 'cccccccc-0000-0000-0000-000000000003', now(), 'ios-waiter',
      690, 'dine_in', '', '[]'::jsonb, %L)$q$, v_table_id),
    'create_order_unknown_table'
  );

  -- Aufraeumen, damit die Zaehlung in Abschnitt 1 fuer spaetere Laeufe stimmt.
  perform public.operator_upsert_table('alte-muehle', '5', 'Terrasse', 50, true, v_table_id);
end;
$$;

-- Ohne Personalrolle geht gar nichts.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000bb', false);
  perform pg_temp.expect_error(
    $q$select public.operator_create_order(
      'alte-muehle', 'cccccccc-0000-0000-0000-000000000004', now(), 'ios-waiter',
      690, 'dine_in', '', '[]'::jsonb)$q$,
    'create_order_forbidden'
  );
end;
$$;

-- ============================================================================
-- 9. Die drei Tischtabellen sind nicht mehr fuer anon offen
-- ============================================================================

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.tables) = 0,
    'anon darf keine Tische lesen'
  );
  perform pg_temp.assert(
    (select count(*) from public.qr_tokens) = 0,
    'anon darf keine QR-Tokens lesen'
  );
  perform pg_temp.assert(
    (select count(*) from public.table_sessions) = 0,
    'anon darf keine Tisch-Sessions lesen'
  );
  perform pg_temp.expect_error(
    $q$insert into public.tables (venue_id, label)
       values ('11111111-1111-1111-1111-111111111111', 'Eingeschmuggelt')$q$,
    'row-level security'
  );
  perform pg_temp.expect_error(
    $q$insert into public.qr_tokens (token, venue_id, mode)
       values ('geklaut', '11111111-1111-1111-1111-111111111111', 'venue_shared')$q$,
    'row-level security'
  );
end;
$$;

reset role;

select 'KL-TABLE-001: alle SQL-Pruefungen bestanden' as ergebnis;
