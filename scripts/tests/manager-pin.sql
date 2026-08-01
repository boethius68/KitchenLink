-- Funktionstest fuer KL-ROLE-002 (Migration 20260731230000_manager_pin.sql).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Die PIN ueberbrueckt ein fehlendes Recht. Damit ist sie genau der Punkt, an
-- dem KL-ROLE-001 wieder aufgehen koennte — geprueft wird deshalb vor allem,
-- wo sie **nicht** greift: fuer eine andere Aktion, fuer einen anderen Zugang,
-- ein zweites Mal, nach Ablauf, nach einer Herabstufung des Freigebenden und
-- fuer `staff.manage` ueberhaupt nicht.
--
-- Der Test legt eine **eigene Venue** an und raeumt sie am Ende wieder ab: die
-- anderen Tests dieses Verzeichnisses laufen auf derselben Datenbank.

\set ON_ERROR_STOP on

create or replace function pg_temp.expect_error(p_sql text, p_fragment text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception
    when others then
      if position(p_fragment in sqlerrm) = 0 then
        raise exception 'Erwartet Fehler mit "%", bekommen: %', p_fragment, sqlerrm;
      end if;
      return;
  end;
  raise exception 'Erwartet Fehler mit "%", aber der Aufruf war erfolgreich: %',
    p_fragment, p_sql;
end;
$$;

create or replace function pg_temp.assert(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'FEHLGESCHLAGEN: %', p_message;
  end if;
end;
$$;

create or replace function pg_temp.act_as(p_user uuid, p_anonymous boolean)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user, 'is_anonymous', p_anonymous)::text,
    false
  );
end;
$$;

-- Der Token einer Freigabe existiert genau einmal, in der Antwort. Damit
-- mehrere Abschnitte ihn benutzen koennen, wird er hier zwischengelegt.
create table if not exists pg_temp.tokens (name text primary key, value text);

create or replace function pg_temp.remember(p_name text, p_value text)
returns void
language sql
as $$
  insert into pg_temp.tokens values (p_name, p_value)
  on conflict (name) do update set value = excluded.value;
$$;

create or replace function pg_temp.recall(p_name text)
returns text
language sql
stable
as $$ select value from pg_temp.tokens where name = p_name; $$;

-- Konten: Inhaberin, Managerin, Schichtleitung, zwei Servicekraefte, Kueche.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000f1', 'inhaberin@pin.test'),
  ('00000000-0000-0000-0000-0000000000f2', 'managerin@pin.test'),
  ('00000000-0000-0000-0000-0000000000f3', 'schichtleitung@pin.test'),
  ('00000000-0000-0000-0000-0000000000f4', 'service@pin.test'),
  ('00000000-0000-0000-0000-0000000000f5', 'kueche@pin.test'),
  ('00000000-0000-0000-0000-0000000000f6', 'aushilfe@pin.test'),
  ('00000000-0000-0000-0000-0000000000f9', 'gast@pin.test')
on conflict (id) do nothing;

-- ============================================================================
-- 0. Eigene Venue mit Personal
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_create_venue('PIN-Probe', 'pinprobe');

  perform public.operator_add_staff('pinprobe', 'managerin@pin.test', 'manager');
  perform public.operator_add_staff('pinprobe', 'schichtleitung@pin.test', 'shift_lead');
  perform public.operator_add_staff('pinprobe', 'service@pin.test', 'service');
  perform public.operator_add_staff('pinprobe', 'kueche@pin.test', 'kitchen');
  perform public.operator_add_staff('pinprobe', 'aushilfe@pin.test', 'service');
end;
$$;

-- ============================================================================
-- 1. Wer eine PIN hinterlegen darf
-- ============================================================================

-- Eine PIN, die nichts freigeben kann, waere ein stilles Versprechen. Service
-- und Kueche tragen keines der vier ueberbrueckbaren Rechte.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '8317')$q$,
    'pin_no_authority'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f5', false);
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '8317')$q$,
    'pin_no_authority'
  );

  -- Und ein Fremder erst recht nicht.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f9', false);
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '8317')$q$,
    'pin_forbidden'
  );
