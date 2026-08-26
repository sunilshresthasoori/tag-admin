import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String connectionStatus;
  final bool isConnected;
  final VoidCallback onInitialize;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const StatusCard({
    super.key,
    required this.connectionStatus,
    required this.isConnected,
    required this.onInitialize,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade600 : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isConnected ? Colors.green.shade800 : colorScheme.outlineVariant,
          width: 2, // Slightly thicker border for emphasis
        ),
        boxShadow: isConnected ? [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.white : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reader Connection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isConnected ? Colors.white.withValues(alpha: 0.9) : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        connectionStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.white : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isConnected)
                  IconButton.filledTonal(
                    onPressed: onInitialize,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Initialize Reader',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected ? onDisconnect : onConnect,
                    icon: Icon(isConnected ? Icons.link_off : Icons.link),
                    label: Text(isConnected ? 'Disconnect' : 'Connect Reader'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isConnected ? Colors.white.withValues(alpha: 0.2) : colorScheme.primary,
                      foregroundColor: isConnected ? Colors.white : colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(50),
                      side: isConnected ? const BorderSide(color: Colors.white, width: 1.5) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
