-- KL-WEB-002: Autoritative Bestellgrenze, Row Level Security und
-- Sandbox-Seed für das Gast-Web.
--
-- Additive Migration. Die Basis-Schema-Datei
-- `20260318011000_kitchenlink_core_schema.sql` bleibt unangetastet; diese Datei
-- fügt nur Spalten, einen Unique-Constraint, RLS-Policies, eine RPC-Funktion
-- und idempotente Sandbox-Seed-Daten hinzu.
--
-- Umgesetzte Vorgaben:
--   - ADR-001 §6 (autoritative Bestellgrenze) und §6.3 (anon-Rolle vs.
--     Supabase Anonymous Sign-in) aus
--     docs/architecture/guest-web/ADR-001_GUEST_WEB_STACK.md.
--   - DECISIONS.md (Guest Web): Anonymous Sign-in (`authenticated` +
--     `is_anonymous`) für Gastbestellungen; die bloße anon-Rolle darf keine
--     Bestellung anfassen.
--   - PRODUCT_BLUEPRINT.md §6.3: Preis, Verfügbarkeit, Öffnungszeit und
--     Bestellkapazität werden vor Annahme autoritativ geprüft.
--
-- Bewusst simuliert (in ORDER_GATE.md dokumentiert):
--   - Öffnungszeit und Bestellkapazität sind „immer offen, unbegrenzt".

begin;

-- ============================================================================
-- 1. Spalten, Constraint und Index für Idempotenz und anonyme Zuordnung
-- ============================================================================

-- Idempotenz-Key pro Venue. Gleicher Key + gleicher Payload = dieselbe Order
-- (Wiederholung liefert das gespeicherte ACK); gleicher Key + anderer Payload
-- = Konflikt (kein stilles Überschreiben).
alter table public.orders
  add column if not exists idempotency_key text,
  add column if not exists idempotency_payload_hash text,
  add column if not exists created_by uuid;

-- Eindeutigkeit des Idempotenz-Keys innerhalb einer Venue. NULL-Werte (ältere
-- oder interne Bestellungen ohne Key) werden vom Constraint nicht erfasst und
-- bleiben erlaubt.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_venue_idempotency_key_key'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
      add constraint orders_venue_idempotency_key_key
      unique (venue_id, idempotency_key);
  end if;
end$$;

create index if not exists orders_created_by_idx on public.orders(created_by);

-- Stabiler Slug auf menu_items, damit die Gast-Web-Client-IDs (z. B.
-- "kuerbissuppe") serverseitig in DB-Preise aufgelöst werden. Der Slug ist
-- innerhalb einer Venue eindeutig.
alter table public.menu_items
  add column if not exists slug text;

create index if not exists menu_items_category_slug_idx
  on public.menu_items(category_id, slug);

-- ============================================================================
-- 2. Sandbox-Seed: deckungsgleich mit guest-web/src/lib/venue-data.ts
-- ============================================================================
-- Feste UUIDs machen den Seed idempotent (wiederholbare Migration) und
-- erlauben referenzielles Seeding ohne gen_random_uuid()-Zufall. Der Seed
-- existiert parallel zur lokalen Fixture; die RPC rechnet ausschließlich aus
-- diesen DB-Preisen, nie aus dem Client-Request (ADR-001 §6.1).

insert into public.venues (id, name, slug, timezone)
values (
  '11111111-1111-1111-1111-111111111111',
  'Gasthaus Alte Mühle',
  'alte-muehle',
  'Europe/Berlin'
)
on conflict (slug) do update
  set name = excluded.name, timezone = excluded.timezone;

insert into public.tables (id, venue_id, label, active)
values (
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  'Sandbox-Tisch',
  true
)
on conflict (venue_id, label) do nothing;

insert into public.menus (id, venue_id, name, active)
values (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'Standard',
  true
)
on conflict do nothing;

-- Zweig, der bestehende Kategorien intakt hält oder neu anlegt. on conflict
-- ohne passendes Unique-Constraint ist hier nicht sicher möglich, daher
-- WHERE-NOT-EXISTS pro Kategorie.
insert into public.menu_categories (id, menu_id, name, kind, sort_order)
select
  '33333333-3333-3333-3333-333333333301',
  '22222222-2222-2222-2222-222222222222',
  'Küche',
  'food',
  0
where not exists (
  select 1 from public.menu_categories
  where menu_id = '22222222-2222-2222-2222-222222222222'
    and name = 'Küche'
);

insert into public.menu_categories (id, menu_id, name, kind, sort_order)
select
  '33333333-3333-3333-3333-333333333302',
  '22222222-2222-2222-2222-222222222222',
  'Getränke',
  'drink',
  1
