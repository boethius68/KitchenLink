-- Minimale Supabase-Nachbildung fuer eine lokale Wegwerf-Instanz.
--
-- Die Migrationen unter `supabase/migrations/` setzen drei Dinge voraus, die
-- ein nacktes PostgreSQL nicht mitbringt: die Rollen `anon`/`authenticated`,
-- pgcrypto im Schema `extensions` (KL-WEB-003) und die Auth-Helfer
-- `auth.uid()`/`auth.jwt()`. Hier stehen genau diese Stubs — nicht mehr, damit
-- der Test nicht versehentlich etwas beweist, das nur der Stub kann.
--
-- `auth.uid()` und `auth.jwt()` lesen wie in Supabase aus der Sitzungsvariable
-- `request.jwt.claims`; ein Test setzt sie mit
--   select set_config('request.jwt.claims', '{"sub":"...","is_anonymous":true}', true);

create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid;
$$;

grant execute on function auth.jwt() to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

grant usage on schema public to anon, authenticated, service_role;

-- Supabase vergibt Tabellenrechte an anon/authenticated per Default-Privileg.
-- Ohne diese Zeile wuerde ein RLS-Test bestehen, obwohl er nur an fehlenden
-- GRANTs scheitert — der Test soll die Policies pruefen, nicht die Rechte.
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
