// Prueba de integración contra un PostgREST real (el mismo componente que usa
// Supabase) sobre una base PostgreSQL con supabase/migrations/001_*.sql aplicada.
//
// Se omite sola si no hay servidor. Para correrla ver supabase/local_test/README.md:
//   COBRA_PGRST_URL=http://127.0.0.1:3000 \
//   COBRA_JWT_SECRET=... COBRA_USER_A=<uuid> COBRA_USER_B=<uuid> \
//   flutter test test/integration
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:cobra/features/billing/domain/entities/payment_method.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/entities/sale_item.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/sync/data/supabase_remote_sync_source.dart';
import 'package:cobra/features/sync/domain/sync_models.dart';
import 'package:cobra/features/sync/domain/sync_service.dart';
import '../sync/fakes.dart';

final _env = Platform.environment;
final _url = _env['COBRA_PGRST_URL'];
final _secret = _env['COBRA_JWT_SECRET'] ?? '';
final _userA = _env['COBRA_USER_A'] ?? '';
final _userB = _env['COBRA_USER_B'] ?? '';

SupabaseRemoteSyncSource _remoteFor(String uid, {int pageSize = 1000}) {
  final token =
      JWT({'sub': uid, 'role': 'authenticated'}).sign(SecretKey(_secret));
  final client = SupabaseClient(_url!, 'anon-key-no-usada',
      accessToken: () async => token);
  return SupabaseRemoteSyncSource(client,
      currentUserId: () => uid, pageSize: pageSize);
}

