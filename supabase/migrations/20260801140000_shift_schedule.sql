-- KL-PLAN-001: Dienstplan (Blueprint §9.2, Meilenstein 2).
--
-- KL-TIME-001 hat den **tatsächlichen** Zeiteintrag persistiert. Was fehlte,
-- war das Gegenstück: die **geplante** Schicht. Ohne sie hat der Soll-/Ist-
-- Vergleich aus §9.3 nichts, wogegen er vergleichen könnte, und der Betrieb
-- keine Antwort auf „wer kommt morgen".
--
-- Blueprint §9 hält drei Fachobjekte getrennt, und das bleibt so:
--
--   Betriebsschicht      `business_shifts`  — „die Kasse ist offen"
--   geplante Schicht     `planned_shifts`   — „du bist morgen ab 17 Uhr dran"
--   Zeiteintrag          `time_entries`     — „du hast gearbeitet"
--
-- Der Lebenszyklus ist **nicht neu erfunden**: er folgt der seit
-- KL-WORKFORCE-001 getesteten Domäne in
-- `kitchenlink/Features/Workforce/WorkforceShiftLifecycle.swift` —
-- Entwurf → veröffentlicht → angenommen oder abgelehnt.
--
-- Die tragende Zusage steht wieder in der Datenbank, nicht in der App:
-- **niemand ist zweimal gleichzeitig verplant.**

begin;

-- ============================================================================
-- 1. Recht
-- ============================================================================

