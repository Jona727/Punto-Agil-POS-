import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../billing/domain/entities/sale.dart';
import '../../product/domain/entities/product.dart';
import '../../shop/domain/entities/shop.dart';
import '../domain/sync_models.dart';
import 'sync_mappers.dart';

/// Implementación real de la nube con Supabase.
/// Las reglas RLS del servidor garantizan que solo se toquen datos del
/// comercio del usuario; acá igual se filtra por business_id.
class SupabaseRemoteSyncSource implements RemoteSyncSource {
  /// [currentUserId] y [pageSize] se pueden cambiar para probar contra un
  /// servidor local; en la app se usan los valores por defecto.
  SupabaseRemoteSyncSource(
    this._client, {
    String? Function()? currentUserId,
    int pageSize = 1000,
    Duration timeout = const Duration(seconds: 20),
  })  : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id),
        _pageSize = pageSize,
        _timeout = timeout;

  final SupabaseClient _client;
  final String? Function() _currentUserId;
  final int _pageSize;
  final Duration _timeout;

  String? _businessId;
  String? _businessOwner;

  /// SQLSTATE de datos inválidos (22), integridad (23) y permisos/RLS (42):
  /// reintentar el mismo dato no sirve. Todo lo demás se considera pasajero.
  static final _rejectedCode = RegExp(r'^(22|23|42)');

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } on PostgrestException catch (e) {
      if (_rejectedCode.hasMatch(e.code ?? '')) {
        throw SyncRejectedException(_rejectionMessage(e));
      }
      throw SyncRetryableException(e.message);
    } on SyncRetryableException {
      rethrow;
    } catch (e) {
      // Sin red, timeout, sesión vencida, etc.
      throw SyncRetryableException('$e');
    }
  }

  static String _rejectionMessage(PostgrestException e) {
    if (e.code == '23505') {
      return 'Ya existe otro producto con ese código de barras.';
    }
    return 'El servidor rechazó el cambio (${e.code}).';
  }

  Future<String> _bid() async {
    final uid = _currentUserId();
    if (uid == null) throw const SyncRetryableException('Sin sesión iniciada');
    if (_businessId != null && _businessOwner == uid) return _businessId!;
    final row = await _call(() =>
        _client.from('businesses').select('id').eq('owner_id', uid).single());
    _businessOwner = uid;
    return _businessId = row['id'] as String;
  }

  @override
  Future<void> upsertShop(Shop shop) async {
    final id = await _bid();
    await _call(() =>
        _client.from('businesses').update(shopToRow(shop)).eq('id', id));
  }

  @override
  Future<Shop?> fetchShop() async {
    final id = await _bid();
    final row = await _call(
        () => _client.from('businesses').select().eq('id', id).maybeSingle());
    return row == null ? null : rowToShop(row);
  }

  @override
  Future<void> upsertProduct(Product product) async {
    final id = await _bid();
    await _call(() => _client
        .from('products')
        .upsert(productToRow(product, id), onConflict: 'business_id,id'));
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final id = await _bid();
    // Borrado lógico: así los otros teléfonos se enteran de que se borró.
    await _call(() => _client
        .from('products')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('business_id', id)
        .eq('id', productId));
  }

  @override
  Future<List<RemoteProduct>> fetchProducts() async {
    final id = await _bid();
    final result = <RemoteProduct>[];
    for (var from = 0;; from += _pageSize) {
      final page = await _call(() => _client
          .from('products')
          .select()
          .eq('business_id', id)
          .order('id')
          .range(from, from + _pageSize - 1));
      result.addAll(page.map(rowToRemoteProduct));
      if (page.length < _pageSize) return result;
    }
  }

  @override
  Future<void> upsertSale(Sale sale) async {
    final id = await _bid();
    await _call(() => _client
        .from('sales')
        .upsert(saleToRow(sale, id), onConflict: 'business_id,id'));
    final items = saleItemsToRows(sale, id);
    if (items.isNotEmpty) {
      await _call(() => _client
          .from('sale_items')
          .upsert(items, onConflict: 'business_id,sale_id,line'));
    }
  }

  @override
  Future<List<Sale>> fetchSales() async {
    final id = await _bid();
    final result = <Sale>[];
    for (var from = 0;; from += _pageSize) {
      final page = await _call(() => _client
          .from('sales')
          .select('*, sale_items(*)')
          .eq('business_id', id)
          .order('sold_at', ascending: false)
          .range(from, from + _pageSize - 1));
      result.addAll(page.map(rowToSale));
      if (page.length < _pageSize) return result;
    }
  }
}
