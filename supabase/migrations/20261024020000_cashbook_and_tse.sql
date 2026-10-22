-- KL-CASHBOOK-001 & KL-TSE-001: Kassenbuch, Betriebsausgaben & TSE-Simulation (Blueprint §15 & Meilenstein 6).
--
-- Implementiert die Abrechnungssandbox:
-- 1. Chronologisches, lückenloses Kassenbuch (`cashbook_entries`) mit fortlaufendem Kassenbestand.
-- 2. Betriebsausgaben mit Belegnummer und MwSt.-Aufteilung (7% Speisen / 19% Regelsteuersatz).
-- 3. TSE-Simulation nach KassenSichV (`tse_transactions`) mit Signaturzähler, Prüfwert und DSFinV-K QR-String.
-- 4. Betreiber-RPCs:
--    - `operator_list_cashbook`: Liefert Kassenbuchzeilen mit Saldo und Steuer.
--    - `operator_record_cashbook_entry`: Bucht Einnahme/Ausgabe und schreibt den Kassenbestand lückenlos fort.
--    - `operator_sign_tse_transaction`: Simuliert die TSE-Signierung eines Belegs.

begin;

-- ============================================================================
-- 1. Kassenbuch
-- ============================================================================

create table if not exists public.cashbook_entries (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  shift_id uuid references public.business_shifts(id) on delete set null,
  entry_number int not null check (entry_number > 0),
  booking_date date not null default current_date,
  entry_type text not null check (entry_type in (
    'initial_balance', 'cash_sale', 'cash_refund', 'expense', 'deposit', 'payout', 'closing_variance'
  )),
  amount_cents int not null check (amount_cents > 0),
  is_income boolean not null,
  balance_after_cents int not null,
  tax_rate_percent numeric(5, 2) check (tax_rate_percent is null or tax_rate_percent in (0.00, 7.00, 19.00)),
  tax_cents int not null default 0 check (tax_cents >= 0),
  receipt_number text,
  reference text,
  description text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique (venue_id, entry_number)
);

create index if not exists cashbook_entries_venue_date_idx
  on public.cashbook_entries(venue_id, booking_date, entry_number);

alter table public.cashbook_entries enable row level security;

create policy "cashbook_entries_staff_all" on public.cashbook_entries
  for all to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. TSE Transaktionen (KassenSichV Simulation)
-- ============================================================================

create table if not exists public.tse_transactions (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  tse_serial text not null default 'TSE-KL-DEMO-001',
  transaction_number int not null check (transaction_number > 0),
  signature_counter int not null check (signature_counter > 0),
  started_at timestamptz not null default now(),
  finished_at timestamptz not null default now(),
  process_type text not null default 'Kassenbeleg-V1' check (process_type in ('Kassenbeleg-V1', 'Bestellung-V1', 'Tagesabschluss-V1')),
  process_data text not null,
  signature_value text not null,
  qr_code_data text not null,
  created_at timestamptz not null default now(),
  unique (venue_id, transaction_number)
);

create index if not exists tse_transactions_venue_idx
  on public.tse_transactions(venue_id, transaction_number);

alter table public.tse_transactions enable row level security;

create policy "tse_transactions_staff_all" on public.tse_transactions
  for all to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 3. Betreiber RPC: Kassenbuch abrufen
-- ============================================================================

create or replace function public.operator_list_cashbook(
  p_venue_id uuid,
  p_from_date date default null,
  p_to_date date default null
)
returns setof public.cashbook_entries
language sql
security definer
set search_path = public
stable
as $$
  select * from public.cashbook_entries
  where venue_id = p_venue_id
    and (p_from_date is null or booking_date >= p_from_date)
    and (p_to_date is null or booking_date <= p_to_date)
  order by entry_number desc;
$$;

-- ============================================================================
-- 4. Betreiber RPC: Kassenbucheintrag buchen
-- ============================================================================

