-- KL-TIME-001: Zeiterfassung (Blueprint §9.3, Meilenstein 2).
--
-- Seit KL-WORKFORCE-001 liegt unter `kitchenlink/Features/Workforce/` eine
-- vollständige, getestete Domäne für Personal, Planung und Zeiterfassung — mit
-- **null Referenzen** aus der App. Ihr fehlten Persistenz und Oberfläche. Diese
-- Migration liefert die Persistenz für den ersten Teil davon: das Stempeln.
--
-- Blueprint §9 hält drei Fachobjekte ausdrücklich getrennt, und das bleibt so:
--
--   Betriebsschicht      `business_shifts` — „die Kasse ist offen" (KL-SHIFT-001)
--   geplante Schicht     noch nicht persistiert (§9.2, eigene Scheibe)
--   Zeiteintrag          `time_entries` — „diese Person hat gearbeitet"
--
-- Ein Zeiteintrag hängt deshalb **nicht** an einer Betriebsschicht. Wer um
-- 15 Uhr die Küche vorbereitet, arbeitet auch dann, wenn die Kasse noch zu ist.
--
-- Die tragenden Invarianten stehen wieder als Index in der Datenbank: **eine
-- Person kann nicht zweimal gleichzeitig eingestempelt sein**, und in einem
-- Eintrag läuft höchstens eine Pause. Sonst zählt am Monatsende niemand mehr
-- nach, was stimmt.

begin;

-- ============================================================================
-- 1. Tabellen
-- ============================================================================

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'open' check (status in ('open', 'closed')),

  -- Blueprint §9.3: „Korrektur mit Freigabe und Audit". Der ursprünglich
  -- gestempelte Wert bleibt stehen; eine Korrektur ergänzt ihn, sie ersetzt
  -- ihn nicht. Ein Zeitnachweis, der seine eigene Änderung verschweigt, ist
  -- wertlos.
  original_started_at timestamptz,
  original_ended_at timestamptz,
  corrected_by uuid,
  corrected_at timestamptz,
  correction_reason text,

  note text,
  created_at timestamptz not null default now(),

  constraint time_entries_closed_has_end check (
    status = 'open' or ended_at is not null
  ),
  -- `>=`, nicht `>`: wer sich vergreift und sofort wieder ausstempelt, erzeugt
  -- einen Eintrag ohne Dauer. Das ist ehrliche Datenlage — ihn mit einem rohen
  -- Constraint-Fehler abzuweisen waere schlechter, als ihn festzuhalten. Eine
  -- **Korrektur** von Hand verlangt dagegen weiterhin ein Ende nach dem
  -- Beginn: dort waere es ein Tippfehler.
  constraint time_entries_end_after_start check (
    ended_at is null or ended_at >= started_at
  )
);

-- Die eigentliche Zusage: niemand ist zweimal gleichzeitig auf der Uhr.
create unique index if not exists time_entries_one_open_per_user
  on public.time_entries(venue_id, user_id)
  where status = 'open';

create index if not exists time_entries_venue_idx
  on public.time_entries(venue_id, started_at desc);
create index if not exists time_entries_user_idx
  on public.time_entries(user_id, started_at desc);

