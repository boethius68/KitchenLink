-- KL-LEAVE-001: Abwesenheiten (Blueprint §9.2, Meilenstein 2).
--
-- KL-PLAN-001 hat den Dienstplan gebaut — und dabei eine Lücke gelassen, die
-- im Betrieb sofort auffällt: **es liess sich jemand einteilen, der Urlaub
-- hat.** Die Planung merkte es nicht. Diese Migration schliesst das.
--
-- Der Lebenszyklus folgt der seit KL-WORKFORCE-001 getesteten Domäne
-- (`WorkforceLeave` in `WorkforceTimeModels.swift`): beantragt → genehmigt oder
-- abgelehnt, mit denselben fünf Arten.
--
-- **Die tragende Entscheidung ist eine Asymmetrie**, und sie folgt aus dem
-- Betrieb, nicht aus der Technik:
--
--   * In eine **genehmigte** Abwesenheit hinein zu planen wird **abgewiesen**.
--     Die Planung tut dann etwas nachweislich Falsches, und die Datenbank weiss
--     es besser als das Gerät.
--
--   * Eine Abwesenheit zu genehmigen, die auf **bereits geplante** Schichten
--     fällt, wird **erlaubt** — und meldet die betroffenen Schichten zurück.
--     Alles andere wäre absurd: eine Krankmeldung kommt nach dem Dienstplan,
--     nicht davor. Wer krank ist, ist krank; die Schicht muss neu besetzt
--     werden, aber die Genehmigung darf daran nicht scheitern.
--
-- Wer eine Abwesenheit **beantragt**, braucht kein besonderes Recht — es ist
-- die eigene Abwesenheit. Wer sie **genehmigt**, braucht `schedule.manage`.

begin;

-- ============================================================================
-- 1. Tabelle
-- ============================================================================

create table if not exists public.staff_leaves (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,

  -- `timestamptz` statt `date`, damit sich die Überlappung mit
  -- `planned_shifts` exakt und ohne Umrechnung prüfen lässt. Die App setzt für
  -- ganze Tage die Ortsmitternacht der Venue.
  starts_at timestamptz not null,
  ends_at timestamptz not null,

  -- Dieselben fünf Arten wie `WorkforceLeaveType`.
  kind text not null check (
    kind in ('vacation', 'sick', 'unpaid', 'training', 'other')
  ),
  -- `cancelled` ergänzt `WorkforceLeaveStatus`: ein Antrag, den jemand selbst
  -- zurückzieht, ist weder genehmigt noch abgelehnt.
  status text not null default 'requested' check (
    status in ('requested', 'approved', 'rejected', 'cancelled')
  ),

  reason text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  review_note text,

  created_at timestamptz not null default now(),

  constraint staff_leaves_end_after_start check (ends_at > starts_at),
  -- Ein Zustand trägt seinen Zeitstempel, oder er ist nicht dieser Zustand.
  constraint staff_leaves_review_complete check (
    (status in ('requested', 'cancelled')
      and reviewed_by is null and reviewed_at is null)
    or (status in ('approved', 'rejected')
      and reviewed_by is not null and reviewed_at is not null)
  )
);

-- Zwei genehmigte Abwesenheiten derselben Person können sich nicht
-- überschneiden — sonst wäre nicht entscheidbar, welche gilt. Anträge dürfen
-- sich überlappen: erst die Genehmigung macht daraus eine Tatsache.
alter table public.staff_leaves
  drop constraint if exists staff_leaves_no_overlap;
alter table public.staff_leaves
  add constraint staff_leaves_no_overlap
  exclude using gist (
    user_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'approved');

create index if not exists staff_leaves_venue_idx
  on public.staff_leaves(venue_id, starts_at desc);
create index if not exists staff_leaves_user_idx
  on public.staff_leaves(user_id, starts_at desc);

-- ============================================================================
-- 2. Schutz
-- ============================================================================

alter table public.staff_leaves enable row level security;

-- Die eigene Abwesenheit darf jeder sehen; die der anderen nur, wer plant.
-- Anders als beim Dienstplan ist hier auch der **Antrag** für den Antragsteller
-- sichtbar: es ist sein eigener.
drop policy if exists "staff_leaves_read" on public.staff_leaves;
create policy "staff_leaves_read" on public.staff_leaves
  for select
  to authenticated
  using (
    (user_id = auth.uid() and public.is_venue_staff(venue_id))
    or public.has_venue_permission(venue_id, 'schedule.manage')
  );

-- ============================================================================
-- 3. Hilfsfunktion
-- ============================================================================

