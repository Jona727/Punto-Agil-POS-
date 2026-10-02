import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/core/data/hive_database.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/repositories/sale_repository.dart';
import 'package:cobra/features/billing/domain/usecases/sale_usecases.dart';
import 'package:cobra/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/product/domain/repositories/product_repository.dart';
import 'package:cobra/features/product/domain/usecases/product_usecases.dart';

class FakeProductRepository implements ProductRepository {
  final Map<String, Product> byBarcode;
  FakeProductRepository(this.byBarcode);

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    final p = byBarcode[barcode];
    return p == null ? const Left(CacheFailure('no existe')) : Right(p);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSaleRepository implements SaleRepository {
  final List<Sale> saved = [];

  @override
  Future<Either<Failure, void>> saveSale(Sale sale) async {
    saved.add(sale);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<Sale>>> getSalesByDate(DateTime date) async =>
      Right(saved);

  @override
  Future<Either<Failure, void>> voidSale(String saleId) async =>
      const Right(null);
}

void main() {
  const yerba = Product(
      id: 'p1', name: 'Yerba', barcode: '111', price: 2500, stock: 10);
  const galletitas = Product(
      id: 'p2', name: 'Galletitas', barcode: '222', price: 800, stock: 5);

  late FakeSaleRepository saleRepo;
  late BillingBloc bloc;

  setUp(() {
    saleRepo = FakeSaleRepository();
    bloc = BillingBloc(
      getProductByBarcodeUseCase: GetProductByBarcodeUseCase(
          FakeProductRepository({'111': yerba, '222': galletitas})),
      saveSaleUseCase: SaveSaleUseCase(saleRepo),
      getDailySalesUseCase: GetDailySalesUseCase(saleRepo),
    );
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('carrito', () {
    test('agregar el mismo producto dos veces suma la cantidad', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const AddProductToCartEvent(yerba));
      await settle();

      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.cartItems.first.quantity, 2);
      expect(bloc.state.totalAmount, 5000);
    });

    test('el total suma productos distintos', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const AddProductToCartEvent(galletitas));
      bloc.add(const UpdateQuantityEvent('p2', 3));
      await settle();

      expect(bloc.state.totalAmount, 2500 + 800 * 3);
    });

    test('cantidad 0 elimina el producto', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const UpdateQuantityEvent('p1', 0));
      await settle();

      expect(bloc.state.cartItems, isEmpty);
    });

    test('cambiar el precio afecta solo a este carrito', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const UpdateItemPriceEvent('p1', 2000));
      await settle();

      expect(bloc.state.totalAmount, 2000);
      expect(yerba.price, 2500);
    });

    test('un precio negativo se ignora', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const UpdateItemPriceEvent('p1', -1));
      await settle();

      expect(bloc.state.totalAmount, 2500);
    });

    test('vaciar el carrito lo deja en cero', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(ClearCartEvent());
      await settle();

      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.totalAmount, 0);
    });
  });

  group('escaneo', () {
    test('un código existente agrega el producto', () async {
      bloc.add(const ScanBarcodeEvent('111'));
      await settle();

      expect(bloc.state.cartItems.single.product, yerba);
    });

    test('un código inexistente informa el error', () async {
      bloc.add(const ScanBarcodeEvent('999'));
      await settle();

      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.error, contains('999'));
    });
  });

  group('cobro', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cobra_bloc_test');
      Hive.init(dir.path);
      // Sin impresora configurada: imprimir siempre falla.
      await Hive.openBox(HiveDatabase.settingsBoxName);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    const printEvent = PrintReceiptEvent(
      shopName: 'Mi Negocio',
      address1: '',
      address2: '',
      phone: '',
      footer: '',
    );

    test('la venta se guarda aunque la impresora falle', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const UpdateQuantityEvent('p1', 2));
      bloc.add(printEvent);
      await settle();

      expect(saleRepo.saved.length, 1);
      expect(saleRepo.saved.single.total, 5000);
      expect(saleRepo.saved.single.items.single.name, 'Yerba');
      expect(saleRepo.saved.single.items.single.quantity, 2);
      expect(bloc.state.printSuccess, isFalse);
    });

    test('reintentar imprimir no duplica la venta', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(printEvent);
      await settle();
      bloc.add(printEvent);
      await settle();

      expect(saleRepo.saved.length, 1);
    });

    test('con el carrito vacío no se registra nada', () async {
      bloc.add(printEvent);
      await settle();

      expect(saleRepo.saved, isEmpty);
    });

    test('una venta nueva (carrito vaciado) genera otro registro', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(printEvent);
      await settle();
      bloc.add(ClearCartEvent());
      bloc.add(const AddProductToCartEvent(galletitas));
      bloc.add(printEvent);
      await settle();

      expect(saleRepo.saved.length, 2);
      expect(saleRepo.saved.first.id, isNot(saleRepo.saved.last.id));
    });
  });
}
