import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/features/billing/domain/entities/payment_method.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/entities/sale_item.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/sync/data/sync_mappers.dart';

void main() {
  group('negocio', () {
    test('ida y vuelta sin perder datos', () {
      const shop = Shop(
        name: 'Almacén Don Pepe',
        addressLine1: 'Av. Siempre Viva 742',
        addressLine2: 'Córdoba',
        phoneNumber: '+54 9 351 123',
        paymentAlias: 'pepe.mp',
        footerText: '¡Gracias!',
      );
      expect(rowToShop(shopToRow(shop)), shop);
    });

    test('campos nulos de la nube quedan vacíos', () {
      expect(rowToShop({'name': null}), const Shop());
    });
  });

  group('productos', () {
    const p = Product(
        id: 'p1', name: 'Yerba', barcode: '7790', price: 2500.5, stock: 7);

    test('la fila lleva el comercio y revive productos borrados', () {
      final row = productToRow(p, 'biz-1');
      expect(row['business_id'], 'biz-1');
      expect(row['deleted_at'], isNull);
      expect(row.containsKey('deleted_at'), isTrue);
    });

    test('ida y vuelta', () {
      final back = rowToRemoteProduct(productToRow(p, 'biz-1'));
      expect(back.product, p);
      expect(back.deleted, isFalse);
    });

    test('el precio se redondea a 2 decimales (como la base)', () {
      final row = productToRow(p.copyWith(price: 1234.5678), 'b');
      expect(row['price'], 1234.57);
      expect(round2(10 * 1.1), 11.0);
    });

    test('acepta numeric como texto y detecta borrados', () {
      final r = rowToRemoteProduct({
        'id': 'p1',
        'name': 'X',
        'barcode': '1',
        'price': '99.90',
        'stock': 3,
        'deleted_at': '2026-10-02T12:00:00Z',
      });
      expect(r.product.price, 99.9);
      expect(r.deleted, isTrue);
    });
  });

  group('ventas', () {
    final sale = Sale(
      id: 's1',
      date: DateTime.utc(2026, 10, 2, 18, 30),
      total: 5800,
      voided: true,
      items: const [
        SaleItem(
            productId: 'p1',
            name: 'Yerba',
            barcode: '1',
            unitPrice: 2500,
            quantity: 2),
        SaleItem(
            productId: 'p2',
            name: 'Galletitas',
            barcode: '2',
            unitPrice: 800,
            quantity: 1),
      ],
    );

    test('la fecha viaja en UTC', () {
      final row = saleToRow(sale, 'biz-1');
      expect(row['sold_at'], '2026-10-02T18:30:00.000Z');
      expect(row['voided'], isTrue);
    });

    test('los renglones se numeran en orden', () {
      final rows = saleItemsToRows(sale, 'biz-1');
      expect(rows.map((r) => r['line']), [0, 1]);
      expect(rows.every((r) => r['sale_id'] == 's1'), isTrue);
      expect(rows.first['quantity'], 2);
    });

    test('ida y vuelta con renglones anidados, aunque lleguen desordenados', () {
      final rows = saleItemsToRows(sale, 'biz-1').reversed.toList();
      final back = rowToSale({...saleToRow(sale, 'biz-1'), 'sale_items': rows});

      expect(back.id, 's1');
      expect(back.voided, isTrue);
      expect(back.total, 5800);
      expect(back.date.toUtc(), sale.date);
      expect(back.items, sale.items);
    });

    test('una venta sin renglones (ventas viejas) se lee bien', () {
      final back = rowToSale({
        'id': 's0',
        'sold_at': '2026-01-01T00:00:00Z',
        'total': 10,
        'voided': false,
      });
      expect(back.items, isEmpty);
    });
  });

  group('medio de pago en la nube', () {
    test('viaja como código y vuelve igual', () {
      for (final method in PaymentMethod.values) {
        final sale = Sale(
            id: 's', date: DateTime.utc(2026, 1, 1), total: 1, paymentMethod: method);
        final row = saleToRow(sale, 'biz');
        expect(row['payment_method'], method.code);
        expect(rowToSale(row).paymentMethod, method);
      }
    });

    test('filas sin el campo (ventas viejas) o con un valor raro son efectivo',
        () {
      final base = {
        'id': 's',
        'sold_at': '2026-01-01T00:00:00Z',
        'total': 1,
        'voided': false,
      };
      expect(rowToSale(base).paymentMethod, PaymentMethod.cash);
      expect(rowToSale({...base, 'payment_method': null}).paymentMethod,
          PaymentMethod.cash);
      expect(rowToSale({...base, 'payment_method': 'otra_cosa'}).paymentMethod,
          PaymentMethod.cash);
    });
  });
}
