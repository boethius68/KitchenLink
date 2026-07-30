-- Funktionstest fuer KL-PAY-001 (Migration 20260731100000_sandbox_payments.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird, was im Betrieb Geld kostet, wenn es falsch ist: dass eine
-- Position nicht zweimal kassiert wird, dass der Betrag aus der Datenbank
-- kommt und nicht vom Geraet, dass eine Wiederholung keine zweite Zahlung
-- erzeugt, dass die Rechnung sich schliesst, wenn nichts mehr offen ist, und
-- dass ein Storno die Positionen wieder freigibt.

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

insert into public.venue_staff (user_id, venue_id)
select '00000000-0000-0000-0000-0000000000aa', id
from public.venues where slug = 'alte-muehle'
on conflict do nothing;

-- ============================================================================
-- Ausgangslage: zwei Gaeste bestellen an Tisch 2 ueber den Tisch-QR.
-- ============================================================================

do $$
declare
  v_order_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000c1', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'pay-gast-1',
    '[{"slug":"kuerbissuppe","quantity":2}]'::jsonb,
    'dine_in', '', 'sandbox-tisch-2');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000c2', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'pay-gast-2',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in', '', 'sandbox-tisch-2');
end;
$$;

-- ============================================================================
-- 1. Rechnung lesen
-- ============================================================================

do $$
declare
  v_table_id uuid;
  v_check jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '2';

  v_check := public.operator_table_check('alte-muehle', v_table_id);

  -- Beide Bestellungen desselben Tisches stehen auf einer Rechnung (§6.1).
  perform pg_temp.assert(
    jsonb_array_length(v_check -> 'items') = 2,
    'Zwei Positionen erwartet, waren ' || jsonb_array_length(v_check -> 'items')
  );
  perform pg_temp.assert(
    (v_check ->> 'total_cents')::int = 2070,
    'Gesamt 20,70 EUR erwartet, war ' || (v_check ->> 'total_cents')
  );
  perform pg_temp.assert((v_check ->> 'paid_cents')::int = 0, 'Noch nichts bezahlt');
  perform pg_temp.assert((v_check ->> 'open_cents')::int = 2070, 'Alles offen');
end;
$$;

-- Ein Tisch ohne offene Session hat eine leere Rechnung statt eines Fehlers.
do $$
declare
  v_table_id uuid;
  v_check jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '4';

  v_check := public.operator_table_check('alte-muehle', v_table_id);
  perform pg_temp.assert(v_check ->> 'table_session_id' is null, 'Keine offene Rechnung erwartet');
  perform pg_temp.assert((v_check ->> 'open_cents')::int = 0, 'Nichts offen erwartet');
end;
$$;

-- Fremde Identitaet sieht keine Rechnung.
do $$
declare
  v_table_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000bb', false);
  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '2';
  perform pg_temp.expect_error(
    format($q$select public.operator_table_check('alte-muehle', %L)$q$, v_table_id),
    'check_forbidden'
  );
end;
$$;

-- ============================================================================
-- 2. Getrennt zahlen: der Betrag kommt aus der Datenbank
-- ============================================================================

