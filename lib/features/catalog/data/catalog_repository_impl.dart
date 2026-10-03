import '../domain/barcode.dart';
import '../domain/catalog_product.dart';
import '../domain/catalog_repository.dart';
import 'asset_catalog_source.dart';
import 'supabase_catalog_source.dart';

/// Busca primero en el catálogo de la app (rápido y sin internet) y, si no está
/// y hay nube configurada, en el catálogo de Supabase.
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({required this.local, this.remote});

  final AssetCatalogSource local;
  final SupabaseCatalogSource? remote;

  @override
  Future<CatalogProduct?> lookup(String barcode) async {
    final code = normalizeBarcode(barcode);
    if (code == null) return null;
    try {
      return await local.find(code) ?? await remote?.find(code);
    } catch (_) {
      return null;
    }
  }
}
