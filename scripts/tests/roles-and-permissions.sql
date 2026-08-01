-- Funktionstest fuer KL-ROLE-001
-- (Migration 20260731220000_roles_and_permissions.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Der Kern: bis hierher durfte **jeder Angemeldete alles**. Geprueft wird
-- deshalb vor allem, was eine Servicekraft ab jetzt *nicht* mehr kann, dass
-- eine Schichtleitung es sehr wohl kann, und dass keine Regel eine Venue
-- fuehrungslos zurueckoder jemanden aussperren kann.
--
-- Dieser Test legt eine **eigene Venue** an: die Rollen der Sandbox-Venue
-- werden von vier anderen Tests benutzt, die alle mit vollen Rechten arbeiten.

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

-- Konten: Inhaberin, Managerin, Schichtleitung, Servicekraft, Fremde.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'inhaberin@rollen.test'),
  ('00000000-0000-0000-0000-0000000000e2', 'managerin@rollen.test'),
  ('00000000-0000-0000-0000-0000000000e3', 'schichtleitung@rollen.test'),
  ('00000000-0000-0000-0000-0000000000e4', 'service@rollen.test'),
  ('00000000-0000-0000-0000-0000000000e5', 'zweite.inhaberin@rollen.test'),
  ('00000000-0000-0000-0000-0000000000e9', 'fremde@rollen.test')
on conflict (id) do nothing;

-- ============================================================================
-- 0. Eigene Venue; die Anlegerin ist ihre Inhaberin
-- ============================================================================

do $$
declare
  v_venue jsonb;
  v_role text;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);
  v_venue := public.operator_create_venue('Rollenprobe', 'rollenprobe');
  perform pg_temp.assert(v_venue ->> 'venue_id' is not null, 'Venue erwartet');

  select vs.role into v_role
  from public.venue_staff vs
  where vs.user_id = '00000000-0000-0000-0000-0000000000e1'
    and vs.venue_id = (v_venue ->> 'venue_id')::uuid;

  -- Frueher stand hier 'operator'. Wer anlegt, ist Inhaber.
  perform pg_temp.assert(v_role = 'owner', 'Anlegerin ist Inhaberin, war ' || coalesce(v_role, 'NULL'));
end;
$$;

-- Der Trigger hat die neun Standardrollen aus Blueprint §9.1 mitgebracht.
do $$
declare
  v_roles jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);
  v_roles := public.operator_venue_roles('rollenprobe');
  perform pg_temp.assert(
    jsonb_array_length(v_roles) = 9,
    'Neun Standardrollen erwartet, waren ' || jsonb_array_length(v_roles)
  );
  perform pg_temp.assert(
    (select count(*) from jsonb_array_elements(v_roles) r
     where r ->> 'key' = 'owner') = 1,
    'Rolle owner erwartet'
  );
end;
$$;

-- ============================================================================
-- 1. Personal zuordnen
-- ============================================================================

do $$
declare
  v_added jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);

  v_added := public.operator_add_staff('rollenprobe', 'managerin@rollen.test', 'manager');
  perform pg_temp.assert(
    (v_added ->> 'user_id')::uuid = '00000000-0000-0000-0000-0000000000e2',
    'Managerin erwartet'
  );

  perform public.operator_add_staff('rollenprobe', 'schichtleitung@rollen.test', 'shift_lead');
  -- Gross-/Kleinschreibung der E-Mail darf nicht entscheiden.
  perform public.operator_add_staff('rollenprobe', 'Service@Rollen.Test', 'service');
end;
$$;

-- Ohne Konto keine Zuordnung: KitchenLink legt keine fremden Konten an.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);
  perform pg_temp.expect_error(
    $q$select public.operator_add_staff('rollenprobe', 'niemand@rollen.test', 'service')$q$,
    'staff_no_account'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_add_staff('rollenprobe', 'service@rollen.test', 'chefkoch')$q$,
    'staff_unknown_role'
  );
end;
$$;

-- ============================================================================
-- 2. Die eigentliche Zusage: Service darf die sensiblen Dinge nicht
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e4', false);

  perform pg_temp.expect_error(
    $q$select public.operator_open_shift('rollenprobe', 10000, 'service-oeffnet')$q$,
    'permission_denied'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_close_shift('rollenprobe', 0)$q$,
    'permission_denied'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_record_cash_movement('rollenprobe', 'payout', 500, 'x')$q$,
    'permission_denied'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_venue_team('rollenprobe')$q$,
    'permission_denied'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_add_staff('rollenprobe', 'fremde@rollen.test', 'service')$q$,
    'permission_denied'
  );
end;
$$;

