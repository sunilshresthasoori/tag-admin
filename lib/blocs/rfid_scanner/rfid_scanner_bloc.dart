import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../models/rfid_tag.dart';
import '../../models/scan_sessions.dart';
import '../../services/api_service.dart';
import '../../services/rfid_service.dart';
import '../../services/scan_storage_service.dart';
import 'rfid_scanner_event.dart';
import 'rfid_scanner_state.dart';

class RFIDScannerBloc extends Bloc<RFIDScannerEvent, RFIDScannerState> {
  final RFIDService _rfidService;
  final ScanStorageService _storage;
  final ApiService _apiService;
  StreamSubscription? _eventSubscription;

  RFIDScannerBloc({
    required RFIDService rfidService,
    required ScanStorageService storage,
    required ApiService apiService,
  }) : _rfidService = rfidService,
       _storage = storage,
       _apiService = apiService,
       super(const RFIDScannerState()) {
    on<InitializeReader>(_onInitializeReader);
    on<ConnectReader>(_onConnectReader);
    on<DisconnectReader>(_onDisconnectReader);
    on<StartScanning>(_onStartScanning);
    on<StopScanning>(_onStopScanning);
    on<UploadTags>(_onUploadTags);
    on<ClearTags>(_onClearTags);
    on<ClearBarcode>(_onClearBarcode);
    on<ClearConflicts>(_onClearConflicts);
    on<SaveSession>(_onSaveSession);
    on<TagReceived>(_onTagReceived);
    on<BarcodeReceived>(_onBarcodeReceived);
    on<StatusChanged>(_onStatusChanged);
    on<ErrorOccurred>(_onErrorOccurred);

    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = _rfidService.getEventStream().listen(
      (event) {
        if (event is Map) {
          if (event.containsKey('tag')) {
            add(TagReceived(Map<String, dynamic>.from(event['tag'])));
          } else if (event.containsKey('barcode')) {
            final barcode = event['barcode'].toString();
            print("RFIDScannerBloc: Received barcode: $barcode");
            add(BarcodeReceived(barcode));
          } else if (event.containsKey('status')) {
            add(StatusChanged(event['status'].toString()));
          } else if (event.containsKey('error')) {
            add(ErrorOccurred(event['error'].toString()));
          }
        }
      },
      onError: (error) {
        add(ErrorOccurred('Event stream error: $error'));
      },
    );
  }

