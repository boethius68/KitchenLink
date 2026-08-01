-- Funktionstest fuer KL-LEAVE-001 (Migration 20260801160000_staff_leave.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Der Kern ist die **Asymmetrie** aus dem Kopf der Migration: in eine
-- genehmigte Abwesenheit hinein wird nicht geplant, aber eine Abwesenheit auf
-- bereits geplante Schichten wird trotzdem genehmigt und meldet sie nur.
-- Beides zusammen prueft dieser Test, weil beides einzeln plausibel klingt und
-- erst zusammen den Betrieb abbildet.
--
-- Eigener UUID-Block `…9701` ff. — siehe den Kopf von
-- `scripts/verify-supabase-migrations.sh`.

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

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000009701', 'chefin@urlaub.test'),
  ('00000000-0000-0000-0000-000000009702', 'kellner@urlaub.test'),
  ('00000000-0000-0000-0000-000000009703', 'koechin@urlaub.test')
on conflict (id) do nothing;

-- ============================================================================
-- 0. Ausgangslage
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  perform public.operator_create_venue('Urlaubsprobe', 'urlaubsprobe');
  perform public.operator_add_staff('urlaubsprobe', 'kellner@urlaub.test', 'service');
  perform public.operator_add_staff('urlaubsprobe', 'koechin@urlaub.test', 'kitchen');
end;
$$;

-- ============================================================================
-- 1. Beantragen braucht kein Recht
-- ============================================================================

-- Der Kellner traegt keines der sechs Rechte und muss trotzdem Urlaub
-- beantragen koennen — es ist seine eigene Abwesenheit.
do $$
declare
  v_leave jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  v_leave := public.operator_request_leave(
    'urlaubsprobe',
    date_trunc('day', now()) + interval '10 days',
    date_trunc('day', now()) + interval '15 days',
    'vacation', 'Familienbesuch'
  );
  perform pg_temp.assert(v_leave ->> 'leave_id' is not null, 'Antrag erwartet');
  perform pg_temp.assert(v_leave ->> 'status' = 'requested', 'Zustand beantragt');
end;
$$;

-- Unsinnige Antraege erreichen die Tabelle nicht.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_request_leave('urlaubsprobe', %L, %L, 'vacation')$q$,
      now() + interval '3 days', now() + interval '3 days'
    ),
    'leave_invalid_range'
  );
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_request_leave('urlaubsprobe', %L, %L, 'sabbatical')$q$,
      now() + interval '3 days', now() + interval '5 days'
    ),
    'leave_invalid_kind'
  );
end;
$$;

-- ============================================================================
-- 2. Ein Antrag blockiert die Planung noch nicht
-- ============================================================================

-- Erst die Genehmigung macht daraus eine Tatsache. Solange nur beantragt ist,
-- plant die Planung weiter — sie hat ja noch nicht entschieden.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  perform public.operator_plan_shift(
    'urlaubsprobe', '00000000-0000-0000-0000-000000009702',
    date_trunc('day', now()) + interval '11 days 17 hours',
    date_trunc('day', now()) + interval '11 days 23 hours',
    'Gastraum'
  );
end;
$$;

-- ============================================================================
-- 3. Entscheiden braucht `schedule.manage`
-- ============================================================================

do $$
declare
  v_leave_id uuid;
begin
  select l.id into v_leave_id
  from public.staff_leaves l join public.venues v on v.id = l.venue_id
  where v.slug = 'urlaubsprobe' and l.status = 'requested';

  -- Der Antragsteller genehmigt sich nicht selbst.
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_review_leave('urlaubsprobe', %L, true)$q$, v_leave_id),
    'permission_denied'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_venue_leaves('urlaubsprobe')$q$,
    'permission_denied'
  );
end;
$$;

-- ============================================================================
-- 4. Die Asymmetrie, erste Haelfte: genehmigen trotz Kollision
-- ============================================================================

-- Eine Krankmeldung kommt nach dem Dienstplan. Wer krank ist, ist krank — die
-- Genehmigung darf daran nicht scheitern, sie meldet die Schicht nur.
do $$
declare
  v_leave_id uuid;
  v_result jsonb;