-- Was Service sehr wohl darf: der Alltag. Die Rechte regeln nur die sensiblen
-- Aktionen — Kueche, Bar und Service brauchen genau diese Handgriffe.
do $$
declare
  v_mine jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e4', false);

  -- Rollenliste und Tischverwaltung bleiben offen (Mitgliedschaft genuegt).
  perform public.operator_venue_roles('rollenprobe');
  perform public.operator_upsert_table('rollenprobe', 'S1', 'Gastraum', 10, true);

  v_mine := public.operator_my_permissions('rollenprobe');
  perform pg_temp.assert(v_mine ->> 'role' = 'service', 'Rolle service erwartet');
  perform pg_temp.assert(v_mine ->> 'role_name' = 'Service', 'Anzeigename erwartet');
  perform pg_temp.assert(
    jsonb_array_length(v_mine -> 'permissions') = 0,
    'Service traegt keines der fuenf sensiblen Rechte'
  );
end;
$$;

-- ============================================================================
-- 3. Schichtleitung darf die Kasse, aber kein Personal
-- ============================================================================

do $$
declare
  v_mine jsonb;
  v_shift jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e3', false);

  v_mine := public.operator_my_permissions('rollenprobe');
  -- Inhaltlich statt gezaehlt: eine Zahl haette bei jedem neuen Recht
  -- gebrochen, ohne dass sich am Sinn etwas aendert (KL-PLAN-001 hat genau
  -- das ausgeloest). Entscheidend ist, was die Rolle **abgrenzt**.
  perform pg_temp.assert(
    v_mine -> 'permissions' ? 'shift.close', 'Schichtleitung schliesst die Kasse ab');
  perform pg_temp.assert(
    v_mine -> 'permissions' ? 'payments.refund', 'Schichtleitung storniert');
  perform pg_temp.assert(
    v_mine -> 'permissions' ? 'schedule.manage', 'Schichtleitung schreibt den Plan');
  perform pg_temp.assert(
    not (v_mine -> 'permissions' ? 'staff.manage'),
    'Schichtleitung stellt niemanden ein — das ist ihre Grenze'
  );

  v_shift := public.operator_open_shift('rollenprobe', 5000, 'sl-oeffnet');
  perform pg_temp.assert(v_shift ->> 'shift_id' is not null, 'Schichtleitung darf oeffnen');

  perform public.operator_record_cash_movement('rollenprobe', 'payout', 500, 'sl-entnahme');

  -- Personal aber nicht.
  perform pg_temp.expect_error(
    $q$select public.operator_venue_team('rollenprobe')$q$,
    'permission_denied'
  );
end;
$$;

