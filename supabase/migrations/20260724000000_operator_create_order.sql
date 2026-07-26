-- KL-OFFLINE (local-first): Operator-RPC zum Anlegen einer Bestellung in der
-- Cloud, die zuvor lokal im Event Log erfasst wurde (z. B. waiter-entered).
-- Staff-gated; der `source_device` wird auf `ios-waiter` gesetzt, damit
-- Cloud-Bestellungen von lokal erfassten unterscheidbar bleiben.

begin;

create or replace function public.operator_create_order(
  p_venue_slug text,
  p_id text,
  p_created_at timestamptz,
  p_source_device text,
  p_total_cents int,
  p_service_mode text default 'dine_in',
  p_customer_note text default '',
  p_items jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_order_id uuid;
  v_item jsonb;
begin
  if v_user is null then
    raise exception 'create_order_unauthenticated';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'create_order_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'create_order_forbidden';
  end if;

  v_order_id := p_id::uuid;

  insert into public.orders (
    id, venue_id, created_at, source_device, total_cents, status,
    service_mode, customer_note, currency
  ) values (
    v_order_id, v_venue_id, p_created_at, p_source_device, p_total_cents,
    'pending', p_service_mode, p_customer_note, 'EUR'
  ) on conflict (id) do nothing;

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.order_items (
      order_id, name, quantity, unit_price_cents, kind
    ) values (
      v_order_id,
      v_item ->> 'name',
      (v_item ->> 'quantity')::int,
      (v_item ->> 'unit_price_cents')::int,
      coalesce(v_item ->> 'kind', 'food')
    );
  end loop;

  return jsonb_build_object(
    'order_id', v_order_id::text,
    'status', 'pending',
    'total_cents', p_total_cents
  );
end;
$$;

revoke all on function public.operator_create_order(text, text, timestamptz, text, int, text, text, jsonb)
  from public, anon;
grant execute on function public.operator_create_order(text, text, timestamptz, text, int, text, text, jsonb)
  to authenticated;

commit;
