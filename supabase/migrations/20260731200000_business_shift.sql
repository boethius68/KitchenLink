-- KL-SHIFT-001: Betriebsschicht und Kassenabschluss (Blueprint §8.3,
-- Meilenstein 2).
--
-- Meilenstein 1 hat den Geldkreis geöffnet, aber nicht geschlossen: es wird
-- kassiert, storniert und Trinkgeld genommen — und am Ende des Tages gibt es
-- nichts, wogegen jemand zählen könnte. Diese Migration ergänzt die Klammer,
-- die der Blueprint §8.3 verlangt: eine gemeinsame Betriebsschicht, auf der
-- **alle** Geräte der Venue arbeiten, mit Anfangsbestand, gesammelten
-- Bewegungen und einer Zählung mit dokumentierter Abweichung.
--
-- Drei Fachobjekte bleiben laut Blueprint §9 getrennt und werden hier bewusst
-- nicht vermischt: die **Betriebsschicht** (dieses Objekt, „die Kasse ist
-- offen"), die geplante Arbeitsschicht und der tatsächliche Zeiteintrag eines
-- Mitarbeiters. Hier geht es allein um die Kasse.
--
-- Die tragende Invariante steht wieder als Index in der Datenbank: **je Venue
-- ist höchstens eine Schicht offen.** Sonst kassieren zwei Geräte in zwei
-- Kassen und keine Zählung stimmt je wieder.
--
-- **Keine Sandbox-Zahlung bewegt echtes Geld**, also auch kein Abschluss.

begin;

-- ============================================================================
-- 1. Tabellen
-- ============================================================================

create table if not exists public.business_shifts (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'closed')),

  opened_by uuid,
  opened_at timestamptz not null default now(),
  -- Blueprint §8.3: der Anfangsbestand ist optional. 0 heißt „ohne Wechselgeld
  -- begonnen", nicht „unbekannt".
  opening_cash_cents int not null default 0 check (opening_cash_cents >= 0),

  closed_by uuid,
  closed_at timestamptz,
  -- Alle drei erst beim Abschluss gesetzt und dann eingefroren: der Bericht
  -- einer geschlossenen Schicht darf sich nicht mehr ändern, auch wenn später
  -- noch eine Zahlung storniert wird.
  counted_cash_cents int check (counted_cash_cents >= 0),
  expected_cash_cents int,
  variance_cents int,
  close_note text,

  -- Fortlaufende Nummer je Venue, vergeben beim Abschluss. Das ist es, was den
  -- Bericht zu einem Z-Bericht macht: eine lückenlose Folge.
  z_number int,

  idempotency_key text,
  unique (venue_id, idempotency_key),
  unique (venue_id, z_number),

  -- Eine geschlossene Schicht ist vollständig oder gar nicht geschlossen.
  constraint business_shifts_closed_is_complete check (
    status = 'open'
    or (closed_at is not null
        and counted_cash_cents is not null
        and expected_cash_cents is not null
        and variance_cents is not null
        and z_number is not null)
  )
);

-- Die eigentliche Zusage: zwei offene Kassen kann niemand zählen.
create unique index if not exists business_shifts_one_open_per_venue
  on public.business_shifts(venue_id)
  where status = 'open';

create index if not exists business_shifts_venue_idx
  on public.business_shifts(venue_id, opened_at desc);

-- Bargeldbewegungen, die keine Zahlung sind (Blueprint §8.3: Ausgaben und
-- Entnahmen). `deposit` ist die Gegenrichtung — Wechselgeld nachlegen.
create table if not exists public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.business_shifts(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  kind text not null check (kind in ('payout', 'expense', 'deposit')),
  amount_cents int not null check (amount_cents > 0),
  reason text,
  idempotency_key text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (shift_id, idempotency_key)
);

create index if not exists cash_movements_shift_idx
  on public.cash_movements(shift_id, created_at);

-- ============================================================================
-- 2. Zahlungen hängen an der Schicht
-- ============================================================================

alter table public.payments
  add column if not exists shift_id uuid references public.business_shifts(id);

