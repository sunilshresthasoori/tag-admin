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

  Color _getRssiColor(String rssiStr) {
    if (rssiStr.isEmpty) return Colors.grey;
    final rssi = double.tryParse(rssiStr) ?? -100;
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (tags.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors_off,
                size: 64, // Slightly smaller icon
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No tags scanned yet',
                style: TextStyle(
                  fontSize: 16, // Slightly smaller text
                  fontWeight: FontWeight.w500,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Press the button above to start',
                style: TextStyle(
                  fontSize: 12, // Slightly smaller text
                  color: colorScheme.outline.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tags.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tag = tags[index];
        final rssiColor = _getRssiColor(tag.rssi);

        return InkWell(
          onTap: () => onTagTap(tag),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        tag.count.toString(),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.epc,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 12, // Reduced from 15
                          ),
                          // Removed ellipsis to help see the full EPC
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (tag.tid.isNotEmpty)
                              Expanded(
                                child: Text(
                                  'TID: ${tag.tid}',
                                  style: TextStyle(
                                    fontSize: 10, // Reduced from 12
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              Text(
                                'TID: Reading...',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      /*
                      if (tag.rssi.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.signal_cellular_alt, size: 14, color: rssiColor),
                            const SizedBox(width: 4),
                            Text(
                              '${tag.rssi} dBm',
                              style: TextStyle(
                                fontSize: 12,
                                color: rssiColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      */
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

