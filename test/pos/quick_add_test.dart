import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:cobra/core/data/hive_database.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/core/utils/app_validators.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/repositories/sale_repository.dart';
import 'package:cobra/features/billing/domain/usecases/sale_usecases.dart';
import 'package:cobra/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:cobra/features/billing/presentation/widgets/manual_barcode_dialog.dart';
import 'package:cobra/features/billing/presentation/widgets/quick_add_product_sheet.dart';
import 'package:cobra/features/billing/presentation/widgets/unknown_barcode_handler.dart';
import 'package:cobra/features/catalog/domain/catalog_product.dart';
import 'package:cobra/features/catalog/domain/catalog_repository.dart';
import 'package:cobra/features/product/data/models/product_model.dart';
import 'package:cobra/features/product/data/repositories/product_repository_impl.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/product/domain/repositories/product_repository.dart';
import 'package:cobra/features/product/domain/usecases/product_usecases.dart';
import 'package:cobra/features/product/presentation/bloc/product_bloc.dart';

const coca = CatalogProduct(ean: '7790895000430', name: 'Coca Cola 1,5 L');

class FakeCatalog implements CatalogRepository {
  FakeCatalog([Map<String, CatalogProduct>? data]) : data = data ?? {coca.ean: coca};
  final Map<String, CatalogProduct> data;

  @override
  Future<CatalogProduct?> lookup(String barcode) async => data[barcode];
}

/// Productos del comercio en memoria.
class MemProducts implements ProductRepository {
  final List<Product> items = [];

