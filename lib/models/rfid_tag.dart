class RFIDTag {
  final String epc;
  String tid;
  String user;
  String rssi;
  final String antenna;
  int count;
  String? serialNumber;
  final String? uniqueKey;
  final bool epcCollision;

  RFIDTag({
    required this.antenna,
    required this.epc,
    required this.tid,
    required this.rssi,
    required this.user,
    this.count = 1,
    this.serialNumber,
    this.uniqueKey,
    this.epcCollision = false,
  });
}

class TIDConflict {
  final String epcHex;
  final String tid;

  TIDConflict({required this.epcHex, required this.tid});

  factory TIDConflict.fromJson(Map<String, dynamic> json) {
    return TIDConflict(
      epcHex: json['epcHex'] ?? '',
      tid: json['tid'] ?? '',
    );
  }
}

class InvalidEPC {
  final String epcHex;
  final String tid;

  InvalidEPC({required this.epcHex, required this.tid});

  factory InvalidEPC.fromJson(Map<String, dynamic> json) {
    return InvalidEPC(
      epcHex: json['epcHex'] ?? '',
      tid: json['tid'] ?? '',
    );
  }
}

class SkippedTag {
  final String epcHex;
  final String tid;

  SkippedTag({required this.epcHex, required this.tid});

  factory SkippedTag.fromJson(Map<String, dynamic> json) {
    return SkippedTag(
      epcHex: json['epcHex'] ?? '',
      tid: json['tid'] ?? '',
    );
  }
}
