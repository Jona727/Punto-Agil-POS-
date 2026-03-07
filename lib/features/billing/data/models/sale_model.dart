import 'package:hive/hive.dart';
import '../../domain/entities/sale.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 2) // TypeId 0 es Product, 1 es Shop
class SaleModel extends Sale {
  @override
  @HiveField(0)
  final String id;
  
  @override
  @HiveField(1)
  final DateTime date;
  
  @override
  @HiveField(2)
  final double total;

  const SaleModel({
    required this.id,
    required this.date,
    required this.total,
  }) : super(
          id: id,
          date: date,
          total: total,
        );

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      date: sale.date,
      total: sale.total,
    );
  }

  Sale toEntity() {
    return Sale(
      id: id,
      date: date,
      total: total,
    );
  }
}