end;
$$;

-- ============================================================================
-- 2. Was als PIN durchgeht
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f3', false);

  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '831')$q$,
    'pin_invalid_format'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '83a7')$q$,
    'pin_invalid_format'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '123456789')$q$,
    'pin_invalid_format'
  );
  -- Die zwei Muster, die einen Grossteil aller real vergebenen PINs ausmachen.
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '0000')$q$,
    'pin_too_simple'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '1234')$q$,
    'pin_too_simple'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_set_manager_pin('pinprobe', '4321')$q$,
    'pin_too_simple'
  );

  perform public.operator_set_manager_pin('pinprobe', '8317');
end;
$$;

-- Der Hash ist ein Hash: die PIN steht nirgends im Klartext.
do $$
declare
  v_hash text;
begin
  select pin_hash into v_hash
  from public.manager_pins
  where user_id = '00000000-0000-0000-0000-0000000000f3';

  perform pg_temp.assert(v_hash is not null, 'PIN wurde nicht hinterlegt');
  perform pg_temp.assert(v_hash <> '8317', 'PIN darf nicht im Klartext liegen');
  perform pg_temp.assert(
    v_hash like '$2%', 'bcrypt-Hash erwartet, war ' || left(v_hash, 8)
  );
end;
$$;

-- ============================================================================
-- 3. Was die App vorher wissen muss
-- ============================================================================

do $$
declare
  v_status jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f3', false);
  v_status := public.operator_manager_pin_status('pinprobe');
  perform pg_temp.assert((v_status ->> 'has_pin')::boolean, 'Schichtleitung hat eine PIN');

  -- Die Servicekraft sieht nicht, *wer* eine PIN hat — nur, ob ueberhaupt
  -- jemand freigeben koennte. Ohne diese Zahl boete der Bildschirm am Tisch
  -- eine Freigabe an, die niemand erteilen kann.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_status := public.operator_manager_pin_status('pinprobe');
  perform pg_temp.assert(
    (v_status ->> 'has_pin')::boolean = false, 'Service hat keine eigene PIN');
  perform pg_temp.assert(
    (v_status ->> 'authorizers')::int = 1,
    'Genau eine freigabefaehige PIN erwartet, waren ' || (v_status ->> 'authorizers')
  );
end;
$$;

-- ============================================================================
-- 4. Ohne Freigabe bleibt alles, wie KL-ROLE-001 es hinterlassen hat
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    $q$select public.operator_record_cash_movement('pinprobe', 'payout', 500, 'ohne')$q$,
    'permission_denied'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_open_shift('pinprobe', 0, 'ohne')$q$,
    'permission_denied'
  );
  -- Auch ein erfundener Token hilft nicht.
  perform pg_temp.expect_error(
    $q$select public.operator_open_shift('pinprobe', 0, 'erfunden', 'nicht-echt')$q$,
    'permission_override_invalid'
  );
end;
$$;

-- ============================================================================
-- 5. Die falsche PIN
-- ============================================================================

do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);

  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '1379');
  perform pg_temp.assert(
    (v_result ->> 'granted')::boolean = false, 'Falsche PIN gibt nichts frei');
  perform pg_temp.assert(
    v_result ->> 'reason' = 'pin_invalid', 'pin_invalid erwartet, war ' || (v_result ->> 'reason'));
  -- Der Fehlversuch muss die Transaktion ueberleben, sonst greift die Sperre
  -- nie. Deshalb gibt eine falsche PIN eine Antwort zurueck und wirft keinen
  -- Fehler.
  perform pg_temp.assert(
    (v_result ->> 'attempts_left')::int = 4,
    'Vier Versuche uebrig erwartet, waren ' || (v_result ->> 'attempts_left')
  );
  perform pg_temp.assert(
    (select failed_count from public.manager_pin_attempts
     where user_id = '00000000-0000-0000-0000-0000000000f4') = 1,
    'Fehlversuch wurde nicht festgehalten'
  );

  -- Keine Freigabe, kein Protokolleintrag.
  perform pg_temp.assert(
    (select count(*) from public.manager_overrides) = 0,
    'Eine abgelehnte PIN darf keine Freigabe protokollieren'
  );
