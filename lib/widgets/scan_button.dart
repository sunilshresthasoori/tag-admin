import 'package:flutter/material.dart';

class ScanButton extends StatefulWidget {
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
  State<ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<ScanButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            onPressed: !widget.isConnected ? null : (widget.isScanning ? widget.onStop : widget.onStart),
            icon: Icon(
              widget.isScanning ? Icons.stop_circle : Icons.sensors,
              size: 28,
            ),
            label: Text(
              widget.isScanning ? 'STOP SCANNING' : 'START INVENTORY',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: widget.isScanning ? Colors.orange.shade800 : colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: widget.isScanning ? 8 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
