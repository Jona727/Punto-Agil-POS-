import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/sale.dart';
import '../repositories/sale_repository.dart';

class SaveSaleUseCase implements UseCase<void, Sale> {
  final SaleRepository repository;

  SaveSaleUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Sale params) {
    return repository.saveSale(params);
  }
}

class GetDailySalesUseCase implements UseCase<List<Sale>, DateTime> {
  final SaleRepository repository;

  GetDailySalesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Sale>>> call(DateTime params) {
    return repository.getSalesByDate(params);
  }
}
