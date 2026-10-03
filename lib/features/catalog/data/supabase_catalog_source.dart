import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalog_product.dart';

/// Catálogo en la nube (tabla catalog_products). Permite ampliarlo sin publicar
/// una versión nueva de la app. Solo responde con sesión iniciada.
class SupabaseCatalogSource {
  SupabaseCatalogSource(
    this._client, {
    this.timeout = const Duration(seconds: 5),
  });

  final SupabaseClient _client;
  final Duration timeout;

  Future<CatalogProduct?> find(String normalizedBarcode) async {
    try {
      final row = await _client
          .from('catalog_products')
          .select('ean,name,brand,category')
          .eq('ean', normalizedBarcode)
          .maybeSingle()
          .timeout(timeout);
      if (row == null) return null;
      return CatalogProduct(
        ean: row['ean'] as String,
        name: row['name'] as String,
        brand: row['brand'] as String? ?? '',
        category: row['category'] as String? ?? '',
      );
    } catch (e) {
      // Sin internet, sin sesión, tabla sin crear, etc.: no hay sugerencia.
      debugPrint('Catálogo en la nube no disponible: $e');
      return null;
    }
  }
}
