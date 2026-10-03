import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/core/data/hive_database.dart';
import 'package:cobra/features/billing/domain/entities/payment_method.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/repositories/sale_repository.dart';
import 'package:cobra/features/billing/domain/usecases/sale_usecases.dart';
import 'package:cobra/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/product/domain/repositories/product_repository.dart';
import 'package:cobra/features/product/domain/usecases/product_usecases.dart';

class FakeProductRepository implements ProductRepository {
  final Map<String, Product> byBarcode;
  FakeProductRepository(this.byBarcode, {this.fallaLaBase = false});
  final bool fallaLaBase;

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    final p = byBarcode[barcode];
    if (fallaLaBase) return const Left(CacheFailure('la base no responde'));
    return p == null ? const Left(NotFoundFailure('no existe')) : Right(p);
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
  Future<Either<Failure, void>> voidSale(String saleId) async {
    final i = saved.indexWhere((s) => s.id == saleId);
    if (i < 0) return const Left(CacheFailure('Venta no encontrada'));
    saved[i] = saved[i].copyWith(voided: true);
    return const Right(null);
  }
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
      voidSaleUseCase: VoidSaleUseCase(saleRepo),
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

    test('un código que no está en los productos pide darlo de alta (no es un error)',
        () async {
      bloc.add(const ScanBarcodeEvent('999'));
      await settle();

      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.unknownBarcode, '999');
      expect(bloc.state.error, isNull);
    });

    test('un error real al buscar sí se informa', () async {
      final bloc = BillingBloc(
        getProductByBarcodeUseCase:
            GetProductByBarcodeUseCase(FakeProductRepository({}, fallaLaBase: true)),
        saveSaleUseCase: SaveSaleUseCase(saleRepo),
        getDailySalesUseCase: GetDailySalesUseCase(saleRepo),
      );
      addTearDown(bloc.close);
      bloc.add(const ScanBarcodeEvent('111'));
      await settle();

      expect(bloc.state.unknownBarcode, isNull);
      expect(bloc.state.error, contains('la base no responde'));
    });

    test('el código se limpia de espacios y los vacíos se ignoran', () async {
      bloc.add(const ScanBarcodeEvent('   '));
      await settle();
      expect(bloc.state.unknownBarcode, isNull);

      bloc.add(const ScanBarcodeEvent('  999  '));
      await settle();
      expect(bloc.state.unknownBarcode, '999');
    });

    test('mientras se pide el precio de un código, los demás se ignoran '
        '(la cámara lo lee varias veces por segundo)', () async {
      bloc.add(const ScanBarcodeEvent('999'));
      await settle();
      bloc.add(const ScanBarcodeEvent('111')); // sí existe, pero hay una ventana abierta
      bloc.add(const ScanBarcodeEvent('888'));
      await settle();

      expect(bloc.state.unknownBarcode, '999');
      expect(bloc.state.cartItems, isEmpty);
    });

    test('al atender el código se libera y se puede volver a leer', () async {
      bloc.add(const ScanBarcodeEvent('999'));
      await settle();
      bloc.add(const ClearUnknownBarcodeEvent());
      await settle();
      expect(bloc.state.unknownBarcode, isNull);

      bloc.add(const ScanBarcodeEvent('999'));
      await settle();
      expect(bloc.state.unknownBarcode, '999');
    });

    test('un producto que sí existe se agrega sin abrir nada', () async {
      bloc.add(const ScanBarcodeEvent('111'));
      await settle();

      expect(bloc.state.unknownBarcode, isNull);
      expect(bloc.state.cartItems.single.product, yerba);
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

    test('imprimir después de registrar el cobro no duplica la venta', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const SelectPaymentMethodEvent(PaymentMethod.transfer));
      bloc.add(const ConfirmSaleEvent());
      await settle();
      bloc.add(printEvent); // sin impresora: falla, pero la venta ya existe
      await settle();

      expect(saleRepo.saved.length, 1);
      expect(saleRepo.saved.single.paymentMethod, PaymentMethod.transfer);
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

  group('ventas del día y anulación', () {
    Sale venta(String id, double total) =>
        Sale(id: id, date: DateTime.now(), total: total);

    test('carga las ventas del día', () async {
      saleRepo.saved.addAll([venta('a', 100), venta('b', 250)]);
      bloc.add(LoadDailySalesEvent(DateTime.now()));
      await settle();

      expect(bloc.state.dailySales.length, 2);
      expect(bloc.state.isDailySalesLoading, isFalse);
    });

    test('anular una venta la marca y recarga la lista', () async {
      saleRepo.saved.addAll([venta('a', 100), venta('b', 250)]);
      bloc.add(const VoidSaleEvent('a'));
      await settle();

      final a = bloc.state.dailySales.firstWhere((s) => s.id == 'a');
      final b = bloc.state.dailySales.firstWhere((s) => s.id == 'b');
      expect(a.voided, isTrue);
      expect(b.voided, isFalse);
    });

    test('anular una venta inexistente informa el error', () async {
      bloc.add(const VoidSaleEvent('nada'));
      await settle();

      expect(bloc.state.error, isNotNull);
      expect(bloc.state.isDailySalesLoading, isFalse);
    });
  });

  group('medio de pago y registro del cobro', () {
    test('por defecto se cobra en efectivo', () {
      expect(bloc.state.paymentMethod, PaymentMethod.cash);
    });

    test('Registrar cobro guarda la venta con el medio elegido, sin imprimir',
        () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const SelectPaymentMethodEvent(PaymentMethod.mercadoPago));
      bloc.add(const ConfirmSaleEvent());
      await settle();

      expect(saleRepo.saved.length, 1);
      expect(saleRepo.saved.single.paymentMethod, PaymentMethod.mercadoPago);
      expect(saleRepo.saved.single.total, 2500);
      expect(bloc.state.isSaleRegistered, isTrue);
      expect(bloc.state.printSuccess, isFalse, reason: 'no se imprimió nada');
      expect(bloc.state.isPrinting, isFalse);
    });

    test('cada medio de pago queda guardado tal cual', () async {
      for (final method in PaymentMethod.values) {
        bloc.add(ClearCartEvent());
        bloc.add(const AddProductToCartEvent(yerba));
        bloc.add(SelectPaymentMethodEvent(method));
        bloc.add(const ConfirmSaleEvent());
        await settle();
      }
      expect(saleRepo.saved.map((s) => s.paymentMethod).toList(),
          PaymentMethod.values);
    });

    test('registrar dos veces no duplica la venta', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const ConfirmSaleEvent());
      await settle();
      bloc.add(const ConfirmSaleEvent());
      await settle();

      expect(saleRepo.saved.length, 1);
    });

    test('con el carrito vacío no se registra nada', () async {
      bloc.add(const ConfirmSaleEvent());
      await settle();

      expect(saleRepo.saved, isEmpty);
      expect(bloc.state.isSaleRegistered, isFalse);
    });

    test('registrada la venta, el medio de pago ya no se puede cambiar',
        () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const SelectPaymentMethodEvent(PaymentMethod.cash));
      bloc.add(const ConfirmSaleEvent());
      await settle();
      bloc.add(const SelectPaymentMethodEvent(PaymentMethod.card));
      await settle();

      expect(bloc.state.paymentMethod, PaymentMethod.cash);
      expect(saleRepo.saved.single.paymentMethod, PaymentMethod.cash);
    });

    test('una venta nueva vuelve a empezar en efectivo', () async {
      bloc.add(const AddProductToCartEvent(yerba));
      bloc.add(const SelectPaymentMethodEvent(PaymentMethod.card));
      bloc.add(const ConfirmSaleEvent());
      await settle();
      bloc.add(ClearCartEvent());
      await settle();

      expect(bloc.state.paymentMethod, PaymentMethod.cash);
      expect(bloc.state.isSaleRegistered, isFalse);
    });
  });
}
