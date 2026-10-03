# Catálogo de productos (autocompletado)

Al cargar un producto, si el código de barras está en el catálogo, la app
completa el nombre sola. El comercio solo agrega el **precio** y el stock.
No tiene precios a propósito: un kiosco cobra distinto que un supermercado.

## Cómo funciona
1. **Dentro de la app** viaja un catálogo de ~10.000 productos
   (`assets/catalog/productos_ar.json`). Funciona **sin internet y sin cuenta**.
2. Si el código no está ahí y el comercio tiene sesión, la app consulta la tabla
   `catalog_products` de Supabase. Eso permite ampliar el catálogo **sin publicar
   una versión nueva** de la app.
3. Si no hay sugerencia, se carga a mano como siempre.

El nombre que escribe el comercio **nunca se pisa**: si ya había escrito uno, la
app ofrece "Usar el del catálogo". También avisa si el código parece mal escrito
(el dígito de control no coincide).

## Cargar el catálogo en Supabase (una vez)
1. En **SQL Editor**, ejecutar `supabase/migrations/006_catalogo_productos.sql`.
2. En **Table Editor → catalog_products**: botón **Insert → Import data from CSV**
   y elegir `supabase/seed/catalog_seed.csv`. Verificar que las 5 columnas
   (`ean, name, brand, category, source`) estén asignadas a su columna.
3. Deben quedar ~10.000 filas.

La app sigue funcionando aunque no se haga este paso (usa el catálogo incluido).

## Regenerar o actualizar el catálogo
Los datos actuales de SEPA se descargan desde el portal oficial de datos abiertos
(Precios Claros). Con los archivos `productos_*.csv.gz` y `precios_*.csv.gz` del
mismo día:

```
python3 tools/catalog/build_catalog.py --productos productos_AAAA-MM-DD.csv.gz \
    --precios precios_AAAA-MM-DD.csv.gz --max 10000
python3 tools/catalog/test_build_catalog.py     # pruebas de la limpieza
```
Si el formato de los archivos actuales cambió respecto a 2018, hay que ajustar los
nombres de columnas al inicio de `build()`.

## Créditos y licencia
Ver `docs/catalog/ATRIBUCION.md`.
