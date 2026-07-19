-- KL-CLOUD-001: Betreiberseite der Cloud-Bestellschleife.
--
-- Additive Migration. Bisher konnte nur der Gast selbst seine Bestellung lesen
-- (orders_owner_read); es gab keine Betreiber-Identität, keinen Lesepfad für
-- Personal und keinen Status-Schreibpfad. Diese Migration ergänzt:
--
--   1. venue_staff: Zuordnung authentifizierter Nutzer zu einer Venue.
--      Schreibzugriff nur über Service Role / SQL-Editor (keine Policies);
--      das Sandbox-Setup legt genau einen Operator an (SANDBOX_SETUP.md).
--   2. Staff-Lese-Policies auf orders/order_items (zusätzlich zu den
--      bestehenden Owner-Policies, die unverändert bleiben).
--   3. operator_update_order_status: einziger Status-Schreibpfad für
--      Betreiber, SECURITY DEFINER mit Staff-Prüfung, idempotent bei
--      Wiederholungen und verspäteten Retries (Spiegel der lokalen
--      Hub-Semantik aus KL-OFFLINE-005).
--   4. venue_hub_presence: Heartbeat des Service-Geräts plus zuletzt
--      bekannte lokale Gast-URL. Öffentlich lesbar, damit das Gast-Web
--      einen offline gegangenen Betrieb erkennt und Gäste auf die lokale
--      Bestellseite verweist (Blueprint §16.2-Ergänzung: sichtbarer
--      Verbindungsstatus). Schreiben nur über RPC mit Staff-Prüfung.
--
-- Kein Löschen, kein Ändern bestehender Policies oder Funktionen.

begin;

-- ============================================================================
-- 1. venue_staff
-- ============================================================================

create table if not exists public.venue_staff (
  user_id uuid not null,
  venue_id uuid not null references public.venues(id) on delete cascade,
  role text not null default 'operator' check (role in ('operator')),
  created_at timestamptz not null default now(),
  primary key (user_id, venue_id)
);

create index if not exists venue_staff_venue_id_idx on public.venue_staff(venue_id);

alter table public.venue_staff enable row level security;

-- Mitglieder sehen nur die eigene Mitgliedschaft. Anlegen/Entfernen läuft
-- ausschließlich über Service Role (kein INSERT/UPDATE/DELETE für Clients).
drop policy if exists "venue_staff_self_read" on public.venue_staff;
create policy "venue_staff_self_read" on public.venue_staff
  for select to authenticated using (user_id = auth.uid());

-- SECURITY DEFINER, damit Policies auf orders/order_items die Mitgliedschaft
-- prüfen können, ohne an der RLS von venue_staff selbst zu scheitern.
create or replace function public.is_venue_staff(p_venue_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.venue_staff vs
    where vs.user_id = auth.uid()
      and vs.venue_id = p_venue_id
  );
$$;

revoke all on function public.is_venue_staff(uuid) from public, anon;
grant execute on function public.is_venue_staff(uuid) to authenticated;

-- ============================================================================
-- 2. Staff-Lese-Policies (zusätzlich zu den Owner-Policies)
-- ============================================================================

drop policy if exists "orders_staff_read" on public.orders;
create policy "orders_staff_read" on public.orders
  for select to authenticated
  using (venue_id is not null and public.is_venue_staff(venue_id));

drop policy if exists "order_items_staff_read" on public.order_items;
create policy "order_items_staff_read" on public.order_items
  for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and o.venue_id is not null
        and public.is_venue_staff(o.venue_id)
    )
  );

-- ============================================================================
-- 3. Status-RPC: operator_update_order_status
-- ============================================================================
-- Semantik (Spiegel des lokalen Hubs, KL-OFFLINE-005):
--   - Ziel == aktueller Status            -> Replay (kein Fehler).
--   - Vorwärtsschritt in der Kette
--     pending -> accepted -> preparing -> ready -> served
--     (auch über mehrere Stufen, z. B. pending -> ready:
--     die Küche arbeitet mit einem einzigen Bump-Button)  -> Update.
--   - Rückwärts gerichteter, verspäteter Retry            -> Replay mit dem
--     tatsächlichen aktuellen Status (kein falscher Konflikt).
--   - canceled: erlaubt solange nicht served; canceled -> canceled ist Replay.
--   - served -> canceled und jede Änderung ab canceled    -> Fehler.

