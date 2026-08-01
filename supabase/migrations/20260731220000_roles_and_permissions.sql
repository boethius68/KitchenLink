-- KL-ROLE-001: Rollen und Rechte (Blueprint §9.1, Meilenstein 2).
--
-- Bis hierher galt: **wer angemeldet ist, darf alles.** `is_venue_staff` prüft
-- die Mitgliedschaft, nicht die Befugnis — also konnte jede Servicekraft die
-- Kasse abschließen, eine Zahlung stornieren und Geld aus der Schublade
-- nehmen. Blueprint §9.1 verlangt Standardrollen und „sensible Aktionen per
-- besonderem Recht".
--
-- **Zuschnitt, bewusst eng:** diese Migration führt genau fünf Rechte ein — und
-- erzwingt alle fünf. Kein Recht wird definiert, das nirgends geprüft wird:
--
--   shift.open        Betriebsschicht öffnen
--   shift.close       Kasse zählen und abschließen
--   cash.movement     Entnahme, Ausgabe, Einlage buchen
--   payments.refund   Zahlung stornieren
--   staff.manage      Personal und Rollen verwalten
--
-- Alles andere — bestellen, Status ändern, Station freigeben, kassieren,
-- Rechnung lesen — bleibt jedem Personal offen. Das ist keine Lücke, sondern
-- der Betrieb: Küche, Bar und Service brauchen genau diese Handgriffe. Die
-- Konfigurationsrechte (Karte veröffentlichen, Tische ändern) sind eine eigene
-- Scheibe und kommen zusammen mit ihrer Durchsetzung, nicht davor.
--
-- Die Rollen liegen **je Venue** in einer Tabelle statt als Aufzählung im Code.
-- Blueprint §9.1 verlangt später „eigene Rollen mit granularen Rechten"; das
-- ist dann ein Datensatz mehr, kein Umbau.

begin;

-- ============================================================================
-- 1. Rollen
-- ============================================================================

create table if not exists public.venue_roles (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  -- Stabiler Schlüssel für Code und Fremdschlüssel; `name` ist die Anzeige.
  key text not null check (key ~ '^[a-z][a-z0-9_]{1,30}$'),
  name text not null,
  permissions text[] not null default '{}',
  -- Mitgelieferte Rollen sind nicht löschbar; eigene Rollen später schon.
  is_builtin boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (venue_id, key)
);

create index if not exists venue_roles_venue_idx on public.venue_roles(venue_id, sort_order);

