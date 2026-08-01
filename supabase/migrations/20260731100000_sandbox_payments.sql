-- KL-PAY-001: Rechnung, Trinkgeld und simulierte Zahlung (Blueprint §8.1,
-- Meilenstein 1.11).
--
-- Bis hierher endete der Ablauf bei „serviert". Diese Migration ergänzt die
-- Rechnung zur gemeinsamen Tisch-Session (§6.1): mehrere Zahlungen, mehrere
-- Zahlarten, getrenntes Zahlen nach Positionen, Trinkgeld je Zahlung, Storno.
--
-- **Keine Sandbox-Zahlung bewegt echtes Geld.** Jede Zahlung trägt ihren
-- Provider (`sandbox`) und dessen Referenz; ein echter PSP tritt später an
-- dieselbe Stelle, ohne dass sich Rechnung oder Bestellung ändern
-- (Blueprint §8.2: Zahlungs- und Bestellstatus bleiben getrennt).
--
-- Die tragende Invariante steht als Index in der Datenbank, nicht als Regel in
-- der App: **eine Position kann nicht zweimal offen bezahlt sein.**

begin;

-- ============================================================================
-- 1. Tabellen
-- ============================================================================

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  -- Zahlungen ohne Tisch (Theke, Abholung) hängen direkt an einer Bestellung.
  table_session_id uuid references public.table_sessions(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  amount_cents int not null check (amount_cents > 0),
  tip_cents int not null default 0 check (tip_cents >= 0),
  method text not null check (
    method in ('cash', 'card', 'tap_to_pay', 'voucher', 'online')
  ),
  status text not null default 'captured' check (status in ('captured', 'refunded')),
  -- Blueprint §8.2: der Provider ist austauschbar, KitchenLink speichert nie
  -- Kartendaten — nur die Referenz, die der Provider zurückgibt.
  provider text not null default 'sandbox',
  provider_reference text,
  idempotency_key text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  refunded_at timestamptz,
  refund_reason text,
  unique (venue_id, idempotency_key)
);

create index if not exists payments_venue_idx on public.payments(venue_id, created_at);
create index if not exists payments_session_idx on public.payments(table_session_id);

-- Welche Positionen eine Zahlung abdeckt. `active = false` nach einem Storno:
-- die Zuordnung bleibt für die Nachvollziehbarkeit stehen, die Position wird
-- aber wieder zahlbar.
create table if not exists public.payment_items (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  active boolean not null default true
);

create index if not exists payment_items_payment_idx on public.payment_items(payment_id);

-- Die eigentliche Zusage an den Betrieb: kein Gericht wird zweimal kassiert.
create unique index if not exists payment_items_one_open_payment_per_item
  on public.payment_items(order_item_id)
  where active;

-- ============================================================================
-- 2. Schutz
-- ============================================================================

alter table public.payments enable row level security;
alter table public.payment_items enable row level security;

drop policy if exists "payments_staff_read" on public.payments;
create policy "payments_staff_read" on public.payments
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

drop policy if exists "payment_items_staff_read" on public.payment_items;
create policy "payment_items_staff_read" on public.payment_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.payments p
      where p.id = payment_items.payment_id
        and public.is_venue_staff(p.venue_id)
    )
  );

-- Kein Schreibweg für Clients: Zahlungen entstehen ausschließlich in den RPCs
-- weiter unten, die serverseitig rechnen.

-- ============================================================================
-- 3. Rechnung lesen
-- ============================================================================

