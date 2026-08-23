import 'dart:convert';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/rfid_tag.dart';

class ApiService {
  //new feature
  Future<void> uploadScannedTags(List<RFIDTag> tags, {bool isOffline = false}) async {
    final List<Map<String, String>> tagList = tags.map((tag) => {
      'epc_hex': tag.epc,
      'tid': tag.tid,
    }).toList();

    final Map<String, dynamic> requestPayload = {
      'data': tagList,
    };

    // DEBUG: Print the payload to console
    debugPrint('--- UPLOAD DEBUG: PAYLOAD ---');
    debugPrint(jsonEncode(requestPayload));
    debugPrint('-----------------------------');

    if (isOffline) {
      debugPrint('DEBUG: Offline mode enabled. Simulating upload...');
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('DEBUG: Offline upload simulation complete.');
      return;
    }

    final uri = Uri.parse('http://192.168.1.71:8522/api/epc/valid-epc-tags/bulk-create');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed: ${response.body}');
    }
  }

}
