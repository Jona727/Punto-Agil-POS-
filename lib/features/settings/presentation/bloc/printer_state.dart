import 'package:equatable/equatable.dart';

enum PrinterStatus { initial, scanning, connected, disconnected, error, connecting }

class PrinterState extends Equatable {
  final PrinterStatus status;
  final String? connectedIp;
  final String? connectedName;
  final String? errorMessage;

  const PrinterState({
    this.status = PrinterStatus.initial,
    this.connectedIp,
    this.connectedName,
    this.errorMessage,
  });

  PrinterState copyWith({
    PrinterStatus? status,
    String? connectedIp,
    String? connectedName,
    String? errorMessage,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedIp: connectedIp ?? this.connectedIp,
      connectedName: connectedName ?? this.connectedName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, connectedIp, connectedName, errorMessage];
}
