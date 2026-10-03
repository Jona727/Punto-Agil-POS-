# Atribución de datos del catálogo de productos

El catálogo de productos de Cobrá (`assets/catalog/productos_ar.json` y
`supabase/seed/catalog_seed.csv`) se arma a partir de datos abiertos del
**Sistema Electrónico de Publicidad de Precios Argentinos (SEPA) / Precios Claros**,
de la Secretaría de Comercio del Gobierno de Argentina.

- **Fuente de los datos:** https://www.preciosclaros.gob.ar/
- **Copia histórica usada** (2016-2018): "Precios Claros (2016-05 – 2018-03)",
  publicada en Zenodo, https://zenodo.org/records/6568295 — descargada por Diego
  Daruich y Julian Kozlowski y subida por Lars Vilhuber para la American Economic
  Association.
- **Licencia de esa copia:** Creative Commons Atribución 2.5 (CC BY 2.5).
  Se debe dar crédito a la fuente. Por eso la app muestra el crédito al final de
  *Ajustes*. **No quitarlo.**

## Qué se tomó y qué se hizo
- Solo código de barras, descripción, marca y rubro. **No se usan precios.**
- Se validó el dígito de control de cada código y se descartaron los códigos
  internos de los supermercados.
- Se normalizaron los textos (unidades como "g", "ml", "L", "u.") y se eliminaron
  duplicados. Se conservaron los productos que aparecen en más sucursales.

Los datos de productos son de 2018: pueden faltar productos nuevos o haber
cambiado presentaciones.

## Pendiente antes de lanzar
Conviene que un abogado confirme que el uso y la redistribución dentro de una
aplicación comercial cumplen con la licencia. Si más adelante se agregan datos de
**Open Food Facts** (licencia ODbL), esa licencia tiene condiciones propias
(atribución y compartir igual si se redistribuye la base).