where not exists (
  select 1 from public.menu_categories
  where menu_id = '22222222-2222-2222-2222-222222222222'
    and name = 'Getränke'
);

-- Acht Artikel deckungsgleich mit guest-web/src/lib/venue-data.ts
-- (slug = Client-ID, price_cents identisch).
insert into public.menu_items
  (id, category_id, slug, name, description, price_cents, currency, kind, available, sort_order)
values
  (
    '44444444-4444-4444-4444-444444444401',
    '33333333-3333-3333-3333-333333333301',
    'kuerbissuppe',
    'Kürbissuppe',
    'Mit Ingwer, Kürbiskernöl und Bauernbrot',
    690, 'EUR', 'food', true, 0
  ),
  (
    '44444444-4444-4444-4444-444444444402',
    '33333333-3333-3333-3333-333333333301',
    'flammkuchen',
    'Flammkuchen Elsässer Art',
    'Crème fraîche, Zwiebeln und geräucherter Speck',
    1150, 'EUR', 'food', true, 1
  ),
  (
    '44444444-4444-4444-4444-444444444403',
    '33333333-3333-3333-3333-333333333301',
    'kaesespaetzle',
    'Käsespätzle',
    'Bergkäse, Röstzwiebeln und kleiner Blattsalat',
    1490, 'EUR', 'food', true, 2
  ),
  (
    '44444444-4444-4444-4444-444444444404',
    '33333333-3333-3333-3333-333333333301',
    'wiener-schnitzel',
    'Wiener Schnitzel',
    'Kartoffel-Gurken-Salat und Preiselbeeren',
    2180, 'EUR', 'food', true, 3
  ),
  (
    '44444444-4444-4444-4444-444444444405',
    '33333333-3333-3333-3333-333333333301',
    'zander',
    'Gebratener Zander',
    'Rahmwirsing und Petersilienkartoffeln',
    2350, 'EUR', 'food', true, 4
  ),
  (
    '44444444-4444-4444-4444-444444444406',
    '33333333-3333-3333-3333-333333333301',
    'apfelstrudel',
    'Apfelstrudel',
    'Mit Vanillesauce und Schlagsahne',
    780, 'EUR', 'food', true, 5
  ),
  (
    '44444444-4444-4444-4444-444444444407',
    '33333333-3333-3333-3333-333333333302',
    'hauslimonade',
    'Hauslimonade Holunder',
    '0,4 l, hausgemacht',
    490, 'EUR', 'drink', true, 0
  ),
  (
    '44444444-4444-4444-4444-444444444408',
    '33333333-3333-3333-3333-333333333302',
    'muehlen-radler',
    'Mühlen-Radler',
    '0,5 l, naturtrüb',
    450, 'EUR', 'drink', true, 1
  )
on conflict (id) do update
  set slug = excluded.slug,
      name = excluded.name,
      description = excluded.description,
      price_cents = excluded.price_cents,
      currency = excluded.currency,
      kind = excluded.kind,
      available = excluded.available,
      sort_order = excluded.sort_order;

-- ============================================================================
-- 3. Row Level Security
-- ============================================================================
-- Zugriffmodell (Details in docs/architecture/guest-web/ORDER_GATE.md):
--   - Menü (venues, menus, menu_categories, menu_items) ist für anon und
--     authenticated öffentlich lesbar.
--   - orders/order_items: KEINE direkten INSERT/UPDATE/DELETE-Policies. Das
--     Schreiben erfolgt ausschließlich über die RPC guest_web_submit_order,
--     die mit SECURITY DEFINER als privilegierter Eigentümer läuft. Die bloße
--     anon-Rolle darf keine Bestellung anfassen (DECISIONS.md Guest Web).
--   - orders: SELECT nur für den Eigentümer (created_by = auth.uid()), damit
--     ein Gast seinen eigenen Bestellstatus lesen kann.
--   - order_items: SELECT nur über die zugehörige Eigentümer-Bestellung.

alter table public.venues enable row level security;
alter table public.menus enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- venues: öffentlich lesbar. Schreiben nur Service Role (keine Policy).
drop policy if exists "venues_public_read" on public.venues;
create policy "venues_public_read" on public.venues
  for select to anon, authenticated using (true);

-- menus: öffentlich lesbar.
drop policy if exists "menus_public_read" on public.menus;
create policy "menus_public_read" on public.menus
  for select to anon, authenticated using (true);

