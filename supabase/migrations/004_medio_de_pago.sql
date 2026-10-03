-- Cobrá · Medio de pago en las ventas (efectivo, Mercado Pago, transferencia, tarjeta)
--
-- Se puede ejecutar varias veces. Las ventas que ya existen quedan como 'cash'.
-- IMPORTANTE: aplicarla ANTES de instalar la versión de la app que guarda el medio
-- de pago; si no, las ventas nuevas no se pueden subir hasta aplicarla.
--
-- Cómo aplicarla: SQL Editor > New query > pegar > Run.

alter table public.sales
  add column if not exists payment_method text not null default 'cash';

alter table public.sales
  drop constraint if exists sales_payment_method_valido;
alter table public.sales
  add constraint sales_payment_method_valido
  check (payment_method in ('cash', 'mercado_pago', 'transfer', 'card'));
