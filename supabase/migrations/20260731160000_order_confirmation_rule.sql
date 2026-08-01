-- KL-ORDER-001: Annahmeregel (Blueprint §6.3, Meilenstein 1.8).
--
-- Bisher galt für jede Bestellung dasselbe: eingegangen heißt angenommen. Der
-- Blueprint sieht das als Standard vor — „Gastbestellungen werden standardmäßig
-- nach erfolgreicher Validierung automatisch angenommen" —, verlangt aber, dass
-- ein Betrieb die Bestätigungspflicht einschalten kann.
--
-- Umgesetzt ist die Regel **je Kanal** (`dine_in`, `bar`, `pickup`), weil das
-- der Fall ist, den ein Betrieb wirklich unterscheidet: Abholung erst bestätigen,
-- am Tisch durchlaufen lassen. Standort-, Bereichs- und Zeitfenster-Regeln
-- (ebenfalls §6.3) bleiben eine spätere Erweiterung derselben Spalte.
--
-- Die Regel ändert **nicht**, wie eine Bestellung entsteht: sie kommt weiter als
-- `pending` an. Sie ändert, wer sie als Nächstes sieht — die Station erst nach
-- `accepted`.

begin;

-- ============================================================================
-- 1. Regel je Venue
-- ============================================================================

alter table public.venues
  add column if not exists order_confirmation_channels text[] not null default '{}';

comment on column public.venues.order_confirmation_channels is
  'Kanäle, die vor der Zubereitung bestätigt werden müssen. Leer = alles läuft '
  'automatisch durch (Blueprint §6.3, Standardfall).';

-- ============================================================================
-- 2. Abgelehnte Bestellung
-- ============================================================================

-- `rejected` fehlte im Statusmodell der Datenbank, obwohl Blueprint §6.4 es
-- führt. Ohne den Wert müsste eine abgelehnte Bestellung als `canceled`
-- verbucht werden — das ist etwas anderes: storniert wird, was schon lief.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_status_check'
      and pg_get_constraintdef(oid) like '%rejected%'
  ) then
    alter table public.orders drop constraint if exists orders_status_check;
    alter table public.orders
      add constraint orders_status_check check (
        status in ('pending', 'accepted', 'preparing', 'ready', 'served',
                   'canceled', 'rejected')
      );
  end if;
end;
$$;

alter table public.orders
  add column if not exists rejected_at timestamptz,
  add column if not exists rejection_reason text;

-- ============================================================================
-- 3. Regel setzen
-- ============================================================================

create or replace function public.operator_set_confirmation_channels(
  p_venue_slug text,
  p_channels text[]
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_clean text[];
begin
  if v_user is null then
    raise exception 'confirmation_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'confirmation_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'confirmation_forbidden: kein Personal dieser Venue';
  end if;

  select coalesce(array_agg(distinct channel order by channel), '{}')
    into v_clean
  from unnest(coalesce(p_channels, '{}')) as channel
  where channel in ('dine_in', 'bar', 'pickup');

  if array_length(coalesce(p_channels, '{}'), 1) is distinct from
     array_length(v_clean, 1) then
    raise exception 'confirmation_invalid_channel';
  end if;

  update public.venues
  set order_confirmation_channels = v_clean
  where id = v_venue_id;

  return jsonb_build_object('channels', to_jsonb(v_clean));
end;
$$;

revoke all on function public.operator_set_confirmation_channels(text, text[])
  from public, anon;
grant execute on function public.operator_set_confirmation_channels(text, text[])
  to authenticated;

-- ============================================================================
-- 4. Ablehnen
-- ============================================================================

-- Ablehnen ist der Gegenzug zum Annehmen und nur vor der Zubereitung möglich.
-- Ist die Küche schon dran, ist Stornieren der richtige Weg — das unterscheidet
-- sich fachlich und soll sich auch in den Daten unterscheiden.
create or replace function public.operator_reject_order(
  p_venue_slug text,
  p_order_id uuid,
  p_reason text default ''
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_order record;
begin
  if v_user is null then
    raise exception 'reject_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'reject_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'reject_forbidden: kein Personal dieser Venue';
  end if;

  select o.* into v_order
  from public.orders o
  where o.id = p_order_id and o.venue_id = v_venue_id;
  if not found then
    raise exception 'reject_unknown_order';
  end if;

  if v_order.status = 'rejected' then
    return jsonb_build_object('order_id', p_order_id, 'replayed', true);
  end if;
  if v_order.status <> 'pending' then
    raise exception 'reject_too_late: nur eine unbestätigte Bestellung kann abgelehnt werden';
  end if;

  update public.orders
  set status = 'rejected',
      rejected_at = now(),
      rejection_reason = coalesce(nullif(btrim(p_reason), ''), 'ohne Angabe')
  where id = p_order_id;

  return jsonb_build_object('order_id', p_order_id, 'replayed', false);
end;
$$;

revoke all on function public.operator_reject_order(text, uuid, text)
  from public, anon;
grant execute on function public.operator_reject_order(text, uuid, text)
  to authenticated;

commit;
