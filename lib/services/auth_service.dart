import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://ntag-verify.sooritechnology.com.np';
  
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<bool> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth-app/login');
    
    // Swagger says multipart/form-data
    var request = http.MultipartRequest('POST', uri)
      ..fields['username'] = username
      ..fields['password'] = password;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final accessToken = data['access'];
      final refreshToken = data['refresh'];

      if (accessToken != null && refreshToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, accessToken);
        await prefs.setString(_refreshTokenKey, refreshToken);
        return true;
      }
    }
    return false;
  }

  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_refreshTokenKey);
    
    if (refresh == null) return null;

    final uri = Uri.parse('$baseUrl/api/v1/auth-app/refresh-token');
    
    var request = http.MultipartRequest('POST', uri)
      ..fields['refresh'] = refresh;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccess = data['access'];
      if (newAccess != null) {
        await prefs.setString(_accessTokenKey, newAccess);
        return newAccess;
      }
    }
    return null;
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
