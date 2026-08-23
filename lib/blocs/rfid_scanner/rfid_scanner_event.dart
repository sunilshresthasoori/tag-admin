import 'package:equatable/equatable.dart';

abstract class RFIDScannerEvent extends Equatable {
  const RFIDScannerEvent();

  @override
  List<Object?> get props => [];
}

class InitializeReader extends RFIDScannerEvent {}

class ConnectReader extends RFIDScannerEvent {}

class DisconnectReader extends RFIDScannerEvent {}

class StartScanning extends RFIDScannerEvent {}

class StopScanning extends RFIDScannerEvent {}

class UploadTags extends RFIDScannerEvent {}

class ClearTags extends RFIDScannerEvent {}

class SaveSession extends RFIDScannerEvent {
  final String jobNo;
  const SaveSession(this.jobNo);

  @override
  List<Object?> get props => [jobNo];
}

class TagReceived extends RFIDScannerEvent {
  final Map<String, dynamic> tagData;
  const TagReceived(this.tagData);

  @override
  List<Object?> get props => [tagData];
}

class StatusChanged extends RFIDScannerEvent {
  final String status;
  const StatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class ErrorOccurred extends RFIDScannerEvent {
  final String error;
  const ErrorOccurred(this.error);

  @override
  List<Object?> get props => [error];
}