void main() {
  final skip = _url == null ? 'requiere PostgREST local (COBRA_PGRST_URL)' : null;

  // flutter_test bloquea el HTTP real (responde 400); acá hace falta de verdad.
  setUpAll(() => HttpOverrides.global = null);

  const yerba =
      Product(id: 'p1', name: 'Yerba', barcode: '111', price: 2500.5, stock: 7);
  const galletitas =
      Product(id: 'p2', name: 'Galletitas', barcode: '222', price: 800);
  final venta = Sale(
    id: 's1',
    date: DateTime.utc(2026, 10, 2, 18, 30),
    total: 5800,
    items: const [
      SaleItem(
          productId: 'p1',
          name: 'Yerba',
          barcode: '111',
          unitPrice: 2500,
          quantity: 2),
      SaleItem(
          productId: 'p2',
          name: 'Galletitas',
          barcode: '222',
          unitPrice: 800,
          quantity: 1),
    ],
  );

  test('negocio: se guarda y se lee', () async {
    final remote = _remoteFor(_userA);
    const shop = Shop(
      name: 'Almacén Don Pepe',
      addressLine1: 'Av. Siempre Viva 742',
      addressLine2: 'Córdoba',
      phoneNumber: '+54 9 351 123',
      paymentAlias: 'pepe.mp',
      paymentQr:
          '00020101021143650016com.mercadolibre0201...5204000053030325802AR63041D3C',
      footerText: '¡Gracias!',
    );
    await remote.upsertShop(shop);
    expect(await remote.fetchShop(), shop);
  }, skip: skip);

  test('productos: alta, edición, borrado lógico y revivir', () async {
    final remote = _remoteFor(_userA);
    await remote.upsertProduct(yerba);
    await remote.upsertProduct(galletitas);
    await remote.upsertProduct(yerba.copyWith(price: 3000)); // edición

    var all = {for (final r in await remote.fetchProducts()) r.product.id: r};
    expect(all['p1']!.product.price, 3000);
    expect(all['p1']!.product.stock, 7);
    expect(all['p2']!.deleted, isFalse);

    await remote.deleteProduct('p2');
    all = {for (final r in await remote.fetchProducts()) r.product.id: r};
    expect(all['p2']!.deleted, isTrue, reason: 'borrado lógico');

    await remote.upsertProduct(galletitas); // vuelve a crearse
    all = {for (final r in await remote.fetchProducts()) r.product.id: r};
    expect(all['p2']!.deleted, isFalse);
  }, skip: skip);

  test('código de barras duplicado: el servidor lo rechaza', () async {
    final remote = _remoteFor(_userA);
    await remote.upsertProduct(yerba);
    expect(
      () => remote.upsertProduct(
          const Product(id: 'otro', name: 'Otra', barcode: '111', price: 1)),
      throwsA(isA<SyncRejectedException>()
          .having((e) => e.message, 'mensaje', contains('código de barras'))),
    );
  }, skip: skip);

  test('ventas: se suben con su detalle y la anulación conserva los renglones',
      () async {
    final remote = _remoteFor(_userA);
    await remote.upsertSale(venta);
    await remote.upsertSale(Sale(
        id: venta.id,
        date: venta.date,
        total: venta.total,
        voided: true,
        items: venta.items));

    final back = (await remote.fetchSales()).singleWhere((s) => s.id == 's1');
    expect(back.voided, isTrue);
    expect(back.total, 5800);
    expect(back.date.toUtc(), venta.date);
    expect(back.items, venta.items);
  }, skip: skip);

  test('ventas: el medio de pago viaja a la nube y vuelve', () async {
    final remote = _remoteFor(_userA);
    for (final method in PaymentMethod.values) {
      await remote.upsertSale(Sale(
        id: 'pago-${method.code}',
        date: DateTime.utc(2026, 10, 3, 15),
        total: 100,
        paymentMethod: method,
      ));
    }
    final back = {for (final s in await remote.fetchSales()) s.id: s};
    for (final method in PaymentMethod.values) {
      expect(back['pago-${method.code}']!.paymentMethod, method);
    }
  }, skip: skip);

  test('paginación: trae todo aunque supere el tamaño de página', () async {
    final remote = _remoteFor(_userA, pageSize: 2);
    for (var i = 0; i < 5; i++) {
      await remote.upsertProduct(
          Product(id: 'm$i', name: 'M$i', barcode: 'bar$i', price: 1));
    }
    final ids = (await remote.fetchProducts()).map((r) => r.product.id);
    expect(ids, containsAll(['m0', 'm1', 'm2', 'm3', 'm4']));
  }, skip: skip);

  test('aislamiento: otro comercio no ve ni toca estos datos', () async {
    final ana = _remoteFor(_userA);
    final beto = _remoteFor(_userB);
    await ana.upsertProduct(yerba);
    await ana.upsertSale(venta);

    expect(await beto.fetchProducts(), isEmpty);
    expect(await beto.fetchSales(), isEmpty);

    // Aunque Beto intente borrar "p1", no afecta a Ana.
    await beto.deleteProduct('p1');
    final enAna = (await ana.fetchProducts()).singleWhere((r) => r.product.id == 'p1');
    expect(enAna.deleted, isFalse);
  }, skip: skip);

  test('sin servidor: es un error pasajero (se reintenta), no un rechazo',
      () async {
    final token =
        JWT({'sub': _userA, 'role': 'authenticated'}).sign(SecretKey(_secret));
    final caido = SupabaseRemoteSyncSource(
      SupabaseClient('http://127.0.0.1:1', 'x', accessToken: () async => token),
      currentUserId: () => _userA,
      timeout: const Duration(seconds: 3),
    );
    expect(() => caido.upsertProduct(yerba),
        throwsA(isA<SyncRetryableException>()));
  }, skip: skip);

  test('de punta a punta: lo del teléfono sube y se restaura en otro teléfono',
      () async {
    final remote = _remoteFor(_userA);

    // Teléfono 1: venía usando la app sin cuenta y ahora crea la cuenta.
    final local1 = FakeLocalStore()
      ..shop = const Shop(name: 'Kiosco Lucía', paymentAlias: 'lucia.mp')
      ..products['p1'] = yerba
      ..products['p2'] = galletitas
      ..sales['s1'] = venta;
    final servicio1 = SyncService(
      outbox: InMemoryOutbox(),
      local: local1,
      remote: remote,
      settings: FakeSyncSettings(null),
      autoSync: false,
    );
    await servicio1.onSignedIn(_userA);

    // Teléfono 2: vacío, ingresa con la misma cuenta.
    final local2 = FakeLocalStore();
    final servicio2 = SyncService(
      outbox: InMemoryOutbox(),
      local: local2,
      remote: remote,
      settings: FakeSyncSettings(null),
      autoSync: false,
    );
    await servicio2.onSignedIn(_userA);

    expect(local2.shop!.name, 'Kiosco Lucía');
    expect(local2.shop!.paymentAlias, 'lucia.mp');
    expect(local2.products['p1'], yerba);
    expect(local2.products['p2'], galletitas);
    expect(local2.sales['s1']!.items, venta.items);

    // Cambios en el teléfono 1 llegan al 2 en la siguiente sincronización.
    local1.products['p1'] = yerba.copyWith(price: 4000);
    await servicio1.record(SyncKind.product, 'p1', SyncAction.upsert);
    await servicio1.sync();
    await servicio2.sync();
    expect(local2.products['p1']!.price, 4000);

    await servicio1.dispose();
    await servicio2.dispose();
  }, skip: skip);
}
