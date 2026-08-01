-- KL-ROLE-002: Manager-PIN als einmalige Freigabe (Blueprint §9.1).
--
-- KL-ROLE-001 hat die eine Hälfte von §9.1 gebaut: „sensible Aktionen per
-- besonderem Recht **oder** Manager-PIN". Umgesetzt war nur das Recht — und
-- damit fehlt genau der Fall, für den die PIN gedacht ist: eine Servicekraft
-- steht am Tisch, eine Zahlung muss storniert werden, und die Führungskraft
-- gibt **diese eine** Aktion vor Ort frei, ohne dass sich jemand ab- und wieder
-- anmeldet. Ohne PIN muss die Servicekraft den Manager holen — oder der
-- Betrieb vergibt reihum `payments.refund` an alle, was die Rechte wertlos
-- macht.
--
-- **Die PIN gehört einer Person, nicht dem Lokal.** Das ist die tragende
-- Entscheidung dieser Scheibe, und sie folgt aus Blueprint §8.2: jeder
-- Zahlungsvorgang ist auditiert. Eine gemeinsame Haus-PIN kann die Frage „wer
-- hat das freigegeben?" prinzipiell nicht beantworten — sie beweist nur, dass
-- irgendwer im Haus sie kannte. Deshalb hinterlegt jede Führungskraft ihre
-- eigene PIN, und die Freigabe trägt ihren Namen.
--
-- Daraus folgt auch, was eine PIN darf: **genau das, was ihr Inhaber selbst
-- dürfte.** Die PIN einer Schichtleitung kann eine Stornierung freigeben, weil
-- Schichtleitung `payments.refund` trägt. Kein Recht wird dabei erfunden.
--
-- **Vier der fünf Rechte sind überbrückbar, `staff.manage` nicht.** Wer per
-- geliehener PIN Personal verwalten dürfte, könnte sich in derselben Minute
-- selbst zum Inhaber machen — die Freigabe wäre dann keine Freigabe für eine
-- Aktion mehr, sondern eine dauerhafte Rechteerhöhung. Personal verwaltet man
-- angemeldet.
--
-- Ablauf:
--
--   1. `operator_set_manager_pin`      Führungskraft hinterlegt ihre PIN.
--   2. `operator_authorize_with_pin`   Manager tippt sie am Gerät der
--                                      Servicekraft ein; zurück kommt ein
--                                      einmaliger, kurzlebiger Token.
--   3. Die eigentliche RPC bekommt den Token als zusätzlichen Parameter und
--      verbraucht ihn — einmal, für diese Venue, dieses Recht und diesen
--      Zugang.
--
-- Jede Freigabe steht danach in `manager_overrides`: wer, für wen, wofür,
-- wann erteilt und wann verbraucht.

begin;

-- ============================================================================
-- 1. Tabellen
-- ============================================================================

-- Die hinterlegten PINs. **Keine Policy, absichtlich:** kein Client liest hier
-- je eine Zeile, auch nicht die eigene. Der Hash hat auf einem Gerät nichts zu
-- suchen — bei vier Ziffern wäre er dort in Sekunden zurückgerechnet. Alle
-- Zugriffe laufen über die `security definer`-Funktionen weiter unten.
create table if not exists public.manager_pins (
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,
  pin_hash text not null,
  updated_at timestamptz not null default now(),
  primary key (venue_id, user_id)
);

-- Fehlversuche werden am **anfragenden** Zugang gezählt, nicht am Manager.
-- Begründung: die PIN identifiziert die Führungskraft erst, wenn sie stimmt —
-- ein falscher Versuch gehört zu niemandem. Am Gerät der Servicekraft gezählt,
-- trifft die Sperre den, der probiert, und legt nicht das ganze Lokal lahm.
create table if not exists public.manager_pin_attempts (
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,
  failed_count int not null default 0,
  last_failed_at timestamptz,
  locked_until timestamptz,
  primary key (venue_id, user_id)
);

