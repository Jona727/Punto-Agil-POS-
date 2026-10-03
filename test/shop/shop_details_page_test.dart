import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/features/shop/data/qr_image_reader.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/shop/domain/repositories/shop_repository.dart';
import 'package:cobra/features/shop/domain/usecases/shop_usecases.dart';
import 'package:cobra/features/shop/presentation/bloc/shop_bloc.dart';
import 'package:cobra/features/shop/presentation/pages/shop_details_page.dart';

const qrEstandar = '00020101021143650016com.mercadolibre0201...630412AB';

class FakeShopRepository implements ShopRepository {
  FakeShopRepository(this.shop);
  Shop shop;
  final List<Shop> saved = [];

  @override
  Future<Either<Failure, Shop>> getShop() async => Right(shop);

  @override
  Future<Either<Failure, void>> updateShop(Shop s) async {
    saved.add(s);
    shop = s;
    return const Right(null);
  }
}

class FakeQrReader implements QrImageReader {
  FakeQrReader(this.result);
  QrReadResult result;
  int llamadas = 0;

  @override
  Future<QrReadResult> pickAndRead() async {
    llamadas++;
    return result;
  }
}

const negocio = Shop(
  name: 'Kiosco Lucía',
  addressLine1: 'Av. Siempre Viva 742',
  phoneNumber: '+54 9 351 123',
  paymentAlias: 'jonaram727',
  footerText: '¡Gracias!',
);

void main() {
  late FakeShopRepository repo;

  Future<void> abrir(WidgetTester tester, FakeQrReader reader) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/shop', builder: (_, __) => ShopDetailsPage(qrReader: reader)),
    ]);
    await tester.pumpWidget(BlocProvider(
      create: (_) => ShopBloc(
        getShopUseCase: GetShopUseCase(repo),
        updateShopUseCase: UpdateShopUseCase(repo),
      ),
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/shop');
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  testWidgets('cargar el QR desde una imagen y guardarlo', (tester) async {
    repo = FakeShopRepository(negocio);
    final reader = FakeQrReader(const QrReadResult.ok(qrEstandar));
    await abrir(tester, reader);

    expect(find.text('Cargar mi QR desde una imagen'), findsOneWidget);
    expect(find.text('QR cargado ✅'), findsNothing);

    await tocar(tester, 'Cargar mi QR desde una imagen');

    expect(reader.llamadas, 1);
    expect(find.text('QR cargado ✅'), findsOneWidget);
    expect(find.textContaining('QR leído'), findsOneWidget);
    expect(repo.saved, isEmpty, reason: 'recién se guarda al tocar Guardar datos');

    await tocar(tester, 'Guardar datos');

    expect(repo.saved.single.paymentQr, qrEstandar);
    expect(repo.saved.single.name, 'Kiosco Lucía', reason: 'no se pierden los demás datos');
    expect(repo.saved.single.paymentAlias, 'jonaram727');
  });

  testWidgets('si no se encuentra un QR en la imagen, se avisa y no cambia nada',
      (tester) async {
    repo = FakeShopRepository(negocio);
    await abrir(
        tester,
        FakeQrReader(const QrReadResult.failed(
            'No encontramos un QR en esa imagen.')));

    await tocar(tester, 'Cargar mi QR desde una imagen');

    expect(find.textContaining('No encontramos un QR'), findsOneWidget);
    expect(find.text('QR cargado ✅'), findsNothing);
    expect(find.text('Cargar mi QR desde una imagen'), findsOneWidget);
  });

  testWidgets('cancelar la galería no hace nada', (tester) async {
    repo = FakeShopRepository(negocio);
    await abrir(tester, FakeQrReader(const QrReadResult.cancelled()));

    await tocar(tester, 'Cargar mi QR desde una imagen');

    expect(find.text('QR cargado ✅'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('un QR que no es de cobro estándar se carga pero con advertencia',
      (tester) async {
    repo = FakeShopRepository(negocio);
    await abrir(
        tester, FakeQrReader(const QrReadResult.ok('https://ejemplo.com/pagar')));

    await tocar(tester, 'Cargar mi QR desde una imagen');

    expect(find.text('QR cargado ✅'), findsOneWidget);
    expect(find.textContaining('no parece un QR de cobro estándar'), findsOneWidget);
  });

  testWidgets('un QR ya guardado se muestra y se puede quitar', (tester) async {
    repo = FakeShopRepository(negocio.copyWith(paymentQr: qrEstandar));
    await abrir(tester, FakeQrReader(const QrReadResult.cancelled()));

    expect(find.text('QR cargado ✅'), findsOneWidget);

    await tocar(tester, 'Quitar');
    expect(find.text('QR cargado ✅'), findsNothing);
    expect(find.text('Cargar mi QR desde una imagen'), findsOneWidget);

    await tocar(tester, 'Guardar datos');
    expect(repo.saved.single.paymentQr, '');
  });

  testWidgets('guardar sin tocar el QR lo conserva', (tester) async {
    repo = FakeShopRepository(negocio.copyWith(paymentQr: qrEstandar));
    await abrir(tester, FakeQrReader(const QrReadResult.cancelled()));

    await tocar(tester, 'Guardar datos');

    expect(repo.saved.single.paymentQr, qrEstandar);
  });
}
