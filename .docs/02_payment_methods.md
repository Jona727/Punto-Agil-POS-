# Métodos de Pago Explicitados

## Objetivo
Posibilitar al comercio saber de qué forma cobró cada venta para facilitar el arqueo de caja al final del día.

## Requerimientos Técnicos
1. **Modelo de Datos (`Sale`)**:
   - Agregar campo `String paymentMethod` (valores: `cash`, `debit`, `credit`, `digital_wallet`).
2. **Interfaz de Usuario**:
   - En `CheckoutPage`, antes de "Imprimir Ticket", agregar un selector de "Método de Pago" (ej. chips o dropdown).
   - El método de pago se selecciona y se guarda como parte del objeto `Sale`.
3. **Lógica de Reporte Z**:
   - Agrupar los totales por método de pago.
   - En `ZReportPage`, mostrar el desglose (ej: Total Ef: $5.000, Total Card: $3.000).

## Beneficios
- Facilitar el arqueo de la caja física.
- Tener un registro claro de las comisiones de posnet o billeteras digitales.
