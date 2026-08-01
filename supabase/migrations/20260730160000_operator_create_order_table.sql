-- KL-TABLE-002: Kellnerbestellung an einem Tisch.
--
-- `operator_create_order` (20260724000000) ist der Cloud-Weg für eine
-- Bestellung, die das Service-iPhone lokal aufgenommen und in seinem
-- Ereignisprotokoll festgeschrieben hat. Bisher konnte sie keinem Tisch
-- gehören — genau das braucht der beschlossene Offline-Pfad (DECISIONS.md,
-- Local-First vom 23. Juli: der Gast bestellt mündlich, der Kellner tippt).
--
-- Diese Migration:
--   1. zieht das Öffnen/Weiterverwenden der gemeinsamen Tisch-Session in eine
--      Funktion, statt die Rennbedingung ein zweites Mal auszuformulieren;
--   2. gibt `operator_create_order` einen Tisch und hängt die Bestellung an
--      Tisch **und** offene Session;
--   3. behebt einen echten Idempotenzfehler der bisherigen Fassung: bei einer
--      Wiederholung blieb die Bestellung dank `on conflict (id) do nothing`
--      einmalig, die Positionen wurden aber **erneut** eingefügt. Der lokale
--      Outbox-Versand wiederholt nach einem Zustellfehler — die Bestellung
--      hätte dann doppelte Positionen und einen falschen Betrag gezeigt.

begin;

-- ============================================================================
-- 1. Gemeinsame Tisch-Session (Blueprint §6.1)
-- ============================================================================

-- Die erste Bestellung eines Tisches eröffnet die Session, jede weitere hängt
-- sich an dieselbe. Das Rennen zwischen zwei gleichzeitigen Bestellungen
-- entscheidet der Partial-Unique-Index `table_sessions_one_open_per_table`
-- aus 20260730120000; der Verlierer liest die Session des Gewinners.
--
-- Hinweis für später: `guest_web_submit_order_v2` trägt dieselbe Logik noch
-- inline (sie entstand dort zuerst). Beide sind durch denselben Index
-- abgesichert; wer die Bestell-RPC das nächste Mal neu schreibt, sollte sie
-- auf diese Funktion umstellen.
create or replace function public.kitchenlink_open_table_session(
  p_venue_id uuid,
  p_table_id uuid
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_session_id uuid;
begin
  if p_table_id is null then
    return null;
  end if;

  select s.id into v_session_id
  from public.table_sessions s
  where s.table_id = p_table_id and s.status = 'open'
  limit 1;

  if v_session_id is not null then
    return v_session_id;
  end if;

  begin
    insert into public.table_sessions (venue_id, table_id)
    values (p_venue_id, p_table_id)
    returning id into v_session_id;
  exception
    when unique_violation then
      select s.id into v_session_id
      from public.table_sessions s
      where s.table_id = p_table_id and s.status = 'open'
      limit 1;
  end;

  if v_session_id is null then
    raise exception 'table_session_unresolved';
  end if;
  return v_session_id;
end;
$$;

revoke all on function public.kitchenlink_open_table_session(uuid, uuid) from public, anon;

-- ============================================================================
-- 2. Kellnerbestellung mit Tisch
-- ============================================================================

drop function if exists public.operator_create_order(
  text, text, timestamptz, text, int, text, text, jsonb
);

create or replace function public.operator_create_order(
  p_venue_slug text,
  p_id text,
  p_created_at timestamptz,
  p_source_device text,
  p_total_cents int,
  p_service_mode text default 'dine_in',
  p_customer_note text default '',
  p_items jsonb default '[]'::jsonb,
  p_table_id uuid default null
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
  v_table_id uuid;
  v_session_id uuid;
  v_inserted boolean := false;
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

  -- Ein stillgelegter Tisch nimmt auch vom Kellner keine Bestellung an: sonst
  -- landete ein Auftrag auf einem Platz, den der Betrieb bewusst abgeräumt hat.
  if p_table_id is not null then
    select t.id into v_table_id
    from public.tables t
    where t.id = p_table_id and t.venue_id = v_venue_id and t.active;
    if not found then
      raise exception 'create_order_unknown_table';
    end if;
    v_session_id := public.kitchenlink_open_table_session(v_venue_id, v_table_id);
  end if;

  v_order_id := p_id::uuid;

  insert into public.orders (
    id, venue_id, created_at, source_device, total_cents, status,
    service_mode, customer_note, currency, table_id, table_session_id
  ) values (
    v_order_id, v_venue_id, p_created_at, p_source_device, p_total_cents,
    'pending', p_service_mode, p_customer_note, 'EUR', v_table_id, v_session_id
  )
  on conflict (id) do nothing
  returning true into v_inserted;

  -- Nur die *neue* Bestellung bekommt Positionen. Ein wiederholter Versand
  -- derselben Bestellung ist ein Replay, kein zweiter Vorgang.
  if coalesce(v_inserted, false) then
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
  end if;

  return jsonb_build_object(
    'order_id', v_order_id::text,
    'status', 'pending',
    'total_cents', p_total_cents,
    'table_id', v_table_id,
    'table_session_id', v_session_id,
    'replayed', not coalesce(v_inserted, false)
  );
end;
$$;

revoke all on function public.operator_create_order(
  text, text, timestamptz, text, int, text, text, jsonb, uuid
) from public, anon;
grant execute on function public.operator_create_order(
  text, text, timestamptz, text, int, text, text, jsonb, uuid
) to authenticated;

commit;