-- Ein sechstes Recht — und wie die fünf davor wird es an jeder Stelle geprüft,
-- an der es steht. Planen ist eine andere Verantwortung als Personal
-- verwalten: eine Schichtleitung schreibt den Wochenplan, stellt aber niemanden
-- ein. Deshalb ein eigenes Recht statt `staff.manage` mitzubenutzen.
--
-- Bewusst **nicht** per Manager-PIN freigebbar: `kitchenlink_pin_overridable`
-- (KL-ROLE-002) ist eine Positivliste für Handgriffe am Tisch. Einen
-- Wochenplan schreibt niemand unter Zeitdruck mit geliehener Befugnis.
create or replace function public.kitchenlink_seed_venue_roles(p_venue_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.venue_roles (venue_id, key, name, permissions, is_builtin, sort_order)
  values
    (p_venue_id, 'owner', 'Inhaber',
     array['shift.open', 'shift.close', 'cash.movement', 'payments.refund',
           'staff.manage', 'schedule.manage'],
     true, 10),
    (p_venue_id, 'manager', 'Manager',
     array['shift.open', 'shift.close', 'cash.movement', 'payments.refund',
           'staff.manage', 'schedule.manage'],
     true, 20),
    (p_venue_id, 'shift_lead', 'Schichtleitung',
     array['shift.open', 'shift.close', 'cash.movement', 'payments.refund',
           'schedule.manage'],
     true, 30),
    (p_venue_id, 'service', 'Service', '{}', true, 40),
    (p_venue_id, 'kitchen', 'Küche', '{}', true, 50),
    (p_venue_id, 'bar', 'Bar', '{}', true, 60),
    (p_venue_id, 'driver', 'Fahrer', '{}', true, 70),
    (p_venue_id, 'stock', 'Lager', '{}', true, 80),
    (p_venue_id, 'accounting', 'Buchhaltung', '{}', true, 90)
  on conflict (venue_id, key) do update
    set name = excluded.name,
        permissions = excluded.permissions,
        sort_order = excluded.sort_order,
        is_builtin = true;
end;
$$;

-- Bestandsvenues bekommen das neue Recht sofort — sonst könnte in einem
-- bestehenden Lokal niemand planen, bis jemand die Rollen anfasst.
do $$
declare
  v_venue record;
begin
  for v_venue in select id from public.venues loop
    perform public.kitchenlink_seed_venue_roles(v_venue.id);
  end loop;
end;
$$;

-- ============================================================================
-- 2. Tabelle
-- ============================================================================

-- `btree_gist` erlaubt Gleichheit auf `uuid` in einem Ausschluss-Constraint;
-- ohne die Erweiterung liesse sich „dieselbe Person, überlappender Zeitraum"
-- nicht als Constraint schreiben, sondern nur als Regel in der App — und dort
-- gewinnt bei zwei gleichzeitig planenden Geräten der Zufall.
create extension if not exists btree_gist with schema extensions;

create table if not exists public.planned_shifts (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,

  starts_at timestamptz not null,
  ends_at timestamptz not null,

  -- Blueprint §9.2 „Zuordnung zu Bereichen und Stationen". Beide optional:
  -- `area` ist frei wie `tables.area` („Gastraum", „Terrasse"), `station`
  -- trägt dieselben Werte wie `order_items.station`, damit später niemand zwei
  -- Vokabulare zusammenführen muss.
  area text,
  station text check (station is null or station in ('kitchen', 'bar')),

  -- Der Lebenszyklus aus `WorkforceShiftLifecycle.swift`. `swap_requested`
  -- fehlt bewusst: Tauschanfragen sind eine eigene Scheibe, und ein Status,
  -- den nichts erreichen kann, ist Ballast.
  status text not null default 'draft'
    check (status in ('draft', 'published', 'accepted', 'declined')),

  published_at timestamptz,
  accepted_at timestamptz,
  declined_at timestamptz,
  decline_reason text,

  note text,
  created_by uuid,
  created_at timestamptz not null default now(),

  constraint planned_shifts_end_after_start check (ends_at > starts_at),
  -- Ein Zustand traegt seinen Zeitstempel, oder er ist nicht dieser Zustand.
  constraint planned_shifts_status_timestamps check (
    (status = 'draft' and published_at is null
      and accepted_at is null and declined_at is null)
    or (status = 'published' and published_at is not null
      and accepted_at is null and declined_at is null)
    or (status = 'accepted' and published_at is not null and accepted_at is not null)
    or (status = 'declined' and published_at is not null and declined_at is not null)
  )
);

-- Die tragende Zusage: niemand ist zweimal gleichzeitig verplant. Eine
-- **abgelehnte** Schicht blockiert nicht mehr — sie ist keine Zuordnung mehr,
-- sondern nur noch ihre Geschichte.
alter table public.planned_shifts
  drop constraint if exists planned_shifts_no_overlap;
alter table public.planned_shifts
  add constraint planned_shifts_no_overlap
  exclude using gist (
    user_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status <> 'declined');

create index if not exists planned_shifts_venue_idx
  on public.planned_shifts(venue_id, starts_at);
create index if not exists planned_shifts_user_idx
  on public.planned_shifts(user_id, starts_at);

-- ============================================================================
-- 3. Schutz
-- ============================================================================

alter table public.planned_shifts enable row level security;

-- Ein **Entwurf** ist für den Betroffenen unsichtbar. Das ist der ganze Sinn
-- der Trennung: eine Planende soll die Woche umstellen können, ohne dass bei
-- jedem Zwischenstand jemand denkt, er sei eingeteilt.
drop policy if exists "planned_shifts_read" on public.planned_shifts;
create policy "planned_shifts_read" on public.planned_shifts
  for select
  to authenticated
  using (
    (user_id = auth.uid() and status <> 'draft' and public.is_venue_staff(venue_id))
    or public.has_venue_permission(venue_id, 'schedule.manage')
  );

-- ============================================================================
-- 4. Planen
-- ============================================================================

create or replace function public.operator_plan_shift(
  p_venue_slug text,
  p_user_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_area text default null,
  p_station text default null,
  p_note text default null,
  p_shift_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_existing public.planned_shifts%rowtype;
  v_shift_id uuid;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'plan_invalid_range: das Ende muss nach dem Beginn liegen';
  end if;
  if p_station is not null and p_station not in ('kitchen', 'bar') then
    raise exception 'plan_invalid_station: %', p_station;
  end if;

  if not exists (
    select 1 from public.venue_staff
    where venue_id = v_venue_id and user_id = p_user_id
  ) then
    raise exception 'plan_unknown_staff: gehört nicht zum Personal dieser Venue';
  end if;

  begin
    if p_shift_id is null then
      insert into public.planned_shifts (
        venue_id, user_id, starts_at, ends_at, area, station, note, created_by
      ) values (
        v_venue_id, p_user_id, p_starts_at, p_ends_at,
        nullif(btrim(coalesce(p_area, '')), ''),
        p_station,
        nullif(btrim(coalesce(p_note, '')), ''),
        v_user
      ) returning id into v_shift_id;
    else
      select * into v_existing
      from public.planned_shifts
      where id = p_shift_id and venue_id = v_venue_id
      for update;
      if not found then
        raise exception 'plan_unknown_shift';
      end if;

      -- Eine bereits angenommene Schicht zu verschieben, ohne dass der
      -- Betroffene es erfaehrt, waere still. Sie faellt deshalb auf
      -- `published` zurueck und muss erneut angenommen werden.
      update public.planned_shifts
      set starts_at = p_starts_at,
          ends_at = p_ends_at,
          area = nullif(btrim(coalesce(p_area, '')), ''),
          station = p_station,
          note = nullif(btrim(coalesce(p_note, '')), ''),
          status = case when status = 'accepted' then 'published' else status end,
          accepted_at = case when status = 'accepted' then null else accepted_at end
      where id = p_shift_id;
      v_shift_id := p_shift_id;
    end if;
  exception
    when exclusion_violation then
      raise exception
        'plan_overlaps: diese Person ist in diesem Zeitraum bereits verplant';
  end;

  return jsonb_build_object('shift_id', v_shift_id);
end;
$$;

revoke all on function public.operator_plan_shift(
  text, uuid, timestamptz, timestamptz, text, text, text, uuid
) from public, anon;
grant execute on function public.operator_plan_shift(
  text, uuid, timestamptz, timestamptz, text, text, text, uuid
) to authenticated;

create or replace function public.operator_delete_planned_shift(
  p_venue_slug text,
  p_shift_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  delete from public.planned_shifts
  where id = p_shift_id and venue_id = v_venue_id;
  if not found then
    raise exception 'plan_unknown_shift';
  end if;

  return jsonb_build_object('shift_id', p_shift_id, 'deleted', true);
end;
$$;

revoke all on function public.operator_delete_planned_shift(text, uuid) from public, anon;
grant execute on function public.operator_delete_planned_shift(text, uuid) to authenticated;

-- ============================================================================
-- 5. Veröffentlichen
-- ============================================================================

-- Blueprint §9.2 „Veröffentlichung": erst ab hier ist der Plan für das Personal
-- sichtbar. Veroeffentlicht wird ein **Zeitraum**, nicht eine einzelne Schicht —
-- eine halb veroeffentlichte Woche waere fuer niemanden lesbar.
create or replace function public.operator_publish_schedule(
  p_venue_slug text,
  p_from timestamptz,
  p_to timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_count int;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  if p_from is null or p_to is null or p_to <= p_from then
    raise exception 'plan_invalid_range';
  end if;

  with published as (
    update public.planned_shifts
    set status = 'published', published_at = now()
    where venue_id = v_venue_id
      and status = 'draft'
      and starts_at >= p_from
      and starts_at < p_to
    returning 1
  )
  select count(*) into v_count from published;

  return jsonb_build_object('published', v_count);
end;
$$;

revoke all on function public.operator_publish_schedule(
  text, timestamptz, timestamptz
) from public, anon;
grant execute on function public.operator_publish_schedule(
  text, timestamptz, timestamptz
) to authenticated;

-- ============================================================================
-- 6. Annehmen und ablehnen
-- ============================================================================

-- Die eigene Schicht zu beantworten braucht **kein** Recht: es ist die eigene
-- Zeit. Wer sie beantwortet, muss aber der Eingeteilte sein.
create or replace function public.operator_respond_to_shift(
  p_venue_slug text,
  p_shift_id uuid,
  p_accept boolean,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_shift public.planned_shifts%rowtype;
begin
  if v_user is null then
    raise exception 'plan_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'plan_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'plan_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_shift
  from public.planned_shifts
  where id = p_shift_id and venue_id = v_venue_id
  for update;
  if not found then
    raise exception 'plan_unknown_shift';
  end if;

  if v_shift.user_id <> v_user then
    raise exception 'plan_not_yours: das ist nicht deine Schicht';
  end if;
  -- Der Lebenszyklus aus der Domaene: geantwortet wird auf eine
  -- **veroeffentlichte** Schicht, nicht auf einen Entwurf und nicht zweimal.
  if v_shift.status <> 'published' then
    raise exception 'plan_not_published: darauf lässt sich nicht mehr antworten';
  end if;

  if p_accept then
    update public.planned_shifts
    set status = 'accepted', accepted_at = now()
    where id = p_shift_id;
  else
    update public.planned_shifts
    set status = 'declined',
        declined_at = now(),
        decline_reason = nullif(btrim(coalesce(p_reason, '')), '')
    where id = p_shift_id;
  end if;

  return jsonb_build_object(
    'shift_id', p_shift_id,
    'status', case when p_accept then 'accepted' else 'declined' end
  );
end;
$$;

revoke all on function public.operator_respond_to_shift(
  text, uuid, boolean, text
) from public, anon;
grant execute on function public.operator_respond_to_shift(
  text, uuid, boolean, text
) to authenticated;

-- ============================================================================
-- 7. Lesen
-- ============================================================================

-- Die eigenen kommenden Schichten. Entwuerfe sind nicht dabei — sie sind noch
-- niemandes Zusage.
create or replace function public.operator_my_shifts(
  p_venue_slug text,
  p_days_ahead int default 14
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_rows jsonb;
begin
  if v_user is null then
    raise exception 'plan_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'plan_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'plan_forbidden: kein Personal dieser Venue';
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.starts_at), '[]'::jsonb)
    into v_rows
  from (
    select s.id, s.starts_at, s.ends_at, s.area, s.station, s.status,
           s.note, s.decline_reason
    from public.planned_shifts s
    where s.venue_id = v_venue_id
      and s.user_id = v_user
      and s.status <> 'draft'
      and s.ends_at >= now()
      and s.starts_at < now() + make_interval(
            days => least(greatest(coalesce(p_days_ahead, 14), 1), 90))
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_my_shifts(text, int) from public, anon;
grant execute on function public.operator_my_shifts(text, int) to authenticated;

-- Der Plan des Lokals in einem Zeitraum, inklusive Entwuerfen. Braucht
-- `schedule.manage`.
create or replace function public.operator_venue_schedule(
  p_venue_slug text,
  p_from timestamptz,
  p_to timestamptz
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_rows jsonb;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  if p_from is null or p_to is null or p_to <= p_from then
    raise exception 'plan_invalid_range';
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.starts_at, t.email), '[]'::jsonb)
    into v_rows
  from (
    select s.id, s.user_id, u.email, vr.name as role_name,
           s.starts_at, s.ends_at, s.area, s.station, s.status,
           s.note, s.decline_reason
    from public.planned_shifts s
    left join auth.users u on u.id = s.user_id
    left join public.venue_staff vs
      on vs.venue_id = s.venue_id and vs.user_id = s.user_id
    left join public.venue_roles vr
      on vr.venue_id = s.venue_id and vr.key = vs.role
    where s.venue_id = v_venue_id
      and s.starts_at >= p_from
      and s.starts_at < p_to
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_venue_schedule(
  text, timestamptz, timestamptz
) from public, anon;
grant execute on function public.operator_venue_schedule(
  text, timestamptz, timestamptz
) to authenticated;

commit;
