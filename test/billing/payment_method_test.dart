import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cobra/features/billing/data/models/sale_item_model.dart';
import 'package:cobra/features/billing/data/models/sale_model.dart';
import 'package:cobra/features/billing/domain/entities/payment_method.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/entities/sales_summary.dart';

/// Escribe las ventas con el formato ANTERIOR (5 campos, sin medio de pago)
/// cuando [writeLegacy] está activo; para probar que lo ya guardado en los
/// teléfonos se sigue leyendo bien.
class SwitchableSaleAdapter extends TypeAdapter<SaleModel> {
  static bool writeLegacy = false;
  final _real = SaleModelAdapter();

  @override
  int get typeId => 2;

  @override
  SaleModel read(BinaryReader reader) => _real.read(reader);

  @override
  void write(BinaryWriter writer, SaleModel obj) {
    if (!writeLegacy) return _real.write(writer, obj);
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.total)
      ..writeByte(3)
      ..write(obj.voided)
      ..writeByte(4)
      ..write(obj.items);
  }
}

Sale venta(String id, double total, PaymentMethod method,
        {bool voided = false}) =>
    Sale(
      id: id,
      date: DateTime(2026, 10, 3, 12),
      total: total,
      voided: voided,
      paymentMethod: method,
    );

void main() {
  group('PaymentMethod', () {
    test('los códigos guardados no cambian (se persisten en teléfono y nube)',
        () {
      expect(PaymentMethod.cash.code, 'cash');
      expect(PaymentMethod.mercadoPago.code, 'mercado_pago');
      expect(PaymentMethod.transfer.code, 'transfer');
      expect(PaymentMethod.card.code, 'card');
    });

    test('fromCode reconoce cada código', () {
      for (final m in PaymentMethod.values) {
        expect(PaymentMethod.fromCode(m.code), m);
      }
    });

    test('un código vacío o desconocido es efectivo', () {
      expect(PaymentMethod.fromCode(null), PaymentMethod.cash);
      expect(PaymentMethod.fromCode(''), PaymentMethod.cash);
      expect(PaymentMethod.fromCode('bitcoin'), PaymentMethod.cash);
    });

    test('las etiquetas son ASCII: se imprimen en impresoras térmicas', () {
      for (final m in PaymentMethod.values) {
        expect(m.label.codeUnits.every((c) => c < 128), isTrue,
            reason: '"${m.label}" tiene caracteres no ASCII');
      }
    });
  });

  group('SalesSummary', () {
    test('sin ventas todo es cero', () {
      final s = SalesSummary.from(const []);
      expect(s.count, 0);
      expect(s.total, 0);
      expect(s.byMethod, isEmpty);
    });

    test('agrupa por medio de pago y suma el total', () {
      final s = SalesSummary.from([
        venta('1', 1000, PaymentMethod.cash),
        venta('2', 500, PaymentMethod.cash),
        venta('3', 2500, PaymentMethod.mercadoPago),
        venta('4', 300, PaymentMethod.transfer),
      ]);

      expect(s.count, 4);
      expect(s.total, 4300);
      expect(s.byMethod[PaymentMethod.cash],
          const MethodTotal(count: 2, total: 1500));
      expect(s.byMethod[PaymentMethod.mercadoPago],
          const MethodTotal(count: 1, total: 2500));
      expect(s.byMethod.containsKey(PaymentMethod.card), isFalse,
          reason: 'solo aparecen medios con ventas');
    });

    test('las ventas anuladas no suman', () {
      final s = SalesSummary.from([
        venta('1', 1000, PaymentMethod.cash),
        venta('2', 9999, PaymentMethod.cash, voided: true),
      ]);
      expect(s.count, 1);
      expect(s.total, 1000);
      expect(s.byMethod[PaymentMethod.cash]!.count, 1);
    });

    test('mantiene el orden de los medios de pago', () {
      final s = SalesSummary.from([
        venta('1', 1, PaymentMethod.card),
        venta('2', 1, PaymentMethod.cash),
        venta('3', 1, PaymentMethod.mercadoPago),
      ]);
      expect(s.byMethod.keys.toList(), [
        PaymentMethod.cash,
        PaymentMethod.mercadoPago,
        PaymentMethod.card,
      ]);
    });
  });

  group('persistencia', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cobra_pay_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(SaleItemModelAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(SwitchableSaleAdapter());
      }
      SwitchableSaleAdapter.writeLegacy = false;
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('el medio de pago sobrevive a guardar y reabrir', () async {
      var box = await Hive.openBox<SaleModel>('s');
      await box.put('1',
          SaleModel.fromEntity(venta('1', 100, PaymentMethod.mercadoPago)));
      await box.close();

      box = await Hive.openBox<SaleModel>('s');
      expect(box.get('1')!.toEntity().paymentMethod, PaymentMethod.mercadoPago);
    });

    test('las ventas viejas (sin medio de pago) se leen como efectivo',
        () async {
      SwitchableSaleAdapter.writeLegacy = true;
      var box = await Hive.openBox<SaleModel>('s');
      await box.put(
          'vieja', SaleModel.fromEntity(venta('vieja', 777, PaymentMethod.card)));
      await box.close();

      SwitchableSaleAdapter.writeLegacy = false;
      box = await Hive.openBox<SaleModel>('s');
      final leida = box.get('vieja')!.toEntity();

      expect(leida.paymentMethod, PaymentMethod.cash);
      expect(leida.total, 777, reason: 'el resto de los datos no se pierde');
      expect(leida.id, 'vieja');
    });

    test('anular una venta conserva su medio de pago', () {
      final anulada =
          venta('1', 10, PaymentMethod.transfer).copyWith(voided: true);
      expect(anulada.paymentMethod, PaymentMethod.transfer);
      expect(anulada.voided, isTrue);
    });
  });
}
