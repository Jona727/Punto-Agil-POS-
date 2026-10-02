# Control de Inventario (Stock)

## Objetivo
Permitir al comerciante llevar un registro de las unidades físicas disponibles de cada producto y recibir alertas cuando el stock sea bajo.

## Requerimientos Técnicos
1. **Modelo de Datos (`Product`)**: 
   - Agregar campo `double stockQuantity`.
   - Agregar campo `double minStockAlert` (umbral para avisos).
2. **Lógica de Negocio**:
   - Al confirmar una venta (`SaveSaleUseCase`), se debe descontar la cantidad vendida del stock del producto en la base de datos Hive.
   - Si el stock es insuficiente, se puede optar por permitir venta negativa (avisando) o bloquearla (configurable).
3. **Interfaz de Usuario**:
   - En `AddProductPage` / `EditProductPage`, agregar campos para inicializar el stock.
   - En `HomePage` / `ProductListPage`, mostrar un indicador visual (ej. badge rojo) si el stock está por debajo del `minStockAlert`.

## Beneficios
- Evita quiebres de stock.
- Permite valorizar el inventario total del negocio.