create index if not exists payments_shift_idx on public.payments(shift_id);

-- Ein Trigger statt einer Änderung an `operator_record_payment`: die Zuordnung
-- hängt allein vom Zustand der Venue ab, nicht davon, was der Client mitschickt.
-- So greift sie auch für jeden späteren Zahlungsweg (Onlinezahlung im Gast-Web,
-- Theke, Lieferung), ohne dass ihn jemand daran erinnern muss.
--
-- Ist **keine** Schicht offen, bleibt `shift_id` null. Die Zahlung wird dadurch
-- nicht blockiert — Geld anzunehmen darf nie an einem vergessenen Knopfdruck
-- scheitern —, taucht aber im Bericht als „außerhalb der Schicht" auf, statt
-- still zu verschwinden.
create or replace function public.kitchenlink_payment_shift()
returns trigger
language plpgsql
as $$
begin
  if new.shift_id is null then
    select s.id into new.shift_id
    from public.business_shifts s
    where s.venue_id = new.venue_id and s.status = 'open';
  end if;
  return new;
end;
$$;

drop trigger if exists payments_attach_shift on public.payments;
create trigger payments_attach_shift
  before insert on public.payments
  for each row execute function public.kitchenlink_payment_shift();

-- ============================================================================
-- 3. Schutz
-- ============================================================================

alter table public.business_shifts enable row level security;
alter table public.cash_movements enable row level security;

drop policy if exists "business_shifts_staff_read" on public.business_shifts;
create policy "business_shifts_staff_read" on public.business_shifts
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

drop policy if exists "cash_movements_staff_read" on public.cash_movements;
create policy "cash_movements_staff_read" on public.cash_movements
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

-- Kein Schreibweg für Clients: Schichten und Bewegungen entstehen nur in den
-- RPCs weiter unten, die serverseitig rechnen.

-- ============================================================================
-- 4. Summen einer Schicht
-- ============================================================================