-- Die neun Standardrollen aus Blueprint §9.1. Jede trägt nur Rechte, die es
-- heute wirklich gibt — eine leere Rechteliste heißt „darf alles Alltägliche,
-- aber nichts Sensibles", nicht „darf nichts".
create or replace function public.kitchenlink_seed_venue_roles(p_venue_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.venue_roles (venue_id, key, name, permissions, is_builtin, sort_order)
  values
    (p_venue_id, 'owner', 'Inhaber',
     array['shift.open', 'shift.close', 'cash.movement', 'payments.refund', 'staff.manage'],
     true, 10),
    (p_venue_id, 'manager', 'Manager',
     array['shift.open', 'shift.close', 'cash.movement', 'payments.refund', 'staff.manage'],
     true, 20),
    (p_venue_id, 'shift_lead', 'Schichtleitung',
     array['shift.open', 'shift.close', 'cash.movement', 'payments.refund'],
     true, 30),
    (p_venue_id, 'service', 'Service', '{}', true, 40),
    (p_venue_id, 'kitchen', 'Küche', '{}', true, 50),
    (p_venue_id, 'bar', 'Bar', '{}', true, 60),
    (p_venue_id, 'driver', 'Fahrer', '{}', true, 70),
    (p_venue_id, 'stock', 'Lager', '{}', true, 80),
    (p_venue_id, 'accounting', 'Buchhaltung', '{}', true, 90)
  on conflict (venue_id, key) do update
    set name = excluded.name,
        permissions = excluded.permissions,
        sort_order = excluded.sort_order,
        is_builtin = true;
end;
$$;

-- Jede neue Venue bekommt ihre Rollen sofort — sonst hinge die erste
-- Personalzuordnung an einer Zeile, die es noch nicht gibt.
create or replace function public.kitchenlink_venue_roles_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.kitchenlink_seed_venue_roles(new.id);
  return new;
end;
$$;

drop trigger if exists venues_seed_roles on public.venues;
create trigger venues_seed_roles
  after insert on public.venues
  for each row execute function public.kitchenlink_venue_roles_trigger();

-- Bestandsvenues nachziehen.
do $$
declare
  v_venue record;
begin
  for v_venue in select id from public.venues loop
    perform public.kitchenlink_seed_venue_roles(v_venue.id);
  end loop;
end;
$$;

-- ============================================================================
-- 2. Personal trägt eine echte Rolle
-- ============================================================================

-- `venue_staff.role` war per CHECK auf den einen Wert 'operator' festgenagelt.
-- Bestehendes Personal war bis heute uneingeschränkt handlungsfähig; es wird
-- deshalb zu 'owner' und **verliert nichts**. Alles andere wäre eine stille
-- Entrechtung durch eine Migration.
alter table public.venue_staff drop constraint if exists venue_staff_role_check;

update public.venue_staff set role = 'owner' where role = 'operator';

-- Der Spaltendefault stand auf 'operator' — also faktisch auf „darf alles".
-- Für neue Zeilen gilt ab jetzt die **geringste** Befugnis: wer ohne genannte
-- Rolle eingetragen wird, kann arbeiten, aber nicht die Kasse abschließen.
alter table public.venue_staff alter column role set default 'service';

-- Ab jetzt garantiert ein Fremdschlüssel, dass jede Rolle existiert — statt
-- einer Aufzählung, die bei jeder neuen Rolle mitgepflegt werden müsste.
alter table public.venue_staff drop constraint if exists venue_staff_role_fk;
alter table public.venue_staff
  add constraint venue_staff_role_fk
  foreign key (venue_id, role) references public.venue_roles(venue_id, key)
  on update cascade;

alter table public.venue_roles enable row level security;

drop policy if exists "venue_roles_staff_read" on public.venue_roles;
create policy "venue_roles_staff_read" on public.venue_roles
  for select
  to authenticated
  using (public.is_venue_staff(venue_id));

-- ============================================================================
-- 3. Die Rechteprüfung
-- ============================================================================

create or replace function public.has_venue_permission(
  p_venue_id uuid,
  p_permission text
)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.venue_staff vs
    join public.venue_roles vr
      on vr.venue_id = vs.venue_id and vr.key = vs.role
    where vs.user_id = auth.uid()
      and vs.venue_id = p_venue_id
      and p_permission = any(vr.permissions)
  );
$$;

revoke all on function public.has_venue_permission(uuid, text) from public, anon;
grant execute on function public.has_venue_permission(uuid, text) to authenticated;

-- Ein Aufruf statt vier Zeilen in jeder RPC: Venue auflösen, Mitgliedschaft
-- und Recht prüfen, sonst sprechend abbrechen. Gibt die Venue-ID zurück.
create or replace function public.kitchenlink_require_permission(
  p_venue_slug text,
  p_permission text
)
returns uuid
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
begin
  if auth.uid() is null then
    raise exception 'permission_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'permission_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'permission_forbidden: kein Personal dieser Venue';
  end if;

  if not public.has_venue_permission(v_venue_id, p_permission) then
    raise exception
      'permission_denied: dieser Zugang darf % nicht', p_permission;
  end if;

  return v_venue_id;
end;
$$;

revoke all on function public.kitchenlink_require_permission(text, text) from public, anon;
grant execute on function public.kitchenlink_require_permission(text, text) to authenticated;