end;
$$;

-- ============================================================================
-- 6. Was gar nicht erst per PIN geht
-- ============================================================================

do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);

  -- Wer per geliehener PIN Personal verwalten duerfte, koennte sich in
  -- derselben Minute selbst zum Inhaber machen.
  perform pg_temp.expect_error(
    $q$select public.operator_authorize_with_pin('pinprobe', 'staff.manage', '8317')$q$,
    'pin_permission_not_overridable'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_authorize_with_pin('pinprobe', 'menu.publish', '8317')$q$,
    'pin_permission_not_overridable'
  );

  -- Ein Fremder darf an einer fremden Venue keine PINs durchprobieren.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f9', false);
  perform pg_temp.expect_error(
    $q$select public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317')$q$,
    'pin_forbidden'
  );

  -- Und wer das Recht ohnehin hat, erzeugt keine Ausnahme im Protokoll.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.assert(
    v_result ->> 'reason' = 'pin_not_needed',
    'pin_not_needed erwartet, war ' || (v_result ->> 'reason')
  );
end;
$$;

-- ============================================================================
-- 7. Der eigentliche Fall: Storno am Tisch
-- ============================================================================

-- Karte, Tisch, eine Gastbestellung, eine Zahlung.
do $$
declare
  v_table jsonb;
  v_check jsonb;
  v_payment jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_publish_menu_v2(
    'pinprobe',
    jsonb_build_object('categories', jsonb_build_array(
      jsonb_build_object(
        'name', 'Küche', 'kind', 'food', 'sort_order', 0,
        'items', jsonb_build_array(
          jsonb_build_object(
            'slug', 'schnitzel', 'name', 'Schnitzel', 'description', '',
            'price_cents', 1890, 'kind', 'food', 'sort_order', 0
          )
        )
      )
    ))
  );

  v_table := public.operator_upsert_table('pinprobe', '1', 'Gastraum', 10);
  perform pg_temp.remember('table_id', v_table ->> 'table_id');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f9', true);
  perform public.guest_web_submit_order_v2(
    'pinprobe', 'pin-bestellung-1',
    '[{"slug":"schnitzel","quantity":1}]'::jsonb,
    'dine_in', '', v_table ->> 'token');

  -- Kassiert wird von der Servicekraft: kassieren ist Alltag und braucht kein
  -- besonderes Recht. Nur das Zurueckdrehen braucht eines.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_check := public.operator_table_check('pinprobe', (v_table ->> 'table_id')::uuid);
  v_payment := public.operator_record_payment(
    'pinprobe', (v_check ->> 'table_session_id')::uuid,
    'cash', 'pin-zahlung-1', 0, null, 1890
  );
  perform pg_temp.remember('payment_id', v_payment ->> 'payment_id');
end;
$$;

-- Ohne Freigabe kommt die Servicekraft nicht weiter.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_refund_payment('pinprobe', %L::uuid, 'Falsch kassiert')$q$,
      pg_temp.recall('payment_id')
    ),
    'permission_denied'
  );
end;
$$;

