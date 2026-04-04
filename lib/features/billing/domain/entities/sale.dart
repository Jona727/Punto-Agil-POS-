import 'package:equatable/equatable.dart';

class Sale extends Equatable {
  final String id;
  final DateTime date;
  final double total;
  final bool voided;

  const Sale({
    required this.id,
    required this.date,
    required this.total,
    this.voided = false,
  });

  Sale copyWith({bool? voided}) {
    return Sale(
      id: id,
      date: date,
      total: total,
      voided: voided ?? this.voided,
    );
  }

  @override
  List<Object?> get props => [id, date, total, voided];
}
