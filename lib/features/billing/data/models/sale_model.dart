import 'package:hive/hive.dart';
import '../../domain/entities/sale.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 2)
class SaleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double total;

  @HiveField(3)
  final bool voided;

  SaleModel({
    required this.id,
    required this.date,
    required this.total,
    this.voided = false,
  });

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      date: sale.date,
      total: sale.total,
      voided: sale.voided,
    );
  }

  Sale toEntity() {
    return Sale(
      id: id,
      date: date,
      total: total,
      voided: voided,
    );
  }
}
