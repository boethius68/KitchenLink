-- KL-STAFFING-001: Sollbesetzung und Unterbesetzungswarnung
-- (Blueprint §9.2, Meilenstein 2).
--
-- Der Dienstplan (KL-PLAN-001) zeigt, **wer** eingeteilt ist. Die Frage, die
-- eine Planende beim Blick auf die Woche tatsächlich hat, beantwortet er
-- nicht: **reicht das?**
--
-- Der Bedarf ist ein **Wochenmuster**, kein Einzelwert je Tag — so ist er im
-- Betrieb auch gedacht: „freitags und samstags abends drei im Service". Ein
-- Muster je Wochentag mit Zeitfenster und optionaler Station bildet das ab,
-- ohne dass jemand jede Woche dasselbe neu einträgt.
--
-- **Unterbesetzung ist eine Warnung, keine Sperre.** Eine Woche lässt sich auch
-- unterbesetzt veröffentlichen — manchmal ist schlicht niemand da, und ein
-- Dienstplan, den man nicht herausgeben kann, hilft niemandem. Die Zahl steht
-- daneben, die Entscheidung bleibt bei der Planung. Das ist dieselbe Haltung
-- wie beim Kassenabschluss mit offenen Rechnungen (KL-SHIFT-001).
--
-- Die Abdeckung wird **in der Datenbank** gerechnet, nicht in der App: nur sie
-- kennt den Plan, den alle Geräte teilen, und nur sie kann das Zeitfenster
-- korrekt in der Zeitzone der Venue auflösen — inklusive Sommerzeit.

begin;

-- ============================================================================
-- 1. Tabelle
-- ============================================================================

create table if not exists public.staffing_requirements (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,

  -- 1 = Montag … 7 = Sonntag (ISO 8601, wie `extract(isodow ...)`).
  weekday int not null check (weekday between 1 and 7),
  -- Ortszeit ohne Datum. Der konkrete Zeitpunkt entsteht erst beim Auflösen
  -- auf einen Tag, in der Zeitzone der Venue.
  starts_at_local time not null,
  ends_at_local time not null,

  -- Dieselben Werte wie `planned_shifts.station`. Ohne Station zählt jede
  -- Schicht im Fenster mit — „drei Leute abends", egal wo.
  station text check (station is null or station in ('kitchen', 'bar')),
  area text,

  target_headcount int not null check (target_headcount > 0),
  active boolean not null default true,

  note text,
  created_by uuid,
  created_at timestamptz not null default now(),

  -- Ein Fenster, das um Mitternacht endet, wird als 24:00 gedacht; ein
  -- Nachtdienst über Mitternacht ist ein eigenes Muster am Folgetag.
  constraint staffing_requirements_end_after_start check (
    ends_at_local > starts_at_local
  )
);

create index if not exists staffing_requirements_venue_idx
  on public.staffing_requirements(venue_id, weekday, starts_at_local);

alter table public.staffing_requirements enable row level security;

-- Den Bedarf zu **sehen** ist für das Personal kein Eingriff — im Gegenteil,
-- es erklärt, warum eine Woche eng ist. Ändern darf ihn die Planung.
drop policy if exists "staffing_requirements_read" on public.staffing_requirements;
create policy "staffing_requirements_read" on public.staffing_requirements
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. Pflegen
-- ============================================================================

