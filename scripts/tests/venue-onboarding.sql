-- Funktionstest fuer KL-ONBOARD-001 (Migration 20260731180000).
-- Aufruf ueber `scripts/verify-supabase-migrations.sh`.
--
-- Geprueft wird, was den Unterschied zwischen „ein Demo-Lokal" und „ein
-- Produkt" ausmacht: dass ein angemeldetes Konto sein eigenes Restaurant
-- anlegen kann, dabei selbst Personal wird, und dass danach alle
-- Betreiberwege dieser neuen Venue funktionieren, ohne dass jemand SQL
-- schreibt.

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

-- ============================================================================
-- 1. Ein neues Konto legt sein Restaurant an
-- ============================================================================

do $$
declare
  v_result jsonb;
  v_venue_id uuid;
begin
  -- Ein Konto, das bisher zu keiner Venue gehoert.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);

  v_result := public.operator_create_venue('Trattoria Bella Vista', 'trattoria-bella-vista');
  v_venue_id := (v_result ->> 'venue_id')::uuid;

  perform pg_temp.assert(
    (v_result ->> 'slug') = 'trattoria-bella-vista',
    'Slug der neuen Venue falsch'
  );
  -- Wer anlegt, ist Personal — sonst koennte er sein eigenes Lokal nicht bedienen.
  perform pg_temp.assert(
    public.is_venue_staff(v_venue_id),
    'Der Anleger sollte Personal seiner Venue sein'
  );
  -- Eine aktive Karte existiert, damit die Gastseite eine gueltige Venue findet.
  perform pg_temp.assert(
    (select count(*) from public.menus where venue_id = v_venue_id and active) = 1,
    'Genau eine aktive Karte erwartet'
  );

  perform pg_temp.assert(
    (select count(*) from public.operator_my_venues()) = 1,
    'Das Konto sollte genau ein Restaurant sehen'
  );
end;
$$;

-- ============================================================================
-- 2. Der neue Betreiber kann sein Lokal sofort bedienen
-- ============================================================================

do $$
declare
  v_table jsonb;
  v_token text;
  v_order_id uuid;
  v_check jsonb;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);

  -- Karte veroeffentlichen.
  perform public.operator_publish_menu_v2(
    'trattoria-bella-vista',
    jsonb_build_object('categories', jsonb_build_array(
      jsonb_build_object(
        'name', 'Küche', 'kind', 'food', 'sort_order', 0,
        'items', jsonb_build_array(
          jsonb_build_object(
            'slug', 'pizza-margherita', 'name', 'Pizza Margherita',
            'description', '', 'price_cents', 1090, 'kind', 'food',
            'sort_order', 0
          )
        )
      )
    ))
  );

  -- Tisch anlegen.
  v_table := public.operator_upsert_table('trattoria-bella-vista', '1', 'Gastraum', 10);
  v_token := v_table ->> 'token';
  perform pg_temp.assert(v_token is not null, 'Neuer Tisch ohne QR-Token');

  -- Ein Gast bestellt ueber genau diesen Tisch.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e9', true);
  select order_id into v_order_id
  from public.guest_web_submit_order_v2(
    'trattoria-bella-vista', 'onboard-1',
    '[{"slug":"pizza-margherita","quantity":2}]'::jsonb,
    'dine_in', '', v_token);
  perform pg_temp.assert(v_order_id is not null, 'Bestellung im neuen Lokal fehlgeschlagen');

  -- Und der Betreiber kassiert.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e1', false);
  v_check := public.operator_table_check(
    'trattoria-bella-vista',
    (v_table ->> 'table_id')::uuid
  );
  perform pg_temp.assert(
    (v_check ->> 'open_cents')::int = 2180,
    'Offener Betrag im neuen Lokal falsch: ' || (v_check ->> 'open_cents')
  );
end;
$$;

-- ============================================================================
-- 3. Fremde Lokale bleiben fremd
-- ============================================================================

do $$
begin
  -- Ein anderes Konto darf im fremden Lokal nichts tun.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e2', false);
  perform pg_temp.expect_error(
    $q$select public.operator_upsert_table('trattoria-bella-vista', '99', '', 0)$q$,
    'table_forbidden'
  );
  perform pg_temp.assert(
    (select count(*) from public.operator_my_venues()) = 0,
    'Ein fremdes Konto sieht keine Venue'
  );
end;
$$;

-- ============================================================================
-- 4. Grenzen
-- ============================================================================

do $$
declare
  v_index int;
begin
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e2', false);

  -- Ein anonymer Gast eroeffnet kein Restaurant.
  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e3', true);
  perform pg_temp.expect_error(
    $q$select public.operator_create_venue('Gastladen', 'gastladen')$q$,
    'venue_anonymous_not_allowed'
  );

  perform pg_temp.act_as('00000000-0000-0000-0000-0000000000e2', false);

  -- Slug und Name werden geprueft, nicht zurechtgebogen.
  perform pg_temp.expect_error(
    $q$select public.operator_create_venue('X', 'kurz-genug')$q$,
    'venue_invalid_name'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_create_venue('Gutes Lokal', 'Gutes Lokal')$q$,
    'venue_invalid_slug'
  );
  perform pg_temp.expect_error(
    $q$select public.operator_create_venue('Doppelt', 'trattoria-bella-vista')$q$,
    'venue_slug_taken'
  );

  -- Vorschlag weicht auf eine freie Variante aus, statt zu scheitern.
  perform pg_temp.assert(
    public.operator_suggest_venue_slug('trattoria-bella-vista') = 'trattoria-bella-vista-2',
    'Slug-Vorschlag sollte ausweichen'
  );
  perform pg_temp.assert(
    public.operator_suggest_venue_slug('noch-frei') = 'noch-frei',
    'Ein freier Slug soll unveraendert bleiben'
  );

  -- Sandbox-Obergrenze.
  for v_index in 1..5 loop
    perform public.operator_create_venue('Lokal ' || v_index, 'lokal-nummer-' || v_index);
  end loop;
  perform pg_temp.expect_error(
    $q$select public.operator_create_venue('Zu viel', 'zu-viel')$q$,
    'venue_limit_reached'
  );
end;
$$;

select 'KL-ONBOARD-001: alle SQL-Pruefungen bestanden' as ergebnis;
