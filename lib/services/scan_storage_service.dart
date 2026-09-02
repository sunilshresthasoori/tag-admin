import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_sessions.dart';

class ScanStorageService {
  static const _key = 'scan_sessions';

  Future<List<ScanSession>> getAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    final sessions = decoded.map((e) => ScanSession.fromJson(e)).toList();
    sessions.sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return sessions;
  }

  Future<void> saveSession(ScanSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getAllSessions();
    sessions.add(session);
    await prefs.setString(
      _key,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getAllSessions();
    sessions.removeWhere((s) => s.id == id);
    await prefs.setString(
      _key,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }
}
