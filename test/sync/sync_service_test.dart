import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/billing/domain/entities/sale_item.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/sync/domain/sync_models.dart';
import 'package:cobra/features/sync/domain/sync_service.dart';
import 'fakes.dart';

const yerba =
    Product(id: 'p1', name: 'Yerba', barcode: '111', price: 2500, stock: 10);
const galletitas =
    Product(id: 'p2', name: 'Galletitas', barcode: '222', price: 800, stock: 5);

Sale venta(String id, {bool voided = false}) => Sale(
      id: id,
      date: DateTime(2026, 10, 2, 15),
      total: 5000,
      voided: voided,
      items: const [
        SaleItem(
            productId: 'p1',
            name: 'Yerba',
            barcode: '111',
            unitPrice: 2500,
            quantity: 2),
      ],
    );

void main() {
  late InMemoryOutbox outbox;
  late FakeLocalStore local;
  late FakeRemote remote;
  late FakeSyncSettings settings;
  late SyncService service;

  setUp(() {
    outbox = InMemoryOutbox();
    local = FakeLocalStore();
    remote = FakeRemote();
    settings = FakeSyncSettings('ana');
    service = SyncService(
      outbox: outbox,
      local: local,
      remote: remote,
      settings: settings,
      autoSync: false,
    );
  });

  tearDown(() => service.dispose());

  Future<void> signIn([String user = 'ana']) => service.onSignedIn(user);

  group('subir cambios', () {
    test('un producto nuevo se sube y sale de la cola', () async {
      await signIn();
      local.products['p1'] = yerba;
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.sync();

      expect(remote.products['p1'], yerba);
      expect(outbox.pending(), isEmpty);
      expect(service.state.value.pending, 0);
    });

    test('varias ediciones seguidas suben una sola vez, con el último valor',
        () async {
      await signIn();
      for (final price in [100.0, 200.0, 300.0]) {
        local.products['p1'] = yerba.copyWith(price: price);
        await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      }
      await service.sync();

      expect(remote.calls.where((c) => c == 'upsert:p1').length, 1);
      expect(remote.products['p1']!.price, 300);
    });

    test('borrar un producto lo marca borrado en la nube', () async {
      await signIn();
      remote.products['p1'] = yerba;
      await service.record(SyncKind.product, 'p1', SyncAction.delete);
      await service.sync();

      expect(remote.calls, contains('delete:p1'));
      expect(remote.deleted, contains('p1'));
    });

    test('una venta se sube con su detalle; anularla sube la versión nueva',
        () async {
      await signIn();
      local.sales['s1'] = venta('s1');
      await service.record(SyncKind.sale, 's1', SyncAction.upsert);
      await service.sync();
      expect(remote.sales['s1']!.items.single.quantity, 2);
      expect(remote.sales['s1']!.voided, isFalse);

      local.sales['s1'] = venta('s1', voided: true);
      await service.record(SyncKind.sale, 's1', SyncAction.upsert);
      await service.sync();
      expect(remote.sales['s1']!.voided, isTrue);
      expect(remote.sales['s1']!.items, isNotEmpty);
    });

    test('los datos del negocio se suben', () async {
      await signIn();
      local.shop = const Shop(name: 'Almacén Don Pepe', paymentAlias: 'pepe.mp');
      await service.record(SyncKind.shop, 'shop', SyncAction.upsert);
      await service.sync();

      expect(remote.shop!.name, 'Almacén Don Pepe');
      expect(remote.shop!.paymentAlias, 'pepe.mp');
    });
  });

  group('sin conexión', () {
    test('no se pierde nada y se reintenta cuando vuelve internet', () async {
      await signIn();
      remote.offline = true;
      local.products['p1'] = yerba;
      local.sales['s1'] = venta('s1');
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.record(SyncKind.sale, 's1', SyncAction.upsert);
      await service.sync();

      expect(service.state.value.offline, isTrue);
      expect(service.state.value.pending, 2);
      expect(service.state.value.lastError, 'sin internet',
          reason: 'el motivo real debe verse para poder diagnosticar');
      expect(remote.products, isEmpty);

      remote.offline = false;
      await service.sync();

      expect(service.state.value.offline, isFalse);
      expect(service.state.value.lastError, isNull, reason: 'se limpia al funcionar');
      expect(service.state.value.pending, 0);
      expect(remote.products['p1'], yerba);
      expect(remote.sales['s1'], isNotNull);
    });

    test('registrar cambios no requiere internet ni sesión', () async {
      // Sin onSignedIn: modo sin cuenta / antes de ingresar.
      local.products['p1'] = yerba;
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.sync(); // no hace nada sin sesión

      expect(outbox.pending().length, 1);
      expect(remote.calls, isEmpty);
    });
  });

  group('datos rechazados por el servidor', () {
    test('un rechazo no bloquea al resto y cuenta como fallido tras varios intentos',
        () async {
      await signIn();
      remote.products['otro'] =
          const Product(id: 'otro', name: 'Otro', barcode: '111', price: 1);
      local.products['p1'] = yerba; // mismo código de barras que 'otro'
      local.products['p2'] = galletitas;
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.record(SyncKind.product, 'p2', SyncAction.upsert);

      for (var i = 0; i < SyncService.maxAttempts; i++) {
        await service.sync();
      }

      expect(remote.products['p2'], galletitas); // el otro sí se subió
      expect(remote.products['p1'], isNull);
      expect(service.state.value.failed, 1);
      expect(service.state.value.pending, 0);
      expect(service.state.value.lastError, contains('duplicado'));
    });

    test('corregir el producto reinicia los intentos', () async {
      await signIn();
      remote.products['otro'] =
          const Product(id: 'otro', name: 'Otro', barcode: '111', price: 1);
      local.products['p1'] = yerba;
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.sync();

      local.products['p1'] = yerba.copyWith(barcode: '999');
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.sync();

      expect(remote.products['p1']!.barcode, '999');
      expect(outbox.pending(), isEmpty);
    });
  });

  group('bajar datos de la nube', () {
    test('trae productos y datos del negocio y avisa para recargar', () async {
      remote.products['p1'] = yerba;
      remote.shop = const Shop(name: 'Mi Kiosco', phoneNumber: '123');
      var avisos = 0;
      service.dataChanges.listen((_) => avisos++);

      await signIn();
      await Future<void>.delayed(Duration.zero);

      expect(local.products['p1'], yerba);
      expect(local.shop!.name, 'Mi Kiosco');
      expect(avisos, greaterThan(0));
    });

    test('un producto borrado en la nube se borra del teléfono', () async {
      local.products['p1'] = yerba;
      remote.products['p1'] = yerba;
      remote.deleted.add('p1');

      await signIn();

      expect(local.products, isEmpty);
    });

    test('no baja nada mientras haya cambios locales sin subir', () async {
      await signIn();
      remote.offline = true;
      local.products['p1'] = yerba.copyWith(price: 999);
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      remote.offline = false;
      remote.products['p1'] = yerba; // versión vieja en la nube
      remote.deleted.clear();
      remote.calls.clear();

      // El push sube 999 y recién después baja: queda 999, no se pisa.
      await service.sync();
      expect(local.products['p1']!.price, 999);
      expect(remote.products['p1']!.price, 999);
    });

    test('sin sesión no sincroniza nada', () async {
      remote.products['p1'] = yerba;
      await service.sync();
      expect(local.products, isEmpty);
    });

    test('en un teléfono vacío se restauran las ventas', () async {
      remote.sales['s1'] = venta('s1');
      await signIn();
      expect(local.sales['s1']!.items.single.name, 'Yerba');
    });

    test('con ventas locales no se vuelven a bajar', () async {
      local.sales['local'] = venta('local');
      remote.sales['s1'] = venta('s1');
      settings = FakeSyncSettings('ana');
      await signIn();
      expect(local.sales.keys, ['local']);
    });
  });

  group('cuentas', () {
    test('la primera vez, lo que había sin cuenta se sube', () async {
      settings = FakeSyncSettings(null);
      service = SyncService(
          outbox: outbox,
          local: local,
          remote: remote,
          settings: settings,
          autoSync: false);
      local.shop = const Shop(name: 'Mi Kiosco');
      local.products['p1'] = yerba;
      local.products['p2'] = galletitas;
      local.sales['s1'] = venta('s1');

      await service.onSignedIn('ana');

      expect(remote.products.keys, containsAll(['p1', 'p2']));
      expect(remote.sales.keys, ['s1']);
      expect(remote.shop!.name, 'Mi Kiosco');
      expect(settings.userId, 'ana');
    });

    test('volver a ingresar con la misma cuenta no borra nada', () async {
      local.products['p1'] = yerba;
      remote.products['p1'] = yerba;
      await signIn('ana');
      expect(local.products['p1'], yerba);
    });

    test('otra cuenta en el mismo teléfono no ve ni sube datos ajenos',
        () async {
      local.products['p1'] = yerba; // datos de "ana"
      local.sales['s1'] = venta('s1');
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);

      await signIn('beto');

      expect(local.products, isEmpty);
      expect(local.sales, isEmpty);
      expect(outbox.pending(), isEmpty);
      expect(remote.products, isEmpty, reason: 'no se suben los datos de ana');
      expect(settings.userId, 'beto');
    });

    test('cerrar sesión borra el teléfono y desvincula la cuenta', () async {
      await signIn();
      local.products['p1'] = yerba;
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);
      await service.flush();

      await service.clearLocalAndSignOut();

      expect(local.products, isEmpty);
      expect(outbox.pending(), isEmpty);
      expect(settings.userId, isNull);
      expect(service.isSignedIn, isFalse);
      expect(remote.products['p1'], yerba, reason: 'en la nube sigue');
    });

    test('flush informa cuántos cambios no se pudieron subir', () async {
      await signIn();
      remote.offline = true;
      local.products['p1'] = yerba;
      await service.record(SyncKind.product, 'p1', SyncAction.upsert);

      expect(await service.flush(), 1);

      remote.offline = false;
      expect(await service.flush(), 0);
    });
  });
}
