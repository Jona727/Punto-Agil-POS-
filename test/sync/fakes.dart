import 'package:cobra/features/billing/domain/entities/sale.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/sync/domain/sync_models.dart';

class InMemoryOutbox implements SyncOutbox {
  final Map<String, SyncOp> _ops = {};
  int _clock = 0;

  String _key(SyncKind k, String id) => '${k.name}:$id';

  @override
  Future<void> enqueue(SyncKind kind, String id, SyncAction action) async {
    _ops[_key(kind, id)] = SyncOp(
        kind: kind, id: id, action: action, queuedAtMs: ++_clock, attempts: 0);
  }

  @override
  List<SyncOp> pending() =>
      _ops.values.toList()..sort((a, b) => a.queuedAtMs.compareTo(b.queuedAtMs));

  @override
  Future<void> markFailed(SyncOp op) async {
    final cur = _ops[_key(op.kind, op.id)];
    if (cur == null || cur.queuedAtMs != op.queuedAtMs) return;
    _ops[_key(op.kind, op.id)] = SyncOp(
        kind: cur.kind,
        id: cur.id,
        action: cur.action,
        queuedAtMs: cur.queuedAtMs,
        attempts: cur.attempts + 1);
  }

  @override
  Future<void> remove(SyncOp op) async {
    final cur = _ops[_key(op.kind, op.id)];
    if (cur != null && cur.queuedAtMs == op.queuedAtMs) {
      _ops.remove(_key(op.kind, op.id));
    }
  }

  @override
  Future<void> clear() async => _ops.clear();
}

class FakeSyncSettings implements SyncSettings {
  FakeSyncSettings([this._userId]);
  String? _userId;
  @override
  String? get userId => _userId;
  @override
  Future<void> setUserId(String? id) async => _userId = id;
}

class FakeLocalStore implements LocalSyncStore {
  Shop? shop;
  final Map<String, Product> products = {};
  final Map<String, Sale> sales = {};

  @override
  Shop? getShop() => shop;
  @override
  Product? getProduct(String id) => products[id];
  @override
  Sale? getSale(String id) => sales[id];
  @override
  List<Product> allProducts() => products.values.toList();
  @override
  List<Sale> allSales() => sales.values.toList();
  @override
  bool get hasNoSales => sales.isEmpty;

  @override
  Future<void> saveShop(Shop s) async => shop = s;
  @override
  Future<void> saveProducts(List<Product> list) async {
    for (final p in list) {
      products[p.id] = p;
    }
  }

  @override
  Future<void> deleteProducts(List<String> ids) async {
    ids.forEach(products.remove);
  }

  @override
  Future<void> saveSales(List<Sale> list) async {
    for (final s in list) {
      sales[s.id] = s;
    }
  }

  @override
  Future<void> clearAll() async {
    shop = null;
    products.clear();
    sales.clear();
  }
}

/// Nube simulada. Se puede dejar "sin conexión" o hacer que rechace datos.
class FakeRemote implements RemoteSyncSource {
  bool offline = false;
  Shop? shop = const Shop(name: 'Mi Negocio');
  final Map<String, Product> products = {};
  final Set<String> deleted = {};
  final Map<String, Sale> sales = {};

  /// Cantidad de llamadas de escritura (para comprobar que no se repiten).
  final List<String> calls = [];

  void _check() {
    if (offline) throw const SyncRetryableException('sin internet');
  }

  @override
  Future<void> upsertShop(Shop s) async {
    _check();
    calls.add('shop');
    shop = s;
  }

  @override
  Future<void> upsertProduct(Product p) async {
    _check();
    calls.add('upsert:${p.id}');
    // Igual que el índice único del servidor.
    final clash = products.values.any(
        (o) => o.id != p.id && o.barcode == p.barcode && !deleted.contains(o.id));
    if (clash) {
      throw const SyncRejectedException('Código de barras duplicado');
    }
    products[p.id] = p;
    deleted.remove(p.id);
  }

  @override
  Future<void> deleteProduct(String id) async {
    _check();
    calls.add('delete:$id');
    if (products.containsKey(id)) deleted.add(id);
  }

  @override
  Future<void> upsertSale(Sale s) async {
    _check();
    calls.add('sale:${s.id}');
    sales[s.id] = s;
  }

  @override
  Future<Shop?> fetchShop() async {
    _check();
    return shop;
  }

  @override
  Future<List<RemoteProduct>> fetchProducts() async {
    _check();
    return [
      for (final p in products.values)
        RemoteProduct(p, deleted: deleted.contains(p.id)),
    ];
  }

  @override
  Future<List<Sale>> fetchSales() async {
    _check();
    return sales.values.toList();
  }
}
