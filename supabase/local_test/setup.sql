-- Simula lo mínimo de Supabase (esquema auth + roles) para probar el SQL y la
-- sincronización en un PostgreSQL común. NO usar en un proyecto real de Supabase.
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid $$;
do $$ begin
  if not exists (select from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select from pg_roles where rolname='authenticator') then create role authenticator login password 'pw' noinherit; end if;
end $$;
grant anon, authenticated to authenticator;
grant usage on schema auth to authenticated;
-- Ejecutar DESPUÉS de aplicar supabase/migrations/001_esquema_inicial.sql:
--   grant usage on schema public to anon, authenticated;
--   grant select, insert, update, delete on all tables in schema public to authenticated;
--   grant execute on all functions in schema public to authenticated;
