/// Reglas sobre el QR de cobro que el comercio carga desde una imagen.

/// Un QR de cobro de Mercado Pago o de un banco (estándar interoperable EMVCo)
/// empieza con "000201". Otros QR (por ejemplo, un enlace) pueden funcionar,
/// pero no se puede asegurar: se avisa para que lo prueben.
bool looksLikePaymentQr(String raw) => raw.trim().startsWith('000201');

/// Los QR de cobro reales miden unos 200-300 caracteres; más de esto no cabe
/// en un QR legible en pantalla y probablemente no es un QR de cobro.
const int maxPaymentQrLength = 1000;

bool isUsablePaymentQr(String raw) {
  final value = raw.trim();
  return value.isNotEmpty && value.length <= maxPaymentQrLength;
}
