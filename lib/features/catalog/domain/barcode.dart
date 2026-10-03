// Utilidades para códigos de barras (EAN-8, EAN-13 y UPC-A de 12 dígitos).

/// Deja el código en su forma canónica o devuelve null si no tiene forma de
/// código de barras: solo dígitos, de 8, 12 o 13 posiciones.
/// Un UPC-A (12 dígitos) se completa con un 0 adelante: es el mismo código que
/// muchos lectores devuelven como EAN-13.
String? normalizeBarcode(String raw) {
  final text = raw.trim();
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  switch (text.length) {
    case 8:
    case 13:
      return text;
    case 12:
      return '0$text';
    default:
      return null;
  }
}

/// Verifica el dígito de control de un código ya normalizado (8 o 13 dígitos).
/// Sirve para detectar errores de tipeo.
bool barcodeChecksumOk(String code) {
  if (code.length != 8 && code.length != 13) return false;
  if (!RegExp(r'^\d+$').hasMatch(code)) return false;
  final digits = code.split('').map(int.parse).toList();
  final check = digits.removeLast();
  var sum = 0;
  // Desde la derecha del cuerpo los pesos alternan 3, 1, 3, 1...
  for (var i = 0; i < digits.length; i++) {
    final fromRight = digits.length - 1 - i;
    sum += digits[i] * (fromRight.isEven ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == check;
}