-- ============================================================================
-- 4. Sperren gegen Aussperren und Fuehrungslosigkeit
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);

  -- (1) Niemand aendert die eigene Rolle.
  perform pg_temp.expect_error(
    $q$select public.operator_set_staff_role(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e1', 'service')$q$,
    'staff_self_change'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_remove_staff(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e1')$q$,
    'staff_self_change'
  );

  -- (3) Der letzte Inhaber bleibt Inhaber — hier ueber den Umweg, dass die
  -- Managerin es versucht (siehe unten) bzw. dass es nur einen gibt.
  perform pg_temp.expect_error(
    $q$select public.operator_set_staff_role(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e9', 'service')$q$,
    'staff_unknown'
  );
end;
$$;

-- (2) Eine Managerin darf die Inhaberin nicht umstufen.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e2', false);
  perform pg_temp.expect_error(
    $q$select public.operator_set_staff_role(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e1', 'service')$q$,
    'staff_owner_protected'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_remove_staff(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e1')$q$,
    'staff_owner_protected'
  );

  -- Eine Servicekraft umzustufen ist ihr dagegen erlaubt.
  perform public.operator_set_staff_role(
    'rollenprobe', '00000000-0000-0000-0000-0000000000e4', 'kitchen');
end;
$$;

do $$
declare
  v_role text;
begin
  select role into v_role from public.venue_staff
  where user_id = '00000000-0000-0000-0000-0000000000e4'
    and venue_id = (select id from public.venues where slug = 'rollenprobe');
  perform pg_temp.assert(v_role = 'kitchen', 'Umstufung erwartet, war ' || coalesce(v_role, 'NULL'));
end;
$$;

-- Der letzte Inhaber kann nicht heruntergestuft werden. Mit einem zweiten
-- Inhaber geht es, danach wieder nicht.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);
  perform public.operator_add_staff('rollenprobe', 'zweite.inhaberin@rollen.test', 'owner');
end;
$$;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e5', false);
  -- Jetzt gibt es zwei Inhaberinnen, also darf eine die andere umstufen.
  perform public.operator_set_staff_role(
    'rollenprobe', '00000000-0000-0000-0000-0000000000e1', 'manager');

  -- Sie selbst ist jetzt die letzte Inhaberin und kommt nicht mehr heraus.
  perform pg_temp.expect_error(
    $q$select public.operator_set_staff_role(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e5', 'service')$q$,
    'staff_self_change'
  );
end;
$$;

do $$
begin
  -- Die zur Managerin gewordene erste Inhaberin kann die letzte Inhaberin
  -- weder umstufen noch entfernen.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);
  perform pg_temp.expect_error(
    $q$select public.operator_set_staff_role(
      'rollenprobe', '00000000-0000-0000-0000-0000000000e5', 'service')$q$,
    'staff_owner_protected'
  );
end;
$$;

-- ============================================================================
-- 5. Team lesen
-- ============================================================================

do $$
declare
  v_team jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e5', false);
  v_team := public.operator_venue_team('rollenprobe');

  perform pg_temp.assert(
    jsonb_array_length(v_team) = 5,
    'Fuenf Personen erwartet, waren ' || jsonb_array_length(v_team)
  );
  perform pg_temp.assert(
    (select count(*) from jsonb_array_elements(v_team) t
     where (t ->> 'is_me')::boolean) = 1,
    'Genau ein Eintrag ist der eigene'
  );
  perform pg_temp.assert(
    (select t ->> 'email' from jsonb_array_elements(v_team) t
     where t ->> 'role' = 'shift_lead') = 'schichtleitung@rollen.test',
    'E-Mail der Schichtleitung erwartet'
  );
  perform pg_temp.assert(
    (select t ->> 'role_name' from jsonb_array_elements(v_team) t
     where t ->> 'role' = 'shift_lead') = 'Schichtleitung',
    'Anzeigename der Rolle erwartet'
  );
end;
$$;

-- ============================================================================
-- 6. Bestandspersonal verliert nichts
-- ============================================================================

-- Die Sandbox-Venue hatte vor dieser Migration Personal mit der Rolle
-- 'operator', das uneingeschraenkt handeln durfte. Es waere eine stille
-- Entrechtung, wenn eine Migration ihm Rechte naehme.
do $$
declare
  v_venue_id uuid;
begin
  select id into v_venue_id from public.venues where slug = 'alte-muehle';
  perform pg_temp.assert(
    not exists (select 1 from public.venue_staff where role = 'operator'),
    'Keine Zeile darf auf der abgeschafften Rolle stehenbleiben'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000aa', false);
  perform pg_temp.assert(
    public.has_venue_permission(v_venue_id, 'shift.close'),
    'Bestandspersonal darf weiterhin abschliessen'
  );
  perform pg_temp.assert(
    public.has_venue_permission(v_venue_id, 'payments.refund'),
    'Bestandspersonal darf weiterhin stornieren'
  );
end;
$$;

-- Fremde haben in fremden Venues kein Recht.
do $$
declare
  v_venue_id uuid;
begin
  select id into v_venue_id from public.venues where slug = 'rollenprobe';
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e9', false);
  perform pg_temp.assert(
    not public.has_venue_permission(v_venue_id, 'shift.close'),
    'Fremde duerfen nichts'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_my_permissions('nicht-vorhanden')$q$,
    'permission_unknown_venue'
  );
end;
$$;

-- Wer nicht zum Personal gehoert, bekommt eine leere Auskunft statt eines
-- Fehlers: die App zeigt dann „kein Zugriff" statt eines Absturzes.
do $$
declare
  v_mine jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e9', false);
  v_mine := public.operator_my_permissions('rollenprobe');
  perform pg_temp.assert(v_mine ->> 'role' is null, 'Keine Rolle erwartet');
  perform pg_temp.assert(
    jsonb_array_length(v_mine -> 'permissions') = 0, 'Keine Rechte erwartet');
end;
$$;

-- ============================================================================
-- 7. RLS auf den Rollen
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e9', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.venue_roles) = 0,
    'Fremde sehen keine Rollen'
  );
end;
$$;

reset role;

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e5', false);
end;
$$;

set role authenticated;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.venue_roles) = 9,
    'Eigenes Personal sieht die neun Rollen seiner Venue'
  );
end;
$$;

reset role;

set role anon;

do $$
begin
  perform pg_temp.assert(
    (select count(*) from public.venue_roles) = 0,
    'anon sieht keine Rollen'
  );
end;
$$;

reset role;

-- ============================================================================
-- 8. Aufraeumen
-- ============================================================================

-- Die Testvenue wird stillgelegt, damit sie den Venue-Zaehlungen der anderen
-- Tests nicht in die Quere kommt (alle laufen auf derselben Datenbank).
do $$
begin
  delete from public.venues where slug = 'rollenprobe';
end;
$$;

select 'KL-ROLE-001: alle SQL-Pruefungen bestanden' as ergebnis;