create or replace function public.operator_table_check(
  p_venue_slug text,
  p_table_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_session_id uuid;
  v_items jsonb;
  v_total bigint := 0;
  v_paid bigint := 0;
  v_tip bigint := 0;
begin
  if v_user is null then
    raise exception 'check_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'check_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'check_forbidden: kein Personal dieser Venue';
  end if;

  select s.id into v_session_id
  from public.table_sessions s
  where s.table_id = p_table_id and s.venue_id = v_venue_id and s.status = 'open'
  limit 1;

  if v_session_id is null then
    return jsonb_build_object(
      'table_session_id', null,
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
        'payment_id', line.payment_id
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
      pi.payment_id
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    left join public.payment_items pi
      on pi.order_item_id = oi.id and pi.active
    where o.table_session_id = v_session_id
      and o.status <> 'canceled'
  ) as line;

  select
    coalesce(sum(p.amount_cents), 0),
    coalesce(sum(p.tip_cents), 0)
    into v_paid, v_tip
  from public.payments p
  where p.table_session_id = v_session_id and p.status = 'captured';

  return jsonb_build_object(
    'table_session_id', v_session_id,
    'total_cents', v_total,
    'paid_cents', v_paid,
    'tip_cents', v_tip,
    'open_cents', greatest(v_total - v_paid, 0),
    'items', v_items
  );
end;
$$;

revoke all on function public.operator_table_check(text, uuid) from public, anon;
grant execute on function public.operator_table_check(text, uuid) to authenticated;

-- ============================================================================
-- 4. Zahlung erfassen
-- ============================================================================

-- Der Betrag kommt **nicht** vom Gerät: bei ausgewählten Positionen rechnet die
-- Datenbank ihn aus deren Zeilensummen. Ein mitgeschickter Betrag wird nur
-- gegengeprüft. Das ist dieselbe Regel wie bei der Gastbestellung — der Client
-- schlägt vor, der Server entscheidet.
create or replace function public.operator_record_payment(
  p_venue_slug text,
  p_table_session_id uuid,
  p_method text,
  p_idempotency_key text,
  p_tip_cents int default 0,
  p_order_item_ids uuid[] default null,
  p_amount_cents int default null,
  -- Referenz des Zahlungsanbieters (Blueprint §8.2). In der Sandbox liefert
  -- sie der simulierte Provider; fehlt sie, vergibt die Datenbank eine eigene.
  -- Ein echter PSP schreibt hier später seine Autorisierung hinein.
  p_provider_reference text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_existing public.payments%rowtype;
  v_amount bigint;
  v_open bigint;
  v_total bigint;
  v_paid bigint;
  v_payment_id uuid;
  v_selected int;
  v_session record;
  v_reference text;
begin
  if v_user is null then
    raise exception 'payment_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'payment_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'payment_forbidden: kein Personal dieser Venue';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'payment_invalid_idempotency_key';
  end if;
  if p_method not in ('cash', 'card', 'tap_to_pay', 'voucher', 'online') then
    raise exception 'payment_invalid_method: %', p_method;
  end if;
  if coalesce(p_tip_cents, 0) < 0 then
    raise exception 'payment_invalid_tip';
  end if;

  -- Wiederholung derselben Zahlung: die erste Antwort gilt.
  select * into v_existing
  from public.payments
  where venue_id = v_venue_id and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'payment_id', v_existing.id,
      'amount_cents', v_existing.amount_cents,
      'tip_cents', v_existing.tip_cents,
      'method', v_existing.method,
      'provider_reference', v_existing.provider_reference,
      'replayed', true
    );
  end if;

  select s.* into v_session
  from public.table_sessions s
  where s.id = p_table_session_id and s.venue_id = v_venue_id;
  if not found then
    raise exception 'payment_unknown_session';
  end if;
  if v_session.status <> 'open' then
    raise exception 'payment_session_closed: die Rechnung ist bereits abgeschlossen';
  end if;

  select
    coalesce(sum(oi.quantity * oi.unit_price_cents), 0)
    into v_total
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where o.table_session_id = p_table_session_id and o.status <> 'canceled';

  select coalesce(sum(p.amount_cents), 0) into v_paid
  from public.payments p
  where p.table_session_id = p_table_session_id and p.status = 'captured';

  v_open := greatest(v_total - v_paid, 0);
  if v_open = 0 then
    raise exception 'payment_nothing_open: es ist nichts mehr offen';
  end if;

  if p_order_item_ids is not null and array_length(p_order_item_ids, 1) > 0 then
    -- Getrennt zahlen: die gewählten Positionen müssen zu dieser Rechnung
    -- gehören und noch offen sein. Beides prüft die Datenbank, weil nur sie
    -- den Stand kennt, den zwei gleichzeitig kassierende Geräte teilen.
    select count(*), coalesce(sum(oi.quantity * oi.unit_price_cents), 0)
      into v_selected, v_amount
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = any(p_order_item_ids)
      and o.table_session_id = p_table_session_id
      and o.status <> 'canceled'
      and not exists (
        select 1 from public.payment_items pi
        where pi.order_item_id = oi.id and pi.active
      );

    if v_selected <> array_length(p_order_item_ids, 1) then
      raise exception 'payment_item_unavailable: Position gehört nicht zur Rechnung oder ist bereits bezahlt';
    end if;
    if p_amount_cents is not null and p_amount_cents <> v_amount then
      raise exception 'payment_amount_mismatch: % statt %', p_amount_cents, v_amount;
    end if;
  else
    -- Teilbetrag ohne Positionsauswahl (z. B. „die zahlen 20 € an").
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
    'sandbox-' || replace(gen_random_uuid()::text, '-', '')
  );
  if char_length(v_reference) > 128 then
    raise exception 'payment_invalid_reference';
  end if;

  insert into public.payments (
    venue_id, table_session_id, amount_cents, tip_cents, method,
    status, provider, provider_reference, idempotency_key, created_by
  ) values (
    v_venue_id, p_table_session_id, v_amount::int, coalesce(p_tip_cents, 0), p_method,
    'captured', 'sandbox', v_reference, p_idempotency_key, v_user
  ) returning id into v_payment_id;

  if p_order_item_ids is not null and array_length(p_order_item_ids, 1) > 0 then
    begin
      insert into public.payment_items (payment_id, order_item_id)
      select v_payment_id, unnest(p_order_item_ids);
    exception
      when unique_violation then
        -- Zwei Geräte kassieren gleichzeitig denselben Tisch: der Index hat
        -- entschieden. Der Verlierer bekommt eine klare Absage statt eines
        -- rohen Datenbankfehlers.
        raise exception 'payment_item_unavailable: Position wurde soeben von einem anderen Gerät kassiert';
    end;
  end if;

  -- Nichts mehr offen: die gemeinsame Tisch-Session ist beendet. Der nächste
  -- Gast an diesem Tisch eröffnet eine neue.
  if v_paid + v_amount >= v_total then
    update public.table_sessions
    set status = 'closed', closed_at = now()
    where id = p_table_session_id;
  end if;

  return jsonb_build_object(
    'payment_id', v_payment_id,
    'amount_cents', v_amount,
    'tip_cents', coalesce(p_tip_cents, 0),
    'method', p_method,
    'provider_reference', v_reference,
    'open_cents', greatest(v_total - v_paid - v_amount, 0),
    'session_closed', (v_paid + v_amount >= v_total),
    'replayed', false
  );
end;
$$;

revoke all on function public.operator_record_payment(
  text, uuid, text, text, int, uuid[], int, text
) from public, anon;
grant execute on function public.operator_record_payment(
  text, uuid, text, text, int, uuid[], int, text
) to authenticated;

-- ============================================================================
-- 5. Storno
-- ============================================================================

-- Eine stornierte Zahlung bleibt stehen (Blueprint §8.2: jeder Vorgang ist
-- auditiert); ihre Positionen werden wieder zahlbar und eine bereits
-- geschlossene Rechnung öffnet sich erneut.
create or replace function public.operator_refund_payment(
  p_venue_slug text,
  p_payment_id uuid,
  p_reason text default ''
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_payment public.payments%rowtype;
  v_reopened boolean := false;
  v_table_id uuid;
begin
  if v_user is null then
    raise exception 'refund_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'refund_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'refund_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_payment
  from public.payments
  where id = p_payment_id and venue_id = v_venue_id;
  if not found then
    raise exception 'refund_unknown_payment';
  end if;

  if v_payment.status = 'refunded' then
    -- Zweiter Klick auf denselben Storno: kein Fehler, aber auch kein zweiter
    -- Vorgang.
    return jsonb_build_object('payment_id', v_payment.id, 'replayed', true);
  end if;

  update public.payments
  set status = 'refunded',
      refunded_at = now(),
      refund_reason = coalesce(nullif(btrim(p_reason), ''), 'ohne Angabe')
  where id = p_payment_id;

  update public.payment_items
  set active = false
  where payment_id = p_payment_id;

  -- Die Rechnung wird wieder geöffnet — aber nur, wenn an diesem Tisch nicht
  -- längst neue Gäste sitzen. Ein Tisch hat höchstens eine offene Session
  -- (Index aus 20260730120000); in dem Fall bleibt die alte Rechnung
  -- geschlossen und der Storno steht trotzdem. Die Ansicht sagt das dann auch.
  if v_payment.table_session_id is not null then
    select s.table_id into v_table_id
    from public.table_sessions s
    where s.id = v_payment.table_session_id and s.status = 'closed';

    if v_table_id is not null and not exists (
      select 1 from public.table_sessions s
      where s.table_id = v_table_id and s.status = 'open'
    ) then
      update public.table_sessions
      set status = 'open', closed_at = null
      where id = v_payment.table_session_id;
      v_reopened := true;
    end if;
  end if;

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'replayed', false,
    'session_reopened', v_reopened
  );
end;
$$;

revoke all on function public.operator_refund_payment(text, uuid, text) from public, anon;
grant execute on function public.operator_refund_payment(text, uuid, text) to authenticated;

commit;
