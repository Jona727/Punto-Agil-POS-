import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/catalog_product.dart';

/// Catálogo que viaja dentro de la app (assets/catalog/productos_ar.json).
/// Funciona sin internet y sin cuenta. Se arma con tools/catalog/build_catalog.py.
class AssetCatalogSource {
  AssetCatalogSource({
    AssetBundle? bundle,
    this.assetPath = 'assets/catalog/productos_ar.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  Future<Map<String, CatalogProduct>>? _index;

  /// Se lee una sola vez, la primera vez que se necesita.
  Future<Map<String, CatalogProduct>> _load() => _index ??= _parse();

  Future<Map<String, CatalogProduct>> _parse() async {
    try {
      final raw = await _bundle.loadString(assetPath);
      final list = jsonDecode(raw) as List;
      final index = <String, CatalogProduct>{};
      for (final row in list) {
        final r = row as List;
        final ean = r[0] as String;
        index[ean] = CatalogProduct(
          ean: ean,
          name: r[1] as String,
          brand: r.length > 2 ? r[2] as String : '',
          category: r.length > 3 ? r[3] as String : '',
        );
      }
      return index;
    } catch (e) {
      // Sin catálogo la app funciona igual, solo que sin sugerencias.
      debugPrint('No se pudo leer el catálogo: $e');
      return {};
    }
  }

  Future<CatalogProduct?> find(String normalizedBarcode) async =>
      (await _load())[normalizedBarcode];

  Future<int> get size async => (await _load()).length;
}
