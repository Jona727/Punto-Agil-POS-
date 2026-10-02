-- Cobrá · Esquema inicial (Fase 2)
-- Cómo aplicarlo: Supabase > SQL Editor > New query > pegar este archivo > Run.
--
-- Modelo: cada usuario registrado es dueño de UN comercio (businesses).
-- Todo lo demás (productos, ventas) pertenece a un comercio, y las reglas RLS
-- garantizan que cada usuario solo vea y modifique datos de SU comercio.

-- ───────────────────────── Tablas ─────────────────────────

create table public.businesses (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null unique references auth.users (id) on delete cascade,
  name          text not null default 'Mi Negocio',
  address1      text not null default '',
  address2      text not null default '',
  phone         text not null default '',
  payment_alias text not null default '',
  footer_text   text not null default '¡Gracias por su compra!',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- El id del producto lo genera la app (uuid v4 como texto), así puede crearse
-- sin internet y subirse después sin conflictos.
create table public.products (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id          text not null,
  name        text not null,
  barcode     text not null,
  price       numeric(12, 2) not null check (price >= 0),
  stock       integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  primary key (business_id, id)
);

-- Un código de barras no puede repetirse dentro de un comercio
-- (ignorando los productos borrados).
create unique index products_barcode_unico
  on public.products (business_id, barcode)
  where deleted_at is null;

create table public.sales (
  business_id uuid not null references public.businesses (id) on delete cascade,
  id          text not null,
  sold_at     timestamptz not null,
  total       numeric(12, 2) not null check (total >= 0),
  voided      boolean not null default false,
  created_at  timestamptz not null default now(),
  primary key (business_id, id)
);

create index sales_por_fecha on public.sales (business_id, sold_at desc);

create table public.sale_items (
  business_id uuid not null,
  sale_id     text not null,
  line        integer not null,
  product_id  text not null,
  name        text not null,
  barcode     text not null,
  unit_price  numeric(12, 2) not null check (unit_price >= 0),
  quantity    integer not null check (quantity > 0),
  primary key (business_id, sale_id, line),
  foreign key (business_id, sale_id)
    references public.sales (business_id, id) on delete cascade
);

-- ───────────────────── Seguridad (RLS) ─────────────────────

alter table public.businesses enable row level security;
alter table public.products   enable row level security;
alter table public.sales      enable row level security;
alter table public.sale_items enable row level security;

-- Ids de los comercios del usuario que hace la consulta.
create function public.my_business_ids()
returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  select id from public.businesses where owner_id = (select auth.uid());
$$;

create policy "ver mi comercio" on public.businesses
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy "editar mi comercio" on public.businesses
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- El comercio se crea solo al registrarse (trigger de abajo), por eso no hay
-- política de insert/delete sobre businesses para usuarios.

create policy "mis productos" on public.products
  for all to authenticated
  using (business_id in (select public.my_business_ids()))
  with check (business_id in (select public.my_business_ids()));

create policy "mis ventas" on public.sales
  for all to authenticated
  using (business_id in (select public.my_business_ids()))
  with check (business_id in (select public.my_business_ids()));

create policy "mis items de venta" on public.sale_items
  for all to authenticated
  using (business_id in (select public.my_business_ids()))
  with check (business_id in (select public.my_business_ids()));

-- ───────────── Alta automática del comercio ─────────────

create function public.crear_comercio_al_registrarse()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.businesses (owner_id) values (new.id);
  return new;
end;
$$;

create trigger al_registrarse
  after insert on auth.users
  for each row execute function public.crear_comercio_al_registrarse();

-- ───────────── updated_at automático ─────────────

create function public.tocar_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger businesses_updated before update on public.businesses
  for each row execute function public.tocar_updated_at();
create trigger products_updated before update on public.products
  for each row execute function public.tocar_updated_at();

-- ───────────── Permisos de acceso desde la app (Data API) ─────────────
-- Se declaran explícitos para no depender de los permisos por defecto de
-- Supabase, que pueden cambiar. Solo usuarios con sesión (authenticated) tocan
-- las tablas, y aun así las reglas RLS limitan cada fila a su comercio.

grant usage on schema public to authenticated;
grant select, update on public.businesses to authenticated;
grant select, insert, update, delete on public.products   to authenticated;
grant select, insert, update, delete on public.sales      to authenticated;
grant select, insert, update, delete on public.sale_items to authenticated;

-- Las funciones se crean ejecutables por todos; se restringen a usuarios con sesión.
revoke execute on function public.my_business_ids() from public, anon;
grant  execute on function public.my_business_ids() to authenticated;

-- Sin sesión (anon) no se accede a nada.
revoke all on public.businesses, public.products, public.sales, public.sale_items from anon;
