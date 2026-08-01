-- KL-STATION-001: Produktionsstationen (Blueprint §7, Meilenstein 1.9).
--
-- Bisher landete jede Position in einer Liste: der Barkeeper sah Schnitzel, die
-- Küche sah Bier. Blueprint §7 verlangt „Positionen werden automatisch nach
-- Produktionsstation getrennt" und „Service sieht, welche Station noch
-- arbeitet". Genau das ergänzt diese Migration.
--
-- Die Station wird aus `order_items.kind` abgeleitet — Speisen in die Küche,
-- Getränke an die Bar. Das ist bewusst noch keine frei konfigurierbare
-- Stationsverwaltung (Pass, Grill, Dessert); die Spalte trägt den Wert
-- ausdrücklich, damit eine spätere Zuordnung je Artikel nichts umbauen muss.
--
-- Der Bestellstatus bleibt, was er war: `ready` heißt weiterhin „fertig für den
-- Kellner". Neu ist nur, **wann** er das wird — wenn jede beteiligte Station
-- ihre Positionen freigegeben hat.

begin;

-- ============================================================================
-- 1. Station je Position
-- ============================================================================

alter table public.order_items
  add column if not exists station text
    check (station in ('kitchen', 'bar')),
  add column if not exists ready_at timestamptz;

-- Bestandspositionen und alles, was ohne Station eingefügt wird, bekommen sie
-- aus `kind`. Ein Trigger statt eines Defaults, weil der Wert von einer anderen
-- Spalte derselben Zeile abhängt.
create or replace function public.kitchenlink_order_item_station()
returns trigger
language plpgsql
as $$
begin
  if new.station is null then
    new.station := case when new.kind = 'drink' then 'bar' else 'kitchen' end;
  end if;
  return new;
end;
$$;

drop trigger if exists order_items_station_default on public.order_items;
create trigger order_items_station_default
  before insert or update on public.order_items
  for each row execute function public.kitchenlink_order_item_station();

update public.order_items
set station = case when kind = 'drink' then 'bar' else 'kitchen' end
where station is null;

create index if not exists order_items_station_idx
  on public.order_items(order_id, station);

-- ============================================================================
-- 2. Station meldet fertig
-- ============================================================================

-- Gibt die Positionen **einer** Station frei. Erst wenn keine Position mehr
-- offen ist, wandert die Bestellung auf `ready` — vorher wäre sie für den
-- Kellner nicht wirklich fertig.
--
-- Idempotent wie der bestehende Statuspfad: ein zweiter Tap derselben Station
-- ist kein Fehler und ändert nichts.
create or replace function public.operator_mark_station_ready(
  p_venue_slug text,
  p_order_id uuid,
  p_station text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_order record;
  v_open_stations text[];
  v_touched int;
begin
  if v_user is null then
    raise exception 'station_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'station_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'station_forbidden: kein Personal dieser Venue';
  end if;
  if p_station not in ('kitchen', 'bar') then
    raise exception 'station_invalid: %', p_station;
  end if;

  select o.* into v_order
  from public.orders o
  where o.id = p_order_id and o.venue_id = v_venue_id;
  if not found then
    raise exception 'station_unknown_order';
  end if;
  if v_order.status in ('served', 'canceled') then
    raise exception 'station_order_closed: Bestellung ist bereits abgeschlossen';
  end if;

  update public.order_items
  set ready_at = now()
  where order_id = p_order_id
    and station = p_station
    and ready_at is null;
  get diagnostics v_touched = row_count;

  select coalesce(array_agg(distinct oi.station), '{}')
    into v_open_stations
  from public.order_items oi
  where oi.order_id = p_order_id and oi.ready_at is null;

  -- Alle Stationen fertig: die Bestellung ist für den Kellner bereit. Der
  -- Statuswechsel bleibt vorwärtsgerichtet wie in `operator_update_order_status`.
  if array_length(v_open_stations, 1) is null then
    update public.orders
    set status = 'ready',
        ready_at = coalesce(ready_at, now()),
        accepted_at = coalesce(accepted_at, now()),
        preparing_at = coalesce(preparing_at, now())
    where id = p_order_id and status in ('pending', 'accepted', 'preparing');
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'station', p_station,
    'items_marked', v_touched,
    'open_stations', coalesce(to_jsonb(v_open_stations), '[]'::jsonb),
    'order_ready', array_length(v_open_stations, 1) is null
  );
end;
$$;

revoke all on function public.operator_mark_station_ready(text, uuid, text)
  from public, anon;
grant execute on function public.operator_mark_station_ready(text, uuid, text)
  to authenticated;

commit;
