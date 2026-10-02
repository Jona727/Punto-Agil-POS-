import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cobra/core/data/hive_database.dart';
import 'package:cobra/features/billing/data/models/sale_item_model.dart';
import 'package:cobra/features/billing/data/models/sale_model.dart';
import 'package:cobra/features/billing/data/repositories/sale_repository_impl.dart';
import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/product/data/models/product_model.dart';
import 'package:cobra/features/product/data/repositories/product_repository_impl.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/shop/data/models/shop_model.dart';
import 'package:cobra/features/shop/data/repositories/shop_repository_impl.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/sync/data/hive_sync_storage.dart';
import 'package:cobra/features/sync/domain/sync_models.dart';

class RecordingSync implements SyncRecorder {
  final List<String> log = [];
  @override
  Future<void> record(SyncKind kind, String id, SyncAction action) async =>
      log.add('${kind.name}:$id:${action.name}');
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cobra_sync_test');
    Hive.init(dir.path);
    // Los adaptadores sobreviven entre pruebas: se registran una sola vez.
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShopModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SaleItemModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SaleModelAdapter());
    await Hive.openBox<ProductModel>(HiveDatabase.productBoxName);
    await Hive.openBox<ShopModel>(HiveDatabase.shopBoxName);
    await Hive.openBox<SaleModel>(HiveDatabase.salesBoxName);
    await Hive.openBox(HiveDatabase.settingsBoxName);
    await Hive.openBox(HiveDatabase.syncOutboxBoxName);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  group('cola de pendientes (Hive)', () {
    test('un mismo elemento editado varias veces ocupa un solo lugar', () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await outbox.enqueue(SyncKind.product, 'p2', SyncAction.upsert);

      expect(outbox.pending().length, 2);
    });

    test('borrar después de editar deja solo el borrado', () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.delete);

      expect(outbox.pending().single.action, SyncAction.delete);
    });

    test('se conserva el orden de llegada y sobrevive a reabrir la app',
        () async {
      var outbox = HiveSyncOutbox();
      await outbox.enqueue(SyncKind.sale, 's1', SyncAction.upsert);
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await Hive.box(HiveDatabase.syncOutboxBoxName).close();
      await Hive.openBox(HiveDatabase.syncOutboxBoxName);

      outbox = HiveSyncOutbox();
      expect(outbox.pending().map((o) => o.id), ['s1', 'p1']);
    });

    test('quitar un cambio ya subido lo elimina', () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await outbox.remove(outbox.pending().single);

      expect(outbox.pending(), isEmpty);
    });

    test('si se re-edita mientras se sube, el cambio NO se pierde', () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      final subiendo = outbox.pending().single;

      // Mientras se sube, el comerciante vuelve a editar el producto.
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await outbox.remove(subiendo);

      expect(outbox.pending().length, 1, reason: 'falta subir la edición nueva');
    });

    test('markFailed suma intentos y un cambio nuevo los reinicia', () async {
      final outbox = HiveSyncOutbox();
      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      await outbox.markFailed(outbox.pending().single);
      await outbox.markFailed(outbox.pending().single);
      expect(outbox.pending().single.attempts, 2);

      await outbox.enqueue(SyncKind.product, 'p1', SyncAction.upsert);
      expect(outbox.pending().single.attempts, 0);
    });
  });

  group('cuenta vinculada', () {
    test('guarda y borra el id de usuario', () async {
      final settings = HiveSyncSettings();
      expect(settings.userId, isNull);
      await settings.setUserId('ana');
      expect(settings.userId, 'ana');
      await settings.setUserId(null);
      expect(settings.userId, isNull);
    });
  });

  group('datos locales', () {
    test('guardar, leer y borrar todo', () async {
      final store = HiveLocalSyncStore();
      const p = Product(id: 'p1', name: 'Yerba', barcode: '1', price: 10);
      await store.saveProducts([p]);
      await store.saveShop(const Shop(name: 'Kiosco', paymentAlias: 'k.mp'));

      expect(store.getProduct('p1'), p);
      expect(store.getShop(), const Shop(name: 'Kiosco', paymentAlias: 'k.mp'));
      expect(store.hasNoSales, isTrue);

      await store.deleteProducts(['p1']);
      expect(store.allProducts(), isEmpty);

      await store.saveProducts([p]);
      await store.clearAll();
      expect(store.allProducts(), isEmpty);
      expect(store.getShop(), isNull);
    });
  });

  group('los repositorios anotan cada cambio', () {
    const p = Product(id: 'p1', name: 'Yerba', barcode: '1', price: 100);

    test('productos: alta, edición, aumento masivo y baja', () async {
      final sync = RecordingSync();
      final repo = ProductRepositoryImpl(sync: sync);

      await repo.addProduct(p);
      await repo.updateProduct(p.copyWith(price: 120));
      await repo.updatePricesMassively(10);
      await repo.deleteProduct('p1');

      expect(sync.log, [
        'product:p1:upsert',
        'product:p1:upsert',
        'product:p1:upsert',
        'product:p1:delete',
      ]);
    });

    test('el aumento masivo anota todos los productos', () async {
      final sync = RecordingSync();
      final repo = ProductRepositoryImpl(sync: sync);
      await repo.addProduct(p);
      await repo.addProduct(p.copyWith(id: 'p2', barcode: '2'));
      sync.log.clear();

      await repo.updatePricesMassively(5);

      expect(sync.log.toSet(), {'product:p1:upsert', 'product:p2:upsert'});
    });

    test('negocio y ventas (incluida la anulación)', () async {
      final sync = RecordingSync();
      await ShopRepositoryImpl(sync: sync).updateShop(const Shop(name: 'K'));
      final sales = SaleRepositoryImpl(sync: sync);
      final sale = Sale(id: 's1', date: DateTime.now(), total: 10);
      await sales.saveSale(sale);
      await sales.voidSale('s1');

      expect(sync.log,
          ['shop:shop:upsert', 'sale:s1:upsert', 'sale:s1:upsert']);
    });

    test('sin cuenta (Noop) todo funciona igual y no anota nada', () async {
      final repo = ProductRepositoryImpl();
      expect((await repo.addProduct(p)).isRight(), isTrue);
      expect((await repo.getProducts()).getOrElse((_) => []).length, 1);
    });

    test('una operación que falla no anota nada', () async {
      final sync = RecordingSync();
      final sales = SaleRepositoryImpl(sync: sync);
      final result = await sales.voidSale('no-existe');

      expect(result.isLeft(), isTrue);
      expect(sync.log, isEmpty);
    });
  });
}
