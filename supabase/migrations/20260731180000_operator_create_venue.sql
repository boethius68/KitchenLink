-- KL-ONBOARD-001: Eigenes Restaurant anlegen (Blueprint §5, Meilenstein 1.3).
--
-- Bis hierher gab es genau eine Venue: `alte-muehle`, im Seed angelegt und in
-- der App fest verdrahtet. Wer das Produkt für ein zweites Lokal sehen wollte,
-- musste SQL schreiben (`SANDBOX_SETUP.md` §6.1 legt `venue_staff` von Hand
-- an). Damit war der Kern-Pitch — „Speisekarte scannen, Restaurant starten" —
-- genau an der Stelle zu Ende, an der er anfangen sollte.
--
-- Diese Migration erlaubt es einem angemeldeten Konto, sein eigenes Restaurant
-- anzulegen und dabei selbst dessen Personal zu werden. Alles Weitere — Karte
-- veröffentlichen, Tische, Bestellungen, Rechnung — funktioniert danach ohne
-- weitere Einrichtung, weil jede dieser RPCs ohnehin über `is_venue_staff`
-- gegen die Venue prüft.

begin;

-- ============================================================================
-- 1. Restaurant anlegen
-- ============================================================================

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

  insert into public.venue_staff (user_id, venue_id, role)
  values (v_user, v_venue_id, 'operator');

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

revoke all on function public.operator_create_venue(text, text, text) from public, anon;
grant execute on function public.operator_create_venue(text, text, text) to authenticated;

-- ============================================================================
-- 2. Freien Slug vorschlagen
-- ============================================================================

-- Der Name kommt vom Betreiber, der Slug soll er nicht erfinden müssen. Die
-- Funktion hängt bei Bedarf eine Zahl an, statt den Betreiber raten zu lassen.
create or replace function public.operator_suggest_venue_slug(
  p_slug text
) returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_base text := lower(btrim(coalesce(p_slug, '')));
  v_candidate text;
  v_suffix int := 1;
begin
  if v_base !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or char_length(v_base) < 3 then
    raise exception 'venue_invalid_slug: 3 bis 60 Zeichen, nur a-z, 0-9 und Bindestrich';
  end if;

  v_candidate := v_base;
  while exists (select 1 from public.venues v where v.slug = v_candidate) loop
    v_suffix := v_suffix + 1;
    v_candidate := v_base || '-' || v_suffix;
    if v_suffix > 999 then
      raise exception 'venue_slug_exhausted';
    end if;
  end loop;

  return v_candidate;
end;
$$;

revoke all on function public.operator_suggest_venue_slug(text) from public, anon;
grant execute on function public.operator_suggest_venue_slug(text) to authenticated;

-- ============================================================================
-- 3. Eigene Restaurants lesen
-- ============================================================================

-- `venue_staff` hat bereits eine Self-Read-Policy, `venues` ist öffentlich
-- lesbar — die App könnte das auch einbetten. Die Funktion existiert trotzdem,
-- damit die Zuordnung „welche Venue gehört mir" **eine** Quelle hat und die
-- App keine Join-Semantik nachbauen muss.
create or replace function public.operator_my_venues()
returns table (
  venue_id uuid,
  name text,
  slug text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'venue_unauthenticated: Anmeldung erforderlich';
  end if;

  return query
  select v.id, v.name, v.slug
  from public.venue_staff s
  join public.venues v on v.id = s.venue_id
  where s.user_id = v_user
  order by v.name;
end;
$$;

revoke all on function public.operator_my_venues() from public, anon;
grant execute on function public.operator_my_venues() to authenticated;

commit;
