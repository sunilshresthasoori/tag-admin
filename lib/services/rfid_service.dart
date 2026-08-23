import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class RFIDService{
  static const platform = MethodChannel('rfid_scanner_channel');
  static const eventChannel = EventChannel('rfid_scanner_events');


  Future<void> requestPermissions()async{
    await[
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location
    ].request();
  }
  
  Stream<dynamic>  getEventStream(){
    return eventChannel.receiveBroadcastStream();
  }

  Future<void> initializeReader() async {
    await platform.invokeMethod('initializeReader');
  }

  Future<String> connectReader() async {
    final result = await platform.invokeMethod('connectReader');
    return result;
  }

  Future<void> disconnectReader() async {
    await platform.invokeMethod('disconnectReader');
  }

  Future<void> startInventory() async {
    await platform.invokeMethod('startInventory');
  }

  Future<void> stopInventory() async {
    await platform.invokeMethod('stopInventory');
  }
}