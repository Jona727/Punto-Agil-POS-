import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale.dart';
import '../repositories/sale_repository.dart';

class SaveSaleUseCase {
  final SaleRepository repository;

  SaveSaleUseCase(this.repository);

  Future<Either<Failure, void>> call(Sale sale) async {
    return await repository.saveSale(sale);
  }
}

class GetDailySalesUseCase {
  final SaleRepository repository;

  GetDailySalesUseCase(this.repository);

  Future<Either<Failure, List<Sale>>> call(DateTime date) async {
    return await repository.getSalesByDate(date);
  }
}

class VoidSaleUseCase {
  final SaleRepository repository;

  VoidSaleUseCase(this.repository);

  Future<Either<Failure, void>> call(String saleId) async {
    return await repository.voidSale(saleId);
  }
}
