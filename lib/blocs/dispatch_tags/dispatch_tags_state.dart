import 'package:equatable/equatable.dart';

enum DispatchStatus { initial, loading, success, failure }

class DispatchTagsState extends Equatable {
  final List<String> barcodes;
  final bool isScanning;
  final bool isDispatching;
  final DispatchStatus status;
  final String? errorMessage;
  final String? successMessage;

  const DispatchTagsState({
    this.barcodes = const [],
    this.isScanning = false,
    this.isDispatching = false,
    this.status = DispatchStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  DispatchTagsState copyWith({
    List<String>? barcodes,
    bool? isScanning,
    bool? isDispatching,
    DispatchStatus? status,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return DispatchTagsState(
      barcodes: barcodes ?? this.barcodes,
      isScanning: isScanning ?? this.isScanning,
      isDispatching: isDispatching ?? this.isDispatching,
      status: status ?? this.status,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        barcodes,
        isScanning,
        isDispatching,
        status,
        errorMessage,
        successMessage,
      ];
}