begin
  select l.id into v_leave_id
  from public.staff_leaves l join public.venues v on v.id = l.venue_id
  where v.slug = 'urlaubsprobe' and l.status = 'requested';

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  v_result := public.operator_review_leave(
    'urlaubsprobe', v_leave_id, true, 'Genehmigt, Schicht wird neu besetzt');

  perform pg_temp.assert(v_result ->> 'status' = 'approved', 'Genehmigt erwartet');
  perform pg_temp.assert(
    jsonb_array_length(v_result -> 'conflicting_shifts') = 1,
    'Eine kollidierende Schicht erwartet, waren '
      || jsonb_array_length(v_result -> 'conflicting_shifts')
  );

  -- Die Schicht wird **nicht** automatisch entfernt: das entscheidet die
  -- Planung, nicht eine Migration.
  perform pg_temp.assert(
    (select count(*) from public.planned_shifts s join public.venues v on v.id = s.venue_id
     where v.slug = 'urlaubsprobe') = 1,
    'Die geplante Schicht steht noch'
  );
end;
$$;

-- Zweimal entscheiden geht nicht.
do $$
declare
  v_leave_id uuid;
begin
  select l.id into v_leave_id
  from public.staff_leaves l join public.venues v on v.id = l.venue_id
  where v.slug = 'urlaubsprobe' and l.status = 'approved';

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_review_leave('urlaubsprobe', %L, false)$q$, v_leave_id),
    'leave_already_decided'
  );
end;
$$;

-- ============================================================================
-- 5. Die Asymmetrie, zweite Haelfte: nicht in eine Abwesenheit planen
-- ============================================================================

-- Das ist die Luecke, die KL-PLAN-001 gelassen hatte.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_plan_shift('urlaubsprobe', %L, %L, %L)$q$,
      '00000000-0000-0000-0000-000000009702',
      date_trunc('day', now()) + interval '13 days 17 hours',
      date_trunc('day', now()) + interval '13 days 23 hours'
    ),
    'plan_on_leave'
  );

  -- Direkt daneben geht es weiterhin.
  perform public.operator_plan_shift(
    'urlaubsprobe', '00000000-0000-0000-0000-000000009702',
    date_trunc('day', now()) + interval '16 days 17 hours',
    date_trunc('day', now()) + interval '16 days 23 hours'
  );

  -- Und eine **andere** Person ist von fremdem Urlaub nicht betroffen.
  perform public.operator_plan_shift(
    'urlaubsprobe', '00000000-0000-0000-0000-000000009703',
    date_trunc('day', now()) + interval '13 days 17 hours',
    date_trunc('day', now()) + interval '13 days 23 hours'
  );
end;
$$;

-- ============================================================================
-- 6. Zwei genehmigte Abwesenheiten ueberschneiden sich nicht
-- ============================================================================

-- Antraege duerfen sich ueberlappen — sonst koennte niemand einen Zeitraum
-- umplanen. Erst die zweite **Genehmigung** wird abgewiesen.
do $$
declare
  v_leave_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_request_leave('urlaubsprobe', %L, %L, 'sick')$q$,
      date_trunc('day', now()) + interval '12 days',
      date_trunc('day', now()) + interval '13 days'
    ),
    'leave_already_approved'
  );

  -- Ein Antrag daneben ist moeglich …
  select (public.operator_request_leave(
    'urlaubsprobe',
    date_trunc('day', now()) + interval '20 days',
    date_trunc('day', now()) + interval '25 days',
    'unpaid'
  ) ->> 'leave_id')::uuid into v_leave_id;

  -- … und laesst sich zurueckziehen.
  perform public.operator_cancel_leave('urlaubsprobe', v_leave_id);
end;
$$;

do $$
declare
  v_leave public.staff_leaves%rowtype;
begin
  select l.* into v_leave
  from public.staff_leaves l join public.venues v on v.id = l.venue_id
  where v.slug = 'urlaubsprobe' and l.status = 'cancelled';

  perform pg_temp.assert(v_leave.id is not null, 'Zurueckgezogener Antrag erwartet');
  perform pg_temp.assert(v_leave.reviewed_by is null, 'Ein Rueckzug ist keine Entscheidung');

  -- Ein zurueckgezogener Antrag laesst sich nicht erneut zurueckziehen.
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_cancel_leave('urlaubsprobe', %L)$q$, v_leave.id),
    'leave_already_decided'
  );
