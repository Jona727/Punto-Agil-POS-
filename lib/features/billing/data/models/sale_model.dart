import 'package:hive/hive.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/sale.dart';
import 'sale_item_model.dart';

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

  @HiveField(4)
  final List<SaleItemModel> items;

  /// Código del medio de pago (ver [PaymentMethod.code]).
  @HiveField(5)
  final String paymentMethod;

  SaleModel({
    required this.id,
    required this.date,
    required this.total,
    this.voided = false,
    this.items = const [],
    this.paymentMethod = 'cash',
  });

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      date: sale.date,
      total: sale.total,
      voided: sale.voided,
      items: sale.items.map(SaleItemModel.fromEntity).toList(),
      paymentMethod: sale.paymentMethod.code,
    );
  }

  Sale toEntity() {
    return Sale(
      id: id,
      date: date,
      total: total,
      voided: voided,
      items: items.map((i) => i.toEntity()).toList(),
      paymentMethod: PaymentMethod.fromCode(paymentMethod),
    );
  }
}