-- Das Protokoll. Blueprint §8.2 verlangt, dass jeder Zahlungsvorgang
-- nachvollziehbar ist; eine Freigabe, die ein fehlendes Recht überbrückt,
-- gehört erst recht dazu.
create table if not exists public.manager_overrides (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  permission text not null,
  -- Wessen PIN die Freigabe erteilt hat …
  granted_by uuid not null,
  -- … und an welchem Zugang sie gilt. Ein Token eines anderen Zugangs wird
  -- nicht angenommen, sonst wäre die Freigabe weiterreichbar.
  requested_by uuid not null,
  granted_at timestamptz not null default now(),
  expires_at timestamptz not null,
  -- Nur der Hash. Der Token selbst existiert genau einmal, in der Antwort.
  token_hash text not null unique,
  used_at timestamptz,
  note text,
  context jsonb not null default '{}'::jsonb
);

create index if not exists manager_overrides_venue_idx
  on public.manager_overrides(venue_id, granted_at desc);

alter table public.manager_pins enable row level security;
alter table public.manager_pin_attempts enable row level security;
alter table public.manager_overrides enable row level security;

-- Row Level Security ohne Policy heißt: für `anon` und `authenticated` ist die
-- Tabelle leer und unbeschreibbar. Das ist hier die Absicht und nicht ein
-- vergessener Zusatz — gelesen wird ausschließlich über
-- `operator_recent_overrides`, das sein eigenes Recht prüft und den
-- `token_hash` gar nicht erst herausgibt. Die Grants nehmen wir zusätzlich
-- zurück, damit nicht ein einziges späteres `create policy` alles öffnet.
revoke all on table public.manager_pins from anon, authenticated;
revoke all on table public.manager_pin_attempts from anon, authenticated;
revoke all on table public.manager_overrides from anon, authenticated;

-- ============================================================================
-- 2. Was überbrückbar ist
-- ============================================================================

-- An einer Stelle, damit die Liste nicht an drei Orten auseinanderläuft.
create or replace function public.kitchenlink_pin_overridable(p_permission text)
returns boolean
language sql
immutable
set search_path = pg_temp
as $$
  -- `staff.manage` fehlt hier bewusst (siehe Kopf dieser Datei).
  select p_permission in ('shift.open', 'shift.close', 'cash.movement', 'payments.refund');
$$;

grant execute on function public.kitchenlink_pin_overridable(text) to authenticated;

-- ============================================================================
-- 3. Hashen
-- ============================================================================

-- bcrypt aus pgcrypto. Eine vierstellige PIN hat 10.000 Möglichkeiten — eine
-- einfache Prüfsumme wäre offline in Millisekunden durchprobiert, ein
-- Schlüsselableitungsverfahren braucht dafür Stunden. Zusammen mit der Sperre
-- aus Abschnitt 6 ist das die tragende Absicherung dieses kurzen Geheimnisses.
--
-- `extensions.`-qualifiziert, weil pgcrypto bei Supabase dort liegt und nicht
-- im `search_path` dieser Funktion — genau der Fehler, den KL-WEB-003 erst auf
-- der öffentlichen Instanz gefunden hat (siehe `digest()` in
-- `20260718010000`). Der lokale Testharness bildet dieselbe Lage nach.
--
-- Kostenfaktor 8 statt der üblichen 10: bei einem Freigabeversuch wird gegen
-- **jede** hinterlegte PIN der Venue gerechnet (siehe Abschnitt 6), und die
-- Führungskraft steht dabei am Tisch und wartet.
create or replace function public.kitchenlink_hash_pin(p_pin text)
returns text
language sql
volatile
set search_path = public, pg_temp
as $$
  select extensions.crypt(p_pin, extensions.gen_salt('bf', 8));
$$;

revoke all on function public.kitchenlink_hash_pin(text) from public, anon, authenticated;

-- Prüft eine eingegebene PIN gegen einen gespeicherten Hash.
create or replace function public.kitchenlink_pin_matches(p_pin text, p_hash text)
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select p_hash = extensions.crypt(p_pin, p_hash);
$$;

revoke all on function public.kitchenlink_pin_matches(text, text) from public, anon, authenticated;

-- Der Token, der die Freigabe transportiert. Zwei UUIDs = 256 Zufallsbits;
-- der wird nicht erraten, also genügt für ihn eine einfache Prüfsumme. Die
-- eingebaute `sha256()` liegt in `pg_catalog` und braucht deshalb keine
-- Erweiterung — anders als die PIN, die ein echtes Ableitungsverfahren braucht.
create or replace function public.kitchenlink_hash_override_token(p_token text)
returns text
language sql
immutable
set search_path = pg_temp
as $$
  select encode(sha256(convert_to(p_token, 'UTF8')), 'hex');
