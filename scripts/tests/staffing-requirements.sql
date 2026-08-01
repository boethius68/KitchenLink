-- Funktionstest fuer KL-STAFFING-001
-- (Migration 20260801180000_staffing_requirements.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird die Rechnung, die den Ausschlag gibt: **wie viele fehlen**.
-- Sie ist falsch, wenn sie abgelehnte Schichten mitzaehlt, die Station
-- ignoriert, oder wenn das Zeitfenster ueber die Sommerzeitgrenze verrutscht —
-- letzteres faellt im Betrieb genau zweimal im Jahr auf und ist dann teuer.
--
-- Eigener UUID-Block `…9601` ff. — siehe den Kopf von
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

-- Liest einen Abdeckungswert fuer einen Tag heraus.
create or replace function pg_temp.coverage(
  p_day date, p_station text default null
)
returns jsonb
language sql
as $$
  select t
  from jsonb_array_elements(
    public.operator_staffing_coverage('bedarfsprobe', p_day, p_day)
  ) t
  where (t ->> 'day')::date = p_day
    and (p_station is null and t ->> 'station' is null
         or t ->> 'station' = p_station)
  limit 1;
$$;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000009601', 'chefin@bedarf.test'),
  ('00000000-0000-0000-0000-000000009602', 'kellner@bedarf.test'),
  ('00000000-0000-0000-0000-000000009603', 'koechin@bedarf.test')
on conflict (id) do nothing;

-- ============================================================================
-- 0. Ausgangslage: eine Venue in Europe/Berlin
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  perform public.operator_create_venue('Bedarfsprobe', 'bedarfsprobe', 'Europe/Berlin');
  perform public.operator_add_staff('bedarfsprobe', 'kellner@bedarf.test', 'service');
  perform public.operator_add_staff('bedarfsprobe', 'koechin@bedarf.test', 'kitchen');
end;
$$;

-- ============================================================================
-- 1. Bedarf anlegen
-- ============================================================================

do $$
declare
  v_req jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);

  -- Freitagabend: drei Personen, egal wo.
  v_req := public.operator_upsert_staffing_requirement(
    'bedarfsprobe', 5, '17:00', '23:00', 3);
  perform pg_temp.assert(v_req ->> 'requirement_id' is not null, 'Bedarf erwartet');

  -- Freitagabend zusaetzlich: zwei in der Kueche.
  perform public.operator_upsert_staffing_requirement(
    'bedarfsprobe', 5, '17:00', '23:00', 2, 'kitchen');
end;
$$;

-- Unsinnige Angaben erreichen die Tabelle nicht.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_staffing_requirement(
      'bedarfsprobe', 8, '17:00', '23:00', 3)$q$,
    'staffing_invalid_weekday'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_staffing_requirement(
      'bedarfsprobe', 5, '23:00', '17:00', 3)$q$,
    'staffing_invalid_window'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_staffing_requirement(
      'bedarfsprobe', 5, '17:00', '23:00', 0)$q$,
    'staffing_invalid_headcount'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_staffing_requirement(
      'bedarfsprobe', 5, '17:00', '23:00', 3, 'pass')$q$,
    'staffing_invalid_station'
  );
end;
$$;

-- Ohne `schedule.manage` wird nichts gepflegt — gelesen aber schon.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009602', false);
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_staffing_requirement(
      'bedarfsprobe', 1, '10:00', '14:00', 1)$q$,
    'permission_denied'
  );
  -- Den Bedarf zu sehen erklaert, warum eine Woche eng ist.
  perform pg_temp.assert(
    jsonb_array_length(public.operator_staffing_requirements('bedarfsprobe')) = 2,
    'Personal darf den Bedarf lesen'
  );
end;
$$;

-- ============================================================================
-- 2. Ohne Plan fehlt alles
-- ============================================================================

do $$
declare
  v_friday date;
  v_row jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);

  -- Der naechste Freitag.
  select (date_trunc('week', now() at time zone 'Europe/Berlin')::date + 4)
    into v_friday;
  if v_friday < (now() at time zone 'Europe/Berlin')::date then
    v_friday := v_friday + 7;
  end if;

  v_row := pg_temp.coverage(v_friday);
  perform pg_temp.assert(v_row is not null, 'Ein Bedarf am Freitag erwartet');
  perform pg_temp.assert(
    (v_row ->> 'planned_headcount')::int = 0, 'Noch niemand eingeteilt');
  perform pg_temp.assert(
    (v_row ->> 'missing')::int = 3,
    'Drei fehlen, waren ' || (v_row ->> 'missing')
  );

  -- An einem Montag gibt es kein Muster — also auch keine Zeile.
  perform pg_temp.assert(
    jsonb_array_length(public.operator_staffing_coverage(
      'bedarfsprobe', v_friday + 3, v_friday + 3)) = 0,
    'Ohne Muster keine Zeile'
  );
