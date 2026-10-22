-- KL-RES-002: Warteliste und Walk-ins (Blueprint §10, Meilenstein 3).
--
-- Wenn Gäste spontan eintreffen und kein Tisch sofort frei ist, werden sie
-- auf der Warteliste mit Personenanzahl, geschätzter Wartezeit und Mobilnummer
-- erfasst. Sobald ein Tisch frei wird, erfolgt die Zuweisung und Platzierung.

begin;

-- ============================================================================
-- 1. Tabelle anlegen und absichern
-- ============================================================================

create table if not exists public.table_waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  guest_name text not null,
  guest_phone text,
  party_size int not null check (party_size > 0 and party_size <= 50),
  area text not null default '',
  estimated_wait_minutes int not null default 15,
  notes text,
  status text not null default 'waiting'
    check (status in ('waiting', 'notified', 'seated', 'cancelled')),
  table_id uuid references public.tables(id) on delete set null,
  created_at timestamptz not null default now(),
  seated_at timestamptz
);

create index if not exists table_waitlist_venue_status_idx
  on public.table_waitlist_entries(venue_id, status, created_at);

alter table public.table_waitlist_entries enable row level security;

drop policy if exists "table_waitlist_staff_all" on public.table_waitlist_entries;
create policy "table_waitlist_staff_all" on public.table_waitlist_entries
  for all
  to authenticated
  using (public.is_venue_staff(venue_id))
  with check (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. Betreiber RPC: Walk-in auf Warteliste setzen
-- ============================================================================

create or replace function public.operator_add_waitlist_entry(
  p_venue_id uuid,
  p_guest_name text,
  p_party_size int,
  p_guest_phone text default null,
  p_area text default '',
  p_estimated_wait_minutes int default 15,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_id uuid;
  v_clean_name text;
begin
  if not public.is_venue_staff(p_venue_id) then
    return jsonb_build_object('ok', false, 'error', 'Keine Berechtigung');
  end if;

  v_clean_name := trim(p_guest_name);
  if length(v_clean_name) < 2 then
    return jsonb_build_object('ok', false, 'error', 'Name muss mindestens 2 Zeichen lang sein');
  end if;

  if p_party_size < 1 or p_party_size > 50 then
    return jsonb_build_object('ok', false, 'error', 'Personenanzahl muss zwischen 1 und 50 liegen');
  end if;

  insert into public.table_waitlist_entries (
    venue_id,
    guest_name,
    party_size,
    guest_phone,
    area,
    estimated_wait_minutes,
    notes,
    status
  ) values (
    p_venue_id,
    v_clean_name,
    p_party_size,
    nullif(trim(p_guest_phone), ''),
    coalesce(trim(p_area), ''),
    greatest(5, p_estimated_wait_minutes),
    nullif(trim(p_notes), ''),
    'waiting'
  )
  returning id into v_entry_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_entry_id,
    'guest_name', v_clean_name,
    'party_size', p_party_size,
    'status', 'waiting'
  );
end;
$$;

grant execute on function public.operator_add_waitlist_entry to authenticated;

-- ============================================================================
-- 3. Betreiber RPC: Aktive Warteliste abrufen
-- ============================================================================

create or replace function public.operator_list_waitlist(
  p_venue_id uuid
)
returns table (
  id uuid,
  guest_name text,
  guest_phone text,
  party_size int,
  area text,
  estimated_wait_minutes int,
  notes text,
  status text,
  table_id uuid,
  table_label text,
  created_at timestamptz,
  seated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    w.id,
    w.guest_name,
    w.guest_phone,
    w.party_size,
    w.area,
    w.estimated_wait_minutes,
    w.notes,
    w.status,
    w.table_id,
    t.label as table_label,
    w.created_at,
    w.seated_at
  from public.table_waitlist_entries w
  left join public.tables t on t.id = w.table_id
  where w.venue_id = p_venue_id
    and w.status in ('waiting', 'notified')
    and public.is_venue_staff(p_venue_id)
  order by w.created_at asc;
$$;

grant execute on function public.operator_list_waitlist to authenticated;

-- ============================================================================
-- 4. Betreiber RPC: Wartelisten-Status aktualisieren (Benachrichtigen, Platzieren)
-- ============================================================================

create or replace function public.operator_update_waitlist_status(
  p_venue_id uuid,
  p_entry_id uuid,
  p_status text,
  p_table_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seated_at timestamptz := null;
begin
  if not public.is_venue_staff(p_venue_id) then
    return jsonb_build_object('ok', false, 'error', 'Keine Berechtigung');
  end if;

  if p_status not in ('waiting', 'notified', 'seated', 'cancelled') then
    return jsonb_build_object('ok', false, 'error', 'Ungültiger Status');
  end if;

  if p_status = 'seated' then
    v_seated_at := now();
  end if;

  update public.table_waitlist_entries
  set
    status = p_status,
    table_id = coalesce(p_table_id, table_id),
    seated_at = coalesce(v_seated_at, seated_at)
  where id = p_entry_id
    and venue_id = p_venue_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Wartelisten-Eintrag nicht gefunden');
  end if;

  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

grant execute on function public.operator_update_waitlist_status to authenticated;

commit;