create or replace function public.operator_record_cashbook_entry(
  p_venue_id uuid,
  p_entry_type text,
  p_amount_cents int,
  p_is_income boolean,
  p_description text,
  p_tax_rate numeric default null,
  p_receipt_number text default null,
  p_reference text default null
)
returns public.cashbook_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_number int;
  v_current_balance int := 0;
  v_new_balance int;
  v_tax_cents int := 0;
  v_result public.cashbook_entries;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  if p_amount_cents <= 0 then
    raise exception 'invalid_amount: Betrag muss groesser 0 sein';
  end if;

  -- Fortlaufende Nummer ermitteln (lückenlos)
  select coalesce(max(entry_number), 0) + 1 into v_next_number
  from public.cashbook_entries
  where venue_id = p_venue_id;

  -- Letzten Kassenbestand ermitteln
  select balance_after_cents into v_current_balance
  from public.cashbook_entries
  where venue_id = p_venue_id
  order by entry_number desc
  limit 1;

  v_current_balance := coalesce(v_current_balance, 0);

  if p_is_income then
    v_new_balance := v_current_balance + p_amount_cents;
  else
    v_new_balance := v_current_balance - p_amount_cents;
  end if;

  -- Steueranteil berechnen falls Steuersatz angegeben
  if p_tax_rate is not null and p_tax_rate > 0 then
    -- Brutto -> Netto Steuer = Brutto - (Brutto / (1 + satz/100))
    v_tax_cents := (p_amount_cents::numeric - (p_amount_cents::numeric / (1.0 + (p_tax_rate / 100.0))))::int;
  end if;

  insert into public.cashbook_entries (
    venue_id, entry_number, booking_date, entry_type, amount_cents,
    is_income, balance_after_cents, tax_rate_percent, tax_cents,
    receipt_number, reference, description, created_by
  ) values (
    p_venue_id, v_next_number, current_date, p_entry_type, p_amount_cents,
    p_is_income, v_new_balance, p_tax_rate, v_tax_cents,
    nullif(trim(coalesce(p_receipt_number, '')), ''), p_reference, trim(p_description), auth.uid()
  ) returning * into v_result;

  return v_result;
end;
$$;

-- ============================================================================
-- 5. Betreiber RPC: TSE-Signierung simulieren (KassenSichV)
-- ============================================================================

create or replace function public.operator_sign_tse_transaction(
  p_venue_id uuid,
  p_order_id uuid default null,
  p_process_type text default 'Kassenbeleg-V1',
  p_amount_cents int default 0
)
returns public.tse_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_tx int;
  v_next_sig int;
  v_started timestamptz := now() - interval '3 seconds';
  v_finished timestamptz := now();
  v_process_data text;
  v_signature text;
  v_qr_data text;
  v_result public.tse_transactions;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  -- Transaktions- und Signaturzähler fortführen
  select coalesce(max(transaction_number), 0) + 1, coalesce(max(signature_counter), 0) + 1
    into v_next_tx, v_next_sig
  from public.tse_transactions
  where venue_id = p_venue_id;

  v_process_data := concat(
    'Beleg^', (p_amount_cents::numeric / 100.0)::text, '_EUR^Bar'
  );

  -- Simulierte kryptografische Signatur (SHA256 Hash)
  v_signature := encode(
    extensions.digest(
      concat(p_venue_id::text, ':', v_next_tx::text, ':', v_next_sig::text, ':', v_process_data, ':', v_finished::text),
      'sha256'
    ),
    'base64'
  );

  -- Standard KassenSichV / DSFinV-K QR-String Format:
  -- V0;Kassen-ID;Transaktionsnr;Start;Ende;Signaturzähler;Signatur;Seriennr
  v_qr_data := concat(
    'V0;KL-CASH-01;', v_next_tx::text, ';',
    to_char(v_started at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), ';',
    to_char(v_finished at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), ';',
    v_next_sig::text, ';', substring(v_signature from 1 for 24), ';TSE-KL-DEMO-001'
  );

  insert into public.tse_transactions (
    venue_id, order_id, tse_serial, transaction_number, signature_counter,
    started_at, finished_at, process_type, process_data, signature_value, qr_code_data
  ) values (
    p_venue_id, p_order_id, 'TSE-KL-DEMO-001', v_next_tx, v_next_sig,
    v_started, v_finished, p_process_type, v_process_data, v_signature, v_qr_data
  ) returning * into v_result;

  return v_result;
end;
$$;

commit;