end;
$$;

-- ============================================================================
-- 3. Die Rechnung
-- ============================================================================

do $$
declare
  v_friday date;
  v_row jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  select (date_trunc('week', now() at time zone 'Europe/Berlin')::date + 4)
    into v_friday;
  if v_friday < (now() at time zone 'Europe/Berlin')::date then
    v_friday := v_friday + 7;
  end if;

  -- Der Kellner arbeitet mitten im Fenster.
  perform public.operator_plan_shift(
    'bedarfsprobe', '00000000-0000-0000-0000-000000009602',
    (v_friday + time '18:00') at time zone 'Europe/Berlin',
    (v_friday + time '22:00') at time zone 'Europe/Berlin'
  );

  v_row := pg_temp.coverage(v_friday);
  perform pg_temp.assert(
    (v_row ->> 'planned_headcount')::int = 1,
    'Eine Person erwartet, waren ' || (v_row ->> 'planned_headcount')
  );
  perform pg_temp.assert((v_row ->> 'missing')::int = 2, 'Zwei fehlen noch');

  -- Er zaehlt aber **nicht** auf den Kuechenbedarf: der filtert die Station.
  v_row := pg_temp.coverage(v_friday, 'kitchen');
  perform pg_temp.assert(
    (v_row ->> 'planned_headcount')::int = 0,
    'Service deckt keinen Kuechenbedarf'
  );
  perform pg_temp.assert((v_row ->> 'missing')::int = 2, 'Zwei in der Kueche fehlen');
end;
$$;

-- Eine Kuechenschicht zaehlt auf beide: auf den Kuechenbedarf und auf den
-- Bedarf ohne Station.
do $$
declare
  v_friday date;
  v_row jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  select (date_trunc('week', now() at time zone 'Europe/Berlin')::date + 4)
    into v_friday;
  if v_friday < (now() at time zone 'Europe/Berlin')::date then
    v_friday := v_friday + 7;
  end if;

  perform public.operator_plan_shift(
    'bedarfsprobe', '00000000-0000-0000-0000-000000009603',
    (v_friday + time '17:00') at time zone 'Europe/Berlin',
    (v_friday + time '23:00') at time zone 'Europe/Berlin',
    null, 'kitchen'
  );

  v_row := pg_temp.coverage(v_friday);
  perform pg_temp.assert(
    (v_row ->> 'planned_headcount')::int = 2, 'Zwei insgesamt erwartet');

  v_row := pg_temp.coverage(v_friday, 'kitchen');
  perform pg_temp.assert(
    (v_row ->> 'planned_headcount')::int = 1, 'Eine in der Kueche erwartet');
  perform pg_temp.assert((v_row ->> 'missing')::int = 1, 'Eine fehlt noch');
end;
$$;

-- Eine **abgelehnte** Schicht deckt nichts: sie ist keine Zuordnung mehr.
do $$
declare
  v_friday date;
  v_shift_id uuid;
  v_row jsonb;
begin
  select (date_trunc('week', now() at time zone 'Europe/Berlin')::date + 4)
    into v_friday;
  if v_friday < (now() at time zone 'Europe/Berlin')::date then
    v_friday := v_friday + 7;
  end if;

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  perform public.operator_publish_schedule(
    'bedarfsprobe',
    (v_friday - 1) at time zone 'Europe/Berlin',
    (v_friday + 1) at time zone 'Europe/Berlin'
  );

  select s.id into v_shift_id
  from public.planned_shifts s join public.venues v on v.id = s.venue_id
  where v.slug = 'bedarfsprobe'
    and s.user_id = '00000000-0000-0000-0000-000000009602';

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009602', false);
  perform public.operator_respond_to_shift(
    'bedarfsprobe', v_shift_id, false, 'Doch nicht');

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  v_row := pg_temp.coverage(v_friday);
  perform pg_temp.assert(
    (v_row ->> 'planned_headcount')::int = 1,
    'Die abgelehnte Schicht zaehlt nicht mehr mit, waren '
      || (v_row ->> 'planned_headcount')
  );
end;
$$;

-- Eine Schicht **neben** dem Fenster zaehlt nicht.
do $$
declare
  v_friday date;
  v_row jsonb;
  v_before int;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  select (date_trunc('week', now() at time zone 'Europe/Berlin')::date + 4)
    into v_friday;
  if v_friday < (now() at time zone 'Europe/Berlin')::date then
    v_friday := v_friday + 7;
  end if;

  v_before := (pg_temp.coverage(v_friday) ->> 'planned_headcount')::int;

  -- 08:00 bis 12:00 liegt vollstaendig vor dem Fenster ab 17:00.
  perform public.operator_plan_shift(
    'bedarfsprobe', '00000000-0000-0000-0000-000000009602',
    (v_friday + time '08:00') at time zone 'Europe/Berlin',
    (v_friday + time '12:00') at time zone 'Europe/Berlin'
  );

  perform pg_temp.assert(
    (pg_temp.coverage(v_friday) ->> 'planned_headcount')::int = v_before,
    'Eine Schicht neben dem Fenster zaehlt nicht'
  );