-- Liegt in diesem Zeitraum eine **genehmigte** Abwesenheit dieser Person?
create or replace function public.kitchenlink_has_approved_leave(
  p_venue_id uuid,
  p_user_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.staff_leaves l
    where l.venue_id = p_venue_id
      and l.user_id = p_user_id
      and l.status = 'approved'
      and tstzrange(l.starts_at, l.ends_at, '[)')
          && tstzrange(p_starts_at, p_ends_at, '[)')
  );
$$;

-- ============================================================================
-- 4. Beantragen und zurückziehen
-- ============================================================================

-- Die eigene Abwesenheit zu beantragen braucht **kein** Recht.
create or replace function public.operator_request_leave(
  p_venue_slug text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_kind text,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_leave_id uuid;
begin
  if v_user is null then
    raise exception 'leave_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'leave_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'leave_forbidden: kein Personal dieser Venue';
  end if;

  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'leave_invalid_range: das Ende muss nach dem Beginn liegen';
  end if;
  if p_kind not in ('vacation', 'sick', 'unpaid', 'training', 'other') then
    raise exception 'leave_invalid_kind: %', p_kind;
  end if;

  -- Ein Antrag auf einen Zeitraum, der schon genehmigt frei ist, hilft
  -- niemandem und würde den Genehmigenden nur verwirren.
  if public.kitchenlink_has_approved_leave(v_venue_id, v_user, p_starts_at, p_ends_at) then
    raise exception 'leave_already_approved: für diesen Zeitraum ist bereits etwas genehmigt';
  end if;

  insert into public.staff_leaves (
    venue_id, user_id, starts_at, ends_at, kind, reason
  ) values (
    v_venue_id, v_user, p_starts_at, p_ends_at, p_kind,
    nullif(btrim(coalesce(p_reason, '')), '')
  ) returning id into v_leave_id;

  return jsonb_build_object('leave_id', v_leave_id, 'status', 'requested');
end;
$$;

revoke all on function public.operator_request_leave(
  text, timestamptz, timestamptz, text, text
) from public, anon;
grant execute on function public.operator_request_leave(
  text, timestamptz, timestamptz, text, text
) to authenticated;

-- Zurückziehen kann nur, wer beantragt hat, und nur solange noch niemand
-- entschieden hat. Eine genehmigte Abwesenheit zurückzunehmen ist eine
-- Entscheidung der Planung, kein Rückzug.
create or replace function public.operator_cancel_leave(
  p_venue_slug text,
  p_leave_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_leave public.staff_leaves%rowtype;
begin
  if v_user is null then
    raise exception 'leave_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'leave_unknown_venue: %', p_venue_slug;
  end if;

  select * into v_leave
  from public.staff_leaves
  where id = p_leave_id and venue_id = v_venue_id
  for update;
  if not found then
    raise exception 'leave_unknown';
  end if;
  if v_leave.user_id <> v_user then
    raise exception 'leave_not_yours: das ist nicht dein Antrag';
  end if;
  if v_leave.status <> 'requested' then
    raise exception 'leave_already_decided: darüber ist bereits entschieden';
  end if;

  update public.staff_leaves set status = 'cancelled' where id = p_leave_id;

  return jsonb_build_object('leave_id', p_leave_id, 'status', 'cancelled');
end;
$$;

revoke all on function public.operator_cancel_leave(text, uuid) from public, anon;
grant execute on function public.operator_cancel_leave(text, uuid) to authenticated;

-- ============================================================================
-- 5. Entscheiden
-- ============================================================================

-- Genehmigt wird **trotz** kollidierender Schichten — sie werden nur gemeldet.
-- Siehe den Kopf dieser Datei: eine Krankmeldung kommt nach dem Dienstplan.
create or replace function public.operator_review_leave(
  p_venue_slug text,
  p_leave_id uuid,
  p_approve boolean,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_leave public.staff_leaves%rowtype;
  v_conflicts jsonb;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  select * into v_leave
  from public.staff_leaves
  where id = p_leave_id and venue_id = v_venue_id
  for update;
  if not found then
    raise exception 'leave_unknown';
  end if;
  if v_leave.status <> 'requested' then
    raise exception 'leave_already_decided: darüber ist bereits entschieden';
  end if;

  if p_approve then
    begin
      update public.staff_leaves
      set status = 'approved',
          reviewed_by = v_user,
          reviewed_at = now(),
          review_note = nullif(btrim(coalesce(p_note, '')), '')
      where id = p_leave_id;
    exception
      when exclusion_violation then
        raise exception
          'leave_overlaps_approved: für diesen Zeitraum ist bereits etwas genehmigt';
    end;

    -- Die Schichten, die jetzt neu besetzt werden müssen. Sie werden **nicht**
    -- automatisch entfernt: wer sie streicht oder umbesetzt, entscheidet die
    -- Planung, nicht eine Migration.
    select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.starts_at), '[]'::jsonb)
      into v_conflicts
    from (
      select s.id, s.starts_at, s.ends_at, s.status, s.area, s.station
      from public.planned_shifts s
      where s.venue_id = v_venue_id
        and s.user_id = v_leave.user_id
        and s.status <> 'declined'
        and tstzrange(s.starts_at, s.ends_at, '[)')
            && tstzrange(v_leave.starts_at, v_leave.ends_at, '[)')
    ) t;
  else
    update public.staff_leaves
    set status = 'rejected',
        reviewed_by = v_user,
        reviewed_at = now(),
        review_note = nullif(btrim(coalesce(p_note, '')), '')
    where id = p_leave_id;
    v_conflicts := '[]'::jsonb;
  end if;

  return jsonb_build_object(
    'leave_id', p_leave_id,
    'status', case when p_approve then 'approved' else 'rejected' end,
    'conflicting_shifts', v_conflicts
  );
end;
$$;

revoke all on function public.operator_review_leave(
  text, uuid, boolean, text
) from public, anon;
grant execute on function public.operator_review_leave(
  text, uuid, boolean, text
) to authenticated;

-- ============================================================================
-- 6. Lesen
-- ============================================================================

create or replace function public.operator_my_leaves(
  p_venue_slug text,
  p_days_back int default 30
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
    raise exception 'leave_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'leave_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'leave_forbidden: kein Personal dieser Venue';
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.starts_at desc), '[]'::jsonb)
    into v_rows
  from (
    select l.id, l.starts_at, l.ends_at, l.kind, l.status, l.reason, l.review_note
    from public.staff_leaves l
    where l.venue_id = v_venue_id
      and l.user_id = v_user
      and l.ends_at >= now() - make_interval(
            days => least(greatest(coalesce(p_days_back, 30), 0), 365))
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_my_leaves(text, int) from public, anon;
grant execute on function public.operator_my_leaves(text, int) to authenticated;

-- Alle Abwesenheiten der Venue. Braucht `schedule.manage` — dasselbe Recht wie
-- die Planung, weil es dieselbe Aufgabe ist.
create or replace function public.operator_venue_leaves(
  p_venue_slug text,
  p_only_open boolean default false
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

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.starts_at), '[]'::jsonb)
    into v_rows
  from (
    select l.id, l.user_id, u.email, vr.name as role_name,
           l.starts_at, l.ends_at, l.kind, l.status, l.reason, l.review_note,
           -- Wie viele geplante Schichten dieser Zeitraum trifft. Bei einem
           -- offenen Antrag ist das die Zahl, die den Ausschlag gibt.
           (
             select count(*)
             from public.planned_shifts s
             where s.venue_id = l.venue_id
               and s.user_id = l.user_id
               and s.status <> 'declined'
               and tstzrange(s.starts_at, s.ends_at, '[)')
                   && tstzrange(l.starts_at, l.ends_at, '[)')
           ) as conflicting_shifts
    from public.staff_leaves l
    left join auth.users u on u.id = l.user_id
    left join public.venue_staff vs
      on vs.venue_id = l.venue_id and vs.user_id = l.user_id
    left join public.venue_roles vr
      on vr.venue_id = l.venue_id and vr.key = vs.role
    where l.venue_id = v_venue_id
      and (not coalesce(p_only_open, false) or l.status = 'requested')
      and l.ends_at >= now() - interval '30 days'
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_venue_leaves(text, boolean) from public, anon;
grant execute on function public.operator_venue_leaves(text, boolean) to authenticated;

-- ============================================================================
-- 7. Die Planung kennt die Abwesenheit
-- ============================================================================

-- Wortgleich mit `20260801140000_shift_schedule.sql`, ergänzt um **eine**
-- Prüfung: in eine genehmigte Abwesenheit wird nicht geplant.
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

  -- KL-LEAVE-001: die eine neue Prüfung.
  if public.kitchenlink_has_approved_leave(
       v_venue_id, p_user_id, p_starts_at, p_ends_at) then
    raise exception
      'plan_on_leave: diese Person hat in dem Zeitraum eine genehmigte Abwesenheit';
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

commit;