-- Die Schichtleitung tippt ihre PIN am Geraet der Servicekraft ein.
do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin(
    'pinprobe', 'payments.refund', '8317',
    'Gast hat falsch bestellt',
    jsonb_build_object('payment_id', pg_temp.recall('payment_id'))
  );

  perform pg_temp.assert((v_result ->> 'granted')::boolean, 'Freigabe erwartet');
  perform pg_temp.assert(length(v_result ->> 'token') = 64, 'Token mit 64 Zeichen erwartet');
  -- Die Servicekraft sieht, in wessen Namen sie gleich handelt.
  perform pg_temp.assert(
    v_result ->> 'granted_by_email' = 'schichtleitung@pin.test',
    'Freigebende erwartet, war ' || coalesce(v_result ->> 'granted_by_email', 'NULL')
  );

  perform pg_temp.remember('token', v_result ->> 'token');
  perform pg_temp.remember('override_id', v_result ->> 'override_id');

  -- Der erfolgreiche Versuch loescht die Fehlversuche.
  perform pg_temp.assert(
    not exists (
      select 1 from public.manager_pin_attempts
      where user_id = '00000000-0000-0000-0000-0000000000f4'
    ),
    'Nach einer gelungenen Freigabe zaehlt kein alter Fehlversuch mehr'
  );
end;
$$;

-- Ein Token, der noch nicht benutzt wurde, aendert nichts an der Sperre.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.assert(
    (select used_at from public.manager_overrides
     where id = pg_temp.recall('override_id')::uuid) is null,
    'Freigabe darf vor der Aktion nicht als verbraucht gelten'
  );
end;
$$;

-- Und jetzt der Storno.
do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_refund_payment(
    'pinprobe', pg_temp.recall('payment_id')::uuid, 'Gast hat falsch bestellt',
    pg_temp.recall('token')
  );
  perform pg_temp.assert(
    (v_result ->> 'replayed')::boolean = false, 'Storno erwartet');

  perform pg_temp.assert(
    (select status from public.payments where id = pg_temp.recall('payment_id')::uuid)
      = 'refunded',
    'Zahlung sollte storniert sein'
  );
end;
$$;

-- ============================================================================
-- 8. Genau eine Aktion
-- ============================================================================

do $$
declare
  v_override public.manager_overrides%rowtype;
begin
  select * into v_override
  from public.manager_overrides where id = pg_temp.recall('override_id')::uuid;

  perform pg_temp.assert(v_override.used_at is not null, 'Freigabe muss verbraucht sein');
  perform pg_temp.assert(
    v_override.granted_by = '00000000-0000-0000-0000-0000000000f3',
    'Freigebende falsch protokolliert'
  );
  perform pg_temp.assert(
    v_override.requested_by = '00000000-0000-0000-0000-0000000000f4',
    'Anfragende falsch protokolliert'
  );
  perform pg_temp.assert(
    v_override.note = 'Gast hat falsch bestellt', 'Notiz fehlt im Protokoll');
  perform pg_temp.assert(
    v_override.context ->> 'payment_id' = pg_temp.recall('payment_id'),
    'Bezug fehlt im Protokoll'
  );
end;
$$;

-- Derselbe Token ein zweites Mal: nein.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_refund_payment('pinprobe', %L::uuid, 'nochmal', %L)$q$,
      pg_temp.recall('payment_id'), pg_temp.recall('token')
    ),
    'permission_override_invalid'
  );
end;
$$;

-- ============================================================================
-- 9. Eine Freigabe gilt fuer ihre Aktion und ihren Zugang
-- ============================================================================

do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.remember('token2', v_result ->> 'token');
end;
$$;

-- Nicht fuer eine andere Aktion.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_open_shift('pinprobe', 0, 'fremde-aktion', %L)$q$,
      pg_temp.recall('token2')
    ),
    'permission_override_invalid'
  );
end;
$$;

-- Nicht fuer einen anderen Zugang: eine Freigabe ist nicht weiterreichbar.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f6', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_refund_payment('pinprobe', %L::uuid, 'geliehen', %L)$q$,
      pg_temp.recall('payment_id'), pg_temp.recall('token2')
    ),
    'permission_override_invalid'
  );
end;
$$;