end;
$$;

-- ============================================================================
-- 4. Sommerzeit
-- ============================================================================

-- Das Fenster ist **Ortszeit**. Ueber die Zeitumstellung hinweg muss
-- „17 bis 23 Uhr" weiterhin 17 bis 23 Uhr sein und nicht um eine Stunde
-- verrutschen. Geprueft an den beiden echten Uebergaengen 2026 in
-- Europe/Berlin: 29. Maerz (Sommerzeit beginnt) und 25. Oktober (endet).
do $$
declare
  v_row jsonb;
  v_start timestamptz;
  v_end timestamptz;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);

  -- Sonntagsmuster, damit beide Uebergangstage getroffen werden.
  perform public.operator_upsert_staffing_requirement(
    'bedarfsprobe', 7, '17:00', '23:00', 1);

  select t into v_row
  from jsonb_array_elements(
    public.operator_staffing_coverage('bedarfsprobe', date '2026-03-29', date '2026-03-29')
  ) t;
  v_start := (v_row ->> 'starts_at')::timestamptz;
  v_end := (v_row ->> 'ends_at')::timestamptz;

  perform pg_temp.assert(
    to_char(v_start at time zone 'Europe/Berlin', 'HH24:MI') = '17:00',
    'Sommerzeitbeginn: Fenster beginnt um 17:00 Ortszeit, war '
      || to_char(v_start at time zone 'Europe/Berlin', 'HH24:MI')
  );
  perform pg_temp.assert(
    to_char(v_end at time zone 'Europe/Berlin', 'HH24:MI') = '23:00',
    'Sommerzeitbeginn: Fenster endet um 23:00 Ortszeit'
  );

  select t into v_row
  from jsonb_array_elements(
    public.operator_staffing_coverage('bedarfsprobe', date '2026-10-25', date '2026-10-25')
  ) t;
  v_start := (v_row ->> 'starts_at')::timestamptz;

  perform pg_temp.assert(
    to_char(v_start at time zone 'Europe/Berlin', 'HH24:MI') = '17:00',
    'Sommerzeitende: Fenster beginnt um 17:00 Ortszeit, war '
      || to_char(v_start at time zone 'Europe/Berlin', 'HH24:MI')
  );

  -- Und der absolute Abstand zu UTC unterscheidet sich zwischen den beiden
  -- Tagen tatsaechlich — sonst prueft der Test nichts.
  perform pg_temp.assert(
    to_char(
      ((date '2026-03-29' + time '17:00') at time zone 'Europe/Berlin')
        at time zone 'UTC', 'HH24:MI') <> to_char(
      ((date '2026-10-25' + time '17:00') at time zone 'Europe/Berlin')
        at time zone 'UTC', 'HH24:MI'),
    'Die beiden Tage liegen wirklich in verschiedenen Zeitzonen-Offsets'
  );
end;
$$;

-- ============================================================================
-- 5. Grenzen und Aufraeumen
-- ============================================================================

do $$
declare
  v_req_id uuid;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);

  perform pg_temp.expect_error(
    $q$select public.operator_staffing_coverage(
      'bedarfsprobe', date '2026-01-01', date '2026-12-31')$q$,
    'staffing_range_too_long'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_staffing_coverage(
      'bedarfsprobe', date '2026-05-10', date '2026-05-01')$q$,
    'staffing_invalid_range'
  );

  select id into v_req_id from public.staffing_requirements
  where venue_id = (select id from public.venues where slug = 'bedarfsprobe')
    and weekday = 7;

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009602', false);
  perform pg_temp.expect_error(
    format($q$select public.operator_delete_staffing_requirement('bedarfsprobe', %L)$q$,
           v_req_id),
    'permission_denied'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-000000009601', false);
  perform public.operator_delete_staffing_requirement('bedarfsprobe', v_req_id);
  perform pg_temp.expect_error(
    format($q$select public.operator_delete_staffing_requirement('bedarfsprobe', %L)$q$,
           v_req_id),
    'staffing_unknown_requirement'
  );
end;
$$;

-- RLS
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-000000009602', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.staffing_requirements) = 2,
    'Personal sieht den Bedarf seiner Venue'
  );
end;
$$;

reset role;

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.staffing_requirements) = 0, 'anon sieht keinen Bedarf');
end;
$$;

reset role;

do $$
begin
  delete from public.venues where slug = 'bedarfsprobe';
end;
$$;

select 'KL-STAFFING-001: alle SQL-Pruefungen bestanden' as ergebnis;
