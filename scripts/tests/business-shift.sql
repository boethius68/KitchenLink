-- Funktionstest fuer KL-SHIFT-001 (Migration 20260731200000_business_shift.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird, was einen Kassenabschluss wertlos macht, wenn es falsch ist:
-- dass nie zwei Schichten gleichzeitig offen sind, dass der erwartete
-- Bargeldbestand nur Bargeld zaehlt (Karte liegt nicht in der Schublade),
-- dass Trinkgeld in bar mitzaehlt, dass eine stornierte Barzahlung den
-- Bestand wieder senkt, dass eine Abweichung dokumentiert statt weggerechnet
-- wird und dass eine geschlossene Schicht eingefroren bleibt.
--
-- Der Test legt seinen **eigenen** Tisch an, statt einen der Seed-Tische zu
-- belegen: alle Tests dieses Verzeichnisses laufen nacheinander auf derselben
-- Datenbank, und dieser hier laeuft als erster.

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
-- 0. Eigener Tisch fuer diesen Test
-- ============================================================================

do $$
declare
  v_table jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_table := public.operator_upsert_table('alte-muehle', 'Schicht-Test', 'Kasse', 900, true);
  perform pg_temp.assert(v_table ->> 'token' is not null, 'Tisch braucht einen QR-Token');

  -- Fester Token, damit die Gastbestellungen unten lesbar bleiben.
  -- (`qr_tokens` hat keine eigene ID; der Token selbst ist der Schluessel.)
  update public.qr_tokens
  set token = 'schicht-test-tisch'
  where table_id = (v_table ->> 'table_id')::uuid and active;
end;
$$;

-- ============================================================================
-- 1. Ohne offene Schicht
-- ============================================================================

-- Ein Bericht ohne offene Schicht ist ein gueltiger Zustand, kein Fehler --
-- die App zeigt dann den Knopf zum Oeffnen.
do $$
declare
  v_report jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_report := public.operator_shift_report('alte-muehle');
  perform pg_temp.assert((v_report ->> 'open')::boolean = false, 'Noch keine Schicht offen');
  perform pg_temp.assert(v_report ->> 'shift' is null, 'Keine Schicht im Bericht erwartet');
end;
$$;

-- Eine Entnahme braucht eine offene Kasse: sie waere sonst nirgends zugeordnet.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform pg_temp.expect_error(
    $q$select public.operator_record_cash_movement(
      'alte-muehle', 'payout', 500, 'ohne-schicht')$q$,
    'cash_no_open_shift'
  );
end;
$$;

-- Eine **Zahlung** dagegen wird nicht blockiert. Geld anzunehmen darf nie an
-- einem vergessenen Knopfdruck scheitern; die Zahlung bleibt nur ohne Schicht.
do $$
declare
  v_order_id uuid;
  v_table_id uuid;
  v_check jsonb;
  v_result jsonb;
  v_shift_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000d1', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'schicht-vorher-1',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in', '', 'schicht-test-tisch');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = 'Schicht-Test';

  v_check := public.operator_table_check('alte-muehle', v_table_id);
  v_result := public.operator_record_payment(
    'alte-muehle', (v_check ->> 'table_session_id')::uuid,
    'cash', 'zahlung-ohne-schicht', 0, null, 690
  );

  select shift_id into v_shift_id
  from public.payments where id = (v_result ->> 'payment_id')::uuid;
  perform pg_temp.assert(v_shift_id is null, 'Zahlung ohne Schicht bleibt ohne Schicht');
end;
$$;

-- ============================================================================
-- 2. Schicht oeffnen
-- ============================================================================

do $$
declare
  v_shift jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_shift := public.operator_open_shift('alte-muehle', 10000, 'schicht-1');

  perform pg_temp.assert(v_shift ->> 'shift_id' is not null, 'Schicht-ID erwartet');
  perform pg_temp.assert(
    (v_shift ->> 'opening_cash_cents')::int = 10000,
    'Anfangsbestand 100 EUR erwartet, war ' || (v_shift ->> 'opening_cash_cents')
  );
  perform pg_temp.assert((v_shift ->> 'replayed')::boolean = false, 'Neu erwartet');