$$;

revoke all on function public.kitchenlink_hash_override_token(text) from public, anon, authenticated;

-- ============================================================================
-- 4. PIN hinterlegen
-- ============================================================================

-- Vier bis acht Ziffern. Kürzer ist raten, länger tippt am Tisch niemand.
-- Zurückgewiesen werden zusätzlich die Muster, die einen Großteil aller real
-- vergebenen PINs ausmachen: eine wiederholte Ziffer (0000) und eine gerade
-- Zahlenreihe (1234, 4321). Bei 10.000 Möglichkeiten ist das kein Schikane,
-- sondern der Unterschied zwischen „geraten" und „nicht geraten".
create or replace function public.kitchenlink_validate_pin(p_pin text)
returns text
language plpgsql
immutable
set search_path = pg_temp
as $$
declare
  v_pin text := btrim(coalesce(p_pin, ''));
begin
  if v_pin !~ '^[0-9]{4,8}$' then
    raise exception 'pin_invalid_format: vier bis acht Ziffern';
  end if;
  if v_pin ~ '^(.)\1*$' then
    raise exception 'pin_too_simple: eine durchgehend gleiche Ziffer ist keine PIN';
  end if;
  if strpos('01234567890123456789', v_pin) > 0
     or strpos('98765432109876543210', v_pin) > 0 then
    raise exception 'pin_too_simple: eine fortlaufende Zahlenreihe ist keine PIN';
  end if;
  return v_pin;
end;
$$;

grant execute on function public.kitchenlink_validate_pin(text) to authenticated;

