# Probar la sincronización contra un servidor local (opcional, para desarrollo)

La prueba `test/integration/supabase_remote_integration_test.dart` habla con un
**PostgREST real** (el mismo componente que usa Supabase) sobre una base con el
esquema de `supabase/migrations`. Sirve para comprobar consultas, reglas RLS y
la sincronización de punta a punta sin gastar un proyecto de Supabase.
Sin las variables de entorno, la prueba se omite sola.

Requisitos: PostgreSQL 14+, el binario de PostgREST 12 y Python 3.

```bash
createdb cobra_test
psql cobra_test -f supabase/local_test/setup.sql
psql cobra_test -f supabase/migrations/001_esquema_inicial.sql
psql cobra_test -f supabase/migrations/002_asegurar_comercio.sql

# Dos usuarios de prueba (el trigger les crea su comercio)
psql cobra_test -c "insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','a@x.com'),
  ('22222222-2222-2222-2222-222222222222','b@x.com');"

cat > postgrest.conf <<'CONF'
db-uri = "postgres://authenticator:pw@127.0.0.1:5432/cobra_test"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "super-secret-jwt-token-with-at-least-32-characters-long"
server-port = 3000
CONF
postgrest postgrest.conf &
python3 supabase/local_test/rest_proxy.py &   # agrega el prefijo /rest/v1 como Supabase

COBRA_PGRST_URL=http://127.0.0.1:3001 \
COBRA_JWT_SECRET="super-secret-jwt-token-with-at-least-32-characters-long" \
COBRA_USER_A=11111111-1111-1111-1111-111111111111 \
COBRA_USER_B=22222222-2222-2222-2222-222222222222 \
flutter test test/integration
```

Entre corridas conviene vaciar los datos:
`truncate public.sale_items, public.sales, public.products;`
