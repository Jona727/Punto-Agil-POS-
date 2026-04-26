import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../models/sale_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  @override
  Future<Either<Failure, void>> saveSale(Sale sale) async {
    try {
      final box = HiveDatabase.salesBox;
      final model = SaleModel.fromEntity(sale);
      await box.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getSalesByDate(DateTime date) async {
    try {
      final box = HiveDatabase.salesBox;
      final sales = box.values
          .where((model) {
            return model.date.year == date.year &&
                model.date.month == date.month &&
                model.date.day == date.day;
          })
          .map((model) => model.toEntity())
          .toList();

      return Right(sales);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> voidSale(String saleId) async {
    try {
      final box = HiveDatabase.salesBox;
      final model = box.get(saleId);
      if (model != null) {
        final updatedModel = SaleModel(
          id: model.id,
          date: model.date,
          total: model.total,
          voided: true,
        );
        await box.put(saleId, updatedModel);
        return const Right(null);
      }
      return Left(CacheFailure('Sale not found: $saleId'));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
