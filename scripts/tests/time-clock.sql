-- Funktionstest fuer KL-TIME-001 (Migration 20260801120000_time_clock.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird, was einen Zeitnachweis wertlos macht: dass niemand zweimal
-- gleichzeitig auf der Uhr steht, dass Pausen von der Arbeitszeit abgehen,
-- dass ein vergessener Ausstempel wieder aufloesbar ist (sonst kaeme die
-- Person nie wieder auf die Uhr), und dass eine Korrektur den Originalwert
-- **behaelt** statt ihn zu ueberschreiben.
--
-- Dauern werden geprueft, indem die Stempelzeiten direkt zurueckdatiert
-- werden: Ein- und Ausstempeln liegen im Test sonst Mikrosekunden auseinander.
--
-- Der Test legt eine eigene Venue an und raeumt sie am Ende weg; alle Tests
-- dieses Verzeichnisses laufen nacheinander auf derselben Datenbank.

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
  ('00000000-0000-0000-0000-0000000000f1', 'chefin@zeit.test'),
  ('00000000-0000-0000-0000-0000000000f2', 'koechin@zeit.test'),
  ('00000000-0000-0000-0000-0000000000f9', 'fremde@zeit.test')
on conflict (id) do nothing;

-- ============================================================================
-- 0. Ausgangslage
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_create_venue('Zeitprobe', 'zeitprobe');
  perform public.operator_add_staff('zeitprobe', 'koechin@zeit.test', 'kitchen');
end;
$$;

-- ============================================================================
-- 1. Ein- und Ausstempeln
-- ============================================================================

-- Die eigene Zeit zu stempeln braucht kein besonderes Recht: die Koechin traegt
-- keines der fuenf sensiblen Rechte und muss trotzdem auf die Uhr kommen.
do $$
declare
  v_in jsonb;
  v_status jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);

  v_in := public.operator_clock_in('zeitprobe');
  perform pg_temp.assert(v_in ->> 'entry_id' is not null, 'Eintrag erwartet');

  v_status := public.operator_my_time_status('zeitprobe');
  perform pg_temp.assert((v_status ->> 'clocked_in')::boolean, 'Eingestempelt erwartet');
  perform pg_temp.assert((v_status ->> 'on_break')::boolean = false, 'Keine Pause erwartet');
end;
$$;

-- Zweimal einstempeln geht nicht — das ist die tragende Zusage.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform pg_temp.expect_error(
    $q$select public.operator_clock_in('zeitprobe')$q$,
    'time_already_clocked_in'
  );
end;
$$;

-- ============================================================================
-- 2. Pausen gehen von der Arbeitszeit ab
-- ============================================================================

-- Zwei Stunden zurueckdatieren, damit es ueberhaupt etwas zu rechnen gibt.
do $$
begin
  update public.time_entries e
  set started_at = now() - interval '2 hours'
  from public.venues v
  where v.id = e.venue_id and v.slug = 'zeitprobe' and e.status = 'open';
end;
$$;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform public.operator_break_start('zeitprobe', 'meal_break');

  perform pg_temp.expect_error(
    $q$select public.operator_break_start('zeitprobe')$q$,
    'time_break_already_running'
  );
end;
$$;

-- Die Pause auf 30 Minuten zurueckdatieren.
do $$
begin
  update public.time_breaks b
  set started_at = now() - interval '30 minutes'
  where b.ended_at is null;
end;
$$;

do $$
declare
  v_status jsonb;
  v_net bigint;
  v_break bigint;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);

  v_status := public.operator_my_time_status('zeitprobe');
  perform pg_temp.assert((v_status ->> 'on_break')::boolean, 'Pause laeuft');

  v_break := (v_status -> 'current' ->> 'break_seconds')::bigint;
  v_net := (v_status -> 'current' ->> 'net_seconds')::bigint;

  -- Die laufende Pause zaehlt bis jetzt: rund 30 Minuten.
  perform pg_temp.assert(
    v_break between 1790 and 1810,
    'Pause rund 1800 s erwartet, war ' || v_break
  );
  -- Netto also rund 1,5 Stunden statt 2.
  perform pg_temp.assert(
    v_net between 5390 and 5410,
    'Netto rund 5400 s erwartet, war ' || v_net
  );
end;
$$;

do $$
declare
  v_end jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  v_end := public.operator_break_end('zeitprobe');
  perform pg_temp.assert(v_end ->> 'break_id' is not null, 'Pause beendet erwartet');

  perform pg_temp.expect_error(
    $q$select public.operator_break_end('zeitprobe')$q$,
    'time_no_open_break'
  );
end;
$$;

-- ============================================================================
-- 3. Ausstempeln beendet eine laufende Pause mit
-- ============================================================================

do $$
declare
  v_out jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);

  -- Neue Pause, die beim Feierabend noch laeuft.
  perform public.operator_break_start('zeitprobe');

  v_out := public.operator_clock_out('zeitprobe');
  perform pg_temp.assert(
    (v_out ->> 'break_ended_with_clock_out')::boolean,
    'Laufende Pause wird mit ausgestempelt'
  );
  perform pg_temp.assert(
    (select count(*) from public.time_breaks where ended_at is null) = 0,
    'Keine offene Pause mehr erwartet'
  );
