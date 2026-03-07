import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/printer_repository.dart';
import 'printer_event.dart';
import 'printer_state.dart';

class PrinterBloc extends Bloc<PrinterEvent, PrinterState> {
  final PrinterRepository repository;

  PrinterBloc({required this.repository}) : super(const PrinterState()) {
    on<InitPrinterEvent>(_onInitPrinter);
    on<ConnectPrinterEvent>(_onConnectPrinter);
    on<DisconnectPrinterEvent>(_onDisconnectPrinter);
    on<TestPrintEvent>(_onTestPrint);
  }

  Future<void> _onInitPrinter(
      InitPrinterEvent event, Emitter<PrinterState> emit) async {
    final ip = repository.getSavedPrinterIp();
    final name = repository.getSavedPrinterName();

    if (ip != null && ip.isNotEmpty) {
      emit(state.copyWith(
        status: PrinterStatus.connected,
        connectedIp: ip,
        connectedName: name ?? 'WiFi Printer',
      ));
    } else {
      emit(state.copyWith(status: PrinterStatus.disconnected));
    }
  }

  Future<void> _onConnectPrinter(
      ConnectPrinterEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.connecting));

    try {
      final success = await repository.connect(event.ip);
      if (success) {
        await repository.savePrinterData(event.ip, event.name);
        emit(state.copyWith(
          status: PrinterStatus.connected,
          connectedIp: event.ip,
          connectedName: event.name,
        ));
      } else {
        emit(state.copyWith(
          status: PrinterStatus.error,
          errorMessage: 'Failed to connect. Make sure IP and Port (9100) are reachable.',
        ));
        emit(state.copyWith(status: PrinterStatus.disconnected));
      }
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.error,
        errorMessage: e.toString(),
      ));
      emit(state.copyWith(status: PrinterStatus.disconnected));
    }
  }

  Future<void> _onDisconnectPrinter(
      DisconnectPrinterEvent event, Emitter<PrinterState> emit) async {
    await repository.disconnect();
    await repository.clearSavedPrinter();
    emit(const PrinterState(
        status: PrinterStatus.disconnected,
        connectedIp: null,
        connectedName: null));
  }

  Future<void> _onTestPrint(
      TestPrintEvent event, Emitter<PrinterState> emit) async {
    await repository.testPrint(event.shopName);
  }
}
