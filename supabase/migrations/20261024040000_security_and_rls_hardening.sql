-- KL-SEC-001: RLS-Härtung, Rollentrennung & Zugriffssicherheit (Blueprint §21 Meilenstein 7).
--
-- Erzwingt Row-Level-Security auf allen operativen Tabellen, verhindert
-- direkte Tabellenzugriffe durch unauthentifizierte Rollen (anon) und
-- bindet Datenzugriffe zwingend an die zugehörige venue_id.

begin;

-- 1. Row Level Security auf allen operativen Kern- und Erweiterungstabellen aktivieren

alter table if exists public.venues enable row level security;
alter table if exists public.tables enable row level security;
alter table if exists public.table_floorplans enable row level security;
alter table if exists public.table_reservations enable row level security;
alter table if exists public.waitlist_entries enable row level security;
alter table if exists public.delivery_areas enable row level security;

alter table if exists public.inventory_stock_locations enable row level security;
alter table if exists public.inventory_ingredients enable row level security;
alter table if exists public.inventory_recipes enable row level security;
alter table if exists public.inventory_recipe_components enable row level security;
alter table if exists public.inventory_suppliers enable row level security;
alter table if exists public.inventory_purchase_orders enable row level security;
alter table if exists public.inventory_purchase_order_lines enable row level security;
alter table if exists public.inventory_stock_movements enable row level security;

alter table if exists public.customer_profiles enable row level security;
alter table if exists public.vouchers enable row level security;
alter table if exists public.order_feedbacks enable row level security;

alter table if exists public.cashbook_entries enable row level security;
alter table if exists public.tse_transactions enable row level security;

-- 2. Rechtebeschränkung für unauthentifizierte Gäste (anon)
-- Gäste dürfen interne Tabellen niemals direkt lesen oder manipulieren.
-- Sämtliche Aktionen laufen zwingend über validierende security definer RPCs.

revoke all on table public.cashbook_entries from anon;
revoke all on table public.tse_transactions from anon;
revoke all on table public.inventory_stock_movements from anon;
revoke all on table public.inventory_purchase_orders from anon;
revoke all on table public.inventory_purchase_order_lines from anon;
revoke all on table public.inventory_suppliers from anon;
revoke all mod on table public.inventory_ingredients from anon;
revoke all on table public.delivery_areas from anon;
revoke all on table public.customer_profiles from anon;
revoke all on table public.table_floorplans from anon;

-- 3. Mandanten-Policies (Organisation / Venue Isolation)

drop policy if exists cashbook_venue_isolation on public.cashbook_entries;
create policy cashbook_venue_isolation on public.cashbook_entries
  for all to authenticated
  using (
    venue_id is null or
    exists (
      select 1 from public.venue_memberships m
      where m.venue_id = cashbook_entries.venue_id
        and m.user_id = auth.uid()
        and m.active = true
    )
  );

drop policy if exists tse_venue_isolation on public.tse_transactions;
create policy tse_venue_isolation on public.tse_transactions
  for all to authenticated
  using (
    venue_id is null or
    exists (
      select 1 from public.venue_memberships m
      where m.venue_id = tse_transactions.venue_id
        and m.user_id = auth.uid()
        and m.active = true
    )
  );

drop policy if exists inventory_movements_venue_isolation on public.inventory_stock_movements;
create policy inventory_movements_venue_isolation on public.inventory_stock_movements
  for all to authenticated
  using (
    venue_id is null or
    exists (
      select 1 from public.venue_memberships m
      where m.venue_id = inventory_stock_movements.venue_id
        and m.user_id = auth.uid()
        and m.active = true
    )
  );

drop policy if exists customer_profiles_venue_isolation on public.customer_profiles;
create policy customer_profiles_venue_isolation on public.customer_profiles
  for all to authenticated
  using (
    venue_id is null or
    exists (
      select 1 from public.venue_memberships m
      where m.venue_id = customer_profiles.venue_id
        and m.user_id = auth.uid()
        and m.active = true
    )
  );

-- 4. Explizite RPC-Rechtevergabe
-- Nur freigegebene Gast-RPCs stehen 'anon' zur Verfügung:

grant execute on function public.guest_web_validate_voucher(text, text, int) to anon, authenticated;
grant execute on function public.guest_web_submit_order_feedback(uuid, int, text, text) to anon, authenticated;
grant execute on function public.guest_web_create_reservation(uuid, text, text, text, int, timestamptz, text) to anon, authenticated;

commit;