  @override
  Future<Either<Failure, List<Product>>> getProducts() async => Right(List.of(items));

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    final p = items.where((p) => p.barcode == barcode).firstOrNull;
    return p == null ? Left(NotFoundFailure('no existe $barcode')) : Right(p);
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    items.add(product);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemSales implements SaleRepository {
  @override
  Future<Either<Failure, void>> saveSale(Sale sale) async => const Right(null);
  @override
  Future<Either<Failure, List<Sale>>> getSalesByDate(DateTime date) async => const Right([]);
  @override
  Future<Either<Failure, void>> voidSale(String saleId) async => const Right(null);
}

void main() {
  group('validación del precio escrito a mano', () {
    test('acepta coma o punto', () {
      expect(AppValidators.parsePrice('1500'), 1500);
      expect(AppValidators.parsePrice('1500.50'), 1500.5);
      expect(AppValidators.parsePrice('1500,50'), 1500.5);
      expect(AppValidators.parsePrice(' 99,9 '), 99.9);
    });

    test('rechaza vacío, texto y precios en cero o negativos', () {
      expect(AppValidators.positivePrice(null), isNotNull);
      expect(AppValidators.positivePrice(''), isNotNull);
      expect(AppValidators.positivePrice('abc'), isNotNull);
      expect(AppValidators.positivePrice('0'), isNotNull);
      expect(AppValidators.positivePrice('-5'), isNotNull);
      expect(AppValidators.positivePrice('1500'), isNull);
      expect(AppValidators.positivePrice('1500,50'), isNull);
    });
  });

  group('ventana de alta rápida', () {
    Future<Product?> Function() abrir(WidgetTester tester, String barcode, FakeCatalog catalog) {
      Product? resultado;
      var cerrada = false;
      return () async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await showModalBottomSheet<Product>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => QuickAddProductSheet(barcode: barcode, catalog: catalog),
                  );
                  cerrada = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(cerrada, isFalse);
        return resultado;
      };
    }

    testWidgets('con el código en el catálogo: nombre listo, solo falta el precio', (tester) async {
      await abrir(tester, coca.ean, FakeCatalog())();

      expect(find.text('Producto nuevo'), findsOneWidget);
      expect(find.text('Código ${coca.ean}'), findsOneWidget);
      expect(find.textContaining('Encontrado en el catálogo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Coca Cola 1,5 L'), findsOneWidget);
    });

    testWidgets('si no está en el catálogo, pide también el nombre', (tester) async {
      await abrir(tester, '7799999999990', FakeCatalog())();

      expect(find.textContaining('No está en el catálogo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Coca Cola 1,5 L'), findsNothing);
    });

    testWidgets('no deja confirmar sin precio ni con precio cero', (tester) async {
      await abrir(tester, coca.ean, FakeCatalog())();

      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresá el precio'), findsOneWidget);
      expect(find.text('Producto nuevo'), findsOneWidget, reason: 'la ventana sigue abierta');

      await tester.enterText(find.widgetWithText(TextFormField, 'Precio de venta'), '0');
      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();
      expect(find.text('El precio debe ser mayor a 0'), findsOneWidget);
    });

    testWidgets('no deja confirmar sin nombre', (tester) async {
      await abrir(tester, '7799999999990', FakeCatalog())();

      await tester.enterText(find.widgetWithText(TextFormField, 'Precio de venta'), '500');
      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresá un nombre'), findsOneWidget);
    });
  });

  group('en la caja: código desconocido -> precio -> a la venta', () {
    late MemProducts productos;
    late BillingBloc billing;
    late ProductBloc productBloc;

    Future<void> abrirCaja(WidgetTester tester, {FakeCatalog? catalog}) async {
      productos = MemProducts();
      final sales = MemSales();
      billing = BillingBloc(
        getProductByBarcodeUseCase: GetProductByBarcodeUseCase(productos),
        saveSaleUseCase: SaveSaleUseCase(sales),
        getDailySalesUseCase: GetDailySalesUseCase(sales),
      );
      productBloc = ProductBloc(
        getProductsUseCase: GetProductsUseCase(productos),
        addProductUseCase: AddProductUseCase(productos),
        updateProductUseCase: UpdateProductUseCase(productos),
        deleteProductUseCase: DeleteProductUseCase(productos),
        updatePricesMassivelyUseCase: UpdatePricesMassivelyUseCase(productos),
      );
      addTearDown(() {
        billing.close();
        productBloc.close();
      });

      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider.value(value: billing),
          BlocProvider.value(value: productBloc),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: UnknownBarcodeHandler(
              catalog: catalog ?? FakeCatalog(),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ));
    }

    Future<void> leer(WidgetTester tester, String code) async {
      billing.add(ScanBarcodeEvent(code));
      await tester.pumpAndSettle();
    }

    testWidgets('el caso completo: lee el código, pone el precio y queda en la venta y en los productos',
        (tester) async {
      await abrirCaja(tester);

      await leer(tester, coca.ean);
      expect(find.text('Producto nuevo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Coca Cola 1,5 L'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Precio de venta'), '2500,50');
      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();

      // Quedó en la venta, con el precio y el nombre del catálogo
      final item = billing.state.cartItems.single;
      expect(item.product.name, 'Coca Cola 1,5 L');
      expect(item.product.price, 2500.5);
      expect(item.quantity, 1);
      expect(billing.state.totalAmount, 2500.5);
      // ...y quedó guardado entre los productos del comercio
      expect(productos.items.single.barcode, coca.ean);
      expect(productos.items.single.price, 2500.5);
      expect(find.text('Producto nuevo'), findsNothing, reason: 'la ventana se cerró');
      expect(find.textContaining('agregado a la venta y guardado'), findsOneWidget);
      expect(billing.state.unknownBarcode, isNull);
    });

    testWidgets('la segunda vez que se lee el mismo código ya no pregunta: se suma a la venta',
        (tester) async {
      await abrirCaja(tester);
      await leer(tester, coca.ean);
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio de venta'), '2500');
      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();

      await leer(tester, coca.ean);

      expect(find.text('Producto nuevo'), findsNothing);
      expect(billing.state.cartItems.single.quantity, 2);
      expect(billing.state.totalAmount, 5000);
      expect(productos.items.length, 1, reason: 'no se duplicó el producto');
    });

    testWidgets('si se cancela, no se guarda nada y se puede volver a leer', (tester) async {
      await abrirCaja(tester);
      await leer(tester, coca.ean);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Producto nuevo'), findsNothing);
      expect(billing.state.cartItems, isEmpty);
      expect(productos.items, isEmpty);
      expect(billing.state.unknownBarcode, isNull);

      await leer(tester, coca.ean);
      expect(find.text('Producto nuevo'), findsOneWidget, reason: 'se puede reintentar');
    });

    testWidgets('un código que tampoco está en el catálogo se carga con nombre y precio escritos',
        (tester) async {
      await abrirCaja(tester);
      await leer(tester, '7799999999990');

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Alfajor artesanal');
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio de venta'), '800');
      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();

      expect(billing.state.cartItems.single.product.name, 'Alfajor artesanal');
      expect(productos.items.single.name, 'Alfajor artesanal');
    });

    testWidgets('un producto ya cargado no abre la ventana', (tester) async {
      await abrirCaja(tester);
      productos.items.add(const Product(id: 'p1', name: 'Yerba', barcode: '111', price: 3000));

      await leer(tester, '111');

      expect(find.text('Producto nuevo'), findsNothing);
      expect(billing.state.cartItems.single.product.name, 'Yerba');
    });

    testWidgets('mientras la ventana está abierta, lecturas repetidas no abren otra', (tester) async {
      await abrirCaja(tester);
      billing.add(const ScanBarcodeEvent('7790895000430'));
      billing.add(const ScanBarcodeEvent('7790895000430'));
      billing.add(const ScanBarcodeEvent('7790895000430'));
      await tester.pumpAndSettle();

      expect(find.text('Producto nuevo'), findsOneWidget);
    });
  });

  group('ingresar el código a mano', () {
    testWidgets('devuelve el código escrito', (tester) async {
      String? codigo;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => codigo = await showManualBarcodeDialog(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  7790895000430 ');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      expect(codigo, '7790895000430');
    });

    testWidgets('no acepta vacío y se puede cancelar', (tester) async {
      String? codigo = 'sin cambios';
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => codigo = await showManualBarcodeDialog(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribí el código de barras'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(codigo, isNull);
    });
  });

  group('búsqueda de productos del comercio (base real)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cobra_pos_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductModelAdapter());
      await Hive.openBox<ProductModel>(HiveDatabase.productBoxName);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('un código que no existe devuelve "no encontrado", no un error', () async {
      final result = await ProductRepositoryImpl().getProductByBarcode('7799999999990');
      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<NotFoundFailure>()), (_) => fail('no debía encontrar'));
    });

    test('un UPC de 12 dígitos encuentra el producto guardado con 13', () async {
      final repo = ProductRepositoryImpl();
      await repo.addProduct(const Product(
          id: 'p', name: 'Pringles', barcode: '0038000846731', price: 1000));

      expect((await repo.getProductByBarcode('038000846731')).isRight(), isTrue);
      expect((await repo.getProductByBarcode('0038000846731')).isRight(), isTrue);
      expect((await repo.getProductByBarcode(' 0038000846731 ')).isRight(), isTrue);
    });

    test('y al revés: guardado con 12, leído con 13', () async {
      final repo = ProductRepositoryImpl();
      await repo.addProduct(const Product(
          id: 'p', name: 'Pringles', barcode: '038000846731', price: 1000));

      expect((await repo.getProductByBarcode('0038000846731')).isRight(), isTrue);
    });

    test('códigos propios (no estándar) se buscan tal cual', () async {
      final repo = ProductRepositoryImpl();
      await repo.addProduct(const Product(id: 'p', name: 'Pan', barcode: '123', price: 100));

      expect((await repo.getProductByBarcode('123')).isRight(), isTrue);
      expect((await repo.getProductByBarcode('124')).isLeft(), isTrue);
    });
  });
}
