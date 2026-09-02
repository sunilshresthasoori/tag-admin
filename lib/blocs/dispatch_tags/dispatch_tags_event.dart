import 'package:equatable/equatable.dart';

abstract class DispatchTagsEvent extends Equatable {
  const DispatchTagsEvent();

  @override
  List<Object?> get props => [];
}

class StartBarcodeScanning extends DispatchTagsEvent {}

class StopBarcodeScanning extends DispatchTagsEvent {}

class BarcodeScanned extends DispatchTagsEvent {
  final String barcode;

  const BarcodeScanned(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

class AddBarcodeManually extends DispatchTagsEvent {
  final String barcode;

  const AddBarcodeManually(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

class RemoveBarcode extends DispatchTagsEvent {
  final String barcode;

  const RemoveBarcode(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

class ClearBarcodes extends DispatchTagsEvent {}

class DispatchBarcodes extends DispatchTagsEvent {}

class ClearMessages extends DispatchTagsEvent {}
