import 'package:equatable/equatable.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

abstract class PrinterEvent extends Equatable {
  const PrinterEvent();

  @override
  List<Object?> get props => [];
}

// ── Wi-Fi / LAN events ───────────────────────────────────────────────────────

class InitPrinterEvent extends PrinterEvent {}

class RefreshPrinterEvent extends PrinterEvent {}

class ScanPrintersEvent extends PrinterEvent {}

class ConnectPrinterEvent extends PrinterEvent {
  final String ip;
  final String name;

  const ConnectPrinterEvent({required this.ip, required this.name});

  @override
  List<Object?> get props => [ip, name];
}

class DisconnectPrinterEvent extends PrinterEvent {}

class TestPrintEvent extends PrinterEvent {
  final String shopName;

  const TestPrintEvent(this.shopName);

  @override
  List<Object?> get props => [shopName];
}

// ── Bluetooth events ─────────────────────────────────────────────────────────

class InitBluetoothPrinterEvent extends PrinterEvent {}

class ScanBluetoothEvent extends PrinterEvent {}

class ConnectBluetoothEvent extends PrinterEvent {
  final BluetoothDevice device;

  const ConnectBluetoothEvent(this.device);

  @override
  List<Object?> get props => [device.address];
}

class DisconnectBluetoothEvent extends PrinterEvent {}

class TestPrintBluetoothEvent extends PrinterEvent {
  final String shopName;

  const TestPrintBluetoothEvent(this.shopName);

  @override
  List<Object?> get props => [shopName];
}

// ── Preferences ────────────────────────────────────────────────────────────

class SetPreferredPrinterEvent extends PrinterEvent {
  final String type; // 'wifi', 'bluetooth', or 'none'

  const SetPreferredPrinterEvent(this.type);

  @override
  List<Object?> get props => [type];
}