create or replace function public.operator_upsert_staffing_requirement(
  p_venue_slug text,
  p_weekday int,
  p_starts_at_local time,
  p_ends_at_local time,
  p_target_headcount int,
  p_station text default null,
  p_area text default null,
  p_note text default null,
  p_requirement_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_id uuid;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'staffing_invalid_weekday: 1 (Montag) bis 7 (Sonntag)';
  end if;
  if p_starts_at_local is null or p_ends_at_local is null
     or p_ends_at_local <= p_starts_at_local then
    raise exception 'staffing_invalid_window: das Ende muss nach dem Beginn liegen';
  end if;
  if p_target_headcount is null or p_target_headcount < 1 then
    raise exception 'staffing_invalid_headcount: mindestens eine Person';
  end if;
  if p_station is not null and p_station not in ('kitchen', 'bar') then
    raise exception 'staffing_invalid_station: %', p_station;
  end if;

  if p_requirement_id is null then
    insert into public.staffing_requirements (
      venue_id, weekday, starts_at_local, ends_at_local,
      station, area, target_headcount, note, created_by
    ) values (
      v_venue_id, p_weekday, p_starts_at_local, p_ends_at_local,
      p_station, nullif(btrim(coalesce(p_area, '')), ''),
      p_target_headcount, nullif(btrim(coalesce(p_note, '')), ''), v_user
    ) returning id into v_id;
  else
    update public.staffing_requirements
    set weekday = p_weekday,
        starts_at_local = p_starts_at_local,
        ends_at_local = p_ends_at_local,
        station = p_station,
        area = nullif(btrim(coalesce(p_area, '')), ''),
        target_headcount = p_target_headcount,
        note = nullif(btrim(coalesce(p_note, '')), '')
    where id = p_requirement_id and venue_id = v_venue_id
    returning id into v_id;
    if v_id is null then
      raise exception 'staffing_unknown_requirement';
    end if;
  end if;

  return jsonb_build_object('requirement_id', v_id);
end;
$$;

revoke all on function public.operator_upsert_staffing_requirement(
  text, int, time, time, int, text, text, text, uuid
) from public, anon;
grant execute on function public.operator_upsert_staffing_requirement(
  text, int, time, time, int, text, text, text, uuid
) to authenticated;

create or replace function public.operator_delete_staffing_requirement(
  p_venue_slug text,
  p_requirement_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'schedule.manage');

  delete from public.staffing_requirements
  where id = p_requirement_id and venue_id = v_venue_id;
  if not found then
    raise exception 'staffing_unknown_requirement';
  end if;

  return jsonb_build_object('requirement_id', p_requirement_id, 'deleted', true);
end;
$$;

revoke all on function public.operator_delete_staffing_requirement(text, uuid)
  from public, anon;
grant execute on function public.operator_delete_staffing_requirement(text, uuid)
  to authenticated;

create or replace function public.operator_staffing_requirements(p_venue_slug text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'staffing_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'staffing_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'staffing_forbidden: kein Personal dieser Venue';
  end if;

  select coalesce(
      jsonb_agg(row_to_json(t)::jsonb order by t.weekday, t.starts_at_local),
      '[]'::jsonb)
    into v_rows
  from (
    select id, weekday, starts_at_local::text, ends_at_local::text,
           station, area, target_headcount, note, active
    from public.staffing_requirements
    where venue_id = v_venue_id and active
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_staffing_requirements(text) from public, anon;
grant execute on function public.operator_staffing_requirements(text) to authenticated;

-- ============================================================================
-- 3. Abdeckung
-- ============================================================================

-- Für jeden Tag im Zeitraum und jedes Muster dieses Wochentags: wie viele
-- Personen sind eingeteilt, und wie viele fehlen.
--
-- Das Zeitfenster wird **in der Zeitzone der Venue** auf den konkreten Tag
-- aufgelöst. `(datum + zeit) at time zone tz` rechnet dabei die Sommerzeit
-- korrekt mit — dieselbe Regel, die `WorkforceShiftTemplate.resolvedRange`
-- in der Swift-Domäne seit KL-WORKFORCE-001 anwendet.
--
-- Gezählt werden **Personen**, nicht Schichten: wer zweimal am selben Abend
-- eingeteilt wäre, könnte den Bedarf nicht doppelt decken. (Der
-- Ausschluss-Constraint aus KL-PLAN-001 verhindert das ohnehin; die
-- `count(distinct)` sagt trotzdem, was gemeint ist.)
create or replace function public.operator_staffing_coverage(
  p_venue_slug text,
  p_from date,
  p_to date
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_tz text;
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'staffing_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id, coalesce(v.timezone, 'Europe/Berlin') into v_venue_id, v_tz
  from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'staffing_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'staffing_forbidden: kein Personal dieser Venue';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'staffing_invalid_range';
  end if;
  if p_to - p_from > 62 then
    raise exception 'staffing_range_too_long: höchstens 62 Tage';
  end if;

  -- `generate_series` mit `date`-Argumenten liefert **timestamptz**. Auf einem
  -- timestamptz dreht `at time zone` die Richtung um: es rechnet *aus* der Zone
  -- heraus statt in sie hinein, und das Fenster verrutscht an den beiden
  -- Zeitumstellungen um eine Stunde. Deshalb ausdrücklich über `timestamp`:
  -- `(datum::date + ortszeit)` ist ein Zeitstempel **ohne** Zone, und erst
  -- `at time zone` macht daraus den richtigen absoluten Zeitpunkt.
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.day, t.starts_at), '[]'::jsonb)
    into v_rows
  from (
    select
      d.day::date::text as day,
      r.id as requirement_id,
      r.station,
      r.area,
      r.target_headcount,
      ((d.day::date + r.starts_at_local) at time zone v_tz) as starts_at,
      ((d.day::date + r.ends_at_local) at time zone v_tz) as ends_at,
      (
        select count(distinct s.user_id)
        from public.planned_shifts s
        where s.venue_id = v_venue_id
          and s.status <> 'declined'
          and (r.station is null or s.station = r.station)
          and tstzrange(s.starts_at, s.ends_at, '[)')
              && tstzrange(
                   (d.day::date + r.starts_at_local) at time zone v_tz,
                   (d.day::date + r.ends_at_local) at time zone v_tz,
                   '[)')
      )::int as planned_headcount
    from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') as d(day)
    join public.staffing_requirements r
      on r.venue_id = v_venue_id
     and r.active
     and r.weekday = extract(isodow from d.day)::int
  ) t;

  -- Die Fehlzahl wird erst hier gebildet, damit sie nie negativ wird:
  -- Überbesetzung ist keine Unterbesetzung mit umgekehrtem Vorzeichen.
  select coalesce(jsonb_agg(
      row || jsonb_build_object(
        'missing', greatest(
          (row ->> 'target_headcount')::int - (row ->> 'planned_headcount')::int, 0)
      )
    ), '[]'::jsonb)
    into v_rows
  from jsonb_array_elements(v_rows) as row;

  return v_rows;
end;
$$;

revoke all on function public.operator_staffing_coverage(text, date, date)
  from public, anon;
grant execute on function public.operator_staffing_coverage(text, date, date)
  to authenticated;

commit;