-- Was der angemeldete Zugang in dieser Venue darf. Die App fragt das einmal
-- und sperrt danach, was gesperrt gehört — statt den Nutzer in einen
-- Serverfehler laufen zu lassen.
create or replace function public.operator_my_permissions(p_venue_slug text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_role public.venue_roles%rowtype;
  v_key text;
begin
  if auth.uid() is null then
    raise exception 'permission_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'permission_unknown_venue: %', p_venue_slug;
  end if;

  select vs.role into v_key
  from public.venue_staff vs
  where vs.user_id = auth.uid() and vs.venue_id = v_venue_id;

  if v_key is null then
    return jsonb_build_object('role', null, 'role_name', null, 'permissions', '[]'::jsonb);
  end if;

  select * into v_role
  from public.venue_roles
  where venue_id = v_venue_id and key = v_key;

  return jsonb_build_object(
    'role', v_role.key,
    'role_name', v_role.name,
    'permissions', to_jsonb(v_role.permissions)
  );
end;
$$;

revoke all on function public.operator_my_permissions(text) from public, anon;
grant execute on function public.operator_my_permissions(text) to authenticated;

-- ============================================================================
-- 4. Die sensiblen Aktionen prüfen ab jetzt das Recht
-- ============================================================================

-- Vier Funktionen werden ersetzt. Der einzige Unterschied zur vorherigen
-- Fassung ist der Austausch der Mitgliedschaftsprüfung gegen die
-- Rechteprüfung; die Fachlogik darunter ist unverändert.

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
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'shift.open');

  if coalesce(p_opening_cash_cents, 0) < 0 then
    raise exception 'shift_invalid_opening_cash';
  end if;

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
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'cash.movement');

  if p_kind not in ('payout', 'expense', 'deposit') then
    raise exception 'cash_invalid_kind: %', p_kind;
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'cash_invalid_amount';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'cash_invalid_idempotency_key';
  end if;

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
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'shift.close');

  if p_counted_cash_cents is null or p_counted_cash_cents < 0 then
    raise exception 'shift_invalid_count: gezähltes Bargeld fehlt';
  end if;

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
    'variance_cents', v_variance,
    'totals', v_totals
  );
end;
$$;

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
  v_venue_id uuid;
  v_payment public.payments%rowtype;
  v_reopened boolean := false;
  v_table_id uuid;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'payments.refund');

  select * into v_payment
  from public.payments
  where id = p_payment_id and venue_id = v_venue_id;
  if not found then
    raise exception 'refund_unknown_payment';
  end if;

  if v_payment.status = 'refunded' then
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

-- ============================================================================
-- 5. Personal verwalten
-- ============================================================================