end;
$$;

-- Fremde Antraege zieht niemand zurueck.
do $$
declare
  v_leave_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009703', false);
  select (public.operator_request_leave(
    'urlaubsprobe',
    date_trunc('day', now()) + interval '40 days',
    date_trunc('day', now()) + interval '42 days',
    'training'
  ) ->> 'leave_id')::uuid into v_leave_id;

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_cancel_leave('urlaubsprobe', %L)$q$, v_leave_id),
    'leave_not_yours'
  );
end;
$$;

-- ============================================================================
-- 7. Ablehnen
-- ============================================================================

do $$
declare
  v_leave_id uuid;
  v_result jsonb;
begin
  select l.id into v_leave_id
  from public.staff_leaves l join public.venues v on v.id = l.venue_id
  where v.slug = 'urlaubsprobe' and l.status = 'requested'
    and l.user_id = '00000000-0000-0000-0000-000000009703';

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  v_result := public.operator_review_leave(
    'urlaubsprobe', v_leave_id, false, 'Schulung faellt in die Hochsaison');

  perform pg_temp.assert(v_result ->> 'status' = 'rejected', 'Abgelehnt erwartet');
  perform pg_temp.assert(
    jsonb_array_length(v_result -> 'conflicting_shifts') = 0,
    'Eine Ablehnung meldet keine Kollisionen'
  );

  -- Eine abgelehnte Abwesenheit blockiert die Planung nicht.
  perform public.operator_plan_shift(
    'urlaubsprobe', '00000000-0000-0000-0000-000000009703',
    date_trunc('day', now()) + interval '41 days 17 hours',
    date_trunc('day', now()) + interval '41 days 23 hours'
  );
end;
$$;

-- ============================================================================
-- 8. Lesen
-- ============================================================================

do $$
declare
  v_mine jsonb;
  v_venue jsonb;
  v_open jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
  v_mine := public.operator_my_leaves('urlaubsprobe');
  perform pg_temp.assert(
    jsonb_array_length(v_mine) = 2,
    'Zwei eigene Vorgaenge erwartet, waren ' || jsonb_array_length(v_mine)
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
  v_venue := public.operator_venue_leaves('urlaubsprobe');
  perform pg_temp.assert(
    jsonb_array_length(v_venue) = 3,
    'Drei Vorgaenge im Lokal erwartet, waren ' || jsonb_array_length(v_venue)
  );

  -- Die genehmigte Abwesenheit nennt ihre kollidierende Schicht.
  perform pg_temp.assert(
    (select (t ->> 'conflicting_shifts')::int
     from jsonb_array_elements(v_venue) t
     where t ->> 'status' = 'approved') = 1,
    'Die Genehmigung nennt die kollidierende Schicht'
  );

  v_open := public.operator_venue_leaves('urlaubsprobe', true);
  perform pg_temp.assert(
    jsonb_array_length(v_open) = 0,
    'Kein offener Antrag mehr erwartet, waren ' || jsonb_array_length(v_open)
  );
end;
$$;

-- ============================================================================
-- 9. RLS
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009702', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.staff_leaves
     where user_id <> '00000000-0000-0000-0000-000000009702') = 0,
    'Fremde Abwesenheiten bleiben unsichtbar'
  );
  -- Der **eigene** Antrag ist sichtbar, anders als ein Dienstplan-Entwurf:
  -- es ist der eigene.
  perform pg_temp.assert(
    (select count(*) from public.staff_leaves) = 2,
    'Die eigenen Vorgaenge sind sichtbar'
  );
end;
$$;

reset role;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009701', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.staff_leaves) = 3,
    'Mit schedule.manage sind alle sichtbar'
  );
end;
$$;

reset role;

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.staff_leaves) = 0, 'anon sieht keine Abwesenheiten');
end;
$$;

reset role;

-- ============================================================================
-- 10. Aufraeumen
-- ============================================================================

do $$
begin
  delete from public.venues where slug = 'urlaubsprobe';
end;
$$;

select 'KL-LEAVE-001: alle SQL-Pruefungen bestanden' as ergebnis;
