import 'catalog_product.dart';

abstract class CatalogRepository {
  /// Busca un producto por su código de barras. Devuelve null si no está, si el
  /// código no es válido o si no se puede consultar: nunca lanza errores,
  /// porque el autocompletado es una ayuda y no puede trabar la carga.
  Future<CatalogProduct?> lookup(String barcode);
}
