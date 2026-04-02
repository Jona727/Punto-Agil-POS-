import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/printer_repository.dart';
import 'printer_event.dart';
import 'printer_state.dart';

class PrinterBloc extends Bloc<PrinterEvent, PrinterState> {
  final PrinterRepository repository;

  PrinterBloc({required this.repository}) : super(const PrinterState()) {
    // Wi-Fi handlers
    on<InitPrinterEvent>(_onInitPrinter);
    on<ConnectPrinterEvent>(_onConnectPrinter);
    on<DisconnectPrinterEvent>(_onDisconnectPrinter);
    on<TestPrintEvent>(_onTestPrint);

    // Bluetooth handlers
    on<InitBluetoothPrinterEvent>(_onInitBluetooth);
    on<ScanBluetoothEvent>(_onScanBluetooth);
    on<ConnectBluetoothEvent>(_onConnectBluetooth);
    on<DisconnectBluetoothEvent>(_onDisconnectBluetooth);
    on<TestPrintBluetoothEvent>(_onTestPrintBluetooth);
  }

  // ── Wi-Fi ─────────────────────────────────────────────────────────────────

  Future<void> _onInitPrinter(
      InitPrinterEvent event, Emitter<PrinterState> emit) async {
    final ip = repository.getSavedPrinterIp();
    final name = repository.getSavedPrinterName();

    if (ip != null && ip.isNotEmpty) {
      emit(state.copyWith(
        wifiStatus: PrinterStatus.connected,
        connectedIp: ip,
        connectedName: name ?? 'WiFi Printer',
      ));
    } else {
      emit(state.copyWith(wifiStatus: PrinterStatus.disconnected));
    }

    // Also init BT state
    add(InitBluetoothPrinterEvent());
  }

  Future<void> _onConnectPrinter(
      ConnectPrinterEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(wifiStatus: PrinterStatus.connecting));

    try {
      final success = await repository.connect(event.ip);
      if (success) {
        await repository.savePrinterData(event.ip, event.name);
        emit(state.copyWith(
          wifiStatus: PrinterStatus.connected,
          connectedIp: event.ip,
          connectedName: event.name,
        ));
      } else {
        emit(state.copyWith(
          wifiStatus: PrinterStatus.error,
          wifiErrorMessage:
              'Failed to connect. Make sure IP and Port (9100) are reachable.',
        ));
        emit(state.copyWith(wifiStatus: PrinterStatus.disconnected));
      }
    } catch (e) {
      emit(state.copyWith(
        wifiStatus: PrinterStatus.error,
        wifiErrorMessage: e.toString(),
      ));
      emit(state.copyWith(wifiStatus: PrinterStatus.disconnected));
    }
  }

  Future<void> _onDisconnectPrinter(
      DisconnectPrinterEvent event, Emitter<PrinterState> emit) async {
    await repository.disconnect();
    await repository.clearSavedPrinter();
    emit(state.copyWith(
      wifiStatus: PrinterStatus.disconnected,
      clearIp: true,
      clearName: true,
    ));
  }

  Future<void> _onTestPrint(
      TestPrintEvent event, Emitter<PrinterState> emit) async {
    await repository.testPrint(event.shopName);
  }

  // ── Bluetooth ─────────────────────────────────────────────────────────────

  Future<void> _onInitBluetooth(
      InitBluetoothPrinterEvent event, Emitter<PrinterState> emit) async {
    final address = repository.getSavedBluetoothAddress();
    final name = repository.getSavedBluetoothName();

    if (address != null && address.isNotEmpty) {
      emit(state.copyWith(
        btStatus: PrinterStatus.connected,
        connectedBtAddress: address,
        connectedBtName: name ?? 'Bluetooth Printer',
      ));
    } else {
      emit(state.copyWith(btStatus: PrinterStatus.disconnected));
    }
  }

  Future<void> _onScanBluetooth(
      ScanBluetoothEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(btStatus: PrinterStatus.scanning));
    try {
      final devices = await repository.getPairedBluetoothDevices();
      emit(state.copyWith(
        btStatus: PrinterStatus.disconnected,
        availableBtDevices: devices,
      ));
    } catch (e) {
      emit(state.copyWith(
        btStatus: PrinterStatus.error,
        btErrorMessage: e.toString(),
      ));
      emit(state.copyWith(btStatus: PrinterStatus.disconnected));
    }
  }

  Future<void> _onConnectBluetooth(
      ConnectBluetoothEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(btStatus: PrinterStatus.connecting));
    try {
      final success = await repository.connectBluetooth(event.device);
      if (success) {
        await repository.saveBluetoothDevice(
            event.device.address, event.device.name ?? 'BT Printer');
        emit(state.copyWith(
          btStatus: PrinterStatus.connected,
          connectedBtAddress: event.device.address,
          connectedBtName: event.device.name ?? 'BT Printer',
        ));
      } else {
        emit(state.copyWith(
          btStatus: PrinterStatus.error,
          btErrorMessage: 'Could not connect. Is the device paired and on?',
        ));
        emit(state.copyWith(btStatus: PrinterStatus.disconnected));
      }
    } catch (e) {
      emit(state.copyWith(
        btStatus: PrinterStatus.error,
        btErrorMessage: e.toString(),
      ));
      emit(state.copyWith(btStatus: PrinterStatus.disconnected));
    }
  }

  Future<void> _onDisconnectBluetooth(
      DisconnectBluetoothEvent event, Emitter<PrinterState> emit) async {
    await repository.disconnectBluetooth();
    await repository.clearSavedBluetooth();
    emit(state.copyWith(
      btStatus: PrinterStatus.disconnected,
      clearBtAddress: true,
      clearBtName: true,
    ));
  }

  Future<void> _onTestPrintBluetooth(
      TestPrintBluetoothEvent event, Emitter<PrinterState> emit) async {
    await repository.testPrintBluetooth(event.shopName);
  }
}
