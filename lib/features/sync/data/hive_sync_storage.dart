import 'package:hive/hive.dart';

import '../../../core/data/hive_database.dart';
import '../../billing/data/models/sale_model.dart';
import '../../billing/domain/entities/sale.dart';
import '../../product/data/models/product_model.dart';
import '../../product/domain/entities/product.dart';
import '../../shop/data/models/shop_model.dart';
import '../../shop/data/repositories/shop_repository_impl.dart';
import '../../shop/domain/entities/shop.dart';
import '../domain/sync_models.dart';

/// Cola de cambios pendientes, guardada en el teléfono.
/// Hay como máximo un registro por (tipo, id): si un producto se edita varias
/// veces antes de subirse, se sube una sola vez con su último estado.
class HiveSyncOutbox implements SyncOutbox {
  Box get _box => Hive.box(HiveDatabase.syncOutboxBoxName);

  String _key(SyncKind kind, String id) => '${kind.name}:$id';

  SyncOp _toOp(Map m) => SyncOp(
        kind: SyncKind.values.byName(m['k'] as String),
        id: m['i'] as String,
        action: SyncAction.values.byName(m['a'] as String),
        attempts: m['n'] as int,
        queuedAtMs: m['t'] as int,
      );

  @override
  Future<void> enqueue(SyncKind kind, String id, SyncAction action) {
    // Un cambio nuevo reinicia los intentos: puede que ahora sí funcione.
    return _box.put(_key(kind, id), {
      'k': kind.name,
      'i': id,
      'a': action.name,
      'n': 0,
      't': DateTime.now().microsecondsSinceEpoch,
    });
  }

  @override
  List<SyncOp> pending() {
    final ops = _box.values.map((v) => _toOp(Map.from(v as Map))).toList()
      ..sort((a, b) => a.queuedAtMs.compareTo(b.queuedAtMs));
    return ops;
  }

  @override
  Future<void> markFailed(SyncOp op) async {
    final key = _key(op.kind, op.id);
    final current = _box.get(key);
    if (current == null || (current as Map)['t'] != op.queuedAtMs) return;
    await _box.put(key, {...Map.from(current), 'n': op.attempts + 1});
  }

  @override
  Future<void> remove(SyncOp op) async {
    final key = _key(op.kind, op.id);
    final current = _box.get(key);
    // Si se volvió a editar mientras se subía, se conserva para otra vuelta.
    if (current != null && (current as Map)['t'] == op.queuedAtMs) {
      await _box.delete(key);
    }
  }

  @override
  Future<void> clear() => _box.clear();
}

class HiveSyncSettings implements SyncSettings {
  static const _key = 'sync_user_id';

  @override
  String? get userId => HiveDatabase.settingsBox.get(_key) as String?;

  @override
  Future<void> setUserId(String? id) => id == null
      ? HiveDatabase.settingsBox.delete(_key)
      : HiveDatabase.settingsBox.put(_key, id);
}

class HiveLocalSyncStore implements LocalSyncStore {
  @override
  Shop? getShop() {
    final model = HiveDatabase.shopBox.get(ShopRepositoryImpl.shopKey);
    if (model == null) return null;
    return Shop(
      name: model.name,
      addressLine1: model.addressLine1,
      addressLine2: model.addressLine2,
      phoneNumber: model.phoneNumber,
      paymentAlias: model.paymentAlias,
      paymentQr: model.paymentQr,
      footerText: model.footerText,
    );
  }

  @override
  Product? getProduct(String id) => HiveDatabase.productBox.get(id)?.toEntity();

  @override
  Sale? getSale(String id) => HiveDatabase.salesBox.get(id)?.toEntity();

  @override
  List<Product> allProducts() =>
      HiveDatabase.productBox.values.map((m) => m.toEntity()).toList();

  @override
  List<Sale> allSales() =>
      HiveDatabase.salesBox.values.map((m) => m.toEntity()).toList();

  @override
  bool get hasNoSales => HiveDatabase.salesBox.isEmpty;

  @override
  Future<void> saveShop(Shop shop) => HiveDatabase.shopBox
      .put(ShopRepositoryImpl.shopKey, ShopModel.fromEntity(shop));

  @override
  Future<void> saveProducts(List<Product> products) =>
      HiveDatabase.productBox.putAll({
        for (final p in products) p.id: ProductModel.fromEntity(p),
      });

  @override
  Future<void> deleteProducts(List<String> ids) =>
      HiveDatabase.productBox.deleteAll(ids);

  @override
  Future<void> saveSales(List<Sale> sales) => HiveDatabase.salesBox.putAll({
        for (final s in sales) s.id: SaleModel.fromEntity(s),
      });

  @override
  Future<void> clearAll() async {
    await HiveDatabase.productBox.clear();
    await HiveDatabase.shopBox.clear();
    await HiveDatabase.salesBox.clear();
  }
}
