import 'dart:convert';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/rfid_tag.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();
  static const String baseUrl = 'https://ntag-verify.sooritechnology.com.np';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  //new feature
  Future<void> uploadScannedTags(String packetCode, List<RFIDTag> tags, {bool isOffline = false}) async {
    final List<Map<String, String>> tagList = tags.map((tag) => {
      'epcHex': tag.epc,
      'tid': tag.tid,
    }).toList();

    final Map<String, dynamic> requestPayload = {
      'packetCode': packetCode,
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

    final uri = Uri.parse('$baseUrl/api/v1/epc-tags-app/valid-epc-tags/bulk-create');

    var response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode == 401) {
      debugPrint('DEBUG: 401 Unauthorized. Attempting to refresh token...');
      final newToken = await _authService.refreshToken();
      if (newToken != null) {
        response = await http.post(
          uri,
          headers: await _getHeaders(),
          body: jsonEncode(requestPayload),
        );
      }
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed: ${response.body}');
    }
  }
}
