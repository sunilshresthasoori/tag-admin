import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tag_admin/screens/rfid_scanner_page.dart';
import 'package:tag_admin/screens/scan_details_page.dart';

import '../models/scan_sessions.dart';
import '../services/scan_storage_service.dart';

class ScanSessionsListPage extends StatefulWidget {
  const ScanSessionsListPage({super.key});

  @override
  State<ScanSessionsListPage> createState() => _ScanSessionsListPageState();
}

class _ScanSessionsListPageState extends State<ScanSessionsListPage> {
  final _storage = ScanStorageService();
  List<ScanSession> _sessions = [];

  Future<void> _load() async {
    final sessions = await _storage.getAllSessions();
    setState(() {
      _sessions = sessions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Sessions')),
      body: _sessions.isEmpty
          ? const Center(child: Text('No scan sessions yet...!'))
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text('Job No: ${session.jobNo}'),
                    subtitle: Text(
                      DateFormat('dd MM yyyy, HM:mm').format(session.scanDate),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanDetailsPage(session: session),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.add),
        label: Text("New Scan"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RFIDScannerPage()),
          );
          _load(); //refresh the state kunai purano scan cha bhane
        },
      ),
    );
  }
}