create table if not exists public.time_breaks (
  id uuid primary key default gen_random_uuid(),
  time_entry_id uuid not null references public.time_entries(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  kind text not null default 'rest_break' check (kind in ('rest_break', 'meal_break')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  constraint time_breaks_end_after_start check (
    ended_at is null or ended_at >= started_at
  )
);

create unique index if not exists time_breaks_one_open_per_entry
  on public.time_breaks(time_entry_id)
  where ended_at is null;

create index if not exists time_breaks_entry_idx
  on public.time_breaks(time_entry_id, started_at);

-- ============================================================================
-- 2. Schutz
-- ============================================================================

alter table public.time_entries enable row level security;
alter table public.time_breaks enable row level security;

-- Die eigene Arbeitszeit darf jeder sehen; die der anderen nur, wer Personal
-- verwaltet. Kein Schreibweg für Clients: alles läuft über die RPCs unten.
drop policy if exists "time_entries_read" on public.time_entries;
create policy "time_entries_read" on public.time_entries
  for select
  to authenticated
  using (
    (user_id = auth.uid() and public.is_venue_staff(venue_id))
    or public.has_venue_permission(venue_id, 'staff.manage')
  );

drop policy if exists "time_breaks_read" on public.time_breaks;
create policy "time_breaks_read" on public.time_breaks
  for select
  to authenticated
  using (
    exists (
      select 1 from public.time_entries e
      where e.id = time_breaks.time_entry_id
        and (
          (e.user_id = auth.uid() and public.is_venue_staff(e.venue_id))
          or public.has_venue_permission(e.venue_id, 'staff.manage')
        )
    )
  );

-- ============================================================================
-- 3. Summen eines Eintrags
-- ============================================================================

-- Eine Quelle für Anzeige, Tagessumme und Korrektur. Pausen zählen **nicht**
-- als Arbeitszeit; eine noch laufende Pause wird bis jetzt gerechnet, damit
-- die Anzeige während der Pause nicht weiterläuft.
create or replace function public.kitchenlink_time_entry_seconds(p_entry_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with entry as (
    select * from public.time_entries where id = p_entry_id
  ),
  gross as (
    select extract(epoch from (coalesce(entry.ended_at, now()) - entry.started_at))::bigint as s
    from entry
  ),
  paused as (
    select coalesce(sum(
      extract(epoch from (
        least(coalesce(b.ended_at, now()), coalesce(entry.ended_at, now())) - b.started_at
      ))
    ), 0)::bigint as s
    from public.time_breaks b, entry
    where b.time_entry_id = p_entry_id
  )
  select jsonb_build_object(
    'gross_seconds', greatest(gross.s, 0),
    'break_seconds', greatest(paused.s, 0),
    'net_seconds', greatest(gross.s - paused.s, 0)
  )
  from gross, paused;
$$;

-- ============================================================================
-- 4. Stempeln
-- ============================================================================

-- Die eigene Zeit zu stempeln braucht **kein** besonderes Recht: es ist die
-- eigene Arbeitszeit, und die Küche muss sie erfassen können, ohne jemanden zu
-- fragen. Geprüft wird nur die Zugehörigkeit zur Venue.
create or replace function public.operator_clock_in(
  p_venue_slug text,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_entry_id uuid;
begin
  if v_user is null then
    raise exception 'time_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'time_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'time_forbidden: kein Personal dieser Venue';
  end if;

  begin
    insert into public.time_entries (venue_id, user_id, note)
    values (v_venue_id, v_user, nullif(btrim(coalesce(p_note, '')), ''))
    returning id into v_entry_id;
  exception
    when unique_violation then
      -- Zweimal auf denselben Knopf, oder ein zweites Gerät. Kein Fehler im
      -- Wortsinn, aber auch kein zweiter Eintrag.
      raise exception 'time_already_clocked_in: du bist bereits eingestempelt';
  end;

  return jsonb_build_object(
    'entry_id', v_entry_id,
    'started_at', now()
  );
end;
$$;

revoke all on function public.operator_clock_in(text, text) from public, anon;
grant execute on function public.operator_clock_in(text, text) to authenticated;

-- Ausstempeln beendet eine noch laufende Pause gleich mit. Die Alternative —
-- das Ausstempeln zu verweigern, bis die Pause beendet ist — würde am
-- Feierabend niemandem helfen und nur zu vergessenen Einträgen führen.
create or replace function public.operator_clock_out(
  p_venue_slug text,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_entry public.time_entries%rowtype;
  v_break_ended boolean := false;
begin
  if v_user is null then
    raise exception 'time_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'time_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'time_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_entry
  from public.time_entries
  where venue_id = v_venue_id and user_id = v_user and status = 'open'
  for update;
  if not found then
    raise exception 'time_not_clocked_in: du bist nicht eingestempelt';
  end if;

  update public.time_breaks
  set ended_at = now()
  where time_entry_id = v_entry.id and ended_at is null;
  v_break_ended := found;

  update public.time_entries
  set status = 'closed',
      ended_at = now(),
      note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), note)
  where id = v_entry.id;

  return jsonb_build_object(
    'entry_id', v_entry.id,
    'started_at', v_entry.started_at,
    'ended_at', now(),
    'break_ended_with_clock_out', v_break_ended,
    'totals', public.kitchenlink_time_entry_seconds(v_entry.id)
  );
end;
$$;

revoke all on function public.operator_clock_out(text, text) from public, anon;
grant execute on function public.operator_clock_out(text, text) to authenticated;

-- ============================================================================
-- 5. Pausen
-- ============================================================================

create or replace function public.operator_break_start(
  p_venue_slug text,
  p_kind text default 'rest_break'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_entry public.time_entries%rowtype;
  v_break_id uuid;
begin
  if v_user is null then
    raise exception 'time_unauthenticated: Anmeldung erforderlich';
  end if;
  if p_kind not in ('rest_break', 'meal_break') then
    raise exception 'time_invalid_break_kind: %', p_kind;
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'time_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'time_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_entry
  from public.time_entries
  where venue_id = v_venue_id and user_id = v_user and status = 'open';
  if not found then
    raise exception 'time_not_clocked_in: Pause ohne Einstempeln gibt es nicht';
  end if;

  begin
    insert into public.time_breaks (time_entry_id, venue_id, kind)
    values (v_entry.id, v_venue_id, p_kind)
    returning id into v_break_id;
  exception
    when unique_violation then
      raise exception 'time_break_already_running: die Pause läuft bereits';
  end;

  return jsonb_build_object('break_id', v_break_id, 'started_at', now(), 'kind', p_kind);
end;
$$;

revoke all on function public.operator_break_start(text, text) from public, anon;
grant execute on function public.operator_break_start(text, text) to authenticated;

create or replace function public.operator_break_end(p_venue_slug text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_entry public.time_entries%rowtype;
  v_break public.time_breaks%rowtype;
begin
  if v_user is null then
    raise exception 'time_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'time_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'time_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_entry
  from public.time_entries
  where venue_id = v_venue_id and user_id = v_user and status = 'open';
  if not found then
    raise exception 'time_not_clocked_in: du bist nicht eingestempelt';
  end if;

  select * into v_break
  from public.time_breaks
  where time_entry_id = v_entry.id and ended_at is null
  for update;
  if not found then
    raise exception 'time_no_open_break: es läuft keine Pause';
  end if;

  update public.time_breaks set ended_at = now() where id = v_break.id;

  return jsonb_build_object(
    'break_id', v_break.id,
    'started_at', v_break.started_at,
    'ended_at', now(),
    'totals', public.kitchenlink_time_entry_seconds(v_entry.id)
  );
end;
$$;

revoke all on function public.operator_break_end(text) from public, anon;
grant execute on function public.operator_break_end(text) to authenticated;

-- ============================================================================
-- 6. Eigener Stand
-- ============================================================================

create or replace function public.operator_my_time_status(p_venue_slug text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_entry public.time_entries%rowtype;
  v_break public.time_breaks%rowtype;
  v_today jsonb;
  v_net bigint;
begin
  if v_user is null then
    raise exception 'time_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'time_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'time_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_entry
  from public.time_entries
  where venue_id = v_venue_id and user_id = v_user and status = 'open';

  if v_entry.id is not null then
    select * into v_break
    from public.time_breaks
    where time_entry_id = v_entry.id and ended_at is null;
  end if;

  -- Die Einträge des laufenden Tages, in der Zeitzone der Venue: ein
  -- Nachtdienst gehört zu dem Tag, an dem er begonnen hat.
  select
    coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.started_at desc), '[]'::jsonb),
    coalesce(sum((t.totals ->> 'net_seconds')::bigint), 0)
    into v_today, v_net
  from (
    select e.id, e.started_at, e.ended_at, e.status,
           e.corrected_at is not null as corrected,
           public.kitchenlink_time_entry_seconds(e.id) as totals
    from public.time_entries e
    join public.venues v on v.id = e.venue_id
    where e.venue_id = v_venue_id
      and e.user_id = v_user
      and (e.started_at at time zone coalesce(v.timezone, 'Europe/Berlin'))::date
          = (now() at time zone coalesce(v.timezone, 'Europe/Berlin'))::date
  ) t;

  return jsonb_build_object(
    'clocked_in', v_entry.id is not null,
    'entry_id', v_entry.id,
    'started_at', v_entry.started_at,
    'on_break', v_break.id is not null,
    'break_started_at', v_break.started_at,
    'current', case
      when v_entry.id is null then null
      else public.kitchenlink_time_entry_seconds(v_entry.id)
    end,
    'today_net_seconds', v_net,
    'today', v_today
  );
end;
$$;

revoke all on function public.operator_my_time_status(text) from public, anon;
grant execute on function public.operator_my_time_status(text) to authenticated;

-- ============================================================================
-- 7. Team-Stand
-- ============================================================================

-- Wer gerade auf der Uhr steht, und die Einträge des Tages. Braucht
-- `staff.manage` — bewusst **kein** eigenes Recht: die Arbeitszeiten anderer
-- Leute zu sehen gehört zur Personalverwaltung, und ein Recht, das nur an
-- einer Stelle wirkt, wäre eine Zeile mehr in jeder Rollenliste ohne Gewinn.
create or replace function public.operator_team_time(
  p_venue_slug text,
  p_days_back int default 0
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
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.started_at desc), '[]'::jsonb)
    into v_rows
  from (
    select e.id,
           e.user_id,
           u.email,
           vs.role,
           vr.name as role_name,
           e.started_at,
           e.ended_at,
           e.status,
           e.corrected_at is not null as corrected,
           e.correction_reason,
           public.kitchenlink_time_entry_seconds(e.id) as totals,
           exists (
             select 1 from public.time_breaks b
             where b.time_entry_id = e.id and b.ended_at is null
           ) as on_break
    from public.time_entries e
    join public.venues v on v.id = e.venue_id
    left join auth.users u on u.id = e.user_id
    left join public.venue_staff vs on vs.venue_id = e.venue_id and vs.user_id = e.user_id
    left join public.venue_roles vr on vr.venue_id = e.venue_id and vr.key = vs.role
    where e.venue_id = v_venue_id
      and (e.started_at at time zone coalesce(v.timezone, 'Europe/Berlin'))::date
          >= (now() at time zone coalesce(v.timezone, 'Europe/Berlin'))::date
             - least(greatest(coalesce(p_days_back, 0), 0), 90)
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_team_time(text, int) from public, anon;
grant execute on function public.operator_team_time(text, int) to authenticated;

-- ============================================================================
-- 8. Korrektur
-- ============================================================================

-- Der Alltagsfall, für den es eine Korrektur überhaupt braucht: jemand hat das
-- Ausstempeln vergessen und der Eintrag läuft seit gestern. Ohne diesen Weg
-- bliebe er für immer offen — und die Person könnte sich nie wieder
-- einstempeln, weil der Index genau das verhindert.
--
-- Blueprint §9.3 verlangt „Korrektur mit Freigabe und Audit": das Recht
-- `staff.manage` ist die Freigabe, die erhaltenen Originalwerte sind das Audit.
create or replace function public.operator_correct_time_entry(
  p_venue_slug text,
  p_entry_id uuid,
  p_reason text,
  p_started_at timestamptz default null,
  p_ended_at timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_entry public.time_entries%rowtype;
  v_new_start timestamptz;
  v_new_end timestamptz;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'time_correction_needs_reason: eine Korrektur ohne Grund ist keine';
  end if;

  select * into v_entry
  from public.time_entries
  where id = p_entry_id and venue_id = v_venue_id
  for update;
  if not found then
    raise exception 'time_unknown_entry';
  end if;

  v_new_start := coalesce(p_started_at, v_entry.started_at);
  v_new_end := coalesce(p_ended_at, v_entry.ended_at);

  if v_new_end is null then
    raise exception 'time_correction_needs_end: ein korrigierter Eintrag braucht ein Ende';
  end if;
  if v_new_end <= v_new_start then
    raise exception 'time_correction_invalid_range: das Ende liegt vor dem Beginn';
  end if;

  -- Eine noch laufende Pause dieses Eintrags wird mitgeschlossen, sonst bliebe
  -- sie ewig offen und der Nettowert liefe weiter.
  update public.time_breaks
  set ended_at = least(coalesce(ended_at, v_new_end), v_new_end)
  where time_entry_id = v_entry.id and ended_at is null;

  update public.time_entries
  set started_at = v_new_start,
      ended_at = v_new_end,
      status = 'closed',
      -- Nur beim ersten Mal setzen: sonst überschriebe eine zweite Korrektur
      -- den echten Originalwert und das Audit wäre wertlos.
      original_started_at = coalesce(original_started_at, v_entry.started_at),
      original_ended_at = coalesce(original_ended_at, v_entry.ended_at),
      corrected_by = v_user,
      corrected_at = now(),
      correction_reason = btrim(p_reason)
  where id = v_entry.id;

  return jsonb_build_object(
    'entry_id', v_entry.id,
    'started_at', v_new_start,
    'ended_at', v_new_end,
    'original_started_at', coalesce(v_entry.original_started_at, v_entry.started_at),
    'original_ended_at', coalesce(v_entry.original_ended_at, v_entry.ended_at),
    'totals', public.kitchenlink_time_entry_seconds(v_entry.id)
  );
end;
$$;

revoke all on function public.operator_correct_time_entry(
  text, uuid, text, timestamptz, timestamptz
) from public, anon;
grant execute on function public.operator_correct_time_entry(
  text, uuid, text, timestamptz, timestamptz
) to authenticated;

commit;