-- Jede Führungskraft hinterlegt ihre PIN **selbst**. Es gibt bewusst keinen
-- Weg, jemand anderem eine PIN zu setzen: eine PIN, die ein Zweiter kennt,
-- beweist bei der nächsten Freigabe nichts mehr.
create or replace function public.operator_set_manager_pin(
  p_venue_slug text,
  p_pin text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_pin text;
begin
  if v_user is null then
    raise exception 'pin_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'pin_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'pin_forbidden: kein Personal dieser Venue';
  end if;

  -- Eine PIN ohne überbrückbares Recht könnte nichts freigeben. Sie
  -- anzunehmen wäre ein stilles Versprechen, das im Betrieb erst am Tisch
  -- auffliegt.
  if not exists (
    select 1
    from public.venue_staff vs
    join public.venue_roles vr on vr.venue_id = vs.venue_id and vr.key = vs.role
    cross join lateral unnest(vr.permissions) as p(permission)
    where vs.venue_id = v_venue_id
      and vs.user_id = v_user
      and public.kitchenlink_pin_overridable(p.permission)
  ) then
    raise exception
      'pin_no_authority: dieser Zugang trägt kein Recht, das eine PIN freigeben könnte';
  end if;

  v_pin := public.kitchenlink_validate_pin(p_pin);

  insert into public.manager_pins (venue_id, user_id, pin_hash, updated_at)
  values (v_venue_id, v_user, public.kitchenlink_hash_pin(v_pin), now())
  on conflict (venue_id, user_id) do update
    set pin_hash = excluded.pin_hash,
        updated_at = now();

  return jsonb_build_object('has_pin', true, 'updated_at', now());
end;
$$;

revoke all on function public.operator_set_manager_pin(text, text) from public, anon;
grant execute on function public.operator_set_manager_pin(text, text) to authenticated;

-- Eigene PIN löschen darf jeder; eine fremde nur, wer Personal verwaltet
-- (vergessene PIN, Austritt). Löschen nimmt nur eine Möglichkeit weg und
-- verschafft keine — deshalb ist es die eine PIN-Operation, die über den
-- eigenen Zugang hinausgeht. Einen Inhaber fasst wie überall sonst nur ein
-- Inhaber an.
create or replace function public.operator_clear_manager_pin(
  p_venue_slug text,
  p_user_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_target uuid;
  v_target_role text;
begin
  if v_user is null then
    raise exception 'pin_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'pin_unknown_venue: %', p_venue_slug;
  end if;

  v_target := coalesce(p_user_id, v_user);

  if v_target = v_user then
    if not public.is_venue_staff(v_venue_id) then
      raise exception 'pin_forbidden: kein Personal dieser Venue';
    end if;
  else
    perform public.kitchenlink_require_permission(p_venue_slug, 'staff.manage');

    select vs.role into v_target_role
    from public.venue_staff vs
    where vs.venue_id = v_venue_id and vs.user_id = v_target;
    if v_target_role is null then
      raise exception 'pin_unknown_staff: gehört nicht zum Personal dieser Venue';
    end if;
    if v_target_role = 'owner' and not exists (
      select 1 from public.venue_staff
      where venue_id = v_venue_id and user_id = v_user and role = 'owner'
    ) then
      raise exception 'staff_owner_protected: nur ein Inhaber kann einen Inhaber ändern';
    end if;
  end if;

  delete from public.manager_pins
  where venue_id = v_venue_id and user_id = v_target;

  return jsonb_build_object('user_id', v_target, 'has_pin', false);
end;
$$;

revoke all on function public.operator_clear_manager_pin(text, uuid) from public, anon;
grant execute on function public.operator_clear_manager_pin(text, uuid) to authenticated;

-- ============================================================================
-- 5. Was die App vorher wissen muss
-- ============================================================================

-- Zwei Fragen, eine Antwort: „habe ich selbst eine PIN?" (für den
-- Team-Bildschirm) und „kann hier überhaupt jemand freigeben?" (für den
-- Bildschirm am Tisch). Ohne die zweite bietet die App eine Freigabe an, die
-- niemand erteilen kann — der Bildschirm muss dann stattdessen sagen, dass
-- noch keine Führungskraft eine PIN hinterlegt hat.
create or replace function public.operator_manager_pin_status(p_venue_slug text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_mine public.manager_pins%rowtype;
  v_authorizers int;
begin
  if v_user is null then
    raise exception 'pin_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'pin_unknown_venue: %', p_venue_slug;
  end if;
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'pin_forbidden: kein Personal dieser Venue';
  end if;

  select * into v_mine
  from public.manager_pins
  where venue_id = v_venue_id and user_id = v_user;

  -- Gezählt wird nur, wer heute noch etwas freigeben könnte: eine
  -- herabgestufte Führungskraft hat vielleicht noch eine PIN in der Tabelle,
  -- aber kein Recht mehr dahinter.
  select count(distinct mp.user_id) into v_authorizers
  from public.manager_pins mp
  join public.venue_staff vs
    on vs.venue_id = mp.venue_id and vs.user_id = mp.user_id
  join public.venue_roles vr
    on vr.venue_id = vs.venue_id and vr.key = vs.role
  cross join lateral unnest(vr.permissions) as p(permission)
  where mp.venue_id = v_venue_id
    and public.kitchenlink_pin_overridable(p.permission);

  return jsonb_build_object(
    'has_pin', v_mine.user_id is not null,
    'updated_at', v_mine.updated_at,
    'authorizers', v_authorizers,
    'overridable', to_jsonb(array[
      'shift.open', 'shift.close', 'cash.movement', 'payments.refund'
    ])
  );
end;
$$;

revoke all on function public.operator_manager_pin_status(text) from public, anon;
grant execute on function public.operator_manager_pin_status(text) to authenticated;

-- ============================================================================
-- 6. Die Freigabe
-- ============================================================================

-- Die Führungskraft tippt nur ihre PIN — keinen Namen, keine Auswahl. Das ist
-- der Handgriff, den der Betrieb erwartet, und er ist eindeutig, solange keine
-- zwei Personen dieselbe PIN führen. Passen zwei, wird **nicht** freigegeben:
-- eine Freigabe, die niemandem sicher zuzuordnen ist, wäre für §8.2 wertlos.
--
-- Eine falsche PIN wirft **keinen** Fehler, sondern gibt `granted = false`
-- zurück. Das ist kein Schönheitsgrund: eine Exception rollt die Transaktion
-- zurück und mit ihr den hochgezählten Fehlversuch — die Sperre würde nie
-- greifen.
create or replace function public.operator_authorize_with_pin(
  p_venue_slug text,
  p_permission text,
  p_pin text,
  p_note text default null,
  p_context jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_attempts public.manager_pin_attempts%rowtype;
  v_failed int;
  v_matches uuid[];
  v_granted_by uuid;
  v_token text;
  v_expires timestamptz;
  v_id uuid;
  -- Fünf Versuche, dann fünf Minuten Ruhe. Mit vier Ziffern wären 10.000
  -- Versuche sonst eine Frage von Minuten.
  c_max_failures constant int := 5;
  c_lock_minutes constant int := 5;
  -- Lang genug, um am Tisch in Ruhe zu tippen; kurz genug, dass eine
  -- vergessene Freigabe nicht den halben Abend gültig bleibt.
  c_ttl_minutes constant int := 5;
begin
  if v_user is null then
    raise exception 'pin_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'pin_unknown_venue: %', p_venue_slug;
  end if;
  -- Auch die anfragende Person muss zum Personal gehören: sonst könnte jeder
  -- angemeldete Gast an einer fremden Venue PINs durchprobieren.
  if not public.is_venue_staff(v_venue_id) then
    raise exception 'pin_forbidden: kein Personal dieser Venue';
  end if;

  if not public.kitchenlink_pin_overridable(p_permission) then
    raise exception
      'pin_permission_not_overridable: % lässt sich nicht per PIN freigeben', p_permission;
  end if;

  -- Wer das Recht ohnehin hat, braucht keine Freigabe — und soll auch keine
  -- Protokollzeile erzeugen, die später wie eine Ausnahme aussieht.
  if public.has_venue_permission(v_venue_id, p_permission) then
    return jsonb_build_object('granted', false, 'reason', 'pin_not_needed');
  end if;

  select * into v_attempts
  from public.manager_pin_attempts
  where venue_id = v_venue_id and user_id = v_user
  for update;

  if v_attempts.locked_until is not null and v_attempts.locked_until > now() then
    return jsonb_build_object(
      'granted', false,
      'reason', 'pin_locked',
      'locked_until', v_attempts.locked_until
    );
  end if;

  -- Eine abgelaufene Sperre beginnt von vorn.
  v_failed := case
    when v_attempts.locked_until is not null and v_attempts.locked_until <= now() then 0
    else coalesce(v_attempts.failed_count, 0)
  end;

  if p_pin is null or btrim(p_pin) = '' then
    return jsonb_build_object('granted', false, 'reason', 'pin_missing');
  end if;

  -- Gegen jede hinterlegte PIN dieser Venue, deren Inhaber das verlangte Recht
  -- **jetzt** trägt. Eine gestern herabgestufte Führungskraft gibt heute nichts
  -- mehr frei, ohne dass jemand ihre PIN löschen müsste.
  select coalesce(array_agg(distinct mp.user_id), '{}'::uuid[]) into v_matches
  from public.manager_pins mp
  join public.venue_staff vs
    on vs.venue_id = mp.venue_id and vs.user_id = mp.user_id
  join public.venue_roles vr
    on vr.venue_id = vs.venue_id and vr.key = vs.role
  where mp.venue_id = v_venue_id
    and p_permission = any(vr.permissions)
    and public.kitchenlink_pin_matches(p_pin, mp.pin_hash);

  if array_length(v_matches, 1) is null then
    v_failed := v_failed + 1;

    insert into public.manager_pin_attempts (
      venue_id, user_id, failed_count, last_failed_at, locked_until
    ) values (
      v_venue_id, v_user, v_failed, now(),
      case when v_failed >= c_max_failures
        then now() + make_interval(mins => c_lock_minutes)
      end
    )
    on conflict (venue_id, user_id) do update
      set failed_count = excluded.failed_count,
          last_failed_at = excluded.last_failed_at,
          locked_until = excluded.locked_until;

    if v_failed >= c_max_failures then
      return jsonb_build_object(
        'granted', false,
        'reason', 'pin_locked',
        'locked_until', now() + make_interval(mins => c_lock_minutes)
      );
    end if;

    return jsonb_build_object(
      'granted', false,
      'reason', 'pin_invalid',
      'attempts_left', c_max_failures - v_failed
    );
  end if;

  if array_length(v_matches, 1) > 1 then
    -- Kein Fehlversuch: die PIN war richtig. Nur eben nicht eindeutig.
    return jsonb_build_object('granted', false, 'reason', 'pin_ambiguous');
  end if;

  v_granted_by := v_matches[1];

  delete from public.manager_pin_attempts
  where venue_id = v_venue_id and user_id = v_user;

  v_token := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
  v_expires := now() + make_interval(mins => c_ttl_minutes);

  insert into public.manager_overrides (
    venue_id, permission, granted_by, requested_by,
    expires_at, token_hash, note, context
  ) values (
    v_venue_id, p_permission, v_granted_by, v_user,
    v_expires, public.kitchenlink_hash_override_token(v_token),
    nullif(btrim(coalesce(p_note, '')), ''),
    coalesce(p_context, '{}'::jsonb)
  ) returning id into v_id;

  return jsonb_build_object(
    'granted', true,
    'override_id', v_id,
    'token', v_token,
    'expires_at', v_expires,
    'permission', p_permission,
    -- Damit die Servicekraft am Bildschirm sieht, in wessen Namen sie gleich
    -- handelt — und es später auf dem Beleg wiederfindet.
    'granted_by_email', (select u.email from auth.users u where u.id = v_granted_by)
  );
end;
$$;

revoke all on function public.operator_authorize_with_pin(text, text, text, text, jsonb)
  from public, anon;
grant execute on function public.operator_authorize_with_pin(text, text, text, text, jsonb)
  to authenticated;

-- ============================================================================
-- 7. Die Prüfung, die eine Freigabe akzeptiert
-- ============================================================================

-- Bewusst ein **eigener Name** statt einer dritten Überladung von
-- `kitchenlink_require_permission`: stünden `(text, text)` und
-- `(text, text, text default null)` nebeneinander, wäre jeder zweistellige
-- Aufruf mehrdeutig und PostgreSQL würde ihn abweisen. Die alte Funktion
-- bleibt unverändert und wird weiter von allem benutzt, was keine Freigabe
-- kennt.
create or replace function public.kitchenlink_require_permission_or_pin(
  p_venue_slug text,
  p_permission text,
  p_override_token text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_override public.manager_overrides%rowtype;
begin
  if v_user is null then
    raise exception 'permission_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'permission_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'permission_forbidden: kein Personal dieser Venue';
  end if;

  -- Das eigene Recht gilt vor jeder Freigabe: ein mitgeschickter Token bleibt
  -- dann unverbraucht und läuft ab. Ein Recht zu haben soll nie teurer sein
  -- als keines zu haben.
  if public.has_venue_permission(v_venue_id, p_permission) then
    return v_venue_id;
  end if;

  if p_override_token is null or btrim(p_override_token) = '' then
    raise exception
      'permission_denied: dieser Zugang darf % nicht', p_permission;
  end if;

  -- Einmalig: `used_at is null` steht in der `where`-Klausel des `update`,
  -- also entscheidet die Datenbank, wer den Token verbraucht. Zwei
  -- gleichzeitige Versuche können nicht beide gewinnen.
  update public.manager_overrides o
  set used_at = now()
  where o.token_hash = public.kitchenlink_hash_override_token(btrim(p_override_token))
    and o.venue_id = v_venue_id
    and o.permission = p_permission
    and o.requested_by = v_user
    and o.used_at is null
    and o.expires_at > now()
  returning * into v_override;

  if v_override.id is null then
    raise exception
      'permission_override_invalid: die Freigabe ist abgelaufen, bereits verbraucht '
      'oder gehört nicht zu dieser Aktion';
  end if;

  -- Zwischen Erteilen und Verbrauchen liegen höchstens Minuten — aber wenn die
  -- Führungskraft in dieser Zeit ihr Recht verloren hat, gilt ihre Freigabe
  -- nicht mehr.
  if not exists (
    select 1
    from public.venue_staff vs
    join public.venue_roles vr on vr.venue_id = vs.venue_id and vr.key = vs.role
    where vs.venue_id = v_venue_id
      and vs.user_id = v_override.granted_by
      and p_permission = any(vr.permissions)
  ) then
    raise exception
      'permission_override_revoked: wer die Freigabe erteilt hat, darf % nicht mehr',
      p_permission;
  end if;

  return v_venue_id;
end;
$$;

revoke all on function public.kitchenlink_require_permission_or_pin(text, text, text)
  from public, anon;
grant execute on function public.kitchenlink_require_permission_or_pin(text, text, text)
  to authenticated;

-- ============================================================================
-- 8. Die vier überbrückbaren Aktionen nehmen eine Freigabe entgegen
-- ============================================================================

-- Jede der vier bekommt **einen** zusätzlichen, vorbelegten Parameter am Ende.
-- `create or replace` kann eine Parameterliste nicht erweitern, deshalb Drop
-- und Create in derselben Transaktion — dasselbe Vorgehen wie bei
-- `guest_web_submit_order_v2` in `20260730120000`. Aufrufer ohne Freigabe
-- übergeben ihn nicht und ändern sich nicht.
--
-- Geändert ist in allen vier Rümpfen **genau die Gate-Zeile**. Die Fachlogik
-- darunter ist wortgleich mit der Fassung aus
-- `20260731220000_roles_and_permissions.sql`.

drop function if exists public.operator_open_shift(text, int, text);

create or replace function public.operator_open_shift(
  p_venue_slug text,
  p_opening_cash_cents int default 0,
  p_idempotency_key text default null,
  p_override_token text default null
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
  v_venue_id := public.kitchenlink_require_permission_or_pin(
    p_venue_slug, 'shift.open', p_override_token
  );

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

revoke all on function public.operator_open_shift(text, int, text, text) from public, anon;
grant execute on function public.operator_open_shift(text, int, text, text) to authenticated;

drop function if exists public.operator_record_cash_movement(text, text, int, text, text);

create or replace function public.operator_record_cash_movement(
  p_venue_slug text,
  p_kind text,
  p_amount_cents int,
  p_idempotency_key text,
  p_reason text default null,
  p_override_token text default null
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
  v_venue_id := public.kitchenlink_require_permission_or_pin(
    p_venue_slug, 'cash.movement', p_override_token
  );

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

revoke all on function public.operator_record_cash_movement(
  text, text, int, text, text, text
) from public, anon;
grant execute on function public.operator_record_cash_movement(
  text, text, int, text, text, text
) to authenticated;

drop function if exists public.operator_close_shift(text, int, uuid, text);

create or replace function public.operator_close_shift(
  p_venue_slug text,
  p_counted_cash_cents int,
  p_shift_id uuid default null,
  p_note text default null,
  p_override_token text default null
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
  v_venue_id := public.kitchenlink_require_permission_or_pin(
    p_venue_slug, 'shift.close', p_override_token
  );

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

revoke all on function public.operator_close_shift(text, int, uuid, text, text) from public, anon;
grant execute on function public.operator_close_shift(text, int, uuid, text, text) to authenticated;

drop function if exists public.operator_refund_payment(text, uuid, text);

create or replace function public.operator_refund_payment(
  p_venue_slug text,
  p_payment_id uuid,
  p_reason text default '',
  p_override_token text default null
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
  v_venue_id := public.kitchenlink_require_permission_or_pin(
    p_venue_slug, 'payments.refund', p_override_token
  );

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

revoke all on function public.operator_refund_payment(text, uuid, text, text) from public, anon;
grant execute on function public.operator_refund_payment(text, uuid, text, text) to authenticated;

-- ============================================================================
-- 9. Das Protokoll lesen
-- ============================================================================

-- Ohne diese Auskunft wäre die Nachvollziehbarkeit nur eine Zusage in einem
-- Migrationskommentar. Der `token_hash` bleibt drin, auch wenn er nutzlos ist —
-- was das Gerät nicht braucht, bekommt es nicht.
create or replace function public.operator_recent_overrides(
  p_venue_slug text,
  p_limit int default 20
) returns jsonb
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

  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.granted_at desc), '[]'::jsonb)
    into v_rows
  from (
    select o.id,
           o.permission,
           o.granted_at,
           o.used_at,
           o.expires_at,
           o.note,
           o.context,
           g.email as granted_by_email,
           r.email as requested_by_email
    from public.manager_overrides o
    left join auth.users g on g.id = o.granted_by
    left join auth.users r on r.id = o.requested_by
    where o.venue_id = v_venue_id
    order by o.granted_at desc
    limit greatest(1, least(coalesce(p_limit, 20), 200))
  ) t;

  return v_rows;
end;
$$;

revoke all on function public.operator_recent_overrides(text, int) from public, anon;
grant execute on function public.operator_recent_overrides(text, int) to authenticated;

commit;
