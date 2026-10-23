-- KL-WEB-007: Gast-Self-Checkout & Rechnungs-Splitting am Tisch (Blueprint §6.1, §8.1).
--
-- Verbindet die gemeinsame Tisch-Session (`table_sessions`, `payments`,
-- `payment_items` aus KL-PAY-001) mit dem Gast-Web:
--
--   1. `guest_web_get_table_check(p_venue_slug, p_table_token)` liest die
--      aktuelle Tischrechnung über das gültige Tisch-QR-Token — inklusive
--      aller Positionen, die per QR oder durch den Kellner auf den Tisch
--      gebucht wurden.
--   2. `guest_web_pay_table_check(...)` erlaubt Gästen am Tisch das direkte
--      Begleichen ausgewählter Positionen („Meine Positionen"), eines
--      anteiligen Split-Betrags („Durch X teilen") oder des gesamten offenen
--      Restbetrags („Alles Offene") inkl. Trinkgeld.
--   3. Die Datenbank-Invariante `payment_items_one_open_payment_per_item`
--      schützt gleichzeitig kassierende Gäste und Kellner-iPhones davor,
--      dieselbe Position doppelt abzurechnen.

begin;

-- ============================================================================
-- 1. Tischrechnung für Gäste über gültiges QR-Token lesen
-- ============================================================================

create or replace function public.guest_web_get_table_check(
  p_venue_slug text,
  p_table_token text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_table_id uuid;
  v_table_label text;
  v_table_area text;
  v_session_id uuid;
  v_items jsonb;
  v_total bigint := 0;
  v_paid bigint := 0;
  v_tip bigint := 0;
  v_token text := nullif(btrim(coalesce(p_table_token, '')), '');
begin
  if v_token is null or char_length(v_token) > 128 then
    raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
  end if;

  select v.id into v_venue_id
  from public.venues v
  where v.slug = p_venue_slug;
  if not found then
    raise exception 'guest_web_unknown_venue: %', p_venue_slug;
  end if;

  select t.id, t.label, t.area
    into v_table_id, v_table_label, v_table_area
  from public.qr_tokens q
  join public.tables t on t.id = q.table_id
  where q.token = v_token
    and q.active
    and q.mode = 'table'
    and (q.expires_at is null or q.expires_at > now())
    and t.active
    and t.venue_id = v_venue_id;

  if not found then
    raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
  end if;

  select s.id into v_session_id
  from public.table_sessions s
  where s.table_id = v_table_id
    and s.venue_id = v_venue_id
    and s.status = 'open'
  limit 1;

  if v_session_id is null then
    return jsonb_build_object(
      'table_session_id', null,
      'table_label', v_table_label,
      'table_area', v_table_area,
      'total_cents', 0,
      'paid_cents', 0,
      'tip_cents', 0,
      'open_cents', 0,
      'items', '[]'::jsonb
    );
  end if;

  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'order_item_id', line.id,
        'order_id', line.order_id,
        'name', line.name,
        'quantity', line.quantity,
        'unit_price_cents', line.unit_price_cents,
        'line_total_cents', line.quantity * line.unit_price_cents,
        'paid', line.paid,
        'payment_id', line.payment_id,
        'source', line.source
      )
      order by line.created_at, line.name
    ), '[]'::jsonb),
    coalesce(sum(line.quantity * line.unit_price_cents), 0)
    into v_items, v_total
  from (
    select
      oi.id,
      oi.order_id,
      oi.name,
      oi.quantity,
      oi.unit_price_cents,
      oi.created_at,
      pi.id is not null as paid,
      pi.payment_id,
      case
        when o.source_channel in ('waiter', 'pos', 'operator') then 'service'
        else 'guest_qr'
      end as source
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    left join public.payment_items pi
      on pi.order_item_id = oi.id and pi.active
    where o.table_session_id = v_session_id
      and o.status not in ('canceled', 'rejected')
  ) as line;

  select
    coalesce(sum(p.amount_cents), 0),
    coalesce(sum(p.tip_cents), 0)
    into v_paid, v_tip
  from public.payments p
  where p.table_session_id = v_session_id
    and p.status = 'captured';

  return jsonb_build_object(
    'table_session_id', v_session_id,
    'table_label', v_table_label,
    'table_area', v_table_area,
    'total_cents', v_total,
    'paid_cents', v_paid,
    'tip_cents', v_tip,
    'open_cents', greatest(v_total - v_paid, 0),
    'items', v_items
  );
end;
$$;

revoke all on function public.guest_web_get_table_check(text, text) from public;
grant execute on function public.guest_web_get_table_check(text, text) to anon, authenticated;

-- ============================================================================
-- 2. Gast-Zahlung & Rechnungs-Splitting am Tisch
-- ============================================================================

create or replace function public.guest_web_pay_table_check(
  p_venue_slug text,
  p_table_token text,
  p_idempotency_key text,
  p_order_item_ids uuid[] default null,
  p_amount_cents int default null,
  p_tip_cents int default 0,
  p_provider_reference text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_table_id uuid;
  v_session record;
  v_existing public.payments%rowtype;
  v_total bigint := 0;
  v_paid bigint := 0;
  v_open bigint := 0;
  v_amount bigint := 0;
  v_selected int := 0;
  v_payment_id uuid;
  v_reference text;
  v_tse_sig text;
  v_token text := nullif(btrim(coalesce(p_table_token, '')), '');
begin
  if v_token is null or char_length(v_token) > 128 then
    raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
  end if;

  if p_idempotency_key is null
     or btrim(p_idempotency_key) = ''
     or char_length(p_idempotency_key) > 256 then
    raise exception 'payment_invalid_idempotency_key';
  end if;

  if coalesce(p_tip_cents, 0) < 0 then
    raise exception 'payment_invalid_tip';
  end if;

  select v.id into v_venue_id
  from public.venues v
  where v.slug = p_venue_slug;
  if not found then
    raise exception 'payment_unknown_venue: %', p_venue_slug;
  end if;

  select t.id into v_table_id
  from public.qr_tokens q
  join public.tables t on t.id = q.table_id
  where q.token = v_token
    and q.active
    and q.mode = 'table'
    and (q.expires_at is null or q.expires_at > now())
    and t.active
    and t.venue_id = v_venue_id;

  if not found then
    raise exception 'guest_web_unknown_table: Tisch nicht erkannt';
  end if;

  -- Idempotente Wiederholung derselben Gast-Zahlung prüfen
  select * into v_existing
  from public.payments
  where venue_id = v_venue_id
    and idempotency_key = p_idempotency_key;

  if found then
    return jsonb_build_object(
      'payment_id', v_existing.id,
      'amount_cents', v_existing.amount_cents,
      'tip_cents', v_existing.tip_cents,
      'method', v_existing.method,
      'provider_reference', v_existing.provider_reference,
      'tse_signature', 'TSE-SIM-' || upper(substr(replace(v_existing.id::text, '-', ''), 1, 12)),
      'open_cents', 0,
      'session_closed', false,
      'replayed', true
    );
  end if;

  select s.* into v_session
  from public.table_sessions s
  where s.table_id = v_table_id
    and s.venue_id = v_venue_id
    and s.status = 'open'
  for update;

  if not found then
    raise exception 'payment_nothing_open: Keine offene Tischrechnung vorhanden';
  end if;

  select
    coalesce(sum(oi.quantity * oi.unit_price_cents), 0)
    into v_total
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where o.table_session_id = v_session.id
    and o.status not in ('canceled', 'rejected');

  select coalesce(sum(p.amount_cents), 0) into v_paid
  from public.payments p
  where p.table_session_id = v_session.id
    and p.status = 'captured';

  v_open := greatest(v_total - v_paid, 0);
  if v_open = 0 then
    raise exception 'payment_nothing_open: Die Tischrechnung ist bereits vollständig beglichen';
  end if;

  if p_order_item_ids is not null and array_length(p_order_item_ids, 1) > 0 then
    -- Modus A: Getrennt zahlen nach ausgewählten Positionen
    select count(*), coalesce(sum(oi.quantity * oi.unit_price_cents), 0)
      into v_selected, v_amount
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = any(p_order_item_ids)
      and o.table_session_id = v_session.id
      and o.status not in ('canceled', 'rejected')
      and not exists (
        select 1 from public.payment_items pi
        where pi.order_item_id = oi.id and pi.active
      );

    if v_selected <> array_length(p_order_item_ids, 1) then
      raise exception 'payment_item_unavailable: Eine ausgewählte Position wurde bereits bezahlt oder gehört nicht zu diesem Tisch';
    end if;

    if p_amount_cents is not null and p_amount_cents <> v_amount then
      raise exception 'payment_amount_mismatch: % statt %', p_amount_cents, v_amount;
    end if;

    -- Falls frühere Teilbetrags-Zahlungen ohne Positionsbindung den offenen
    -- Restbetrag unter die Summe der gewählten Positionen gedrückt haben:
    if v_amount > v_open then
      v_amount := v_open;
    end if;
  else
    -- Modus B: Gesamten offenen Betrag oder anteiligen Split-Betrag zahlen
    if p_amount_cents is null or p_amount_cents <= 0 then
      raise exception 'payment_invalid_amount';
    end if;
    if p_amount_cents > v_open then
      raise exception 'payment_exceeds_open: % über offenem Betrag %', p_amount_cents, v_open;
    end if;
    v_amount := p_amount_cents;
  end if;

  v_reference := coalesce(
    nullif(btrim(coalesce(p_provider_reference, '')), ''),
    'sandbox-wallet-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16)
  );
  if char_length(v_reference) > 128 then
    raise exception 'payment_invalid_reference';
  end if;

  insert into public.payments (
    venue_id, table_session_id, amount_cents, tip_cents, method,
    status, provider, provider_reference, idempotency_key, created_by
  ) values (
    v_venue_id, v_session.id, v_amount::int, coalesce(p_tip_cents, 0), 'online',
    'captured', 'sandbox', v_reference, p_idempotency_key, v_user
  ) returning id into v_payment_id;

  if p_order_item_ids is not null and array_length(p_order_item_ids, 1) > 0 then
    begin
      insert into public.payment_items (payment_id, order_item_id)
      select v_payment_id, unnest(p_order_item_ids);
    exception
      when unique_violation then
        raise exception 'payment_item_unavailable: Position wurde soeben von einem anderen Gerät bezahlt';
    end;
  elsif v_paid + v_amount >= v_total then
    -- Wenn der gesamte Restbetrag beglichen wird, alle noch offenen Positionen
    -- dieser Tisch-Session als bezahlt markieren.
    insert into public.payment_items (payment_id, order_item_id)
    select v_payment_id, oi.id
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where o.table_session_id = v_session.id
      and o.status not in ('canceled', 'rejected')
      and not exists (
        select 1 from public.payment_items pi
        where pi.order_item_id = oi.id and pi.active
      )
    on conflict do nothing;
  end if;

  if v_paid + v_amount >= v_total then
    update public.table_sessions
    set status = 'closed', closed_at = now()
    where id = v_session.id;
  end if;

  v_tse_sig := 'TSE-SIM-' || upper(substr(replace(v_payment_id::text, '-', ''), 1, 12));

  return jsonb_build_object(
    'payment_id', v_payment_id,
    'amount_cents', v_amount,
    'tip_cents', coalesce(p_tip_cents, 0),
    'method', 'online',
    'provider_reference', v_reference,
    'tse_signature', v_tse_sig,
    'open_cents', greatest(v_total - v_paid - v_amount, 0),
    'session_closed', (v_paid + v_amount >= v_total),
    'replayed', false
  );
end;
$$;

revoke all on function public.guest_web_pay_table_check(
  text, text, text, uuid[], int, int, text
) from public;
grant execute on function public.guest_web_pay_table_check(
  text, text, text, uuid[], int, int, text
) to anon, authenticated;

commit;