end;
$$;

-- Nach dem Ausstempeln geht kein zweites.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform pg_temp.expect_error(
    $q$select public.operator_clock_out('zeitprobe')$q$,
    'time_not_clocked_in'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_break_start('zeitprobe')$q$,
    'time_not_clocked_in'
  );
end;
$$;

-- Und jetzt wieder ein neuer Eintrag: die Sperre galt nur dem offenen.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform public.operator_clock_in('zeitprobe');
end;
$$;

-- Die Tagesgrenze. Ein Nachtdienst gehoert zu dem Tag, an dem er **begonnen**
-- hat — deshalb faellt ein Eintrag von gestern aus `today` heraus, auch wenn er
-- erst heute endete.
--
-- Dieser Test lief einmal nur deshalb rot, weil der Harness um 01:57 startete
-- und „zwei Stunden zurueck" damit auf den Vortag fiel. Statt die Uhrzeit des
-- Laufs zu ignorieren, wird die Regel jetzt ausdruecklich geprueft.
do $$
declare
  v_status jsonb;
  v_heute int;
  v_gestern uuid;
begin
  -- Ein abgeschlossener Eintrag von gestern.
  insert into public.time_entries (venue_id, user_id, started_at, ended_at, status)
  select v.id, '00000000-0000-0000-0000-0000000000f2',
         now() - interval '26 hours', now() - interval '20 hours', 'closed'
  from public.venues v where v.slug = 'zeitprobe'
  returning id into v_gestern;

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  v_status := public.operator_my_time_status('zeitprobe');
  v_heute := jsonb_array_length(v_status -> 'today');

  perform pg_temp.assert(
    not exists (
      select 1 from jsonb_array_elements(v_status -> 'today') t
      where (t ->> 'id')::uuid = v_gestern
    ),
    'Der Eintrag von gestern gehoert nicht zu heute'
  );
  perform pg_temp.assert(
    exists (
      select 1 from jsonb_array_elements(v_status -> 'today') t
      where (t ->> 'status') = 'open'
    ),
    'Der laufende Eintrag gehoert zu heute'
  );

  -- Gegenprobe: ohne die Tagesgrenze waere er dabei.
  perform pg_temp.assert(
    (select count(*) from public.time_entries e join public.venues v on v.id = e.venue_id
     where v.slug = 'zeitprobe'
       and e.user_id = '00000000-0000-0000-0000-0000000000f2') > v_heute,
    'Es gibt mehr Eintraege als heutige — sonst prueft der Test nichts'
  );

  delete from public.time_entries where id = v_gestern;
end;
$$;

-- ============================================================================
-- 4. Fremde stempeln nicht
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f9', false);
  perform pg_temp.expect_error(
    $q$select public.operator_clock_in('zeitprobe')$q$,
    'time_forbidden'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_my_time_status('zeitprobe')$q$,
    'time_forbidden'
  );
end;
$$;

-- ============================================================================
-- 5. Team-Stand braucht staff.manage
-- ============================================================================

do $$
begin
  -- Die Koechin sieht ihre eigene Zeit, aber nicht die des Teams.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform pg_temp.expect_error(
    $q$select public.operator_team_time('zeitprobe')$q$,
    'permission_denied'
  );
end;
$$;

do $$
declare
  v_team jsonb;
  v_row jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  -- Einen Tag zurueck: der erste Eintrag ist zwei Stunden zurueckdatiert und
  -- faellt bei einem Lauf kurz nach Mitternacht sonst aus dem Fenster. Das
  -- prueft nebenbei `p_days_back`.
  v_team := public.operator_team_time('zeitprobe', 1);

  perform pg_temp.assert(
    jsonb_array_length(v_team) = 2,
    'Zwei Eintraege erwartet, waren ' || jsonb_array_length(v_team)
  );

  select t into v_row from jsonb_array_elements(v_team) t where (t ->> 'status') = 'open';
  perform pg_temp.assert(v_row ->> 'email' = 'koechin@zeit.test', 'E-Mail erwartet');
  perform pg_temp.assert(v_row ->> 'role_name' = 'Küche', 'Rollenname erwartet');
end;
$$;

-- ============================================================================
-- 6. Der vergessene Ausstempel
-- ============================================================================

-- Ohne Korrekturweg bliebe der Eintrag fuer immer offen — und die Person kaeme
-- wegen des Index nie wieder auf die Uhr. Das ist der Grund, warum es die
-- Korrektur ueberhaupt gibt.
do $$
declare
  v_entry_id uuid;
begin
  -- Den offenen Eintrag auf gestern zurueckdatieren.
  update public.time_entries e
  set started_at = now() - interval '20 hours'
  from public.venues v
  where v.id = e.venue_id and v.slug = 'zeitprobe' and e.status = 'open'
  returning e.id into v_entry_id;

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  -- Die Betroffene selbst darf nicht korrigieren.
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_correct_time_entry('zeitprobe', %L, 'Vergessen')$q$,
      v_entry_id
    ),
    'permission_denied'
  );
