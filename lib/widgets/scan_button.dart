import 'package:flutter/material.dart';

class ScanButton extends StatelessWidget {
  final bool isConnected;
  final bool isScanning;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const ScanButton({
    super.key,
    required this.isConnected,
    required this.isScanning,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: !isConnected
              ? null
              : (isScanning ? onStop : onStart),
          icon: Icon(isScanning ? Icons.stop : Icons.radar),
          label: Text(
            isScanning ? 'STOP SCANNING' : 'START SCANNING',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isScanning ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}