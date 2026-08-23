import 'package:flutter/material.dart';
import '../models/rfid_tag.dart';

class TagsList extends StatelessWidget {
  final List<RFIDTag> tags;
  final Function(RFIDTag) onTagTap;

  const TagsList({
    super.key,
    required this.tags,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Center(
        child: Text(
          'No tags scanned yet',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                tag.count.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              tag.epc,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag.tid.isNotEmpty)
                  Text('TID: ${tag.tid}')
                else
                  const Text(
                    'TID: Reading...',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                if (tag.rssi.isNotEmpty) Text('RSSI: ${tag.rssi} dBm'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTagTap(tag),
          ),
        );
      },
    );
  }
}
