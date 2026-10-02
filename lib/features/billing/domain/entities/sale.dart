import 'package:equatable/equatable.dart';
import 'sale_item.dart';

class Sale extends Equatable {
  final String id;
  final DateTime date;
  final double total;
  final bool voided;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.date,
    required this.total,
    this.voided = false,
    this.items = const [],
  });

  Sale copyWith({bool? voided}) {
    return Sale(
      id: id,
      date: date,
      total: total,
      voided: voided ?? this.voided,
      items: items,
    );
  }

  @override
  List<Object?> get props => [id, date, total, voided, items];
}