create or replace function public.operator_update_order_status(
  p_order_id uuid,
  p_target_status text
) returns table (
  order_id uuid,
  status text,
  replayed boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_order record;
  v_current_rank int;
  v_target_rank int;
begin
  if v_user is null then
    raise exception 'operator_unauthenticated: Anmeldung erforderlich';
  end if;

  if p_target_status is null
     or p_target_status not in ('accepted', 'preparing', 'ready', 'served', 'canceled') then
    raise exception 'operator_invalid_status: %', coalesce(p_target_status, '<null>');
  end if;

  select o.id, o.venue_id, o.status
    into v_order
  from public.orders o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception 'operator_unknown_order: %', p_order_id;
  end if;

  if v_order.venue_id is null or not public.is_venue_staff(v_order.venue_id) then
    raise exception 'operator_forbidden: kein Personal dieser Venue';
  end if;

  -- Replay: Ziel bereits erreicht.
  if v_order.status = p_target_status then
    return query select v_order.id, v_order.status, true;
    return;
  end if;

  if v_order.status = 'canceled' then
    raise exception 'operator_invalid_transition: canceled -> %', p_target_status;
  end if;

  if p_target_status = 'canceled' then
    if v_order.status = 'served' then
      raise exception 'operator_invalid_transition: served -> canceled';
    end if;
    update public.orders o
      set status = 'canceled', canceled_at = now()
      where o.id = v_order.id;
    return query select v_order.id, 'canceled'::text, false;
    return;
  end if;

  v_current_rank := case v_order.status
    when 'pending' then 0
    when 'accepted' then 1
    when 'preparing' then 2
    when 'ready' then 3
    when 'served' then 4
  end;
  v_target_rank := case p_target_status
    when 'accepted' then 1
    when 'preparing' then 2
    when 'ready' then 3
    when 'served' then 4
  end;

  -- Verspäteter Retry eines früheren Schritts: die Bestellung ist schon
  -- weiter. Kein Fehler, sondern der tatsächliche Zustand als Replay.
  if v_target_rank < v_current_rank then
    return query select v_order.id, v_order.status, true;
    return;
  end if;

  update public.orders o
    set status = p_target_status,
        accepted_at  = case when p_target_status = 'accepted'  then now() else o.accepted_at  end,
        preparing_at = case when p_target_status = 'preparing' then now() else o.preparing_at end,
        ready_at     = case when p_target_status = 'ready'     then now() else o.ready_at     end,
        served_at    = case when p_target_status = 'served'    then now() else o.served_at    end
    where o.id = v_order.id;

  return query select v_order.id, p_target_status, false;
  return;
end;
$$;

revoke all on function public.operator_update_order_status(uuid, text) from public, anon;
grant execute on function public.operator_update_order_status(uuid, text) to authenticated;

-- ============================================================================
-- 4. venue_hub_presence: Heartbeat + lokale Gast-URL
-- ============================================================================
-- Genau eine Zeile pro Venue. Bedeutung für das Gast-Web (hub-presence.ts):
--   - updated_at frisch                         -> Service-Gerät online,
--     normale Cloud-Bestellung.
--   - updated_at veraltet UND local_guest_url   -> Gerät hat die Verbindung
--     verloren, läuft aber vermutlich lokal weiter: Gäste im Restaurant-WLAN
--     werden auf die lokale Bestellseite verwiesen.
--   - keine Zeile oder keine local_guest_url    -> keine Aussage; die
--     Cloud-Bestellung bleibt aktiv (heutiges Verhalten).
-- Die lokale URL ist nur im Restaurant-WLAN erreichbar; ihre Veröffentlichung
-- gibt keinen Zugriff von außen frei.

create table if not exists public.venue_hub_presence (
  venue_id uuid primary key references public.venues(id) on delete cascade,
  device_id text not null default '',
  local_guest_url text,
  updated_at timestamptz not null default now()
);

alter table public.venue_hub_presence enable row level security;

drop policy if exists "venue_hub_presence_public_read" on public.venue_hub_presence;
create policy "venue_hub_presence_public_read" on public.venue_hub_presence
  for select to anon, authenticated using (true);

-- Schreiben nur über die RPC (Staff-Prüfung). Keine direkten Write-Policies.
create or replace function public.operator_upsert_hub_presence(
  p_venue_slug text,
  p_device_id text,
  p_local_guest_url text default null
) returns table (
  venue_id uuid,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
begin
  if v_user is null then
    raise exception 'operator_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'operator_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'operator_forbidden: kein Personal dieser Venue';
  end if;

  insert into public.venue_hub_presence as vhp (venue_id, device_id, local_guest_url, updated_at)
  values (v_venue_id, coalesce(p_device_id, ''), p_local_guest_url, now())
  on conflict (venue_id) do update
    set device_id = excluded.device_id,
        local_guest_url = excluded.local_guest_url,
        updated_at = excluded.updated_at;

  return query select v_venue_id, now()::timestamptz;
end;
$$;

revoke all on function public.operator_upsert_hub_presence(text, text, text) from public, anon;
grant execute on function public.operator_upsert_hub_presence(text, text, text) to authenticated;

commit;