end;
$$;

-- Wiederholung desselben Oeffnens legt keine zweite Schicht an.
do $$
declare
  v_shift jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_shift := public.operator_open_shift('alte-muehle', 10000, 'schicht-1');
  perform pg_temp.assert((v_shift ->> 'replayed')::boolean = true, 'Wiederholung erwartet');
  perform pg_temp.assert(
    (select count(*) from public.business_shifts s
     join public.venues v on v.id = s.venue_id
     where v.slug = 'alte-muehle') = 1,
    'Genau eine Schicht erwartet'
  );
end;
$$;

-- Die tragende Zusage: zwei offene Kassen kann niemand zaehlen.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform pg_temp.expect_error(
    $q$select public.operator_open_shift('alte-muehle', 5000, 'schicht-2')$q$,
    'shift_already_open'
  );
end;
$$;

-- Fremdes Personal oeffnet und liest nichts. Oeffnen und Abschliessen laufen
-- seit KL-ROLE-001 ueber die Rechtepruefung und melden deshalb
-- `permission_forbidden`; der Bericht prueft weiterhin nur die Mitgliedschaft.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000bb', false);
  perform pg_temp.expect_error(
    $q$select public.operator_open_shift('alte-muehle', 5000, 'fremd')$q$,
    'permission_forbidden'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_shift_report('alte-muehle')$q$,
    'shift_forbidden'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_close_shift('alte-muehle', 10000)$q$,
    'permission_forbidden'
  );
end;
$$;

-- ============================================================================
-- 3. Umsatz auf der Schicht
-- ============================================================================

-- Zwei Gaeste am selben Tisch, einer zahlt bar mit Trinkgeld, einer mit Karte.
do $$
declare
  v_order_id uuid;
  v_table_id uuid;
  v_check jsonb;
  v_session uuid;
  v_items jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000d2', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'schicht-gast-1',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in', '', 'schicht-test-tisch');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000d3', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'alte-muehle', 'schicht-gast-2',
    '[{"slug":"kuerbissuppe","quantity":1}]'::jsonb,
    'dine_in', '', 'schicht-test-tisch');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = 'Schicht-Test';

  v_check := public.operator_table_check('alte-muehle', v_table_id);
  v_session := (v_check ->> 'table_session_id')::uuid;
  v_items := v_check -> 'items';

  -- Bar: 6,90 EUR plus 1,10 EUR Trinkgeld -- beides landet in der Schublade.
  perform public.operator_record_payment(
    'alte-muehle', v_session, 'cash', 'schicht-bar-1', 110,
    array[(v_items -> 0 ->> 'order_item_id')::uuid]
  );

  -- Karte: 6,90 EUR plus 0,50 EUR Trinkgeld -- nichts davon liegt in der Kasse.
  perform public.operator_record_payment(
    'alte-muehle', v_session, 'card', 'schicht-karte-1', 50,
    array[(v_items -> 1 ->> 'order_item_id')::uuid]
  );
end;
$$;