end;
$$;

-- Eine Korrektur ohne Grund ist keine.
do $$
declare
  v_entry_id uuid;
begin
  select e.id into v_entry_id
  from public.time_entries e join public.venues v on v.id = e.venue_id
  where v.slug = 'zeitprobe' and e.status = 'open';

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_correct_time_entry('zeitprobe', %L, '  ')$q$, v_entry_id
    ),
    'time_correction_needs_reason'
  );
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_correct_time_entry(
        'zeitprobe', %L, 'Grund', null, now() - interval '30 hours')$q$,
      v_entry_id
    ),
    'time_correction_invalid_range'
  );
end;
$$;

do $$
declare
  v_entry_id uuid;
  v_original timestamptz;
  v_fix jsonb;
begin
  select e.id, e.started_at into v_entry_id, v_original
  from public.time_entries e join public.venues v on v.id = e.venue_id
  where v.slug = 'zeitprobe' and e.status = 'open';

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  v_fix := public.operator_correct_time_entry(
    'zeitprobe', v_entry_id, 'Ausstempeln vergessen',
    null, v_original + interval '8 hours'
  );

  perform pg_temp.assert(
    (v_fix -> 'totals' ->> 'net_seconds')::bigint = 28800,
    'Acht Stunden erwartet, waren ' || (v_fix -> 'totals' ->> 'net_seconds')
  );
end;
$$;

-- Der Originalwert bleibt stehen, und eine zweite Korrektur ueberschreibt ihn
-- nicht — sonst waere das Audit wertlos.
do $$
declare
  v_entry public.time_entries%rowtype;
begin
  select e.* into v_entry
  from public.time_entries e join public.venues v on v.id = e.venue_id
  where v.slug = 'zeitprobe' and e.correction_reason is not null;

  perform pg_temp.assert(v_entry.status = 'closed', 'Korrigierter Eintrag ist zu');
  perform pg_temp.assert(v_entry.original_ended_at is null, 'Original war offen: NULL');
  perform pg_temp.assert(
    v_entry.correction_reason = 'Ausstempeln vergessen', 'Grund erwartet');
  perform pg_temp.assert(
    v_entry.corrected_by = '00000000-0000-0000-0000-0000000000f1', 'Urheber erwartet');
  perform pg_temp.assert(v_entry.corrected_at is not null, 'Zeitpunkt erwartet');

  -- Zweite Korrektur: `original_started_at` darf sich nicht mehr aendern.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_correct_time_entry(
    'zeitprobe', v_entry.id, 'Nochmal angepasst',
    v_entry.started_at + interval '1 hour', v_entry.ended_at
  );
end;
$$;

do $$
declare
  v_entry public.time_entries%rowtype;
begin
  select e.* into v_entry
  from public.time_entries e join public.venues v on v.id = e.venue_id
  where v.slug = 'zeitprobe' and e.correction_reason = 'Nochmal angepasst';

  perform pg_temp.assert(
    v_entry.original_started_at is not null,
    'Der erste Originalwert muss erhalten sein'
  );
  perform pg_temp.assert(
    v_entry.original_started_at < v_entry.started_at,
    'Der erhaltene Originalwert ist der urspruengliche, nicht der der ersten Korrektur'
  );
end;
$$;

-- Und die Koechin kann wieder einstempeln.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform public.operator_clock_in('zeitprobe');
  perform pg_temp.assert(
    (public.operator_my_time_status('zeitprobe') ->> 'clocked_in')::boolean,
    'Nach der Korrektur wieder stempelbar'
  );
  perform public.operator_clock_out('zeitprobe');
end;
$$;

-- ============================================================================
-- 7. RLS: die eigene Zeit ja, fremde nein
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_clock_in('zeitprobe');
end;
$$;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
end;
$$;

set role authenticated;

do $$
begin
  -- Die Koechin sieht nur ihre eigenen Eintraege, nicht die der Chefin.
  perform pg_temp.assert(
    (select count(*) from public.time_entries
     where user_id <> '00000000-0000-0000-0000-0000000000f2') = 0,
    'Fremde Eintraege bleiben unsichtbar'
  );
  perform pg_temp.assert(
    (select count(*) from public.time_entries) > 0,
    'Die eigenen Eintraege sind sichtbar'
  );
end;
$$;

reset role;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
end;
$$;

set role authenticated;

do $$
begin
  -- Die Chefin hat staff.manage und sieht alles.
  perform pg_temp.assert(
    (select count(*) from public.time_entries
     where user_id = '00000000-0000-0000-0000-0000000000f2') > 0,
    'Mit staff.manage sind fremde Eintraege sichtbar'
  );
end;
$$;

reset role;

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.time_entries) = 0, 'anon sieht keine Zeiten');
  perform pg_temp.assert(
    (select count(*) from public.time_breaks) = 0, 'anon sieht keine Pausen');
end;
$$;

reset role;

-- ============================================================================
-- 8. Aufraeumen
-- ============================================================================

do $$
begin
  delete from public.venues where slug = 'zeitprobe';
end;
$$;

select 'KL-TIME-001: alle SQL-Pruefungen bestanden' as ergebnis;
