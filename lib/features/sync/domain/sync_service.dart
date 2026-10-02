import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../product/domain/entities/product.dart';
import 'sync_models.dart';

/// Mantiene sincronizados el teléfono y la nube.
///
/// - Los cambios locales se anotan en una cola (outbox) y se suben cuando hay
///   sesión y conexión. La venta nunca espera a internet.
/// - Después de subir todo lo pendiente, se baja lo de la nube (productos y
///   datos del negocio; las ventas solo al restaurar un teléfono vacío).
class SyncService implements SyncRecorder {
  SyncService({
    required this.outbox,
    required this.local,
    required this.remote,
    required this.settings,
    this.autoSync = true,
    this.debounce = const Duration(seconds: 1),
    this.interval = const Duration(minutes: 1),
  });

  static const int maxAttempts = 5;

  final SyncOutbox outbox;
  final LocalSyncStore local;
  final RemoteSyncSource remote;
  final SyncSettings settings;
  final bool autoSync;
  final Duration debounce;
  final Duration interval;

  final ValueNotifier<SyncState> state = ValueNotifier(const SyncState());
  final _changes = StreamController<void>.broadcast();

  /// Emite cuando la sincronización cambió datos locales (hay que recargar
  /// las pantallas).
  Stream<void> get dataChanges => _changes.stream;

  String? _userId;
  bool _running = false;
  bool _rerun = false;
  Timer? _debounceTimer;
  Timer? _periodic;

  bool get isSignedIn => _userId != null;

  // ───────────────────────── Registro de cambios ─────────────────────────

  @override
  Future<void> record(SyncKind kind, String id, SyncAction action) async {
    try {
      await outbox.enqueue(kind, id, action);
      _refreshCounts();
      if (autoSync && isSignedIn) _scheduleSync();
    } catch (e) {
      // Un fallo al anotar nunca debe romper el guardado local.
      debugPrint('SyncService.record falló: $e');
    }
  }

  void _scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(sync()));
  }

  // ───────────────────────── Sesión ─────────────────────────

  /// Llamar cuando hay una sesión iniciada (al abrir la app o al ingresar).
  Future<void> onSignedIn(String userId) async {
    final owner = settings.userId;
    if (owner != null && owner != userId) {
      // Los datos locales son de otra cuenta: no se mezclan.
      await local.clearAll();
      await outbox.clear();
      _changes.add(null);
    } else if (owner == null) {
      // Primera vez: lo que había en el teléfono (modo sin cuenta) se sube.
      await _enqueueEverything();
    }
    await settings.setUserId(userId);
    _userId = userId;

    _periodic?.cancel();
    if (autoSync) {
      _periodic = Timer.periodic(interval, (_) => unawaited(sync()));
    }
    await sync();
  }

  /// Intenta subir lo pendiente. Devuelve cuántos cambios quedaron sin subir.
  Future<int> flush() async {
    await sync();
    return outbox.pending().length;
  }

  /// Borra los datos locales y desvincula la cuenta (al cerrar sesión).
  Future<void> clearLocalAndSignOut() async {
    _debounceTimer?.cancel();
    _periodic?.cancel();
    _userId = null;
    await local.clearAll();
    await outbox.clear();
    await settings.setUserId(null);
    _refreshCounts();
    _changes.add(null);
  }

  /// Se llamó signOut sin borrar datos (la sesión sigue en el teléfono).
  void onSignedOut() {
    _debounceTimer?.cancel();
    _periodic?.cancel();
    _userId = null;
  }

  Future<void> _enqueueEverything() async {
    final shop = local.getShop();
    if (shop != null) {
      await outbox.enqueue(SyncKind.shop, 'shop', SyncAction.upsert);
    }
    for (final p in local.allProducts()) {
      await outbox.enqueue(SyncKind.product, p.id, SyncAction.upsert);
    }
    for (final s in local.allSales()) {
      await outbox.enqueue(SyncKind.sale, s.id, SyncAction.upsert);
    }
    _refreshCounts();
  }

  // ───────────────────────── Sincronizar ─────────────────────────

  Future<void> sync() async {
    if (_userId == null) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    state.value = state.value.copyWith(syncing: true);
    try {
      do {
        _rerun = false;
        await _syncOnce();
      } while (_rerun && _userId != null);
    } finally {
      _running = false;
      _refreshCounts();
      state.value = state.value.copyWith(syncing: false);
    }
  }

  Future<void> _syncOnce() async {
    var offline = false;
    String? error;

    for (final op in outbox.pending()) {
      if (op.attempts >= maxAttempts) continue;
      try {
        await _push(op);
        await outbox.remove(op);
      } on SyncRejectedException catch (e) {
        await outbox.markFailed(op);
        error = e.message;
      } catch (_) {
        // Sin conexión u otro fallo pasajero: se corta y se reintenta luego.
        offline = true;
        break;
      }
    }

    if (!offline && !_hasActivePending()) {
      try {
        if (await _pull()) _changes.add(null);
        state.value = state.value
            .copyWith(lastSyncAt: DateTime.now(), clearError: error == null);
      } catch (_) {
        offline = true;
      }
    }

    state.value = state.value.copyWith(
      offline: offline,
      lastError: error,
      clearError: error == null,
    );
  }

  bool _hasActivePending() =>
      outbox.pending().any((op) => op.attempts < maxAttempts);

  Future<void> _push(SyncOp op) async {
    switch (op.kind) {
      case SyncKind.shop:
        final shop = local.getShop();
        if (shop != null) await remote.upsertShop(shop);
      case SyncKind.product:
        if (op.action == SyncAction.delete) {
          await remote.deleteProduct(op.id);
        } else {
          final product = local.getProduct(op.id);
          if (product != null) await remote.upsertProduct(product);
        }
      case SyncKind.sale:
        final sale = local.getSale(op.id);
        if (sale != null) await remote.upsertSale(sale);
    }
  }

  /// Devuelve true si cambió algo local.
  Future<bool> _pull() async {
    var changed = false;

    final shop = await remote.fetchShop();
    if (shop != null && shop != local.getShop()) {
      await local.saveShop(shop);
      changed = true;
    }

    final localById = {for (final p in local.allProducts()) p.id: p};
    final toSave = <Product>[];
    final toDelete = <String>[];
    for (final rp in await remote.fetchProducts()) {
      final id = rp.product.id;
      if (rp.deleted) {
        if (localById.containsKey(id)) toDelete.add(id);
      } else if (localById[id] != rp.product) {
        toSave.add(rp.product);
      }
    }
    if (toSave.isNotEmpty) await local.saveProducts(toSave);
    if (toDelete.isNotEmpty) await local.deleteProducts(toDelete);
    changed = changed || toSave.isNotEmpty || toDelete.isNotEmpty;

    // Las ventas solo se restauran en un teléfono vacío (cambio de celular).
    if (local.hasNoSales) {
      final sales = await remote.fetchSales();
      if (sales.isNotEmpty) {
        await local.saveSales(sales);
        changed = true;
      }
    }
    return changed;
  }

  void _refreshCounts() {
    final all = outbox.pending();
    final failed = all.where((op) => op.attempts >= maxAttempts).length;
    state.value =
        state.value.copyWith(pending: all.length - failed, failed: failed);
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _periodic?.cancel();
    await _changes.close();
    state.dispose();
  }
}
