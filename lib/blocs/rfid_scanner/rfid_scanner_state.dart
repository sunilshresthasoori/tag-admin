import 'package:equatable/equatable.dart';
import '../../models/rfid_tag.dart';

enum RFIDScannerStatus { initial, loading, success, failure }

class RFIDScannerState extends Equatable {
  final String connectionStatus;
  final bool isScanning;
  final bool isConnected;
  final bool isUploading;
  final bool isCheckingPacket;
  final bool? isValidPacket;
  final String? packetNumber;
  final List<RFIDTag> scannedTags;
  final Map<String, RFIDTag> tagMap;
  final List<TIDConflict> tidConflicts;
  final List<InvalidEPC> invalidEpcs;
  final List<SkippedTag> skippedTags;
  final RFIDScannerStatus status;
  final String? errorMessage;
  final String? successMessage;

  const RFIDScannerState({
    this.connectionStatus = 'Disconnected',
    this.isScanning = false,
    this.isConnected = false,
    this.isUploading = false,
    this.isCheckingPacket = false,
    this.isValidPacket,
    this.packetNumber,
    this.scannedTags = const [],
    this.tagMap = const {},
    this.tidConflicts = const [],
    this.invalidEpcs = const [],
    this.skippedTags = const [],
    this.status = RFIDScannerStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  bool get isBarcodeScanned => packetNumber != null && packetNumber!.isNotEmpty;

  RFIDScannerState copyWith({
    String? connectionStatus,
    bool? isScanning,
    bool? isConnected,
    bool? isUploading,
    bool? isCheckingPacket,
    bool? isValidPacket,
    String? packetNumber,
    List<RFIDTag>? scannedTags,
    Map<String, RFIDTag>? tagMap,
    List<TIDConflict>? tidConflicts,
    List<InvalidEPC>? invalidEpcs,
    List<SkippedTag>? skippedTags,
    RFIDScannerStatus? status,
    String? errorMessage,
    String? successMessage,
    bool clearPacketNumber = false,
    bool clearConflicts = false,
  }) {
    return RFIDScannerState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      isUploading: isUploading ?? this.isUploading,
      isCheckingPacket: isCheckingPacket ?? this.isCheckingPacket,
      isValidPacket: clearPacketNumber
          ? null
          : (isValidPacket ?? this.isValidPacket),
      packetNumber: clearPacketNumber
          ? null
          : (packetNumber ?? this.packetNumber),
      scannedTags: scannedTags ?? this.scannedTags,
      tagMap: tagMap ?? this.tagMap,
      tidConflicts: clearConflicts ? [] : (tidConflicts ?? this.tidConflicts),
      invalidEpcs: clearConflicts ? [] : (invalidEpcs ?? this.invalidEpcs),
      skippedTags: clearConflicts ? [] : (skippedTags ?? this.skippedTags),
      status: status ?? this.status,
      errorMessage: errorMessage,
      // Reset error if not provided
      successMessage: successMessage, // Reset success if not provided
    );
  }

  @override
  List<Object?> get props => [
    connectionStatus,
    isScanning,
    isConnected,
    isUploading,
    isCheckingPacket,
    isValidPacket,
    packetNumber,
    scannedTags,
    tagMap,
    tidConflicts,
    invalidEpcs,
    skippedTags,
    status,
    errorMessage,
    successMessage,
  ];
}