-- Und nicht mehr nach Ablauf.
do $$
begin
  update public.manager_overrides
  set expires_at = now() - interval '1 minute'
  where token_hash = public.kitchenlink_hash_override_token(pg_temp.recall('token2'));

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_refund_payment('pinprobe', %L::uuid, 'zu spaet', %L)$q$,
      pg_temp.recall('payment_id'), pg_temp.recall('token2')
    ),
    'permission_override_invalid'
  );
end;
$$;

-- ============================================================================
-- 10. Dasselbe an der Kasse
-- ============================================================================

do $$
declare
  v_result jsonb;
begin
  -- Die Schichtleitung oeffnet die Kasse …
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f3', false);
  perform public.operator_open_shift('pinprobe', 10000, 'pin-schicht-1');

  -- … und gibt der Servicekraft eine Entnahme frei.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin(
    'pinprobe', 'cash.movement', '8317', 'Gemuesekiste bar bezahlt');
  perform pg_temp.assert((v_result ->> 'granted')::boolean, 'Freigabe erwartet');

  v_result := public.operator_record_cash_movement(
    'pinprobe', 'expense', 1250, 'pin-entnahme-1', 'Gemuesekiste',
    v_result ->> 'token'
  );
  perform pg_temp.assert(
    (v_result ->> 'movement_id') is not null, 'Bewegung erwartet');
  perform pg_temp.assert(
    (v_result -> 'totals' ->> 'expense_cents')::int = 1250,
    'Ausgabe sollte in der Schicht stehen'
  );
end;
$$;

-- ============================================================================
-- 11. Wer freigibt, muss das Recht noch haben
-- ============================================================================

-- Zwischen Erteilen und Verbrauchen liegen Minuten. Wird die Freigebende in
-- dieser Zeit herabgestuft, gilt ihre Freigabe nicht mehr.
do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'shift.close', '8317');
  perform pg_temp.assert((v_result ->> 'granted')::boolean, 'Freigabe erwartet');
  perform pg_temp.remember('token3', v_result ->> 'token');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_set_staff_role(
    'pinprobe', '00000000-0000-0000-0000-0000000000f3', 'service');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    format(
      $q$select public.operator_close_shift('pinprobe', 10000, null, null, %L)$q$,
      pg_temp.recall('token3')
    ),
    'permission_override_revoked'
  );
end;
$$;

-- Dieselbe PIN gibt jetzt auch nichts Neues mehr frei — ohne dass jemand sie
-- loeschen musste.
do $$
declare
  v_result jsonb;
  v_status jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.assert(
    v_result ->> 'reason' = 'pin_invalid',
    'Eine herabgestufte PIN darf nichts mehr freigeben, war ' || (v_result ->> 'reason')
  );

  v_status := public.operator_manager_pin_status('pinprobe');
  perform pg_temp.assert(
    (v_status ->> 'authorizers')::int = 0,
    'Es kann niemand mehr freigeben, gezaehlt wurden ' || (v_status ->> 'authorizers')
  );
end;
$$;

-- Zurueck auf Schichtleitung; die alte PIN gilt wieder.
do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_set_staff_role(
    'pinprobe', '00000000-0000-0000-0000-0000000000f3', 'shift_lead');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  -- Der Fehlversuch von eben wird hier wieder abgeraeumt.
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.assert((v_result ->> 'granted')::boolean, 'Freigabe erwartet');
end;
$$;

-- ============================================================================
-- 12. Die Sperre
-- ============================================================================

