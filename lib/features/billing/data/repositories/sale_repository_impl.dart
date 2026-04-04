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
      final sales = box.values.where((sale) {
        // Mismo día, mes y año
        return sale.date.year == date.year &&
            sale.date.month == date.month &&
            sale.date.day == date.day;
      }).map((model) => model.toEntity()).toList();
      
      return Right(sales);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> voidSale(String saleId) async {
    try {
      final box = HiveDatabase.salesBox;
      await box.delete(saleId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
