# Dashboard de Estadísticas y Analítica

## Objetivo
Ofrecer al dueño del comercio una visión estratégica del desempeño de su negocio a lo largo de un período de tiempo.

## Requerimientos Técnicos
1. **Librería de Gráficos**: Integrar una solución como `fl_chart` o `syncfusion_flutter_charts`.
2. **Lógica de Datos**:
   - Cargar todas las ventas en la `SalesBox`.
   - Implementar agregaciones periódicas (ventas totales por día de la semana, ingresos por mes).
   - Identificar el top 5 de productos más vendidos.
3. **Interfaz de Usuario**:
   - Crear una pestaña "Dashboard" o "Ingresos" en el menú principal.
   - Mostrar un gráfico de líneas para la evolución de los ingresos.
   - Mostrar una lista simple para el top de productos.

## Beneficios
- Permite detectar tendencias de ventas.
- Ayuda a priorizar la compra de mercadería.
