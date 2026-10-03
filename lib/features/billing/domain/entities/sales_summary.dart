import 'package:equatable/equatable.dart';

import 'payment_method.dart';
import 'sale.dart';

class MethodTotal extends Equatable {
  final int count;
  final double total;
  const MethodTotal({this.count = 0, this.total = 0});

  @override
  List<Object> get props => [count, total];
}

/// Totales de un conjunto de ventas (por ejemplo, las del día).
/// Las ventas anuladas no suman.
class SalesSummary extends Equatable {
  final int count;
  final double total;

  /// Solo incluye los medios de pago que tuvieron ventas, en el orden del enum.
  final Map<PaymentMethod, MethodTotal> byMethod;

  const SalesSummary({
    this.count = 0,
    this.total = 0,
    this.byMethod = const {},
  });

  factory SalesSummary.from(Iterable<Sale> sales) {
    final counts = <PaymentMethod, int>{};
    final totals = <PaymentMethod, double>{};
    var count = 0;
    var total = 0.0;
    for (final sale in sales.where((s) => !s.voided)) {
      count++;
      total += sale.total;
      counts[sale.paymentMethod] = (counts[sale.paymentMethod] ?? 0) + 1;
      totals[sale.paymentMethod] =
          (totals[sale.paymentMethod] ?? 0) + sale.total;
    }
    return SalesSummary(
      count: count,
      total: total,
      byMethod: {
        for (final m in PaymentMethod.values)
          if (counts.containsKey(m))
            m: MethodTotal(count: counts[m]!, total: totals[m]!),
      },
    );
  }

  @override
  List<Object> get props => [count, total, byMethod];
}
