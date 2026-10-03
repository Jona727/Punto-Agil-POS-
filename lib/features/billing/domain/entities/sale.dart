import 'package:equatable/equatable.dart';
import 'payment_method.dart';
import 'sale_item.dart';

class Sale extends Equatable {
  final String id;
  final DateTime date;
  final double total;
  final bool voided;
  final List<SaleItem> items;
  final PaymentMethod paymentMethod;

  const Sale({
    required this.id,
    required this.date,
    required this.total,
    this.voided = false,
    this.items = const [],
    this.paymentMethod = PaymentMethod.cash,
  });

  Sale copyWith({bool? voided}) {
    return Sale(
      id: id,
      date: date,
      total: total,
      voided: voided ?? this.voided,
      items: items,
      paymentMethod: paymentMethod,
    );
  }

  @override
  List<Object?> get props => [id, date, total, voided, items, paymentMethod];
}
