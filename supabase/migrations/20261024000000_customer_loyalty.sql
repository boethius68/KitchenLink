-- KL-LOYALTY-001: Kundenkonto, Loyalty, Gutscheine & Feedback (Blueprint §13 & Meilenstein 5).
--
-- Unterstützt Kundenbindung, Promotions und Qualitätsfeedback:
-- 1. Kundenstamm & Treuepunkte (`customer_profiles` mit Stufen 'bronze', 'silver', 'gold', 'vip').
-- 2. Gutscheine & Aktionscodes (`vouchers` mit Prozent- oder Festbetragsrabatten und Mindestbestellwerten).
-- 3. Gäste-Feedback (`order_feedbacks` mit 1-5 Sternen und Freitextkommentar).
-- 4. Gast-Web RPCs:
--    - `guest_web_validate_voucher`: Prüft Gültigkeit und berechnet Rabatt in Cents.
--    - `guest_web_submit_order_feedback`: Erfasst Feedback zur Bestellung.
-- 5. Betreiber RPCs:
--    - `operator_list_vouchers` & `operator_create_voucher`: Gutschein-Verwaltung.
--    - `operator_list_feedbacks`: Auswertung von Gäste-Zufriedenheit.
--    - `operator_list_customers`: Treuekunden-Übersicht mit Punkten und Stufen.

begin;

-- ============================================================================
-- 1. Tabellen
-- ============================================================================

create table if not exists public.customer_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  venue_id uuid not null references public.venues(id) on delete cascade,
  email text,
  name text not null,
  phone text,
  loyalty_points int not null default 0 check (loyalty_points >= 0),
  tier text not null default 'bronze' check (tier in ('bronze', 'silver', 'gold', 'vip')),
  total_orders_count int not null default 0 check (total_orders_count >= 0),
  total_spent_cents int not null default 0 check (total_spent_cents >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, email)
);

create index if not exists customer_profiles_venue_idx on public.customer_profiles(venue_id);

alter table public.customer_profiles enable row level security;

create policy "customer_profiles_staff_all" on public.customer_profiles
  for all to authenticated using (public.is_venue_staff(venue_id));

create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  code text not null,
  discount_type text not null check (discount_type in ('percentage', 'fixed_amount')),
  discount_value int not null check (discount_value > 0),
  min_order_cents int not null default 0 check (min_order_cents >= 0),
  max_uses int default null,
  times_used int not null default 0 check (times_used >= 0),
  valid_until timestamptz default null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (venue_id, code)
);

create index if not exists vouchers_venue_idx on public.vouchers(venue_id, code);

alter table public.vouchers enable row level security;

create policy "vouchers_public_read" on public.vouchers
  for select to anon, authenticated using (true);

create policy "vouchers_staff_all" on public.vouchers
  for all to authenticated using (public.is_venue_staff(venue_id));

