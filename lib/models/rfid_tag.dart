class RFIDTag {
  final String epc;
  String tid;
  String user;
  String rssi;
  final String antenna;
  int count;
  String? serialNumber;

  RFIDTag({
    required this.antenna,
    required this.epc,
    required this.tid,
    required this.rssi,
    required this.user,
    this.count = 1,
    this.serialNumber,
  });
}