do $$
declare
  v_table_id uuid;
  v_check jsonb;
  v_session uuid;
  v_first uuid;
  v_second uuid;
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '2';

  v_check := public.operator_table_check('alte-muehle', v_table_id);
  v_session := (v_check ->> 'table_session_id')::uuid;
  v_first := ((v_check -> 'items' -> 0) ->> 'order_item_id')::uuid;
  v_second := ((v_check -> 'items' -> 1) ->> 'order_item_id')::uuid;

  -- Ein behaupteter Betrag, der nicht zu den Positionen passt, wird abgelehnt.
  perform pg_temp.expect_error(
    format($q$select public.operator_record_payment(
      'alte-muehle', %L, 'cash', 'pay-luege', 0, array[%L]::uuid[], 1)$q$,
      v_session, v_first),
    'payment_amount_mismatch'
  );

  -- Erste Zahlung: nur die eine Position, plus Trinkgeld.
  v_result := public.operator_record_payment(
    'alte-muehle', v_session, 'cash', 'pay-1', 200, array[v_first]::uuid[]);

  perform pg_temp.assert(
    (v_result ->> 'amount_cents')::int = 1380,
    'Serverseitig gerechneter Betrag erwartet, war ' || (v_result ->> 'amount_cents')
  );
  perform pg_temp.assert((v_result ->> 'tip_cents')::int = 200, 'Trinkgeld fehlt');
  perform pg_temp.assert(
    (v_result ->> 'provider_reference') like 'sandbox-%',
    'Sandbox-Referenz erwartet'
  );

  -- Referenz des Anbieters (Blueprint §8.2): wird sie mitgeliefert, gilt sie.
  perform pg_temp.assert(
    (public.operator_record_payment(
      'alte-muehle', v_session, 'card', 'pay-referenz', 0, null, 100,
      'sandbox-terminal-4711') ->> 'provider_reference') = 'sandbox-terminal-4711',
    'Mitgelieferte Anbieter-Referenz wurde nicht uebernommen'
  );
  perform public.operator_refund_payment(
    'alte-muehle',
    (select id from public.payments where idempotency_key = 'pay-referenz'),
    'Testbuchung'
  );
  perform pg_temp.assert(
    (v_result ->> 'session_closed')::boolean = false,
    'Rechnung darf noch nicht geschlossen sein'
  );

  -- Dieselbe Position ein zweites Mal: abgelehnt.
  perform pg_temp.expect_error(
    format($q$select public.operator_record_payment(
      'alte-muehle', %L, 'card', 'pay-doppelt', 0, array[%L]::uuid[])$q$,
      v_session, v_first),
    'payment_item_unavailable'
  );

  -- Wiederholung derselben Zahlung (Netzwerk-Retry): keine zweite Buchung.
  v_result := public.operator_record_payment(
    'alte-muehle', v_session, 'cash', 'pay-1', 200, array[v_first]::uuid[]);
  perform pg_temp.assert((v_result ->> 'replayed')::boolean, 'Replay erwartet');
  perform pg_temp.assert(
    (select count(*) from public.payments where idempotency_key = 'pay-1') = 1,
    'Wiederholung erzeugte eine zweite Zahlung'
  );

  -- Zwischenstand der Rechnung.
  v_check := public.operator_table_check('alte-muehle', v_table_id);
  perform pg_temp.assert((v_check ->> 'paid_cents')::int = 1380, 'Bezahlt-Summe falsch');
  perform pg_temp.assert((v_check ->> 'open_cents')::int = 690, 'Offen-Summe falsch');
  perform pg_temp.assert((v_check ->> 'tip_cents')::int = 200, 'Trinkgeld-Summe falsch');
  perform pg_temp.assert(
    (select count(*) from jsonb_array_elements(v_check -> 'items') as i(value)
      where (i.value ->> 'paid')::boolean) = 1,
    'Genau eine Position sollte als bezahlt gelten'
  );

  -- Teilbetrag ohne Positionsauswahl darf den offenen Betrag nicht ueberschreiten.
  perform pg_temp.expect_error(
    format($q$select public.operator_record_payment(
      'alte-muehle', %L, 'cash', 'pay-zuviel', 0, null, 700)$q$, v_session),
    'payment_exceeds_open'
  );

  -- Rest zahlen: die Rechnung schliesst sich.
  v_result := public.operator_record_payment(
    'alte-muehle', v_session, 'tap_to_pay', 'pay-2', 0, array[v_second]::uuid[]);
  perform pg_temp.assert(
    (v_result ->> 'session_closed')::boolean,
    'Rechnung sollte geschlossen sein'
  );
  perform pg_temp.assert(
    (select status from public.table_sessions where id = v_session) = 'closed',
    'Tisch-Session sollte geschlossen sein'
  );

  -- Auf eine geschlossene Rechnung wird nichts mehr gebucht.
  perform pg_temp.expect_error(
    format($q$select public.operator_record_payment(
      'alte-muehle', %L, 'cash', 'pay-3', 0, null, 100)$q$, v_session),
    'payment_session_closed'
  );
end;
$$;

-- ============================================================================
-- 3. Storno gibt die Positionen wieder frei
-- ============================================================================

do $$
declare
  v_table_id uuid;
  v_session uuid;
  v_payment uuid;
  v_check jsonb;
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = '2';

  select p.id, p.table_session_id into v_payment, v_session
  from public.payments p
  where p.idempotency_key = 'pay-2';

  v_result := public.operator_refund_payment('alte-muehle', v_payment, 'Falsch kassiert');
  perform pg_temp.assert(
    (v_result ->> 'session_reopened')::boolean,
    'Rechnung sollte wieder offen sein'
  );
  perform pg_temp.assert(
    (select status from public.payments where id = v_payment) = 'refunded',
    'Zahlung sollte storniert sein'
  );
  perform pg_temp.assert(
    (select refund_reason from public.payments where id = v_payment) = 'Falsch kassiert',
    'Stornogrund fehlt'
  );

  -- Die Position ist wieder offen und erneut zahlbar.
  v_check := public.operator_table_check('alte-muehle', v_table_id);
  perform pg_temp.assert((v_check ->> 'open_cents')::int = 690, 'Betrag nach Storno falsch');

  v_result := public.operator_record_payment(
    'alte-muehle', v_session, 'card', 'pay-4', 0,
    array[((select ((i.value ->> 'order_item_id')::uuid)
            from jsonb_array_elements(v_check -> 'items') as i(value)
            where not (i.value ->> 'paid')::boolean limit 1))]::uuid[]);
  perform pg_temp.assert(
    (v_result ->> 'amount_cents')::int = 690,
    'Erneute Zahlung der freigegebenen Position fehlgeschlagen'
  );

  -- Zweiter Klick auf denselben Storno ist kein zweiter Vorgang.
  v_result := public.operator_refund_payment('alte-muehle', v_payment, 'nochmal');
  perform pg_temp.assert((v_result ->> 'replayed')::boolean, 'Storno-Replay erwartet');
  perform pg_temp.assert(
    (select count(*) from public.payments
      where id = v_payment and status = 'refunded') = 1,
    'Die Zahlung sollte genau einmal storniert sein'
  );
end;
$$;

-- ============================================================================
-- 4. Zahlungen sind nicht fuer anon lesbar
-- ============================================================================

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.payments) = 0,
    'anon darf keine Zahlungen lesen'
  );
  perform pg_temp.assert(
    (select count(*) from public.payment_items) = 0,
    'anon darf keine Zahlungspositionen lesen'
  );
  perform pg_temp.expect_error(
    $q$insert into public.payments (venue_id, amount_cents, method, idempotency_key)
       values ('11111111-1111-1111-1111-111111111111', 100, 'cash', 'geklaut')$q$,
    'row-level security'
  );
end;
$$;

reset role;

select 'KL-PAY-001: alle SQL-Pruefungen bestanden' as ergebnis;