create table if not exists public.order_feedbacks (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  rating int not null check (rating >= 1 and rating <= 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (order_id)
);

create index if not exists order_feedbacks_venue_idx on public.order_feedbacks(venue_id);

alter table public.order_feedbacks enable row level security;

create policy "order_feedbacks_public_insert" on public.order_feedbacks
  for insert to anon, authenticated with check (true);

create policy "order_feedbacks_staff_select" on public.order_feedbacks
  for select to authenticated using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 2. Gast-Web RPCs: Gutscheinprüfung & Feedback
-- ============================================================================

create or replace function public.guest_web_validate_voucher(
  p_venue_slug text,
  p_code text,
  p_order_total_cents int
)
returns table (
  valid boolean,
  discount_cents int,
  discount_type text,
  discount_value int,
  message text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_venue_id uuid;
  v_voucher record;
  v_discount int := 0;
begin
  select id into v_venue_id from public.venues where slug = p_venue_slug;
  if not found then
    return query select false, 0, ''::text, 0, 'Restaurant nicht gefunden'::text;
    return;
  end if;

  select * into v_voucher
  from public.vouchers
  where venue_id = v_venue_id
    and upper(trim(code)) = upper(trim(p_code))
    and is_active;

  if not found then
    return query select false, 0, ''::text, 0, 'Ungültiger Gutscheincode'::text;
    return;
  end if;

  if v_voucher.valid_until is not null and v_voucher.valid_until < now() then
    return query select false, 0, ''::text, 0, 'Gutschein ist abgelaufen'::text;
    return;
  end if;

  if v_voucher.max_uses is not null and v_voucher.times_used >= v_voucher.max_uses then
    return query select false, 0, ''::text, 0, 'Gutschein wurde bereits maximal eingelöst'::text;
    return;
  end if;

  if p_order_total_cents < v_voucher.min_order_cents then
    return query select false, 0, ''::text, 0, concat('Mindestbestellwert von ', (v_voucher.min_order_cents / 100)::text, ' € nicht erreicht')::text;
    return;
  end if;

  if v_voucher.discount_type = 'percentage' then
    v_discount := (p_order_total_cents * v_voucher.discount_value) / 100;
  else
    v_discount := least(p_order_total_cents, v_voucher.discount_value);
  end if;

  return query select
    true,
    v_discount,
    v_voucher.discount_type,
    v_voucher.discount_value,
    'Gutschein erfolgreich angewendet'::text;
end;
$$;

create or replace function public.guest_web_submit_order_feedback(
  p_order_id uuid,
  p_rating int,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venue_id uuid;
begin
  if p_rating < 1 or p_rating > 5 then
    raise exception 'invalid_rating: Bewertung muss zwischen 1 und 5 Sternen liegen';
  end if;

  select venue_id into v_venue_id
  from public.orders
  where id = p_order_id;

  if not found then
    raise exception 'order_not_found: Bestellung nicht gefunden';
  end if;

  insert into public.order_feedbacks (order_id, venue_id, rating, comment)
  values (p_order_id, v_venue_id, p_rating, nullif(trim(coalesce(p_comment, '')), ''))
  on conflict (order_id) do update
  set
    rating = excluded.rating,
    comment = excluded.comment,
    created_at = now();
end;
$$;

-- ============================================================================
-- 3. Betreiber RPCs: Loyalty, Gutscheine & Feedback
-- ============================================================================

create or replace function public.operator_list_vouchers(
  p_venue_id uuid
)
returns setof public.vouchers
language sql
security definer
set search_path = public
stable
as $$
  select * from public.vouchers
  where venue_id = p_venue_id
  order by created_at desc;
$$;

create or replace function public.operator_create_voucher(
  p_venue_id uuid,
  p_code text,
  p_discount_type text,
  p_discount_value int,
  p_min_order_cents int default 0,
  p_max_uses int default null,
  p_valid_until timestamptz default null
)
returns public.vouchers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_voucher public.vouchers;
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  insert into public.vouchers (
    venue_id, code, discount_type, discount_value, min_order_cents, max_uses, valid_until
  ) values (
    p_venue_id, upper(trim(p_code)), p_discount_type, p_discount_value, p_min_order_cents, p_max_uses, p_valid_until
  ) returning * into v_voucher;

  return v_voucher;
end;
$$;

create or replace function public.operator_list_feedbacks(
  p_venue_id uuid
)
returns table (
  feedback_id uuid,
  order_id uuid,
  order_number text,
  rating int,
  comment text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_venue_staff(p_venue_id) then
    raise exception 'forbidden: nur fuer Mitarbeiter';
  end if;

  return query
  select
    f.id as feedback_id,
    f.order_id,
    upper(substring(f.order_id::text from 1 for 6)) as order_number,
    f.rating,
    f.comment,
    f.created_at
  from public.order_feedbacks f
  where f.venue_id = p_venue_id
  order by f.created_at desc;
end;
$$;

create or replace function public.operator_list_customers(
  p_venue_id uuid
)
returns setof public.customer_profiles
language sql
security definer
set search_path = public
stable
as $$
  select * from public.customer_profiles
  where venue_id = p_venue_id
  order by loyalty_points desc;
$$;

commit;
