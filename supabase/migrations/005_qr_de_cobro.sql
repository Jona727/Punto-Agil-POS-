-- Cobrá · QR de cobro del comercio (el de Mercado Pago o el de su banco)
--
-- Guarda el contenido del QR que el comercio carga desde una imagen, para
-- mostrarlo en cada cobro. Se puede ejecutar varias veces.
-- IMPORTANTE: aplicarla ANTES de instalar la versión de la app que lo guarda.
--
-- Cómo aplicarla: SQL Editor > New query > pegar > Run.

alter table public.businesses
  add column if not exists payment_qr text not null default '';
