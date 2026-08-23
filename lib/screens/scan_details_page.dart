import 'package:flutter/material.dart';
import '../models/scan_sessions.dart';

class ScanDetailsPage extends StatelessWidget {
  final ScanSession session;

  const ScanDetailsPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Job ${session.jobNo}')),
      body: ListView.separated(
        itemCount: session.tags.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        // separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final tag = session.tags[index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(
              'EPC: ${tag.epc}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('TID: ${tag.tid.isEmpty ? "—" : tag.tid}'),
          );
        },
      ),
    );
  }
}
