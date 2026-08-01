-- Funktionstest fuer KL-PLAN-001 (Migration 20260801140000_shift_schedule.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird, was einen Dienstplan wertlos macht: dass niemand zweimal
-- gleichzeitig verplant ist, dass ein **Entwurf** fuer den Betroffenen
-- unsichtbar bleibt (sonst haelt sich jemand fuer eingeteilt, waehrend die
-- Planung noch umstellt), dass nur der Eingeteilte antwortet und nur einmal,
-- und dass eine abgelehnte Schicht den Zeitraum wieder freigibt.
--
-- Eigener UUID-Block `…9801` ff. — siehe den Kopf von
-- `scripts/verify-supabase-migrations.sh`.
--
-- Der Test legt eine eigene Venue an und raeumt sie am Ende weg; alle Tests
-- dieses Verzeichnisses laufen nacheinander auf **derselben** Datenbank.

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
  ('00000000-0000-0000-0000-000000009801', 'chefin@plan.test'),
  ('00000000-0000-0000-0000-000000009802', 'kellner@plan.test'),
  ('00000000-0000-0000-0000-000000009803', 'koechin@plan.test'),
  ('00000000-0000-0000-0000-000000009809', 'fremde@plan.test')
on conflict (id) do nothing;

-- ============================================================================
-- 0. Ausgangslage
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform public.operator_create_venue('Planprobe', 'planprobe');
  perform public.operator_add_staff('planprobe', 'kellner@plan.test', 'service');
  perform public.operator_add_staff('planprobe', 'koechin@plan.test', 'kitchen');
end;
$$;

-- Das neue Recht liegt bei den drei Fuehrungsrollen, nicht beim Service.
do $$
declare
  v_mine jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  v_mine := public.operator_my_permissions('planprobe');
  perform pg_temp.assert(
    v_mine -> 'permissions' ? 'schedule.manage', 'Inhaberin darf planen');

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
  v_mine := public.operator_my_permissions('planprobe');
  perform pg_temp.assert(
    not (v_mine -> 'permissions' ? 'schedule.manage'), 'Service plant nicht');
end;
$$;

-- ============================================================================
-- 1. Planen — und die tragende Zusage
-- ============================================================================

do $$
declare
  v_shift jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);

  v_shift := public.operator_plan_shift(
    'planprobe', '00000000-0000-0000-0000-000000009802',
    date_trunc('day', now()) + interval '1 day 17 hours',
    date_trunc('day', now()) + interval '1 day 23 hours',
    'Gastraum', null, 'Abenddienst'
  );
  perform pg_temp.assert(v_shift ->> 'shift_id' is not null, 'Schicht erwartet');
end;
$$;

-- Ueberlappung derselben Person: abgewiesen.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_plan_shift(
        'planprobe', '00000000-0000-0000-0000-000000009802', %L, %L)$q$,
      date_trunc('day', now()) + interval '1 day 22 hours',
      date_trunc('day', now()) + interval '2 days 2 hours'
    ),
    'plan_overlaps'
  );
end;
$$;

-- Eine **anschliessende** Schicht ist keine Ueberlappung: 23:00 bis 02:00
-- beruehrt 17:00 bis 23:00 nur am Rand.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform public.operator_plan_shift(
    'planprobe', '00000000-0000-0000-0000-000000009802',
    date_trunc('day', now()) + interval '1 day 23 hours',
    date_trunc('day', now()) + interval '2 days 2 hours'
  );
end;
$$;

-- Eine **andere** Person darf zur selben Zeit arbeiten.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform public.operator_plan_shift(
    'planprobe', '00000000-0000-0000-0000-000000009803',
    date_trunc('day', now()) + interval '1 day 17 hours',
    date_trunc('day', now()) + interval '1 day 23 hours',
    null, 'kitchen'
  );
end;
$$;

