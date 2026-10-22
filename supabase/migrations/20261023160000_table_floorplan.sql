-- KL-TABLE-003: Grafischer Tischplan, Raumstatus & Tisch-Transfer (Blueprint §10).
--
-- Erweitert Tische um Koordinaten, Sitzplätze und Raumform.
-- Stellt RPCs bereit für:
-- 1. `operator_get_floorplan_status`: Tischübersicht mit Session-Status, Umsatz und Reservierungen.
-- 2. `operator_transfer_table_session`: Tisch umsetzen (Gäste von Tisch A nach B verlegen).
-- 3. `operator_merge_tables`: Zwei Tische zusammenlegen.

begin;

-- ============================================================================
-- 1. Tische um Geometrie & Sitzplätze erweitern
-- ============================================================================

alter table public.tables
  add column if not exists seats int not null default 4 check (seats > 0 and seats <= 100),
  add column if not exists shape text not null default 'square' check (shape in ('round', 'square', 'rectangle')),
  add column if not exists pos_x int not null default 0,
  add column if not exists pos_y int not null default 0;

-- ============================================================================
-- 2. Betreiber RPC: Tischplan mit aktuellem Belegungsstatus abrufen
-- ============================================================================

create or replace function public.operator_get_floorplan_status(
  p_venue_id uuid
)
returns table (
  table_id uuid,
  label text,
  area text,
  sort_order int,
  active boolean,
  seats int,
  shape text,
  pos_x int,
  pos_y int,
  token text,
  session_id uuid,
  session_started_at timestamptz,
  order_count int,
  total_cents int,
  reservation_time text,
  reservation_guest_name text,
  reservation_party_size int
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  return query
  with active_tokens as (
    select distinct on (q.table_id)
      q.table_id,
      q.token
    from public.qr_tokens q
    where q.venue_id = p_venue_id
      and q.active
      and q.mode = 'table'
    order by q.table_id, q.created_at desc
  ),
  open_sessions as (
    select
      s.id as session_id,
      s.table_id,
      s.created_at as session_started_at,
      count(o.id)::int as order_count,
      coalesce(sum(o.total_cents), 0)::int as total_cents
    from public.table_sessions s
    left join public.orders o on o.table_session_id = s.id and o.status not in ('cancelled', 'rejected')
    where s.venue_id = p_venue_id
      and s.status = 'open'
    group by s.id, s.table_id, s.created_at
  ),
  today_reservations as (
    select distinct on (r.table_id)
      r.table_id,
      to_char(r.reservation_time, 'HH24:MI') as reservation_time,
      r.guest_name as reservation_guest_name,
      r.party_size as reservation_party_size
    from public.table_reservations r
    where r.venue_id = p_venue_id
      and r.reservation_date = current_date
      and r.status = 'confirmed'
      and r.table_id is not null
    order by r.table_id, r.reservation_time asc
  )
  select
    t.id as table_id,
    t.label,
    t.area,
    t.sort_order,
    t.active,
    t.seats,
    t.shape,
    t.pos_x,
    t.pos_y,
    tok.token,
    os.session_id,
    os.session_started_at,
    coalesce(os.order_count, 0) as order_count,
    coalesce(os.total_cents, 0) as total_cents,
    res.reservation_time,
    res.reservation_guest_name,
    res.reservation_party_size
  from public.tables t
  left join active_tokens tok on tok.table_id = t.id
  left join open_sessions os on os.table_id = t.id
  left join today_reservations res on res.table_id = t.id
  where t.venue_id = p_venue_id
  order by t.sort_order asc, t.label asc;
end;
$$;

grant execute on function public.operator_get_floorplan_status to authenticated;

-- ============================================================================
-- 3. Betreiber RPC: Tisch umsetzen (Gäste von Tisch A auf Tisch B verlegen)
-- ============================================================================

create or replace function public.operator_transfer_table_session(
  p_venue_id uuid,
  p_source_table_id uuid,
  p_target_table_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_session_id uuid;
  v_target_has_open boolean;
begin
  if not public.is_venue_staff(p_venue_id) then
    return jsonb_build_object('ok', false, 'error', 'Keine Berechtigung');
  end if;

  if p_source_table_id = p_target_table_id then
    return jsonb_build_object('ok', false, 'error', 'Quell- und Zieltisch dürfen nicht identisch sein');
  end if;

  -- Offene Session des Quelltischs suchen
  select id into v_source_session_id
  from public.table_sessions
  where venue_id = p_venue_id
    and table_id = p_source_table_id
    and status = 'open';

  if v_source_session_id is null then
    return jsonb_build_object('ok', false, 'error', 'Quelltisch hat keine aktive Sitzung');
  end if;

  -- Prüfen ob Zieltisch bereits eine offene Session hat
  select exists (
    select 1 from public.table_sessions
    where venue_id = p_venue_id
      and table_id = p_target_table_id
      and status = 'open'
  ) into v_target_has_open;

  if v_target_has_open then
    return jsonb_build_object('ok', false, 'error', 'Zieltisch ist bereits belegt (bitte Zusammenlegen verwenden)');
  end if;

  -- Session auf Zieltisch verschieben
  update public.table_sessions
  set table_id = p_target_table_id
  where id = v_source_session_id;

  -- Bestellungen der Session ebenfalls auf Zieltisch aktualisieren
  update public.orders
  set table_id = p_target_table_id
  where table_session_id = v_source_session_id;

  return jsonb_build_object(
    'ok', true,
    'session_id', v_source_session_id,
    'source_table_id', p_source_table_id,
    'target_table_id', p_target_table_id
  );
end;
$$;

grant execute on function public.operator_transfer_table_session to authenticated;

-- ============================================================================
-- 4. Betreiber RPC: Tische zusammenlegen
-- ============================================================================

create or replace function public.operator_merge_tables(
  p_venue_id uuid,
  p_source_table_id uuid,
  p_target_table_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_session_id uuid;
  v_target_session_id uuid;
begin
  if not public.is_venue_staff(p_venue_id) then
    return jsonb_build_object('ok', false, 'error', 'Keine Berechtigung');
  end if;

  select id into v_source_session_id
  from public.table_sessions
  where venue_id = p_venue_id
    and table_id = p_source_table_id
    and status = 'open';

  select id into v_target_session_id
  from public.table_sessions
  where venue_id = p_venue_id
    and table_id = p_target_table_id
    and status = 'open';

  if v_source_session_id is null or v_target_session_id is null then
    return jsonb_build_object('ok', false, 'error', 'Beide Tische müssen eine aktive Sitzung haben');
  end if;

  -- Bestellungen der Quell-Session in Ziel-Session überführen
  update public.orders
  set
    table_id = p_target_table_id,
    table_session_id = v_target_session_id
  where table_session_id = v_source_session_id;

  -- Quell-Session schließen (als merged)
  update public.table_sessions
  set status = 'closed'
  where id = v_source_session_id;

  return jsonb_build_object(
    'ok', true,
    'target_session_id', v_target_session_id,
    'closed_source_session_id', v_source_session_id
  );
end;
$$;

grant execute on function public.operator_merge_tables to authenticated;

commit;
