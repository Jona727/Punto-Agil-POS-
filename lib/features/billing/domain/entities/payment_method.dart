/// Cómo pagó el cliente.
///
/// [code] es lo que se guarda (teléfono y nube): no cambiarlo nunca.
/// [label] va sin tildes a propósito: se imprime en el ticket y muchas
/// impresoras térmicas muestran símbolos raros con acentos.
enum PaymentMethod {
  cash('cash', 'Efectivo'),
  mercadoPago('mercado_pago', 'Mercado Pago'),
  transfer('transfer', 'Transferencia'),
  card('card', 'Tarjeta / otro');

  const PaymentMethod(this.code, this.label);

  final String code;
  final String label;

  /// Códigos desconocidos o vacíos (ventas anteriores a este cambio) se
  /// consideran efectivo.
  static PaymentMethod fromCode(String? code) => PaymentMethod.values
      .firstWhere((m) => m.code == code, orElse: () => PaymentMethod.cash);
}