do $$
declare
  v_report jsonb;
  v_totals jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_report := public.operator_shift_report('alte-muehle');
  v_totals := v_report -> 'totals';

  perform pg_temp.assert((v_report ->> 'open')::boolean = true, 'Schicht ist offen');
  perform pg_temp.assert(
    (v_totals ->> 'revenue_cents')::int = 1380,
    'Umsatz 13,80 EUR erwartet, war ' || (v_totals ->> 'revenue_cents')
  );
  perform pg_temp.assert(
    (v_totals ->> 'tip_cents')::int = 160,
    'Trinkgeld 1,60 EUR erwartet, war ' || (v_totals ->> 'tip_cents')
  );
  -- Der Kern: nur Bargeld liegt in der Schublade, und zwar mit Trinkgeld.
  perform pg_temp.assert(
    (v_totals ->> 'cash_payments_cents')::int = 800,
    'Bar 8,00 EUR erwartet (6,90 + 1,10), war ' || (v_totals ->> 'cash_payments_cents')
  );
  perform pg_temp.assert(
    (v_totals ->> 'expected_cash_cents')::int = 10800,
    'Erwartet 108,00 EUR (100 + 8), war ' || (v_totals ->> 'expected_cash_cents')
  );

  -- Aufschluesselung nach Zahlart -- das ist der Kern eines Z-Berichts.
  perform pg_temp.assert(
    (v_totals -> 'by_method' -> 'cash' ->> 'amount_cents')::int = 690,
    'Bar-Aufschluesselung erwartet'
  );
  perform pg_temp.assert(
    (v_totals -> 'by_method' -> 'card' ->> 'amount_cents')::int = 690,
    'Karten-Aufschluesselung erwartet'
  );

  -- Die Zahlung von vor Schichtbeginn zaehlt nicht mit, wird aber genannt.
  perform pg_temp.assert(
    (v_report ->> 'unassigned_cash_cents')::int = 0,
    'Zahlung vor Schichtbeginn zaehlt nicht in dieser Schicht'
  );
end;
$$;

-- ============================================================================
-- 4. Ausgaben und Entnahmen
-- ============================================================================

do $$
declare
  v_move jsonb;
  v_totals jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  -- Lieferant bar bezahlt.
  v_move := public.operator_record_cash_movement(
    'alte-muehle', 'expense', 1250, 'ausgabe-1', 'Gemuesekiste'
  );
  perform pg_temp.assert((v_move ->> 'replayed')::boolean = false, 'Neu erwartet');

  -- Wechselgeld nachgelegt.
  perform public.operator_record_cash_movement(
    'alte-muehle', 'deposit', 2000, 'einlage-1', 'Wechselgeld'
  );

  -- Entnahme in den Tresor.
  perform public.operator_record_cash_movement(
    'alte-muehle', 'payout', 500, 'entnahme-1', 'Tresor'
  );

  -- Wiederholung derselben Buchung bucht nicht doppelt.
  v_move := public.operator_record_cash_movement(
    'alte-muehle', 'payout', 500, 'entnahme-1', 'Tresor'
  );
  perform pg_temp.assert((v_move ->> 'replayed')::boolean = true, 'Wiederholung erwartet');

  v_totals := public.operator_shift_report('alte-muehle') -> 'totals';
  perform pg_temp.assert(
    (v_totals ->> 'expense_cents')::int = 1250, 'Ausgaben 12,50 EUR erwartet');
  perform pg_temp.assert(
    (v_totals ->> 'deposit_cents')::int = 2000, 'Einlage 20,00 EUR erwartet');
  perform pg_temp.assert(
    (v_totals ->> 'payout_cents')::int = 500, 'Entnahme 5,00 EUR erwartet');

  -- 100,00 + 8,00 bar + 20,00 Einlage - 12,50 Ausgabe - 5,00 Entnahme
  perform pg_temp.assert(
    (v_totals ->> 'expected_cash_cents')::int = 11050,
    'Erwartet 110,50 EUR, war ' || (v_totals ->> 'expected_cash_cents')
  );
end;
$$;

-- Unsinnige Buchungen erreichen die Kasse nicht.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform pg_temp.expect_error(
    $q$select public.operator_record_cash_movement('alte-muehle', 'spende', 100, 'k1')$q$,
    'cash_invalid_kind'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_record_cash_movement('alte-muehle', 'payout', 0, 'k2')$q$,
    'cash_invalid_amount'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_record_cash_movement('alte-muehle', 'payout', -100, 'k3')$q$,
    'cash_invalid_amount'
  );
end;
$$;