-- Unsinnige Eingaben erreichen den Plan nicht.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_plan_shift('planprobe', %L, %L, %L)$q$,
      '00000000-0000-0000-0000-000000009802',
      now() + interval '3 days', now() + interval '3 days'
    ),
    'plan_invalid_range'
  );
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_plan_shift('planprobe', %L, %L, %L, null, 'pass')$q$,
      '00000000-0000-0000-0000-000000009802',
      now() + interval '3 days', now() + interval '3 days 4 hours'
    ),
    'plan_invalid_station'
  );
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_plan_shift('planprobe', %L, %L, %L)$q$,
      '00000000-0000-0000-0000-000000009809',
      now() + interval '3 days', now() + interval '3 days 4 hours'
    ),
    'plan_unknown_staff'
  );
end;
$$;

-- ============================================================================
-- 2. Ein Entwurf ist noch niemandes Zusage
-- ============================================================================

do $$
declare
  v_mine jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
  v_mine := public.operator_my_shifts('planprobe');
  perform pg_temp.assert(
    jsonb_array_length(v_mine) = 0,
    'Entwuerfe sind unsichtbar, waren ' || jsonb_array_length(v_mine)
  );
end;
$$;

-- Auch nicht ueber die Tabelle selbst.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.planned_shifts) = 0,
    'RLS haelt Entwuerfe vom Eingeteilten fern'
  );
end;
$$;

reset role;

-- Ohne `schedule.manage` gibt es weder Plan noch Planung.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_venue_schedule('planprobe', %L, %L)$q$,
      now(), now() + interval '7 days'
    ),
    'permission_denied'
  );
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_plan_shift('planprobe', %L, %L, %L)$q$,
      '00000000-0000-0000-0000-000000009802',
      now() + interval '5 days', now() + interval '5 days 4 hours'
    ),
    'permission_denied'
  );
end;
$$;

-- ============================================================================
-- 3. Veroeffentlichen
-- ============================================================================

do $$
declare
  v_result jsonb;
  v_plan jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);

  v_plan := public.operator_venue_schedule(
    'planprobe', now(), now() + interval '7 days');
  perform pg_temp.assert(
    jsonb_array_length(v_plan) = 3,
    'Drei geplante Schichten erwartet, waren ' || jsonb_array_length(v_plan)
  );

  v_result := public.operator_publish_schedule(
    'planprobe', now(), now() + interval '7 days');
  perform pg_temp.assert(
    (v_result ->> 'published')::int = 3,
    'Drei veroeffentlicht erwartet, waren ' || (v_result ->> 'published')
  );

  -- Zweimal veroeffentlichen aendert nichts mehr.
  v_result := public.operator_publish_schedule(
    'planprobe', now(), now() + interval '7 days');
  perform pg_temp.assert(
    (v_result ->> 'published')::int = 0, 'Nichts mehr zu veroeffentlichen');
end;
$$;

do $$
declare
  v_mine jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
  v_mine := public.operator_my_shifts('planprobe');
  perform pg_temp.assert(
    jsonb_array_length(v_mine) = 2,
    'Zwei eigene Schichten erwartet, waren ' || jsonb_array_length(v_mine)
  );
  perform pg_temp.assert(
    (v_mine -> 0 ->> 'area') = 'Gastraum', 'Bereich erwartet');
end;
$$;

-- ============================================================================
-- 4. Annehmen und ablehnen
-- ============================================================================

do $$
declare
  v_shift_id uuid;
begin
  select s.id into v_shift_id
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'planprobe'
    and s.user_id = '00000000-0000-0000-0000-000000009802'
    and s.note = 'Abenddienst';

  -- Fremde beantworten fremde Schichten nicht.
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009803', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_respond_to_shift('planprobe', %L, true)$q$, v_shift_id),
    'plan_not_yours'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
  perform public.operator_respond_to_shift('planprobe', v_shift_id, true);

  -- Zweimal antworten geht nicht.
  perform pg_temp.expect_error(
    format($q$select public.operator_respond_to_shift('planprobe', %L, false)$q$, v_shift_id),
    'plan_not_published'
  );
