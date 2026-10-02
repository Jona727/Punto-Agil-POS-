import 'package:hive/hive.dart';
import '../../domain/entities/sale_item.dart';

part 'sale_item_model.g.dart';

@HiveType(typeId: 3)
class SaleItemModel extends HiveObject {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String barcode;

  @HiveField(3)
  final double unitPrice;

  @HiveField(4)
  final int quantity;

  SaleItemModel({
    required this.productId,
    required this.name,
    required this.barcode,
    required this.unitPrice,
    required this.quantity,
  });

  factory SaleItemModel.fromEntity(SaleItem item) {
    return SaleItemModel(
      productId: item.productId,
      name: item.name,
      barcode: item.barcode,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
    );
  }

  SaleItem toEntity() {
    return SaleItem(
      productId: productId,
      name: name,
      barcode: barcode,
      unitPrice: unitPrice,
      quantity: quantity,
    );
  }
}