-- ============================================================================
-- 5. Storno senkt den Bargeldbestand wieder
-- ============================================================================

do $$
declare
  v_payment_id uuid;
  v_totals jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select p.id into v_payment_id
  from public.payments p
  where p.idempotency_key = 'schicht-bar-1';

  perform public.operator_refund_payment('alte-muehle', v_payment_id, 'Falsch kassiert');

  v_totals := public.operator_shift_report('alte-muehle') -> 'totals';

  -- Das Geld hat die Schublade wieder verlassen: 110,50 - 8,00 = 102,50.
  perform pg_temp.assert(
    (v_totals ->> 'expected_cash_cents')::int = 10250,
    'Nach Storno 102,50 EUR erwartet, war ' || (v_totals ->> 'expected_cash_cents')
  );
  perform pg_temp.assert(
    (v_totals ->> 'refunded_cents')::int = 690,
    'Storno 6,90 EUR erwartet, war ' || (v_totals ->> 'refunded_cents')
  );
  perform pg_temp.assert(
    (v_totals ->> 'refund_count')::int = 1, 'Ein Storno erwartet');
  perform pg_temp.assert(
    (v_totals ->> 'revenue_cents')::int = 690,
    'Umsatz nach Storno 6,90 EUR erwartet, war ' || (v_totals ->> 'revenue_cents')
  );
end;
$$;

-- ============================================================================
-- 6. Abschluss mit dokumentierter Abweichung
-- ============================================================================

do $$
declare
  v_close jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  -- Gezaehlt werden 102,00 EUR -- 50 Cent fehlen.
  v_close := public.operator_close_shift(
    'alte-muehle', 10200, null, 'Fehlbetrag beim Zaehlen bemerkt'
  );

  perform pg_temp.assert(
    (v_close ->> 'expected_cash_cents')::int = 10250,
    'Erwartet 102,50 EUR, war ' || (v_close ->> 'expected_cash_cents')
  );
  perform pg_temp.assert(
    (v_close ->> 'counted_cash_cents')::int = 10200, 'Gezaehlt 102,00 EUR');
  -- Negativ heisst Fehlbetrag. Er wird festgehalten, nicht weggerechnet.
  perform pg_temp.assert(
    (v_close ->> 'variance_cents')::int = -50,
    'Abweichung -50 Cent erwartet, war ' || (v_close ->> 'variance_cents')
  );
  perform pg_temp.assert(
    (v_close ->> 'z_number')::int = 1,
    'Erste Z-Nummer erwartet, war ' || (v_close ->> 'z_number')
  );
end;
$$;

-- Zweimal abschliessen geht nicht.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform pg_temp.expect_error(
    $q$select public.operator_close_shift('alte-muehle', 10200)$q$,
    'shift_none_open'
  );
end;
$$;

-- Ohne Zaehlung kein Abschluss.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform public.operator_open_shift('alte-muehle', 0, 'schicht-3');
  perform pg_temp.expect_error(
    $q$select public.operator_close_shift('alte-muehle', null)$q$,
    'shift_invalid_count'
  );
end;
$$;

-- ============================================================================
-- 7. Eine geschlossene Schicht bleibt eingefroren
-- ============================================================================

-- Der Bericht einer abgeschlossenen Schicht darf sich nicht mehr aendern, auch
-- wenn danach noch etwas passiert -- sonst waere der Z-Bericht wertlos.
do $$
declare
  v_first_id uuid;
  v_report jsonb;
  v_payment_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select s.id into v_first_id
  from public.business_shifts s
  join public.venues v on v.id = s.venue_id
  where v.slug = 'alte-muehle' and s.z_number = 1;

  -- Nachtraeglich die Kartenzahlung der geschlossenen Schicht stornieren.
  select p.id into v_payment_id
  from public.payments p where p.idempotency_key = 'schicht-karte-1';
  perform public.operator_refund_payment('alte-muehle', v_payment_id, 'Nachtraeglich');

  v_report := public.operator_shift_report('alte-muehle', v_first_id);

  perform pg_temp.assert((v_report ->> 'open')::boolean = false, 'Erste Schicht ist zu');
  perform pg_temp.assert(
    (v_report -> 'shift' ->> 'expected_cash_cents')::int = 10250,
    'Eingefrorener Erwartungswert 102,50 EUR, war '
      || (v_report -> 'shift' ->> 'expected_cash_cents')
  );
  perform pg_temp.assert(
    (v_report -> 'shift' ->> 'variance_cents')::int = -50, 'Eingefrorene Abweichung');
  perform pg_temp.assert(
    (v_report -> 'shift' ->> 'z_number')::int = 1, 'Eingefrorene Z-Nummer');
