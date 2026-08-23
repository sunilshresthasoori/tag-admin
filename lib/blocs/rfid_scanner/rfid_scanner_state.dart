import 'package:equatable/equatable.dart';
import '../../models/rfid_tag.dart';

enum RFIDScannerStatus { initial, loading, success, failure }

class RFIDScannerState extends Equatable {
  final String connectionStatus;
  final bool isScanning;
  final bool isConnected;
  final bool isUploading;
  final List<RFIDTag> scannedTags;
  final Map<String, RFIDTag> tagMap;
  final RFIDScannerStatus status;
  final String? errorMessage;
  final String? successMessage;

  const RFIDScannerState({
    this.connectionStatus = 'Disconnected',
    this.isScanning = false,
    this.isConnected = false,
    this.isUploading = false,
    this.scannedTags = const [],
    this.tagMap = const {},
    this.status = RFIDScannerStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  RFIDScannerState copyWith({
    String? connectionStatus,
    bool? isScanning,
    bool? isConnected,
    bool? isUploading,
    List<RFIDTag>? scannedTags,
    Map<String, RFIDTag>? tagMap,
    RFIDScannerStatus? status,
    String? errorMessage,
    String? successMessage,
  }) {
    return RFIDScannerState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      isUploading: isUploading ?? this.isUploading,
      scannedTags: scannedTags ?? this.scannedTags,
      tagMap: tagMap ?? this.tagMap,
      status: status ?? this.status,
      errorMessage: errorMessage, // Reset error if not provided
      successMessage: successMessage, // Reset success if not provided
    );
  }

  @override
  List<Object?> get props => [
        connectionStatus,
        isScanning,
        isConnected,
        isUploading,
        scannedTags,
        tagMap,
        status,
        errorMessage,
        successMessage,
      ];
}
