import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/core/widgets/primary_button.dart';
import 'package:cobra/features/catalog/domain/catalog_product.dart';
import 'package:cobra/features/catalog/domain/catalog_repository.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/product/domain/repositories/product_repository.dart';
import 'package:cobra/features/product/domain/usecases/product_usecases.dart';
import 'package:cobra/features/product/presentation/bloc/product_bloc.dart';
import 'package:cobra/features/product/presentation/pages/add_product_page.dart';

const coca = CatalogProduct(ean: '7790895000430', name: 'Coca Cola 1,5 L', brand: 'Coca Cola');
const fanta = CatalogProduct(ean: '7790895000454', name: 'Gaseosa Naranja Fanta 1,5 L', brand: 'Fanta');

class FakeCatalog implements CatalogRepository {
  final Map<String, CatalogProduct> data = {coca.ean: coca, fanta.ean: fanta};
  final List<String> consultas = [];

  @override
  Future<CatalogProduct?> lookup(String barcode) async {
    consultas.add(barcode);
    return data[barcode];
  }
}

class FakeProductRepository implements ProductRepository {
  final List<Product> saved = [];

  @override
  Future<Either<Failure, List<Product>>> getProducts() async => Right(saved);
  @override
  Future<Either<Failure, void>> addProduct(Product p) async {
    saved.add(p);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeCatalog catalog;
  late FakeProductRepository repo;

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/add', builder: (_, __) => AddProductPage(catalog: catalog)),
      // Escáner simulado: devuelve el código de la Fanta.
      GoRoute(
        path: '/scanner',
        builder: (context, _) => Scaffold(
          body: TextButton(
              onPressed: () => context.pop(fanta.ean), child: const Text('Simular escaneo')),
        ),
      ),
    ]);
    await tester.pumpWidget(BlocProvider(
      create: (_) => ProductBloc(
        getProductsUseCase: GetProductsUseCase(repo),
        addProductUseCase: AddProductUseCase(repo),
        updateProductUseCase: UpdateProductUseCase(repo),
        deleteProductUseCase: DeleteProductUseCase(repo),
        updatePricesMassivelyUseCase: UpdatePricesMassivelyUseCase(repo),
      )..add(LoadProducts()),
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/add');
    await tester.pumpAndSettle();
  }

  Finder campoCodigo() => find.byType(TextFormField).at(0);
  Finder campoNombre() => find.byType(TextFormField).at(1);
  String nombre(WidgetTester tester) => (tester.widget<TextFormField>(campoNombre()).controller!).text;

  Future<void> escribirCodigo(WidgetTester tester, String code) async {
    await tester.enterText(campoCodigo(), code);
    await tester.pump(const Duration(milliseconds: 400)); // espera del debounce
    await tester.pumpAndSettle();
  }

  setUp(() {
    catalog = FakeCatalog();
    repo = FakeProductRepository();
  });

  testWidgets('al escribir un código del catálogo, el nombre se completa solo', (tester) async {
    await abrir(tester);
    expect(nombre(tester), '');

    await escribirCodigo(tester, coca.ean);

    expect(nombre(tester), 'Coca Cola 1,5 L');
    expect(find.textContaining('Nombre del catálogo'), findsOneWidget);
  });

  testWidgets('un código que no está en el catálogo no completa nada', (tester) async {
    await abrir(tester);
    await escribirCodigo(tester, '7799999999990');

    expect(nombre(tester), '');
    expect(find.textContaining('catálogo'), findsOneWidget, reason: 'solo el texto de ayuda general');
    expect(find.textContaining('Usar el del catálogo'), findsNothing);
  });

  testWidgets('si ya escribiste un nombre, NO se pisa: se ofrece usar el del catálogo', (tester) async {
    await abrir(tester);
    await tester.enterText(campoNombre(), 'Coca de la heladera');
    await escribirCodigo(tester, coca.ean);

    expect(nombre(tester), 'Coca de la heladera');
    expect(find.text('Usar el del catálogo: Coca Cola 1,5 L'), findsOneWidget);

    await tester.tap(find.text('Usar el del catálogo: Coca Cola 1,5 L'));
    await tester.pumpAndSettle();

    expect(nombre(tester), 'Coca Cola 1,5 L');
    expect(find.textContaining('Nombre del catálogo'), findsOneWidget);
  });

  testWidgets('al cambiar el código se actualiza el nombre sugerido', (tester) async {
    await abrir(tester);
    await escribirCodigo(tester, coca.ean);
    expect(nombre(tester), 'Coca Cola 1,5 L');

    await escribirCodigo(tester, fanta.ean);

    expect(nombre(tester), 'Gaseosa Naranja Fanta 1,5 L');
  });

  testWidgets('si cambiás el código a uno desconocido, se limpia el nombre autocompletado', (tester) async {
    await abrir(tester);
    await escribirCodigo(tester, coca.ean);
    await escribirCodigo(tester, '7799999999990');

    expect(nombre(tester), '');
  });

  testWidgets('un nombre que editaste a mano se respeta aunque cambies el código', (tester) async {
    await abrir(tester);
    await escribirCodigo(tester, coca.ean);
    await tester.enterText(campoNombre(), 'Coca Cola 1,5 L (retornable)');

    await escribirCodigo(tester, '7799999999990');

    expect(nombre(tester), 'Coca Cola 1,5 L (retornable)');
  });

  testWidgets('escanear busca enseguida y completa el nombre', (tester) async {
    await abrir(tester);

    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular escaneo'));
    await tester.pumpAndSettle();

    expect(nombre(tester), 'Gaseosa Naranja Fanta 1,5 L');
    expect(tester.widget<TextFormField>(campoCodigo()).controller!.text, fanta.ean);
  });

  testWidgets('mientras se escribe no se hacen búsquedas con códigos a medio escribir', (tester) async {
    await abrir(tester);

    await tester.enterText(campoCodigo(), '77908950'); // 8 dígitos: parece un EAN-8
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(campoCodigo(), coca.ean);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(catalog.consultas, [coca.ean], reason: 'solo el código completo');
  });

  testWidgets('avisa si el dígito de control no coincide (error de tipeo)', (tester) async {
    await abrir(tester);
    await escribirCodigo(tester, '7790895000431'); // último dígito mal

    expect(find.textContaining('Revisá el código'), findsOneWidget);

    await escribirCodigo(tester, coca.ean);
    expect(find.textContaining('Revisá el código'), findsNothing);
  });

  testWidgets('guardar usa el nombre del catálogo y el precio que escribiste', (tester) async {
    await abrir(tester);
    await escribirCodigo(tester, coca.ean);
    await tester.enterText(find.byType(TextFormField).at(2), '2500');

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(repo.saved.length, 1);
    expect(repo.saved.single.name, 'Coca Cola 1,5 L');
    expect(repo.saved.single.barcode, coca.ean);
    expect(repo.saved.single.price, 2500);
  });

  testWidgets('sigue funcionando a mano cuando no hay catálogo', (tester) async {
    await abrir(tester);
    await tester.enterText(campoCodigo(), '12345');
    await tester.enterText(campoNombre(), 'Producto propio');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(repo.saved.single.name, 'Producto propio');
    expect(repo.saved.single.barcode, '12345');
  });
}