end;
$$;

-- Die Z-Nummern laufen lueckenlos weiter.
do $$
declare
  v_close jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_close := public.operator_close_shift('alte-muehle', 0);
  perform pg_temp.assert(
    (v_close ->> 'z_number')::int = 2,
    'Zweite Z-Nummer erwartet, war ' || (v_close ->> 'z_number')
  );
end;
$$;

-- Der Rueckblick zeigt beide Abschluesse, neueste zuerst.
do $$
declare
  v_rows jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  v_rows := public.operator_recent_shifts('alte-muehle', 10);
  perform pg_temp.assert(
    jsonb_array_length(v_rows) = 2,
    'Zwei Schichten erwartet, waren ' || jsonb_array_length(v_rows)
  );
  perform pg_temp.assert(
    (v_rows -> 0 ->> 'z_number')::int = 2, 'Neueste zuerst erwartet');
end;
$$;

-- ============================================================================
-- 8. RLS: die Schicht gehoert der Venue
-- ============================================================================

-- `set role` ist noetig, weil der Eigentuemer der Tabellen RLS umgeht: als
-- `postgres` wuerde dieser Abschnitt gruen sein, ohne irgendetwas zu belegen.

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000bb', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.business_shifts) = 0,
    'Fremdes Personal sieht keine Schicht'
  );
  perform pg_temp.assert(
    (select count(*) from public.cash_movements) = 0,
    'Fremdes Personal sieht keine Bewegung'
  );
end;
$$;

reset role;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.business_shifts) = 2,
    'Eigenes Personal sieht beide Schichten'
  );
  perform pg_temp.assert(
    (select count(*) from public.cash_movements) = 3,
    'Eigenes Personal sieht die drei Bewegungen'
  );
end;
$$;

reset role;

-- Ein Gast hat mit der Kasse nichts zu tun.
set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.business_shifts) = 0,
    'anon darf keine Schicht lesen'
  );
  perform pg_temp.assert(
    (select count(*) from public.cash_movements) = 0,
    'anon darf keine Bewegung lesen'
  );
end;
$$;

reset role;

-- ============================================================================
-- 9. Aufraeumen
-- ============================================================================

-- Alle Tests dieses Verzeichnisses laufen nacheinander auf **derselben**
-- Datenbank. `table-context` prueft, dass die Venue genau sechs aktive Tische
-- hat -- der Testtisch von oben waere der siebte. Er wird stillgelegt statt
-- geloescht, damit die Bestellungen und Zahlungen dieses Tests ihre Zuordnung
-- behalten und der Bericht oben weiter belegbar bleibt.
do $$
declare
  v_table_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);

  select t.id into v_table_id
  from public.tables t join public.venues v on v.id = t.venue_id
  where v.slug = 'alte-muehle' and t.label = 'Schicht-Test';

  -- Der Token haengt am Tisch, wird aber nicht mit ihm stillgelegt: er zaehlt
  -- sonst weiter als aktiver Tisch-Token.
  update public.qr_tokens set active = false where table_id = v_table_id;
  update public.tables set active = false where id = v_table_id;
end;
$$;

select 'KL-SHIFT-001: alle SQL-Pruefungen bestanden' as ergebnis;