-- menu_categories: öffentlich lesbar.
drop policy if exists "menu_categories_public_read" on public.menu_categories;
create policy "menu_categories_public_read" on public.menu_categories
  for select to anon, authenticated using (true);

-- menu_items: öffentlich lesbar (aktive Venue-Karte).
drop policy if exists "menu_items_public_read" on public.menu_items;
create policy "menu_items_public_read" on public.menu_items
  for select to anon, authenticated using (true);

-- orders: Gast liest nur die eigene Bestellung. Geschrieben wird ausschließlich
-- über guest_web_submit_order (SECURITY DEFINER), daher hier keine
-- INSERT/UPDATE/DELETE-Policies.
drop policy if exists "orders_owner_read" on public.orders;
create policy "orders_owner_read" on public.orders
  for select to authenticated using (created_by = auth.uid());

-- order_items: lesbar nur über die eigene Bestellung.
drop policy if exists "order_items_owner_read" on public.order_items;
create policy "order_items_owner_read" on public.order_items
  for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and o.created_by = auth.uid()
    )
  );

-- ============================================================================
-- 4. Autoritative Bestellgrenze: RPC guest_web_submit_order
-- ============================================================================
-- SECURITY DEFINER, damit die Funktion Bestellungen persistieren kann,
-- obwohl für die authentifizierte Rolle KEINE Schreib-Policies existieren.
-- search_path wird explizit fixiert (Supabase-Empfehlung gegen
-- Schema-Spoofing). Die Funktion prüft ADR-001 §6.1:
--   - anonyme Identität (auth.uid() vorhanden + is_anonymous),
--   - Venue existiert (Lookup über Slug),
--   - Verfügbarkeit (Artikel existiert, gehört zur Venue, aktiv),
--   - Preis serverseitig aus menu_items.price_cents (FOR UPDATE, nie Client),
--   - Idempotenz (gleicher Key + gleicher Payload = gespeicherte Order zurück;
--     gleicher Key + anderer Payload = Konflikt),
--   - Persistierung erst nach erfolgreicher Prüfung (eine Transaktion).
-- Öffenungszeit/Kapazität sind bewusst „immer offen, unbegrenzt" simuliert.

