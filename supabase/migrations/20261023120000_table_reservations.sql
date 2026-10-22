-- KL-RES-001: Tischreservierung (Blueprint §10, Meilenstein 3).
--
-- Ermöglicht Online-Reservierungen durch Gäste im Gast-Web sowie die Einsicht
-- und Zuweisung von Tischen durch das Servicepersonal.
--
-- 1. Tabelle `table_reservations` mit RLS (Staff-Leserecht, kein direktes Client-Schreiben).
-- 2. SECURITY DEFINER RPC `guest_web_create_reservation` für Gast-Web-Buchungen.
-- 3. Staff-RPC `operator_list_reservations` für den Tages- und Schichtbetrieb.
-- 4. Staff-RPC `operator_update_reservation_status` zur Zuweisung und Statusänderung.

begin;

-- ============================================================================
-- 1. Tabelle anlegen und absichern
-- ============================================================================

create table if not exists public.table_reservations (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  reference_code text not null,
  guest_name text not null,
  guest_email text not null,
  guest_phone text,
  party_size int not null check (party_size > 0 and party_size <= 50),
  reservation_date date not null,
  reservation_time time not null,
  area text not null default '',
  special_requests text,
  status text not null default 'confirmed'
    check (status in ('pending', 'confirmed', 'seated', 'completed', 'cancelled', 'no_show')),
  table_id uuid references public.tables(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists table_reservations_venue_date_idx
  on public.table_reservations(venue_id, reservation_date, reservation_time);

create unique index if not exists table_reservations_ref_idx
  on public.table_reservations(reference_code);

alter table public.table_reservations enable row level security;

drop policy if exists "table_reservations_staff_read" on public.table_reservations;
create policy "table_reservations_staff_read" on public.table_reservations
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. Gast-Web RPC: Tisch online reservieren
-- ============================================================================

create or replace function public.guest_web_create_reservation(
  p_venue_slug text,
  p_guest_name text,
  p_guest_email text,
  p_guest_phone text default null,
  p_party_size int default 2,
  p_reservation_date date default current_date,
  p_reservation_time time default '18:30:00'::time,
  p_area text default '',
  p_special_requests text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venue_id uuid;
  v_venue_name text;
  v_reservation_id uuid;
  v_ref_code text;
  v_clean_name text;
  v_clean_email text;
begin
  -- Validierung
  v_clean_name := trim(p_guest_name);
  v_clean_email := lower(trim(p_guest_email));

  if length(v_clean_name) < 2 then
    return jsonb_build_object('ok', false, 'error', 'Name muss mindestens 2 Zeichen lang sein');
  end if;

  if position('@' in v_clean_email) = 0 then
    return jsonb_build_object('ok', false, 'error', 'Ungültige E-Mail-Adresse');
  end if;

  if p_party_size < 1 or p_party_size > 50 then
    return jsonb_build_object('ok', false, 'error', 'Personenanzahl muss zwischen 1 und 50 liegen');
  end if;

  -- Lokal ermitteln
  select id, name into v_venue_id, v_venue_name
  from public.venues
  where slug = p_venue_slug;

  if v_venue_id is null then
    return jsonb_build_object('ok', false, 'error', 'Lokal nicht gefunden');
  end if;

  -- 6-stelligen Referenzcode generieren (z. B. KL-928412)
  v_ref_code := 'KL-' || lpad((floor(random() * 900000) + 100000)::text, 6, '0');

  insert into public.table_reservations (
    venue_id,
    reference_code,
    guest_name,
    guest_email,
    guest_phone,
    party_size,
    reservation_date,
    reservation_time,
    area,
    special_requests,
    status
  ) values (
    v_venue_id,
    v_ref_code,
    v_clean_name,
    v_clean_email,
    nullif(trim(p_guest_phone), ''),
    p_party_size,
    p_reservation_date,
    p_reservation_time,
    coalesce(trim(p_area), ''),
    nullif(trim(p_special_requests), ''),
    'confirmed'
  )
  returning id into v_reservation_id;

  return jsonb_build_object(
    'ok', true,
    'reservation_id', v_reservation_id,
    'reference_code', v_ref_code,
    'venue_name', v_venue_name,
    'guest_name', v_clean_name,
    'party_size', p_party_size,
    'reservation_date', p_reservation_date,
    'reservation_time', p_reservation_time::text,
    'status', 'confirmed'
  );
end;
$$;

grant execute on function public.guest_web_create_reservation to anon, authenticated;

-- ============================================================================
-- 3. Betreiber RPC: Reservierungen abrufen
-- ============================================================================

create or replace function public.operator_list_reservations(
  p_venue_id uuid,
  p_date date default null
)
returns table (
  id uuid,
  reference_code text,
  guest_name text,
  guest_email text,
  guest_phone text,
  party_size int,
  reservation_date date,
  reservation_time text,
  area text,
  special_requests text,
  status text,
  table_id uuid,
  table_label text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    r.id,
    r.reference_code,
    r.guest_name,
    r.guest_email,
    r.guest_phone,
    r.party_size,
    r.reservation_date,
    to_char(r.reservation_time, 'HH24:MI') as reservation_time,
    r.area,
    r.special_requests,
    r.status,
    r.table_id,
    t.label as table_label,
    r.created_at
  from public.table_reservations r
  left join public.tables t on t.id = r.table_id
  where r.venue_id = p_venue_id
    and (p_date is null or r.reservation_date = p_date)
    and public.is_venue_staff(p_venue_id)
  order by r.reservation_date asc, r.reservation_time asc;
$$;

grant execute on function public.operator_list_reservations to authenticated;

-- ============================================================================
-- 4. Betreiber RPC: Status und Tischzuweisung aktualisieren
-- ============================================================================

create or replace function public.operator_update_reservation_status(
  p_venue_id uuid,
  p_reservation_id uuid,
  p_status text,
  p_table_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_venue_staff(p_venue_id) then
    return jsonb_build_object('ok', false, 'error', 'Keine Berechtigung');
  end if;

  update public.table_reservations
  set
    status = p_status,
    table_id = coalesce(p_table_id, table_id)
  where id = p_reservation_id
    and venue_id = p_venue_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Reservierung nicht gefunden');
  end if;

  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

grant execute on function public.operator_update_reservation_status to authenticated;

commit;
