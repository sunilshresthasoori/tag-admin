import 'dart:convert';
import 'dart:core';

import 'package:http/http.dart' as http;

import '../models/rfid_tag.dart';
import '../models/vehicle_type.dart';
import 'encryption_helper_recharge.dart';

class ApiService {
  static const String _baseUrl = 'http://192.168.1.69:8085';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<VehicleType>> getVehicleTypes() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/toll-level/vehicle-types'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    String message = 'Unknown server error';

    try {
      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      message = responseJson['message'] ?? message;

      print('Status: ${response.statusCode}');
      print('Message: $message');

      if (response.statusCode == 200) {
        final List data = responseJson['data'] ?? [];
        return data.map((e) => VehicleType.fromJson(e)).toList();
      } else {
        throw Exception(message);
      }
    } catch (_) {
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      throw Exception(message);
    }
  }

  Future<void> sendTagData({
    required String userName,
    required RFIDTag tag,
    required VehicleType vehicleType,
    required int gateId,
    required int laneId,
    required String paymentMethod,
  }) async {
    final Map<String, dynamic> payloadData = {
      'epcTagId': tag.epc,
      'vehicleType': vehicleType.name,
      'gateId': gateId,
      'laneId': laneId,
      'paymentMethod': paymentMethod,
    };

    final prepared = EncryptionHelperRecharge.prepareRechargeRequest(
      userName: userName,
      payloadData: payloadData,
    );

    final String authToken = prepared['authToken'];
    final Map<String, dynamic> requestBody = prepared['requestBody'];

    final uri = Uri.parse(
      '$_baseUrl/api/v1/toll-level/transactions/initiate',
    );

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(requestBody),
    );

    String message = 'Unknown server error';

    try {
      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      message = responseJson['message'] ?? message;
    } catch (_) {
      message = response.body;
    }

    print('Status: ${response.statusCode}');
    print('Message: $message');

    if (response.statusCode != 200) {
      throw Exception(message);
    }
  }

  Future<String> fetchSerialNumber({
    required String userName,
    required String epc,
    required String tid,
  }) async {
    final Map<String, dynamic> payloadData = {
      'epc': epc,
      'tid': tid,
    };

    final prepared = EncryptionHelperRecharge.prepareRechargeRequest(
      userName: userName,
      payloadData: payloadData,
    );

    final String authToken = prepared['authToken'];
    final Map<String, dynamic> requestBody = prepared['requestBody'];
    final aesKey = prepared['aesKey'];

    final uri = Uri.parse('$_baseUrl/api/v1/toll-level/tags/lookup');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> responseJson = jsonDecode(response.body);
        final String encryptedPayload = responseJson['data'] ?? '';

        if (encryptedPayload.isEmpty) {
          throw Exception('Empty response data');
        }

        final decrypted = EncryptionHelperRecharge.decryptResponse(
          encryptedPayload,
          aesKey,
        );

        return decrypted['serialNumber']?.toString() ?? '';
      } catch (e) {
        throw Exception('Failed to parse serial number: $e');
      }
    } else {
      String message = 'Server error';
      try {
        final Map<String, dynamic> responseJson = jsonDecode(response.body);
        message = responseJson['message'] ?? message;
      } catch (_) {}
      throw Exception(message);
    }
  }


  ///===================================================new feature
  Future<void> uploadScannedTags(List<RFIDTag> tags, {bool isOffline = false}) async {
    final List<Map<String, String>> tagList = tags.map((tag) => {
      'epc_hex': tag.epc,
      'tid': tag.tid,
    }).toList();

    final Map<String, dynamic> requestPayload = {
      'data': tagList,
    };

    // DEBUG: Print the payload to console
    print('--- UPLOAD DEBUG: PAYLOAD ---');
    print(jsonEncode(requestPayload));
    print('-----------------------------');

    if (isOffline) {
      print('DEBUG: Offline mode enabled. Simulating upload...');
      await Future.delayed(const Duration(seconds: 2));
      print('DEBUG: Offline upload simulation complete.');
      return;
    }

    final uri = Uri.parse('http://192.168.1.71:8522/api/epc/valid-epc-tags/bulk-create');

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestPayload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed: ${response.body}');
    }
  }

}