-- Eine Quelle für Bericht, Abschluss und Live-Anzeige. Wäre das dreimal
-- getrennt gerechnet, driftet der erwartete Bargeldbestand irgendwann von dem
-- ab, was der Abschluss festhält.
--
-- Bargeld-Logik: Barzahlungen erhöhen den Kassenbestand **inklusive
-- Trinkgeld** (der Gast legt beides auf den Tisch); Karte, Tap to Pay,
-- Gutschein und Onlinezahlung nicht. Eine stornierte Zahlung ist nicht mehr
-- `captured` und zählt deshalb nirgends mit — bei Bargeld ist das genau
-- richtig, denn das Geld hat die Kasse wieder verlassen.
create or replace function public.kitchenlink_shift_totals(p_shift_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with shift as (
    select * from public.business_shifts where id = p_shift_id
  ),
  pay as (
    select
      coalesce(sum(p.amount_cents) filter (where p.status = 'captured'), 0) as revenue,
      coalesce(sum(p.tip_cents) filter (where p.status = 'captured'), 0) as tips,
      coalesce(sum(p.amount_cents + p.tip_cents)
        filter (where p.status = 'captured' and p.method = 'cash'), 0) as cash_in,
      coalesce(sum(p.amount_cents) filter (where p.status = 'refunded'), 0) as refunded,
      count(*) filter (where p.status = 'captured') as payment_count,
      count(*) filter (where p.status = 'refunded') as refund_count
    from public.payments p
    where p.shift_id = p_shift_id
  ),
  moves as (
    select
      coalesce(sum(amount_cents) filter (where kind = 'payout'), 0) as payouts,
      coalesce(sum(amount_cents) filter (where kind = 'expense'), 0) as expenses,
      coalesce(sum(amount_cents) filter (where kind = 'deposit'), 0) as deposits
    from public.cash_movements
    where shift_id = p_shift_id
  ),
  by_method as (
    select coalesce(
      jsonb_object_agg(method, jsonb_build_object(
        'amount_cents', amount_cents, 'tip_cents', tip_cents, 'count', n
      )),
      '{}'::jsonb
    ) as methods
    from (
      select p.method,
             sum(p.amount_cents)::int as amount_cents,
             sum(p.tip_cents)::int as tip_cents,
             count(*)::int as n
      from public.payments p
      where p.shift_id = p_shift_id and p.status = 'captured'
      group by p.method
    ) m
  )
  select jsonb_build_object(
    'revenue_cents', pay.revenue,
    'tip_cents', pay.tips,
    'refunded_cents', pay.refunded,
    'payment_count', pay.payment_count,
    'refund_count', pay.refund_count,
    'cash_payments_cents', pay.cash_in,
    'payout_cents', moves.payouts,
    'expense_cents', moves.expenses,
    'deposit_cents', moves.deposits,
    'opening_cash_cents', shift.opening_cash_cents,
    -- Was in der Schublade liegen müsste.
    'expected_cash_cents',
      shift.opening_cash_cents + pay.cash_in + moves.deposits
        - moves.payouts - moves.expenses,
    'by_method', by_method.methods
  )
  from shift, pay, moves, by_method;
$$;

-- ============================================================================
-- 5. Schicht öffnen
-- ============================================================================

create or replace function public.operator_open_shift(
  p_venue_slug text,
  p_opening_cash_cents int default 0,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_existing public.business_shifts%rowtype;
  v_shift_id uuid;
begin
  if v_user is null then
    raise exception 'shift_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'shift_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'shift_forbidden: kein Personal dieser Venue';
  end if;

  if coalesce(p_opening_cash_cents, 0) < 0 then
    raise exception 'shift_invalid_opening_cash';
  end if;

  -- Wiederholung desselben Öffnens: die erste Antwort gilt.
  if p_idempotency_key is not null and btrim(p_idempotency_key) <> '' then
    select * into v_existing
    from public.business_shifts
    where venue_id = v_venue_id and idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object(
        'shift_id', v_existing.id,
        'opened_at', v_existing.opened_at,
        'opening_cash_cents', v_existing.opening_cash_cents,
        'replayed', true
      );
    end if;
  end if;

  select * into v_existing
  from public.business_shifts
  where venue_id = v_venue_id and status = 'open';
  if found then
    raise exception
      'shift_already_open: seit % ist bereits eine Schicht offen', v_existing.opened_at;
  end if;

  begin
    insert into public.business_shifts (
      venue_id, opened_by, opening_cash_cents, idempotency_key
    ) values (
      v_venue_id, v_user, coalesce(p_opening_cash_cents, 0),
      nullif(btrim(coalesce(p_idempotency_key, '')), '')
    ) returning id into v_shift_id;
  exception
    when unique_violation then
      -- Zwei Geräte öffnen gleichzeitig: der Index hat entschieden. Der
      -- Verlierer bekommt eine klare Absage statt eines rohen Fehlers.
      raise exception 'shift_already_open: ein anderes Gerät hat die Schicht soeben geöffnet';
  end;

  return jsonb_build_object(
    'shift_id', v_shift_id,
    'opened_at', now(),
    'opening_cash_cents', coalesce(p_opening_cash_cents, 0),
    'replayed', false
  );
end;
$$;

revoke all on function public.operator_open_shift(text, int, text) from public, anon;
grant execute on function public.operator_open_shift(text, int, text) to authenticated;

-- ============================================================================
-- 6. Bargeldbewegung buchen
-- ============================================================================

create or replace function public.operator_record_cash_movement(
  p_venue_slug text,
  p_kind text,
  p_amount_cents int,
  p_idempotency_key text,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_shift public.business_shifts%rowtype;
  v_existing public.cash_movements%rowtype;
  v_movement_id uuid;
begin
  if v_user is null then
    raise exception 'cash_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'cash_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'cash_forbidden: kein Personal dieser Venue';
  end if;

  if p_kind not in ('payout', 'expense', 'deposit') then
    raise exception 'cash_invalid_kind: %', p_kind;
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'cash_invalid_amount';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'cash_invalid_idempotency_key';
  end if;

  -- Anders als eine Zahlung braucht eine Entnahme eine offene Kasse: sie ist
  -- die Buchung *auf* die Schicht und wäre ohne sie nirgends zugeordnet.
  select * into v_shift
  from public.business_shifts
  where venue_id = v_venue_id and status = 'open';
  if not found then
    raise exception 'cash_no_open_shift: es ist keine Schicht offen';
  end if;

  select * into v_existing
  from public.cash_movements
  where shift_id = v_shift.id and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'movement_id', v_existing.id,
      'kind', v_existing.kind,
      'amount_cents', v_existing.amount_cents,
      'replayed', true
    );
  end if;

  insert into public.cash_movements (
    shift_id, venue_id, kind, amount_cents, reason, idempotency_key, created_by
  ) values (
    v_shift.id, v_venue_id, p_kind, p_amount_cents,
    nullif(btrim(coalesce(p_reason, '')), ''), p_idempotency_key, v_user
  ) returning id into v_movement_id;

  return jsonb_build_object(
    'movement_id', v_movement_id,
    'kind', p_kind,
    'amount_cents', p_amount_cents,
    'totals', public.kitchenlink_shift_totals(v_shift.id),
    'replayed', false
  );
end;
$$;

revoke all on function public.operator_record_cash_movement(
  text, text, int, text, text
) from public, anon;
grant execute on function public.operator_record_cash_movement(
  text, text, int, text, text
) to authenticated;

-- ============================================================================
-- 7. Bericht
-- ============================================================================

-- Ohne `p_shift_id` die aktuell offene Schicht — das ist der Live-Blick auf die
-- Kasse. Mit `p_shift_id` auch eine geschlossene: der Z-Bericht.
create or replace function public.operator_shift_report(
  p_venue_slug text,
  p_shift_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_shift public.business_shifts%rowtype;
  v_totals jsonb;
  v_unassigned bigint;
  v_open_sessions int;
begin
  if auth.uid() is null then
    raise exception 'shift_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'shift_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'shift_forbidden: kein Personal dieser Venue';
  end if;

  if p_shift_id is null then
    select * into v_shift
    from public.business_shifts
    where venue_id = v_venue_id and status = 'open';
  else
    select * into v_shift
    from public.business_shifts
    where id = p_shift_id and venue_id = v_venue_id;
    if not found then
      raise exception 'shift_unknown: %', p_shift_id;
    end if;
  end if;

  if v_shift.id is null then
    -- Keine offene Schicht ist ein gültiger Zustand, kein Fehler: die App
    -- zeigt dann den Knopf zum Öffnen.
    return jsonb_build_object('open', false, 'shift', null);
  end if;

  v_totals := public.kitchenlink_shift_totals(v_shift.id);

  -- Geld, das ohne offene Schicht angenommen wurde. Sichtbar statt still
  -- geschluckt (siehe Trigger oben) — sonst fehlt es beim Zählen unerklärt.
  select coalesce(sum(p.amount_cents + p.tip_cents), 0) into v_unassigned
  from public.payments p
  where p.venue_id = v_venue_id
    and p.shift_id is null
    and p.status = 'captured'
    and p.method = 'cash'
    and p.created_at >= v_shift.opened_at;

  select count(*) into v_open_sessions
  from public.table_sessions s
  where s.venue_id = v_venue_id and s.status = 'open';

  return jsonb_build_object(
    'open', v_shift.status = 'open',
    'shift', jsonb_build_object(
      'id', v_shift.id,
      'status', v_shift.status,
      'opened_at', v_shift.opened_at,
      'closed_at', v_shift.closed_at,
      'z_number', v_shift.z_number,
      'counted_cash_cents', v_shift.counted_cash_cents,
      -- Bei einer geschlossenen Schicht gilt der eingefrorene Stand des
      -- Abschlusses, nicht die Neuberechnung von jetzt.
      'expected_cash_cents', coalesce(
        v_shift.expected_cash_cents, (v_totals->>'expected_cash_cents')::int
      ),
      'variance_cents', v_shift.variance_cents,
      'close_note', v_shift.close_note
    ),
    'totals', v_totals,
    'unassigned_cash_cents', v_unassigned,
    'open_table_sessions', v_open_sessions
  );
end;
$$;

revoke all on function public.operator_shift_report(text, uuid) from public, anon;
grant execute on function public.operator_shift_report(text, uuid) to authenticated;

-- Die letzten Abschlüsse, für den Blick zurück.
create or replace function public.operator_recent_shifts(
  p_venue_slug text,
  p_limit int default 20
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'shift_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'shift_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'shift_forbidden: kein Personal dieser Venue';
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.opened_at desc), '[]'::jsonb)
    into v_rows
  from (
    select s.id, s.status, s.opened_at, s.closed_at, s.z_number,
           s.opening_cash_cents, s.counted_cash_cents,
           s.expected_cash_cents, s.variance_cents, s.close_note
    from public.business_shifts s
    where s.venue_id = v_venue_id
    order by s.opened_at desc
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_recent_shifts(text, int) from public, anon;
grant execute on function public.operator_recent_shifts(text, int) to authenticated;

-- ============================================================================
-- 8. Abschluss
-- ============================================================================

-- Blueprint §8.3: „Bargeldzählung und dokumentierte Abweichung". Die Abweichung
-- wird **nicht** verhindert und nicht weggerechnet — sie wird festgehalten. Ein
-- Abschluss, der eine Differenz verschweigt, ist wertlos.
create or replace function public.operator_close_shift(
  p_venue_slug text,
  p_counted_cash_cents int,
  p_shift_id uuid default null,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_shift public.business_shifts%rowtype;
  v_totals jsonb;
  v_expected int;
  v_variance int;
  v_z int;
begin
  if v_user is null then
    raise exception 'shift_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'shift_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'shift_forbidden: kein Personal dieser Venue';
  end if;

  if p_counted_cash_cents is null or p_counted_cash_cents < 0 then
    raise exception 'shift_invalid_count: gezähltes Bargeld fehlt';
  end if;

  -- `for update`: zwei Geräte dürfen nicht gleichzeitig abschließen und zwei
  -- Z-Nummern ziehen.
  if p_shift_id is null then
    select * into v_shift
    from public.business_shifts
    where venue_id = v_venue_id and status = 'open'
    for update;
  else
    select * into v_shift
    from public.business_shifts
    where id = p_shift_id and venue_id = v_venue_id
    for update;
  end if;

  if v_shift.id is null then
    raise exception 'shift_none_open: es ist keine Schicht offen';
  end if;
  if v_shift.status <> 'open' then
    raise exception 'shift_already_closed: seit % abgeschlossen', v_shift.closed_at;
  end if;

  v_totals := public.kitchenlink_shift_totals(v_shift.id);
  v_expected := (v_totals->>'expected_cash_cents')::int;
  v_variance := p_counted_cash_cents - v_expected;

  select coalesce(max(s.z_number), 0) + 1 into v_z
  from public.business_shifts s
  where s.venue_id = v_venue_id;

  update public.business_shifts
  set status = 'closed',
      closed_by = v_user,
      closed_at = now(),
      counted_cash_cents = p_counted_cash_cents,
      expected_cash_cents = v_expected,
      variance_cents = v_variance,
      close_note = nullif(btrim(coalesce(p_note, '')), ''),
      z_number = v_z
  where id = v_shift.id;

  return jsonb_build_object(
    'shift_id', v_shift.id,
    'z_number', v_z,
    'closed_at', now(),
    'counted_cash_cents', p_counted_cash_cents,
    'expected_cash_cents', v_expected,
    -- Positiv heißt Überschuss, negativ heißt Fehlbetrag.
    'variance_cents', v_variance,
    'totals', v_totals
  );
end;
$$;

revoke all on function public.operator_close_shift(text, int, uuid, text) from public, anon;
grant execute on function public.operator_close_shift(text, int, uuid, text) to authenticated;

commit;