end;
$$;

-- Ablehnen gibt den Zeitraum wieder frei — vorher war er blockiert.
do $$
declare
  v_shift_id uuid;
begin
  select s.id into v_shift_id
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'planprobe'
    and s.user_id = '00000000-0000-0000-0000-000000009803';

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009803', false);
  perform public.operator_respond_to_shift(
    'planprobe', v_shift_id, false, 'Arzttermin');
end;
$$;

do $$
declare
  v_shift public.planned_shifts%rowtype;
begin
  select s.* into v_shift
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'planprobe' and s.status = 'declined';

  perform pg_temp.assert(v_shift.decline_reason = 'Arzttermin', 'Grund erwartet');
  perform pg_temp.assert(v_shift.declined_at is not null, 'Zeitpunkt erwartet');

  -- Genau derselbe Zeitraum laesst sich jetzt neu besetzen.
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform public.operator_plan_shift(
    'planprobe', '00000000-0000-0000-0000-000000009803',
    v_shift.starts_at, v_shift.ends_at, null, 'kitchen', 'Ersatz'
  );
end;
$$;

-- ============================================================================
-- 5. Eine angenommene Schicht zu verschieben, hebt die Zusage auf
-- ============================================================================

-- Sonst stuende in der App „angenommen" an einer Zeit, die der Betroffene nie
-- gesehen hat.
do $$
declare
  v_shift public.planned_shifts%rowtype;
begin
  select s.* into v_shift
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'planprobe' and s.status = 'accepted';
  perform pg_temp.assert(v_shift.id is not null, 'Eine angenommene Schicht erwartet');

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform public.operator_plan_shift(
    'planprobe', v_shift.user_id,
    v_shift.starts_at + interval '1 hour', v_shift.ends_at,
    v_shift.area, v_shift.station, v_shift.note, v_shift.id
  );
end;
$$;

do $$
declare
  v_shift public.planned_shifts%rowtype;
begin
  select s.* into v_shift
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'planprobe' and s.note = 'Abenddienst';

  perform pg_temp.assert(
    v_shift.status = 'published',
    'Verschieben faellt auf veroeffentlicht zurueck, war ' || v_shift.status
  );
  perform pg_temp.assert(v_shift.accepted_at is null, 'Die alte Zusage ist weg');
end;
$$;

-- ============================================================================
-- 6. RLS
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
end;
$$;

set role authenticated;

do $$
begin
  -- Der Kellner sieht seine veroeffentlichten Schichten, nicht die der Kueche.
  perform pg_temp.assert(
    (select count(*) from public.planned_shifts
     where user_id <> '00000000-0000-0000-0000-000000009802') = 0,
    'Fremde Schichten bleiben unsichtbar'
  );
  perform pg_temp.assert(
    (select count(*) from public.planned_shifts) = 2,
    'Die eigenen veroeffentlichten Schichten sind sichtbar'
  );
end;
$$;

reset role;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.planned_shifts) = 4,
    'Mit schedule.manage ist der ganze Plan sichtbar'
  );
end;
$$;

reset role;

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.planned_shifts) = 0, 'anon sieht keinen Plan');
end;
$$;

reset role;

-- ============================================================================
-- 7. Loeschen und aufraeumen
-- ============================================================================

do $$
declare
  v_shift_id uuid;
begin
  select s.id into v_shift_id
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'planprobe' and s.note = 'Ersatz';

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009802', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_delete_planned_shift('planprobe', %L)$q$, v_shift_id),
    'permission_denied'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009801', false);
  perform public.operator_delete_planned_shift('planprobe', v_shift_id);
  perform pg_temp.expect_error(
    format($q$select public.operator_delete_planned_shift('planprobe', %L)$q$, v_shift_id),
    'plan_unknown_shift'
  );
end;
$$;

do $$
begin
  delete from public.venues where slug = 'planprobe';
end;
$$;

select 'KL-PLAN-001: alle SQL-Pruefungen bestanden' as ergebnis;
