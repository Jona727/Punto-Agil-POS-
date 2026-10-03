-- Cobrá · Reparar reglas de seguridad, disparadores y permisos
--
-- Se puede ejecutar TODAS las veces que haga falta: no falla si algo ya existe.
-- Sirve cuando la migración 001 quedó aplicada de forma incompleta (por ejemplo,
-- si el texto se cortó al copiarlo en el SQL Editor).
--
-- Cómo aplicarla: SQL Editor > New query > pegar TODO > Run.

-- ───────────── Seguridad por fila (RLS) ─────────────

alter table public.businesses enable row level security;
alter table public.products   enable row level security;
alter table public.sales      enable row level security;
alter table public.sale_items enable row level security;

create or replace function public.my_business_ids()
returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  select id from public.businesses where owner_id = (select auth.uid());
$$;

drop policy if exists "ver mi comercio" on public.businesses;
create policy "ver mi comercio" on public.businesses
  for select to authenticated
  using (owner_id = (select auth.uid()));

drop policy if exists "editar mi comercio" on public.businesses;
create policy "editar mi comercio" on public.businesses
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

drop policy if exists "mis productos" on public.products;
create policy "mis productos" on public.products
  for all to authenticated
  using (business_id in (select public.my_business_ids()))
  with check (business_id in (select public.my_business_ids()));

drop policy if exists "mis ventas" on public.sales;
create policy "mis ventas" on public.sales
  for all to authenticated
  using (business_id in (select public.my_business_ids()))
  with check (business_id in (select public.my_business_ids()));

drop policy if exists "mis items de venta" on public.sale_items;
create policy "mis items de venta" on public.sale_items
  for all to authenticated
  using (business_id in (select public.my_business_ids()))
  with check (business_id in (select public.my_business_ids()));

-- ───────────── updated_at automático ─────────────

create or replace function public.tocar_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists businesses_updated on public.businesses;
create trigger businesses_updated before update on public.businesses
  for each row execute function public.tocar_updated_at();

drop trigger if exists products_updated on public.products;
create trigger products_updated before update on public.products
  for each row execute function public.tocar_updated_at();

-- ───────────── Permisos de acceso desde la app ─────────────

grant usage on schema public to authenticated;
grant select, update on public.businesses to authenticated;
grant select, insert, update, delete on public.products   to authenticated;
grant select, insert, update, delete on public.sales      to authenticated;
grant select, insert, update, delete on public.sale_items to authenticated;

revoke execute on function public.my_business_ids() from public, anon;
grant  execute on function public.my_business_ids() to authenticated;

revoke all on public.businesses, public.products, public.sales, public.sale_items from anon;

-- Nota: el comercio ya no depende de un disparador sobre auth.users; la app lo
-- pide con ensure_my_business() (migración 002).
