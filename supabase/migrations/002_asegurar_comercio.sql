-- Cobrá · Asegurar que cada usuario tenga su comercio
--
-- La migración 001 crea el comercio con un disparador al registrarse. Si ese
-- disparador no llega a ejecutarse (usuarios creados antes, o un proyecto donde
-- no se creó), la sincronización no puede subir nada. Esta migración hace que la
-- app pueda pedir el comercio de forma idempotente, y repara a los usuarios que
-- quedaron sin comercio.
--
-- Cómo aplicarla: SQL Editor > New query > pegar > Run.

create or replace function public.ensure_my_business()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'Se necesita una sesión iniciada' using errcode = '28000';
  end if;

  insert into public.businesses (owner_id)
  values (v_uid)
  on conflict (owner_id) do nothing;

  select id into v_id from public.businesses where owner_id = v_uid;
  return v_id;
end;
$$;

revoke execute on function public.ensure_my_business() from public, anon;
grant  execute on function public.ensure_my_business() to authenticated;

-- Repara a los usuarios que ya existen y no tienen comercio.
insert into public.businesses (owner_id)
select u.id
from auth.users u
where not exists (select 1 from public.businesses b where b.owner_id = u.id);
