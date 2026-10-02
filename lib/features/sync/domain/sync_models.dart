import 'package:equatable/equatable.dart';

import '../../product/domain/entities/product.dart';
import '../../billing/domain/entities/sale.dart';
import '../../shop/domain/entities/shop.dart';

enum SyncKind { shop, product, sale }

enum SyncAction { upsert, delete }

/// Un cambio local pendiente de subir a la nube.
///
/// No guarda los datos, solo *qué* cambió: al subirlo se lee el estado más
/// reciente local. Así, si algo se edita 5 veces offline, se sube una sola vez.
class SyncOp extends Equatable {
  final SyncKind kind;
  final String id;
  final SyncAction action;
  final int attempts;

  /// Marca de tiempo (ms) de cuando se anotó; permite saber si el cambio se
  /// volvió a editar mientras se estaba subiendo.
  final int queuedAtMs;

  const SyncOp({
    required this.kind,
    required this.id,
    required this.action,
    required this.queuedAtMs,
    this.attempts = 0,
  });

  @override
  List<Object> get props => [kind, id, action, attempts, queuedAtMs];
}

/// Falló por algo pasajero (sin internet, servidor caído, sesión por renovar).
/// El cambio se conserva y se reintenta más tarde.
class SyncRetryableException implements Exception {
  final String message;
  const SyncRetryableException(this.message);
  @override
  String toString() => 'SyncRetryableException: $message';
}

/// El servidor rechazó el dato (por ejemplo, código de barras duplicado).
/// Reintentar igual no sirve, así que no bloquea al resto de los cambios.
class SyncRejectedException implements Exception {
  final String message;
  const SyncRejectedException(this.message);
  @override
  String toString() => 'SyncRejectedException: $message';
}

class RemoteProduct extends Equatable {
  final Product product;
  final bool deleted;
  const RemoteProduct(this.product, {this.deleted = false});

  @override
  List<Object> get props => [product, deleted];
}

class SyncState extends Equatable {
  final bool syncing;
  final bool offline;

  /// Cambios que todavía se van a intentar subir.
  final int pending;

  /// Cambios que el servidor rechazó repetidamente (requieren atención).
  final int failed;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncState({
    this.syncing = false,
    this.offline = false,
    this.pending = 0,
    this.failed = 0,
    this.lastSyncAt,
    this.lastError,
  });

  SyncState copyWith({
    bool? syncing,
    bool? offline,
    int? pending,
    int? failed,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncState(
      syncing: syncing ?? this.syncing,
      offline: offline ?? this.offline,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props =>
      [syncing, offline, pending, failed, lastSyncAt, lastError];
}

/// Lo que usan los repositorios locales para avisar "esto cambió".
abstract class SyncRecorder {
  Future<void> record(SyncKind kind, String id, SyncAction action);
}

/// Cuando la app no tiene Supabase configurado no hay nada que sincronizar.
class NoopSyncRecorder implements SyncRecorder {
  const NoopSyncRecorder();
  @override
  Future<void> record(SyncKind kind, String id, SyncAction action) async {}
}

abstract class SyncOutbox {
  Future<void> enqueue(SyncKind kind, String id, SyncAction action);
  List<SyncOp> pending();
  Future<void> markFailed(SyncOp op);

  /// Quita el cambio solo si no se volvió a anotar mientras se subía.
  Future<void> remove(SyncOp op);
  Future<void> clear();
}

abstract class SyncSettings {
  /// Cuenta a la que pertenecen los datos locales (null = nadie todavía).
  String? get userId;
  Future<void> setUserId(String? id);
}

/// Acceso a los datos locales desde el servicio de sincronización.
abstract class LocalSyncStore {
  Shop? getShop();
  Product? getProduct(String id);
  Sale? getSale(String id);
  List<Product> allProducts();
  List<Sale> allSales();
  bool get hasNoSales;

  Future<void> saveShop(Shop shop);
  Future<void> saveProducts(List<Product> products);
  Future<void> deleteProducts(List<String> ids);
  Future<void> saveSales(List<Sale> sales);
  Future<void> clearAll();
}

/// La nube. La implementación real es Supabase; en los tests, un doble.
abstract class RemoteSyncSource {
  Future<void> upsertShop(Shop shop);
  Future<void> upsertProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> upsertSale(Sale sale);

  Future<Shop?> fetchShop();
  Future<List<RemoteProduct>> fetchProducts();
  Future<List<Sale>> fetchSales();
}
