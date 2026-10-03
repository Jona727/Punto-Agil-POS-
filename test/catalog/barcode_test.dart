import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/features/catalog/domain/barcode.dart';

void main() {
  group('normalizeBarcode', () {
    test('EAN-13 y EAN-8 quedan igual', () {
      expect(normalizeBarcode('7790895000430'), '7790895000430');
      expect(normalizeBarcode('77940131'), '77940131');
    });

    test('un UPC-A de 12 dígitos se completa con un 0 (igual que muchos lectores)', () {
      expect(normalizeBarcode('038000846731'), '0038000846731');
      expect(normalizeBarcode('0038000846731'), '0038000846731');
    });

    test('ignora espacios alrededor', () {
      expect(normalizeBarcode('  7790895000430 '), '7790895000430');
    });

    test('rechaza lo que no es un código de barras', () {
      expect(normalizeBarcode(''), isNull);
      expect(normalizeBarcode('abc'), isNull);
      expect(normalizeBarcode('7790895 000430'), isNull, reason: 'espacio en el medio');
      expect(normalizeBarcode('779089500043X'), isNull);
      expect(normalizeBarcode('12345'), isNull, reason: 'largo inválido');
      expect(normalizeBarcode('77908950004301'), isNull, reason: '14 dígitos');
      expect(normalizeBarcode('7790895000'), isNull);
    });
  });

  group('barcodeChecksumOk', () {
    test('acepta códigos reales', () {
      for (final code in [
        '7790895000430', // Coca Cola 1,5 L
        '7790290001193', // Fernet Branca
        '7790040929609', // Bagley
        '0038000846731', // Pringles (UPC con 0)
        '77940131', // EAN-8 de Arcor
      ]) {
        expect(barcodeChecksumOk(code), isTrue, reason: code);
      }
    });

    test('detecta un dígito equivocado', () {
      expect(barcodeChecksumOk('7790895000431'), isFalse);
      expect(barcodeChecksumOk('7790895000440'), isFalse);
      expect(barcodeChecksumOk('77940132'), isFalse);
    });

    test('detecta dos dígitos intercambiados (error de tipeo típico)', () {
      expect(barcodeChecksumOk('7790895000340'), isFalse);
    });

    test('largos o caracteres inválidos', () {
      expect(barcodeChecksumOk('123'), isFalse);
      expect(barcodeChecksumOk('779089500043a'), isFalse);
    });
  });
}
