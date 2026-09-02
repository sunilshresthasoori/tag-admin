import 'dart:async';
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

  Future<Map<String, dynamic>> uploadScannedTags(
    String packetCode,
    List<RFIDTag> tags, {
    bool isOffline = false,
  }) async {
    final List<Map<String, String>> tagList = tags
        .map((tag) => {'epcHex': tag.epc, 'tid': tag.tid})
        .toList();

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
      return {'success': true, 'message': 'Offline success'};
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/epc-tags-app/valid-epc-tags/bulk-create',
    );

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

    final responseBody = jsonDecode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(responseBody['message'] ?? 'Upload failed');
    }

    return responseBody;
  }

  Future<Map<String, dynamic>> dispatchTags(List<String> packetCodes) async {
    try {
      return await _dispatchTagsInternal(packetCodes).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException(
              'The server is taking too long to respond. Please check your internet connection and try again.');
        },
      );
    } on TimeoutException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Map<String, dynamic>> _dispatchTagsInternal(
      List<String> packetCodes) async {
    final uri = Uri.parse('$baseUrl/api/v1/epc-tags-app/dispatch-tags');
    final token = await _authService.getAccessToken();

    var request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['accept'] = 'application/json';

    for (var code in packetCodes) {
      request.files.add(http.MultipartFile.fromString('packetCodes', code));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401) {
      final newToken = await _authService.refreshToken();
      if (newToken != null) {
        request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $newToken';
        request.headers['accept'] = 'application/json';
        for (var code in packetCodes) {
          request.files.add(http.MultipartFile.fromString('packetCodes', code));
        }
        final retryStreamedResponse = await request.send();
        final retryResponse =
            await http.Response.fromStream(retryStreamedResponse);
        return _handleResponse(retryResponse);
      }
    }

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final responseBody = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(responseBody['message'] ?? 'Dispatch failed');
    }
    return responseBody;
  }
}
