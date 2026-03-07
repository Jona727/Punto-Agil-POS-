import 'package:equatable/equatable.dart';

class Sale extends Equatable {
  final String id;
  final DateTime date;
  final double total;

  const Sale({
    required this.id,
    required this.date,
    required this.total,
  });

  @override
  List<Object?> get props => [id, date, total];
}
