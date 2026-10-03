-- Cobrá · Catálogo compartido de productos (código de barras -> nombre)
--
-- Sirve para autocompletar el nombre al cargar un producto. NO tiene precios:
-- cada comercio fija los suyos. Es de solo lectura para los usuarios; se carga
-- desde supabase/seed/catalog_seed.csv (Table Editor > catalog_products >
-- Insert > Import data from CSV). Se puede ejecutar varias veces.
--
-- Cómo aplicarla: SQL Editor > New query > pegar > Run.

create table if not exists public.catalog_products (
  ean        text primary key check (ean ~ '^[0-9]{8}$' or ean ~ '^[0-9]{13}$'),
  name       text not null,
  -- brand y category pueden venir vacíos: al importar un CSV, un campo vacío
  -- entra como NULL, y la app lo trata como texto vacío.
  brand      text default '',
  category   text default '',
  source     text not null default 'sepa',
  created_at timestamptz not null default now()
);

alter table public.catalog_products enable row level security;

drop policy if exists "leer catalogo" on public.catalog_products;
create policy "leer catalogo" on public.catalog_products
  for select to authenticated
  using (true);

grant select on public.catalog_products to authenticated;
revoke all on public.catalog_products from anon;
