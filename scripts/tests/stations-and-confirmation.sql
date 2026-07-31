-- Funktionstest fuer KL-STATION-001 und KL-ORDER-001 (Migrationen
-- 20260731140000 und 20260731160000). Aufruf ueber
-- `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird: dass Speisen und Getraenke automatisch auf ihre Station
-- gehen, dass eine Bestellung erst `ready` wird, wenn **beide** Stationen
-- fertig sind, dass ein zweiter Tap nichts kaputt macht, und dass die
-- Annahmeregel nur den Kanal betrifft, fuer den sie gilt.

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

insert into public.venue_staff (user_id, venue_id, role)
select '00000000-0000-0000-0000-0000000000aa', id, 'owner'
from public.venues where slug = 'alte-muehle'
on conflict do nothing;

-- ============================================================================
-- 1. Station wird aus der Art abgeleitet
-- ============================================================================

do $$
declare
  v_order_id uuid;
  v_stations text[];
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000d1', true);

  -- Kuerbissuppe (food) und Hauslimonade (drink) in einer Bestellung.
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'station-1',
    '[{"slug":"kuerbissuppe","quantity":1},{"slug":"hauslimonade","quantity":2}]'::jsonb,
    'dine_in', '', 'sandbox-tisch-3');

  select array_agg(distinct station order by station) into v_stations
  from public.order_items where order_id = v_order_id;

  perform pg_temp.assert(
    v_stations = array['bar', 'kitchen'],
    'Erwartet Bar und Kueche, waren: ' || coalesce(array_to_string(v_stations, ','), 'keine')
  );
  perform pg_temp.assert(
    (select station from public.order_items
      where order_id = v_order_id and kind = 'drink' limit 1) = 'bar',
    'Getraenk gehoert an die Bar'
  );
  perform pg_temp.assert(
    (select count(*) from public.order_items
      where order_id = v_order_id and ready_at is not null) = 0,
    'Neue Positionen sind noch nicht fertig'
  );
end;
$$;

-- ============================================================================
-- 2. Erst wenn beide Stationen fertig sind, ist die Bestellung bereit
-- ============================================================================

do $$
declare
  v_order_id uuid;
  v_result jsonb;
begin
  select o.id into v_order_id
  from public.orders o
  where o.idempotency_key = 'station-1';

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  -- Die Kueche ist fertig, die Bar noch nicht.
  v_result := public.operator_mark_station_ready('alte-muehle', v_order_id, 'kitchen');
  perform pg_temp.assert(
    (v_result ->> 'items_marked')::int = 1,
    'Genau eine Kuechenposition erwartet'
  );
  perform pg_temp.assert(
    (v_result ->> 'order_ready')::boolean = false,
    'Bestellung darf noch nicht bereit sein — die Bar arbeitet noch'
  );
  perform pg_temp.assert(
    v_result -> 'open_stations' = '["bar"]'::jsonb,
    'Die Bar sollte als offene Station gemeldet werden'
  );
  perform pg_temp.assert(
    (select status from public.orders where id = v_order_id) <> 'ready',
    'Der Bestellstatus darf noch nicht ready sein'
  );

  -- Zweiter Tap derselben Station: kein Fehler, keine Wirkung.
  v_result := public.operator_mark_station_ready('alte-muehle', v_order_id, 'kitchen');
  perform pg_temp.assert(
    (v_result ->> 'items_marked')::int = 0,
    'Wiederholung darf nichts erneut freigeben'
  );

  -- Jetzt die Bar.
  v_result := public.operator_mark_station_ready('alte-muehle', v_order_id, 'bar');
  perform pg_temp.assert(
    (v_result ->> 'order_ready')::boolean,
    'Nach der letzten Station muss die Bestellung bereit sein'
  );
  perform pg_temp.assert(
    (select status from public.orders where id = v_order_id) = 'ready',
    'Bestellstatus sollte ready sein'
  );
  perform pg_temp.assert(
    (select ready_at is not null from public.orders where id = v_order_id),
    'ready_at sollte gesetzt sein'
  );
end;
$$;

-- Eine reine Getraenkebestellung braucht nur die Bar.
do $$
declare
  v_order_id uuid;
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000d2', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'station-2',
    '[{"slug":"hauslimonade","quantity":1}]'::jsonb,
    'bar', '', null);

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_result := public.operator_mark_station_ready('alte-muehle', v_order_id, 'bar');
  perform pg_temp.assert(
    (v_result ->> 'order_ready')::boolean,
    'Ohne Kuechenposition genuegt die Bar'
  );
end;
$$;

-- Unbekannte Station und fremde Identitaet werden abgewiesen.
do $$
declare
  v_order_id uuid;
begin
  select o.id into v_order_id from public.orders o where o.idempotency_key = 'station-2';

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_mark_station_ready('alte-muehle', %L, 'dessert')$q$, v_order_id),
    'station_invalid'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000bb', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_mark_station_ready('alte-muehle', %L, 'bar')$q$, v_order_id),
    'station_forbidden'
  );
end;
$$;

-- ============================================================================
-- 3. Annahmeregel
-- ============================================================================

do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  -- Standard: nichts muss bestaetigt werden.
  perform pg_temp.assert(
    (select order_confirmation_channels from public.venues where slug = 'alte-muehle') = '{}',
    'Standard ist automatische Annahme'
  );

  v_result := public.operator_set_confirmation_channels('alte-muehle', array['pickup']);
  perform pg_temp.assert(
    v_result -> 'channels' = '["pickup"]'::jsonb,
    'Kanal pickup sollte gesetzt sein'
  );

  -- Unbekannte Kanaele werden nicht stillschweigend verschluckt.
  perform pg_temp.expect_error(
    $q$select public.operator_set_confirmation_channels('alte-muehle', array['telepathie'])$q$,
    'confirmation_invalid_channel'
  );
  perform pg_temp.assert(
    (select order_confirmation_channels from public.venues where slug = 'alte-muehle') = array['pickup'],
    'Die abgelehnte Aenderung darf nichts ueberschrieben haben'
  );
end;
$$;

-- Ablehnen ist nur vor der Annahme moeglich.
do $$
declare
  v_pickup uuid;
  v_dinein uuid;
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000d3', true);
  select order_id into v_pickup
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'confirm-1',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb, 'pickup', '', null);

  select order_id into v_dinein
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'confirm-2',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb, 'dine_in', '', 'sandbox-theke');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  -- Die Bestellung kommt weiter als `pending` an; die Regel steuert nur, wer
  -- sie als Naechstes sieht.
  perform pg_temp.assert(
    (select status from public.orders where id = v_pickup) = 'pending',
    'Bestellung sollte pending sein'
  );

  v_result := public.operator_reject_order('alte-muehle', v_pickup, 'Küche voll');
  perform pg_temp.assert((v_result ->> 'replayed')::boolean = false, 'Erste Ablehnung');
  perform pg_temp.assert(
    (select status from public.orders where id = v_pickup) = 'rejected',
    'Status sollte rejected sein'
  );
  perform pg_temp.assert(
    (select rejection_reason from public.orders where id = v_pickup) = 'Küche voll',
    'Ablehnungsgrund fehlt'
  );

  -- Zweite Ablehnung ist ein Replay, kein Fehler.
  v_result := public.operator_reject_order('alte-muehle', v_pickup, 'nochmal');
  perform pg_temp.assert((v_result ->> 'replayed')::boolean, 'Replay erwartet');

  -- Was schon angenommen ist, wird storniert und nicht abgelehnt.
  perform public.operator_update_order_status(v_dinein, 'accepted');
  perform pg_temp.expect_error(
    format($q$select public.operator_reject_order('alte-muehle', %L, 'zu spaet')$q$, v_dinein),
    'reject_too_late'
  );
end;
$$;

-- Aufraeumen: die Regel zurueck auf den Standard, damit spaetere Laeufe von
-- einem sauberen Stand ausgehen.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform public.operator_set_confirmation_channels('alte-muehle', array[]::text[]);
end;
$$;

select 'KL-STATION-001 / KL-ORDER-001: alle SQL-Pruefungen bestanden' as ergebnis;