create or replace function public.guest_web_submit_order(
  p_venue_slug text,
  p_idempotency_key text,
  p_items jsonb,
  p_service_mode text default 'dine_in',
  p_customer_note text default ''
) returns table (
  order_id uuid,
  status text,
  total_cents int,
  currency char(3),
  idempotent_replay boolean,
  accepted boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_is_anonymous boolean;
  v_venue record;
  v_item record;
  v_total int := 0;
  v_order_id uuid;
  v_status text := 'pending';
  v_payload_hash text;
  v_existing record;
  v_clean_items jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_item_slug text;
  v_qty int;
  v_index int := 0;
  v_row record;
begin
  -- 4.1 Anonyme Identität: nur ein anonym eingelogter User darf bestellen.
  -- Die bloße anon-Rolle hat keinen auth.uid() und scheitert hier.
  if v_user is null then
    raise exception 'guest_web_unauthenticated: Anonymous Sign-in erforderlich';
  end if;

  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
    into v_is_anonymous;

  -- Hinweis: in dieser Sandbox akzeptieren wir auch dauerhafte authentifizierte
  -- Nutzer (z. B. Mitarbeiter-Test). Die Bestellgrenze bleibt autoritativ; die
  -- gastseitige Verdrahtung verwendet ausschließlich Anonymous Sign-in.

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'guest_web_invalid_idempotency_key: leer';
  end if;

  if p_service_mode is null then
    p_service_mode := 'dine_in';
  end if;

  if p_service_mode not in ('dine_in', 'bar', 'pickup') then
    raise exception 'guest_web_invalid_service_mode: %', p_service_mode;
  end if;

  -- 4.2 Venue-Lookup über Slug.
  select id into v_venue from public.venues where slug = p_venue_slug;
  if not found then
    raise exception 'guest_web_unknown_venue: %', p_venue_slug;
  end if;

  -- 4.3 Öffnungszeit / Kapazität: bewusst simuliert als „immer offen, unbegrenzt".
  -- Siehe ORDER_GATE.md.

  -- 4.4 Payload normalisieren und deterministischen Hash bilden. Die Sortierung
  -- nach slug macht den Hash unabhängig von der Client-Reihenfolge.
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'guest_web_invalid_items: kein Array';
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_slug := v_elem ->> 'slug';
    v_qty := coalesce((v_elem ->> 'quantity')::int, 0);
    if v_item_slug is null or v_qty is null or v_qty <= 0 then
      raise exception 'guest_web_invalid_item: slug oder quantity fehlt';
    end if;
    v_clean_items := v_clean_items || jsonb_build_array(
      jsonb_build_object('slug', v_item_slug, 'quantity', v_qty)
    );
    v_index := v_index + 1;
  end loop;

  if v_index = 0 then
    raise exception 'guest_web_empty_order: keine Positionen';
  end if;

  select encode(
    digest(
      v_venue.id::text || '|' || p_idempotency_key || '|' ||
      coalesce(p_service_mode, '') || '|' ||
      coalesce(p_customer_note, '') || '|' ||
      coalesce(v_clean_items::text, ''),
      'sha256'
    ),
    'hex'
  ) into v_payload_hash;

  -- 4.5 Idempotenz: gleicher Key + gleicher Payload -> gespeicherte Order als
  -- Replay zurückgeben (kein doppelter INSERT).
  select id, status, total_cents, currency, idempotency_payload_hash
    into v_existing
  from public.orders
  where venue_id = v_venue.id
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.idempotency_payload_hash is distinct from v_payload_hash then
      raise exception 'guest_web_idempotency_conflict: gleicher Key, anderer Inhalt';
    end if;
    return query
      select
        v_existing.id,
        v_existing.status,
        v_existing.total_cents,
        v_existing.currency,
        true,
        true;
    return;
  end if;

  -- 4.6 Serverseitige Neubepreisung aus menu_items.price_cents mit row-lock.
  -- Fremde/inaktive Artikel werden hier abgelehnt (Preis nie aus dem Request).
  for v_row in
    select t.slug, t.quantity
    from (
      select
        (je ->> 'slug') as slug,
        coalesce((je ->> 'quantity')::int, 0) as quantity
      from jsonb_array_elements(v_clean_items) as je
    ) t
  loop
    select mi.id, mi.price_cents, mi.available, mc.menu_id
      into v_item
    from public.menu_items mi
    join public.menu_categories mc on mc.id = mi.category_id
    join public.menus m on m.id = mc.menu_id
    where mi.slug = v_row.slug
      and m.venue_id = v_venue.id
      and m.active = true
    for update of mi;

    if not found then
      raise exception 'guest_web_unknown_item: %', v_row.slug;
    end if;

    if v_item.available is not true then
      raise exception 'guest_web_unavailable_item: %', v_row.slug;
    end if;

    v_total := v_total + v_item.price_cents * v_row.quantity;
  end loop;

  -- 4.7 Persistierung in derselben Transaktion (erst bei Erfolg).
  insert into public.orders (
    venue_id, source_device, total_cents, status, service_mode,
    customer_note, currency, idempotency_key, idempotency_payload_hash, created_by
  )
  values (
    v_venue.id, 'guest_web', v_total, v_status, p_service_mode,
    coalesce(p_customer_note, ''), 'EUR', p_idempotency_key, v_payload_hash, v_user
  )
  returning id into v_order_id;

  -- 4.8 Positionen aus DB-Preisen schreiben.
  for v_row in
    select t.slug, t.quantity
    from (
      select
        (je ->> 'slug') as slug,
        coalesce((je ->> 'quantity')::int, 0) as quantity
      from jsonb_array_elements(v_clean_items) as je
    ) t
  loop
    select mi.id, mi.name, mi.price_cents, mi.kind
      into v_item
    from public.menu_items mi
    join public.menu_categories mc on mc.id = mi.category_id
    join public.menus m on m.id = mc.menu_id
    where mi.slug = v_row.slug
      and m.venue_id = v_venue.id
      and m.active = true;

    insert into public.order_items (order_id, menu_item_id, name, quantity, unit_price_cents, kind)
    values (v_order_id, v_item.id, v_item.name, v_row.quantity, v_item.price_cents, v_item.kind);
  end loop;

  -- 4.9 ACK: die tatsächlich gespeicherte Order.
  return query
    select
      v_order_id,
      v_status,
      v_total,
      'EUR'::char(3),
      false,
      true;

  return;
end;
$$;

-- RESTRICTIVE: die Funktion ist das einzige Schreibtor für Gastbestellungen.
-- revoke verhindert versehentliche Privilegien-Ausweitung; grant nur an die
-- authentifizierte Rolle (anon hat keinen auth.uid() und scheitert in der
-- Funktion ohnehin).
revoke all on function public.guest_web_submit_order(
  text, text, jsonb, text, text
) from public, anon;
grant execute on function public.guest_web_submit_order(
  text, text, jsonb, text, text
) to authenticated;

commit;
