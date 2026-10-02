import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cobra/features/billing/data/models/sale_item_model.dart';
import 'package:cobra/features/billing/data/models/sale_model.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/entities/sale_item.dart';

void main() {
  const items = [
    SaleItem(
        productId: 'p1',
        name: 'Yerba 1kg',
        barcode: '7790001',
        unitPrice: 2500,
        quantity: 2),
    SaleItem(
        productId: 'p2',
        name: 'Galletitas',
        barcode: '7790002',
        unitPrice: 800,
        quantity: 1),
  ];
  final sale = Sale(
    id: 'sale-1',
    date: DateTime(2026, 10, 2, 15, 30),
    total: 5800,
    items: items,
  );

  test('SaleItem calcula el subtotal', () {
    expect(items[0].subtotal, 5000);
    expect(items[1].subtotal, 800);
  });

  test('Sale.copyWith conserva los productos al anular', () {
    final voided = sale.copyWith(voided: true);
    expect(voided.voided, isTrue);
    expect(voided.items, items);
    expect(voided.total, 5800);
  });

  test('SaleModel convierte entidad -> modelo -> entidad sin perder datos', () {
    expect(SaleModel.fromEntity(sale).toEntity(), sale);
  });

  group('persistencia con Hive', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cobra_hive_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(SaleItemModelAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(SaleModelAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('guarda y recupera una venta con sus productos y estado', () async {
      var box = await Hive.openBox<SaleModel>('sales_test');
      await box.put(sale.id, SaleModel.fromEntity(sale.copyWith(voided: true)));
      await box.close();

      box = await Hive.openBox<SaleModel>('sales_test');
      final loaded = box.get(sale.id)!.toEntity();

      expect(loaded.voided, isTrue);
      expect(loaded.total, 5800);
      expect(loaded.items, items);
    });
  });
}
