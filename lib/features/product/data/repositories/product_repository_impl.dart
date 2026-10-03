import 'package:fpdart/fpdart.dart';
import '../../../catalog/domain/barcode.dart';
import '../../../sync/domain/sync_models.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({this.sync = const NoopSyncRecorder()});

  /// Avisa a la sincronización que algo cambió (no hace nada sin cuenta).
  final SyncRecorder sync;

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final box = HiveDatabase.productBox;
      final products = box.values.toList();
      return Right(products);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    try {
      // Se comparan los códigos normalizados: un UPC de 12 dígitos y su EAN-13
      // con 0 adelante son el mismo producto.
      final wanted = normalizeBarcode(barcode) ?? barcode.trim();
      final box = HiveDatabase.productBox;
      for (final product in box.values) {
        final stored = normalizeBarcode(product.barcode) ?? product.barcode.trim();
        if (stored == wanted) return Right(product);
      }
      return Left(NotFoundFailure('Producto no encontrado: $barcode'));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      final box = HiveDatabase.productBox;
      // You can use add() or put()
      final model = ProductModel.fromEntity(product);
      await box.put(model.id, model); // Using ID as key
      await sync.record(SyncKind.product, model.id, SyncAction.upsert);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    try {
      final box = HiveDatabase.productBox;
      final model = ProductModel.fromEntity(product);
      await box.put(model.id, model);
      await sync.record(SyncKind.product, model.id, SyncAction.upsert);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      final box = HiveDatabase.productBox;
      await box.delete(id);
      await sync.record(SyncKind.product, id, SyncAction.delete);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePricesMassively(double percentage) async {
    try {
      final box = HiveDatabase.productBox;
      final products = box.values.toList();
      
      final Map<dynamic, ProductModel> updatedMap = {};
      
      for (var product in products) {
        final newPrice = product.price * (1 + (percentage / 100));
        
        final updatedModel = ProductModel(
          id: product.id,
          name: product.name,
          barcode: product.barcode,
          price: newPrice,
          stock: product.stock,
        );
        
        updatedMap[product.id] = updatedModel;
      }
      
      await box.putAll(updatedMap);
      for (final id in updatedMap.keys) {
        await sync.record(SyncKind.product, id as String, SyncAction.upsert);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