-- Vier Ziffern sind 10.000 Moeglichkeiten. Ohne Sperre waere das eine Frage
-- von Minuten. Gezaehlt wird am anfragenden Zugang: eine falsche PIN gehoert
-- zu niemandem, und das ganze Lokal auszusperren waere die falsche Antwort.
do $$
declare
  v_result jsonb;
  v_index int;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f6', false);

  for v_index in 1..4 loop
    v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '0417');
    perform pg_temp.assert(
      v_result ->> 'reason' = 'pin_invalid',
      'Versuch ' || v_index || ': pin_invalid erwartet, war ' || (v_result ->> 'reason')
    );
    perform pg_temp.assert(
      (v_result ->> 'attempts_left')::int = 5 - v_index,
      'Versuch ' || v_index || ': ' || (5 - v_index) || ' uebrig erwartet'
    );
  end loop;

  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '0417');
  perform pg_temp.assert(
    v_result ->> 'reason' = 'pin_locked',
    'Nach fuenf Fehlversuchen gesperrt, war ' || (v_result ->> 'reason')
  );

  -- Und jetzt hilft auch die richtige PIN nicht mehr.
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.assert(
    v_result ->> 'reason' = 'pin_locked',
    'Gesperrt bleibt gesperrt, war ' || (v_result ->> 'reason')
  );

  -- Die Sperre trifft nur diesen Zugang.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.assert(
    (v_result ->> 'granted')::boolean,
    'Die Sperre eines Zugangs darf das Lokal nicht lahmlegen'
  );
end;
$$;

-- Nach Ablauf der Sperre faengt die Zaehlung von vorn an.
do $$
declare
  v_result jsonb;
begin
  update public.manager_pin_attempts
  set locked_until = now() - interval '1 minute'
  where user_id = '00000000-0000-0000-0000-0000000000f6';

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f6', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '0417');
  perform pg_temp.assert(
    (v_result ->> 'attempts_left')::int = 4,
    'Nach Ablauf der Sperre wieder vier Versuche, waren ' || (v_result ->> 'attempts_left')
  );
end;
$$;

-- ============================================================================
-- 13. Zwei gleiche PINs geben nichts frei
-- ============================================================================

