import 'package:equatable/equatable.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

enum PrinterStatus { initial, scanning, connected, disconnected, error, connecting }

class PrinterState extends Equatable {
  // Wi-Fi
  final PrinterStatus wifiStatus;
  final String? connectedIp;
  final String? connectedName;
  final String? wifiErrorMessage;

  // Bluetooth
  final PrinterStatus btStatus;
  final String? connectedBtAddress;
  final String? connectedBtName;
  final List<BluetoothDevice> availableBtDevices;
  final String? btErrorMessage;

  // Preferences
  final String preferredType; // 'wifi', 'bluetooth', or 'none'

  const PrinterState({
    this.wifiStatus = PrinterStatus.initial,
    this.connectedIp,
    this.connectedName,
    this.wifiErrorMessage,
    this.btStatus = PrinterStatus.initial,
    this.connectedBtAddress,
    this.connectedBtName,
    this.availableBtDevices = const [],
    this.btErrorMessage,
    this.preferredType = 'none',
  });

  // ── backwards-compat getters so existing code keeps working ──────────────
  PrinterStatus get status => wifiStatus;
  String? get errorMessage => wifiErrorMessage;

  PrinterState copyWith({
    PrinterStatus? wifiStatus,
    String? connectedIp,
    bool clearIp = false,
    String? connectedName,
    bool clearName = false,
    String? wifiErrorMessage,
    PrinterStatus? btStatus,
    String? connectedBtAddress,
    bool clearBtAddress = false,
    String? connectedBtName,
    bool clearBtName = false,
    List<BluetoothDevice>? availableBtDevices,
    String? btErrorMessage,
    String? preferredType,
  }) {
    return PrinterState(
      wifiStatus: wifiStatus ?? this.wifiStatus,
      connectedIp: clearIp ? null : (connectedIp ?? this.connectedIp),
      connectedName: clearName ? null : (connectedName ?? this.connectedName),
      wifiErrorMessage: wifiErrorMessage ?? this.wifiErrorMessage,
      btStatus: btStatus ?? this.btStatus,
      connectedBtAddress: clearBtAddress ? null : (connectedBtAddress ?? this.connectedBtAddress),
      connectedBtName: clearBtName ? null : (connectedBtName ?? this.connectedBtName),
      availableBtDevices: availableBtDevices ?? this.availableBtDevices,
      btErrorMessage: btErrorMessage ?? this.btErrorMessage,
      preferredType: preferredType ?? this.preferredType,
    );
  }

  @override
  List<Object?> get props => [
        wifiStatus,
        connectedIp,
        connectedName,
        wifiErrorMessage,
        btStatus,
        connectedBtAddress,
        connectedBtName,
        availableBtDevices,
        btErrorMessage,
        preferredType,
      ];
}