create or replace function public.operator_venue_team(p_venue_slug text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_rows jsonb;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.sort_order, t.email), '[]'::jsonb)
    into v_rows
  from (
    select vs.user_id,
           u.email,
           vs.role,
           vr.name as role_name,
           vr.sort_order,
           vs.created_at,
           (vs.user_id = auth.uid()) as is_me
    from public.venue_staff vs
    join public.venue_roles vr on vr.venue_id = vs.venue_id and vr.key = vs.role
    left join auth.users u on u.id = vs.user_id
    where vs.venue_id = v_venue_id
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_venue_team(text) from public, anon;
grant execute on function public.operator_venue_team(text) to authenticated;

create or replace function public.operator_venue_roles(p_venue_slug text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'permission_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'permission_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'permission_forbidden: kein Personal dieser Venue';
  end if;

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.sort_order), '[]'::jsonb)
    into v_rows
  from (
    select key, name, permissions, is_builtin, sort_order
    from public.venue_roles
    where venue_id = v_venue_id
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_venue_roles(text) from public, anon;
grant execute on function public.operator_venue_roles(text) to authenticated;

-- Rolle ändern. Drei Sperren, die verhindern, dass eine Venue führungslos wird
-- oder jemand sich selbst aussperrt.
create or replace function public.operator_set_staff_role(
  p_venue_slug text,
  p_user_id uuid,
  p_role text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_current text;
  v_owner_count int;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

  -- (1) Niemand ändert die eigene Rolle. Sonst stuft sich der letzte Inhaber
  -- versehentlich herunter und kommt nicht mehr zurück.
  if p_user_id = auth.uid() then
    raise exception 'staff_self_change: die eigene Rolle kann nicht geändert werden';
  end if;

  select vs.role into v_current
  from public.venue_staff vs
  where vs.venue_id = v_venue_id and vs.user_id = p_user_id;
  if v_current is null then
    raise exception 'staff_unknown: gehört nicht zum Personal dieser Venue';
  end if;

  if not exists (
    select 1 from public.venue_roles
    where venue_id = v_venue_id and key = p_role
  ) then
    raise exception 'staff_unknown_role: %', p_role;
  end if;

  -- (2) Ein Manager darf keinen Inhaber umstufen — sonst wäre die
  -- Inhaberrolle nur noch dem Namen nach die höchste.
  if v_current = 'owner'
     and not public.has_venue_permission(v_venue_id, 'staff.manage') then
    raise exception 'staff_forbidden';
  end if;
  if v_current = 'owner' and not exists (
    select 1 from public.venue_staff
    where venue_id = v_venue_id and user_id = auth.uid() and role = 'owner'
  ) then
    raise exception 'staff_owner_protected: nur ein Inhaber kann einen Inhaber umstufen';
  end if;

  -- (3) Der letzte Inhaber bleibt Inhaber.
  if v_current = 'owner' and p_role <> 'owner' then
    select count(*) into v_owner_count
    from public.venue_staff
    where venue_id = v_venue_id and role = 'owner';
    if v_owner_count <= 1 then
      raise exception 'staff_last_owner: die Venue braucht mindestens einen Inhaber';
    end if;
  end if;

  update public.venue_staff
  set role = p_role
  where venue_id = v_venue_id and user_id = p_user_id;

  return jsonb_build_object('user_id', p_user_id, 'role', p_role);
end;
$$;

revoke all on function public.operator_set_staff_role(text, uuid, text) from public, anon;
grant execute on function public.operator_set_staff_role(text, uuid, text) to authenticated;

-- Personal hinzufügen. Das Konto muss es schon geben — KitchenLink legt keine
-- fremden Konten an; der Mitarbeiter registriert sich selbst und wird dann
-- zugeordnet.
create or replace function public.operator_add_staff(
  p_venue_slug text,
  p_email text,
  p_role text default 'service'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_user_id uuid;
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

  if v_email = '' then
    raise exception 'staff_invalid_email';
  end if;

  if not exists (
    select 1 from public.venue_roles where venue_id = v_venue_id and key = p_role
  ) then
    raise exception 'staff_unknown_role: %', p_role;
  end if;

  select u.id into v_user_id from auth.users u where lower(u.email) = v_email;
  if v_user_id is null then
    raise exception
      'staff_no_account: zu % gibt es kein Konto. Erst registrieren, dann zuordnen.', v_email;
  end if;

  insert into public.venue_staff (user_id, venue_id, role)
  values (v_user_id, v_venue_id, p_role)
  on conflict (user_id, venue_id) do nothing;

  return jsonb_build_object('user_id', v_user_id, 'email', v_email, 'role', p_role);
end;
$$;

revoke all on function public.operator_add_staff(text, text, text) from public, anon;
grant execute on function public.operator_add_staff(text, text, text) to authenticated;

create or replace function public.operator_remove_staff(
  p_venue_slug text,
  p_user_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
  v_current text;
  v_owner_count int;
begin
  v_venue_id := public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

  if p_user_id = auth.uid() then
    raise exception 'staff_self_change: der eigene Zugang kann nicht entfernt werden';
  end if;

  select vs.role into v_current
  from public.venue_staff vs
  where vs.venue_id = v_venue_id and vs.user_id = p_user_id;
  if v_current is null then
    raise exception 'staff_unknown: gehört nicht zum Personal dieser Venue';
  end if;

  if v_current = 'owner' then
    if not exists (
      select 1 from public.venue_staff
      where venue_id = v_venue_id and user_id = auth.uid() and role = 'owner'
    ) then
      raise exception 'staff_owner_protected: nur ein Inhaber kann einen Inhaber entfernen';
    end if;
    select count(*) into v_owner_count
    from public.venue_staff
    where venue_id = v_venue_id and role = 'owner';
    if v_owner_count <= 1 then
      raise exception 'staff_last_owner: die Venue braucht mindestens einen Inhaber';
    end if;
  end if;

  delete from public.venue_staff
  where venue_id = v_venue_id and user_id = p_user_id;

  return jsonb_build_object('user_id', p_user_id, 'removed', true);
end;
$$;

revoke all on function public.operator_remove_staff(text, uuid) from public, anon;
grant execute on function public.operator_remove_staff(text, uuid) to authenticated;

-- ============================================================================
-- 6. Wer ein Restaurant anlegt, ist sein Inhaber
-- ============================================================================

-- Bisher stand dort 'operator'. Der Fremdschlüssel oben würde das jetzt
-- ablehnen, und fachlich war es ohnehin nie gemeint: wer anlegt, ist Inhaber.
--
-- Der Rumpf ist wortgleich mit `20260731180000_operator_create_venue.sql`;
-- geändert ist **ein einziges Wort** ('operator' → 'owner'). Alles andere —
-- Fehlerkennungen, Grenzen, Reihenfolge der Prüfungen, der Name der leeren
-- Karte — bleibt, weil `scripts/tests/venue-onboarding.sql` darauf prüft.
create or replace function public.operator_create_venue(
  p_name text,
  p_slug text,
  p_timezone text default 'Europe/Berlin'
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_slug text := lower(btrim(coalesce(p_slug, '')));
  v_venue_id uuid;
  v_owned int;
begin
  if v_user is null then
    raise exception 'venue_unauthenticated: Anmeldung erforderlich';
  end if;
  -- Ein anonymer Gast darf bestellen, aber kein Restaurant eröffnen.
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'venue_anonymous_not_allowed: Betreiberkonto erforderlich';
  end if;

  if char_length(v_name) < 2 or char_length(v_name) > 120 then
    raise exception 'venue_invalid_name: 2 bis 120 Zeichen';
  end if;
  -- Der Slug steht später in der Gast-URL. Deshalb eng gefasst und nicht
  -- „irgendwie schon gültig": Kleinbuchstaben, Ziffern, Bindestriche.
  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     or char_length(v_slug) < 3
     or char_length(v_slug) > 60 then
    raise exception 'venue_invalid_slug: 3 bis 60 Zeichen, nur a-z, 0-9 und Bindestrich';
  end if;

  -- Sandbox-Grenze gegen versehentliche Massenanlage. Kein Produktlimit.
  select count(*) into v_owned
  from public.venue_staff s
  where s.user_id = v_user;
  if v_owned >= 5 then
    raise exception 'venue_limit_reached: In der Sandbox sind fünf Restaurants je Konto möglich';
  end if;

  if exists (select 1 from public.venues v where v.slug = v_slug) then
    raise exception 'venue_slug_taken: % ist schon vergeben', v_slug;
  end if;

  insert into public.venues (name, slug, timezone)
  values (v_name, v_slug, coalesce(nullif(btrim(p_timezone), ''), 'Europe/Berlin'))
  returning id into v_venue_id;

  -- Der Trigger aus Abschnitt 1 hat die Rollen dieser Venue bereits angelegt.
  insert into public.venue_staff (user_id, venue_id, role)
  values (v_user, v_venue_id, 'owner');

  -- Eine leere aktive Karte, damit die Gastseite sofort eine gültige Venue
  -- vorfindet statt eines halb angelegten Zustands. Der erste Scan ersetzt sie.
  insert into public.menus (venue_id, name, active)
  values (v_venue_id, 'Standard', true);

  return jsonb_build_object(
    'venue_id', v_venue_id,
    'name', v_name,
    'slug', v_slug
  );
end;
$$;

commit;