-- Eine Freigabe, die sich niemandem sicher zuordnen laesst, ist fuer §8.2
-- wertlos. Sie wird deshalb verweigert statt geraten.
do $$
declare
  v_result jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform public.operator_set_manager_pin('pinprobe', '8317');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  v_result := public.operator_authorize_with_pin('pinprobe', 'payments.refund', '8317');
  perform pg_temp.assert(
    v_result ->> 'reason' = 'pin_ambiguous',
    'pin_ambiguous erwartet, war ' || (v_result ->> 'reason')
  );

  -- Und es ist kein Fehlversuch: die PIN war ja richtig.
  perform pg_temp.assert(
    not exists (
      select 1 from public.manager_pin_attempts
      where user_id = '00000000-0000-0000-0000-0000000000f4' and failed_count > 0
    ),
    'Eine richtige, aber mehrdeutige PIN ist kein Fehlversuch'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform public.operator_set_manager_pin('pinprobe', '5062');
end;
$$;

-- ============================================================================
-- 14. PIN loeschen
-- ============================================================================

do $$
declare
  v_status jsonb;
begin
  -- Die eigene loescht jeder selbst.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform public.operator_clear_manager_pin('pinprobe');
  v_status := public.operator_manager_pin_status('pinprobe');
  perform pg_temp.assert(
    (v_status ->> 'has_pin')::boolean = false, 'Eigene PIN sollte weg sein');

  -- Eine fremde nur, wer Personal verwaltet (vergessene PIN, Austritt).
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    $q$select public.operator_clear_manager_pin(
      'pinprobe', '00000000-0000-0000-0000-0000000000f3')$q$,
    'permission_denied'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_clear_manager_pin(
    'pinprobe', '00000000-0000-0000-0000-0000000000f3');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f3', false);
  v_status := public.operator_manager_pin_status('pinprobe');
  perform pg_temp.assert(
    (v_status ->> 'has_pin')::boolean = false, 'Fremde PIN sollte weg sein');
end;
$$;

-- Einen Inhaber fasst wie ueberall sonst nur ein Inhaber an.
do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  perform public.operator_set_manager_pin('pinprobe', '7024');

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f2', false);
  perform pg_temp.expect_error(
    $q$select public.operator_clear_manager_pin(
      'pinprobe', '00000000-0000-0000-0000-0000000000f1')$q$,
    'staff_owner_protected'
  );
end;
$$;

-- ============================================================================
-- 15. Das Protokoll
-- ============================================================================

do $$
declare
  v_rows jsonb;
begin
  -- Wer kein Personal verwaltet, liest es nicht.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f4', false);
  perform pg_temp.expect_error(
    $q$select public.operator_recent_overrides('pinprobe')$q$,
    'permission_denied'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
  v_rows := public.operator_recent_overrides('pinprobe');

  perform pg_temp.assert(
    jsonb_array_length(v_rows) >= 4,
    'Mehrere Freigaben erwartet, waren ' || jsonb_array_length(v_rows)
  );
  perform pg_temp.assert(
    (select count(*) from jsonb_array_elements(v_rows) r
     where r ->> 'granted_by_email' = 'schichtleitung@pin.test'
       and r ->> 'requested_by_email' = 'service@pin.test') >= 1,
    'Wer wem freigegeben hat, muss im Protokoll stehen'
  );
  -- Was das Geraet nicht braucht, bekommt es nicht.
  perform pg_temp.assert(
    (select count(*) from jsonb_array_elements(v_rows) r
     where r ? 'token_hash') = 0,
    'Der Token-Hash hat auf einem Geraet nichts zu suchen'
  );
end;
$$;

-- ============================================================================
-- 16. Row Level Security
-- ============================================================================

do $$
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000f1', false);
end;
$$;

set role authenticated;

do $$
begin
  -- Auch die Inhaberin liest die drei Tabellen nicht direkt: der Hash einer
  -- vierstelligen PIN waere auf einem Geraet in Sekunden zurueckgerechnet.
  --
  -- Anders als bei den uebrigen Tabellen dieses Projekts ist die Antwort nicht
  -- „null Zeilen", sondern eine Abweisung: die Tabellen haben **keine** Policy
  -- und zusaetzlich keine Grants. Sonst wuerde ein einziges spaeteres
  -- `create policy` alles oeffnen.
  perform pg_temp.expect_error(
    $q$select count(*) from public.manager_pins$q$, 'permission denied');
  perform pg_temp.expect_error(
    $q$select count(*) from public.manager_pin_attempts$q$, 'permission denied');
  perform pg_temp.expect_error(
    $q$select count(*) from public.manager_overrides$q$, 'permission denied');
  perform pg_temp.expect_error(
    $q$insert into public.manager_pins (venue_id, user_id, pin_hash)
       values (gen_random_uuid(), gen_random_uuid(), 'x')$q$,
    'permission denied');
end;
$$;

reset role;

set role anon;

do $$
begin
  perform pg_temp.expect_error(
    $q$select count(*) from public.manager_pins$q$, 'permission denied');
  perform pg_temp.expect_error(
    $q$select count(*) from public.manager_overrides$q$, 'permission denied');
end;
$$;

reset role;

-- Und die Hilfsfunktionen, die einen Hash erzeugen oder pruefen, sind fuer
-- Clients gar nicht erst aufrufbar.
set role authenticated;

do $$
begin
  perform pg_temp.expect_error(
    $q$select public.kitchenlink_hash_pin('8317')$q$, 'permission denied');
  perform pg_temp.expect_error(
    $q$select public.kitchenlink_pin_matches('8317', 'x')$q$, 'permission denied');
end;
$$;

reset role;

-- ============================================================================
-- 17. Aufraeumen
-- ============================================================================

do $$
begin
  delete from public.venues where slug = 'pinprobe';
  perform pg_temp.assert(
    (select count(*) from public.manager_pins) = 0,
    'Mit der Venue verschwinden ihre PINs'
  );
  perform pg_temp.assert(
    (select count(*) from public.manager_overrides) = 0,
    'Mit der Venue verschwindet ihr Protokoll'
  );
end;
$$;

select 'KL-ROLE-002: alle SQL-Pruefungen bestanden' as ergebnis;
