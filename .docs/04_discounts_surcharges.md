# Aplicación de Descuentos y Recargos

## Objetivo
Dar flexibilidad al vendedor para aplicar ajustes de precio directos al carrito, según promociones o medios de pago.

## Requerimientos Técnicos
1. **Lógica del Carrito (`BillingState`)**:
   - Agregar campos `double discountAmount` y `double surchargeAmount`.
   - Recalcular el `totalAmount` dinámicamente: `(subtotal - discount) + surcharge`.
2. **Interfaz de Usuario**:
   - En la vista del carrito, agregar botones "+" o "%" abajo del subtotal.
   - Mostrar el total tachado si se aplica un descuento.
3. **Lógica del Ticket**:
   - Incluir una línea de "Descuento / Recargo" en la impresión ESC/POS para transparencia con el cliente.

## Beneficios
- Mayor capacidad de negociación en el mostrador.
- Permite gestionar promociones "en el aire".
