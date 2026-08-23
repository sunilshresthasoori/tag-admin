import 'package:rfid_scanner_lane/models/rfid_tag.dart';

class ScanSession {
  final String id;
  final DateTime scanDate;
  final String jobNo;
  final List<RFIDTag> tags;

  ScanSession({
    required this.id,
    required this.jobNo,
    required this.scanDate,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'scanDate': scanDate.toIso8601String(),
    'jobNo': jobNo,
    'tags': tags
        .map(
          (t) => {
            'epc': t.epc,
            'tid': t.tid,
            'user': t.user,
            'rssi': t.rssi,
            'antenna': t.antenna,
            'count': t.count,
          },
        )
        .toList(),
  };

  factory ScanSession.fromJson(Map<String, dynamic> json) => ScanSession(
    id: json['id'],
    scanDate: DateTime.parse(json['scanDate']),
    jobNo: json['jobNo'],
    tags: (json['tags'] as List)
        .map(
          (t) => RFIDTag(
            epc: t['epc'],
            tid: t['tid'],
            user: t['user'],
            rssi: t['rssi'],
            antenna: t['antenna'],
            count: t['count'] ?? 1,
          ),
        )
        .toList(),
  );
}
