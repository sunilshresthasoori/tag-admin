import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../services/rfid_service.dart';
import 'dispatch_tags_event.dart';
import 'dispatch_tags_state.dart';

class DispatchTagsBloc extends Bloc<DispatchTagsEvent, DispatchTagsState> {
  final RFIDService _rfidService;
  final ApiService _apiService;
  StreamSubscription? _eventSubscription;

  DispatchTagsBloc({
    required RFIDService rfidService,
    required ApiService apiService,
  })  : _rfidService = rfidService,
        _apiService = apiService,
        super(const DispatchTagsState()) {
    on<StartBarcodeScanning>(_onStartBarcodeScanning);
    on<StopBarcodeScanning>(_onStopBarcodeScanning);
    on<BarcodeScanned>(_onBarcodeScanned);
    on<AddBarcodeManually>(_onAddBarcodeManually);
    on<RemoveBarcode>(_onRemoveBarcode);
    on<ClearBarcodes>(_onClearBarcodes);
    on<DispatchBarcodes>(_onDispatchBarcodes);
    on<ClearMessages>(_onClearMessages);

    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = _rfidService.getEventStream().listen(
      (event) {
        if (event is Map && event.containsKey('barcode')) {
          add(BarcodeScanned(event['barcode'].toString()));
        }
      },
      onError: (error) {
        // Handle error if needed
      },
    );
  }

  void _onStartBarcodeScanning(
    StartBarcodeScanning event,
    Emitter<DispatchTagsState> emit,
  ) {
    emit(state.copyWith(isScanning: true));
  }

  void _onStopBarcodeScanning(
    StopBarcodeScanning event,
    Emitter<DispatchTagsState> emit,
  ) {
    emit(state.copyWith(isScanning: false));
  }

  void _onBarcodeScanned(
    BarcodeScanned event,
    Emitter<DispatchTagsState> emit,
  ) {
    if (!state.isScanning) return;

    final barcode = event.barcode.trim();
    if (barcode.isEmpty) return;

    if (state.barcodes.contains(barcode)) {
      emit(state.copyWith(errorMessage: 'Barcode $barcode already scanned'));
      return;
    }

    final updatedList = List<String>.from(state.barcodes)..add(barcode);
    emit(state.copyWith(
      barcodes: updatedList,
      successMessage: 'Scanned: $barcode',
    ));
  }

  void _onAddBarcodeManually(
    AddBarcodeManually event,
    Emitter<DispatchTagsState> emit,
  ) {
    final barcode = event.barcode.trim();
    if (barcode.isEmpty) return;

    if (state.barcodes.contains(barcode)) {
      emit(state.copyWith(errorMessage: 'Barcode $barcode already exists'));
      return;
    }

    final updatedList = List<String>.from(state.barcodes)..add(barcode);
    emit(state.copyWith(barcodes: updatedList));
  }

  void _onRemoveBarcode(
    RemoveBarcode event,
    Emitter<DispatchTagsState> emit,
  ) {
    final updatedList = List<String>.from(state.barcodes)..remove(event.barcode);
    emit(state.copyWith(barcodes: updatedList));
  }

  void _onClearBarcodes(
    ClearBarcodes event,
    Emitter<DispatchTagsState> emit,
  ) {
    emit(state.copyWith(barcodes: []));
  }

  Future<void> _onDispatchBarcodes(
    DispatchBarcodes event,
    Emitter<DispatchTagsState> emit,
  ) async {
    if (state.barcodes.isEmpty) {
      emit(state.copyWith(errorMessage: 'No barcodes to dispatch'));
      return;
    }

    emit(state.copyWith(isDispatching: true, status: DispatchStatus.loading));

    try {
      final response = await _apiService.dispatchTags(state.barcodes);
      emit(state.copyWith(
        isDispatching: false,
        status: DispatchStatus.success,
        successMessage: response['message'] ?? 'Successfully dispatched tags',
        barcodes: [], // Clear on success
      ));
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      emit(state.copyWith(
        isDispatching: false,
        status: DispatchStatus.failure,
        errorMessage: errorMessage,
      ));
    }
  }

  void _onClearMessages(
    ClearMessages event,
    Emitter<DispatchTagsState> emit,
  ) {
    emit(state.copyWith(clearMessages: true));
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