  Future<void> _onInitializeReader(
    InitializeReader event,
    Emitter<RFIDScannerState> emit,
  ) async {
    try {
      await _rfidService.initializeReader();
      emit(state.copyWith(successMessage: 'Reader initialized'));
    } on PlatformException catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to initialize: ${e.message}'));
    }
  }

  Future<void> _onConnectReader(
    ConnectReader event,
    Emitter<RFIDScannerState> emit,
  ) async {
    try {
      emit(state.copyWith(connectionStatus: 'Connecting...'));
      final result = await _rfidService.connectReader();
      final isConnected = result.toString().contains('successfully');
      emit(
        state.copyWith(
          connectionStatus: result,
          isConnected: isConnected,
          successMessage: isConnected ? result : null,
          errorMessage: !isConnected ? result : null,
        ),
      );
    } on PlatformException catch (e) {
      emit(
        state.copyWith(
          connectionStatus: 'Connection failed',
          isConnected: false,
          errorMessage: 'Failed to connect: ${e.message}',
        ),
      );
    }
  }

  Future<void> _onDisconnectReader(
    DisconnectReader event,
    Emitter<RFIDScannerState> emit,
  ) async {
    try {
      await _rfidService.disconnectReader();
      emit(
        state.copyWith(
          isConnected: false,
          isScanning: false,
          connectionStatus: 'Disconnected',
          successMessage: 'Reader disconnected',
        ),
      );
    } on PlatformException catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to disconnect: ${e.message}'));
    }
  }

  Future<void> _onStartScanning(
    StartScanning event,
    Emitter<RFIDScannerState> emit,
  ) async {
    try {
      await _rfidService.startInventory();
      emit(state.copyWith(isScanning: true));
    } on PlatformException catch (e) {
      emit(
        state.copyWith(errorMessage: 'Failed to start scanning: ${e.message}'),
      );
    }
  }

  Future<void> _onStopScanning(
    StopScanning event,
    Emitter<RFIDScannerState> emit,
  ) async {
    try {
      await _rfidService.stopInventory();
      emit(state.copyWith(isScanning: false));
    } on PlatformException catch (e) {
      emit(
        state.copyWith(errorMessage: 'Failed to stop scanning: ${e.message}'),
      );
    }
  }

  Future<void> _onUploadTags(
    UploadTags event,
    Emitter<RFIDScannerState> emit,
  ) async {
    if (state.scannedTags.isEmpty) {
      emit(state.copyWith(errorMessage: 'No tags to upload'));
      return;
    }

    if (state.packetNumber == null) {
      emit(state.copyWith(errorMessage: 'Packet code required for upload'));
      return;
    }

    emit(state.copyWith(isUploading: true, clearConflicts: true));

    try {
      final response = await _apiService.uploadScannedTags(
        state.packetNumber!,
        state.scannedTags,
        isOffline: false,
      );

      final data = response['data'] ?? {};
      final tidConflictsJson = data['tidConflicts'] as List? ?? [];
      final tidConflicts = tidConflictsJson
          .map((c) => TIDConflict.fromJson(c))
          .toList();

      final invalidEpcJson = data['invalidEpc'] as List? ?? [];
      final invalidEpcs = invalidEpcJson
          .map((c) => InvalidEPC.fromJson(c))
          .toList();

      final skippedTagsJson = data['skippedDueToPacketLimit'] as List? ?? [];
      final skippedTags = skippedTagsJson
          .map((c) => SkippedTag.fromJson(c))
          .toList();

      if (tidConflicts.isNotEmpty || invalidEpcs.isNotEmpty || skippedTags.isNotEmpty) {
        String errorMsg = 'Upload partial: ';
        if (tidConflicts.isNotEmpty) errorMsg += '${tidConflicts.length} TID conflicts. ';
        if (invalidEpcs.isNotEmpty) errorMsg += '${invalidEpcs.length} Invalid EPCs. ';
        if (skippedTags.isNotEmpty) errorMsg += '${skippedTags.length} tags skipped (limit reached).';

        emit(
          state.copyWith(
            isUploading: false,
            tidConflicts: tidConflicts,
            invalidEpcs: invalidEpcs,
            skippedTags: skippedTags,
            errorMessage: errorMsg,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isUploading: false,
            scannedTags: [],
            tagMap: {},
            successMessage:
                'Successfully uploaded ${state.scannedTags.length} tags for packet ${state.packetNumber}!',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(isUploading: false, errorMessage: 'Upload failed: $e'),
      );
    }
  }

  void _onClearTags(ClearTags event, Emitter<RFIDScannerState> emit) {
    emit(state.copyWith(scannedTags: [], tagMap: {}, clearPacketNumber: true, clearConflicts: true));
  }

  void _onClearBarcode(ClearBarcode event, Emitter<RFIDScannerState> emit) {
    emit(state.copyWith(clearPacketNumber: true, clearConflicts: true));
  }

  void _onClearConflicts(ClearConflicts event, Emitter<RFIDScannerState> emit) {
    emit(state.copyWith(clearConflicts: true));
  }

  Future<void> _onSaveSession(
    SaveSession event,
    Emitter<RFIDScannerState> emit,
  ) async {
    if (state.scannedTags.isEmpty) {
      emit(state.copyWith(errorMessage: 'No tags scanned yet'));
      return;
    }

    if (state.isScanning) {
      await _rfidService.stopInventory();
    }

    final session = ScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scanDate: DateTime.now(),
      jobNo: event.jobNo.trim(),
      packetNumber: state.packetNumber,
      tags: List.from(state.scannedTags),
    );

    await _storage.saveSession(session);
    emit(
      state.copyWith(
        isScanning: false,
        successMessage:
            'Saved ${state.scannedTags.length} tags under Job ${event.jobNo.trim()}',
      ),
    );
  }

  void _onTagReceived(TagReceived event, Emitter<RFIDScannerState> emit) {
    if (!state.isBarcodeScanned) {
      emit(state.copyWith(errorMessage: 'Please scan box barcode first'));
      return;
    }

    final tagData = event.tagData;
    final epc = tagData['epc'] ?? '';
    if (epc.isEmpty) return;

    final tid = tagData['tid'] ?? '';
    final rssi = tagData['rssi']?.toString() ?? '';
    final uniqueKey = tagData['uniqueKey'] ?? '${epc}_$tid';
    final epcCollision = tagData['epcCollision'] == 'true';

    final updatedTagMap = Map<String, RFIDTag>.from(state.tagMap);
    final updatedScannedTags = List<RFIDTag>.from(state.scannedTags);

    if (updatedTagMap.containsKey(uniqueKey)) {
      final existingTag = updatedTagMap[uniqueKey]!;
      final newTag = RFIDTag(
        epc: existingTag.epc,
        tid: tid.isNotEmpty ? tid : existingTag.tid,
        user: existingTag.user,
        rssi: rssi.isNotEmpty ? rssi : existingTag.rssi,
        antenna: existingTag.antenna,
        count: existingTag.count + 1,
        uniqueKey: uniqueKey,
        epcCollision: epcCollision,
      );
      updatedTagMap[uniqueKey] = newTag;

      final index = updatedScannedTags.indexWhere((t) => t.uniqueKey == uniqueKey);
      if (index != -1) updatedScannedTags[index] = newTag;
    } else {
      final tag = RFIDTag(
        epc: epc,
        tid: tid,
        user: tagData['user'] ?? '',
        rssi: rssi,
        antenna: tagData['antenna']?.toString() ?? '',
        uniqueKey: uniqueKey,
        epcCollision: epcCollision,
      );
      updatedTagMap[uniqueKey] = tag;
      updatedScannedTags.add(tag);
    }

    emit(
      state.copyWith(tagMap: updatedTagMap, scannedTags: updatedScannedTags),
    );
  }

  void _onBarcodeReceived(
    BarcodeReceived event,
    Emitter<RFIDScannerState> emit,
  ) {
    final barcode = event.barcode.trim();

    // Validation: Starts with PKT and has exactly 9 characters after (Total 12)
    final pktRegex = RegExp(r'^PKT[a-zA-Z0-9]{8}$');

    if (!pktRegex.hasMatch(barcode)) {
      emit(
        state.copyWith(
          errorMessage:
              'Invalid Barcode: Must start with PKT followed by 8 characters (e.g., PKT00000001)',
          isValidPacket: false,
          clearPacketNumber: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        packetNumber: barcode,
        successMessage: 'Box barcode scanned: $barcode',
        isValidPacket: true,
      ),
    );
  }

  void _onStatusChanged(StatusChanged event, Emitter<RFIDScannerState> emit) {
    bool? isScanning;
    if (event.status.contains('Scanning started') ||
        event.status.contains('trigger pressed')) {
      isScanning = true;
    } else if (event.status.contains('Scanning stopped') ||
        event.status.contains('trigger released')) {
      isScanning = false;
    }

    emit(
      state.copyWith(connectionStatus: event.status, isScanning: isScanning),
    );
  }

  void _onErrorOccurred(ErrorOccurred event, Emitter<RFIDScannerState> emit) {
    emit(state.copyWith(errorMessage: event.error));
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
