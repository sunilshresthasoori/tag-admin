import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_event.dart';
import '../blocs/rfid_scanner/rfid_scanner_state.dart';
import '../services/api_service.dart';
import '../services/rfid_service.dart';
import '../services/scan_storage_service.dart';
import '../widgets/scan_button.dart';
import '../widgets/status_card.dart';
import '../widgets/tags_list.dart';
import 'scan_sessions_list_page.dart';

class RFIDScannerPage extends StatelessWidget {
  const RFIDScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RFIDScannerBloc(
        rfidService: context.read<RFIDService>(),
        storage: context.read<ScanStorageService>(),
        apiService: context.read<ApiService>(),
      )..add(InitializeReader()),
      child: const RFIDScannerView(),
    );
  }
}

class _BarcodeStatusCard extends StatelessWidget {
  final String? packetNumber;
  final bool isScanned;
  final bool isChecking;
  final bool? isValid;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _BarcodeStatusCard({
    required this.packetNumber,
    required this.isScanned,
    this.isChecking = false,
    this.isValid,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color borderColor;
    if (isScanned) {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      borderColor = colorScheme.outlineVariant;
    }

    return GestureDetector(
      onTap: !isScanned ? onTap : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isScanned ? Colors.green.shade100 : colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isScanned ? Icons.inventory_2 : Icons.barcode_reader,
                color: isScanned ? Colors.green.shade700 : colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isScanned ? 'Box Scanned' : 'Awaiting Box Scan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isScanned ? Colors.green.shade800 : colorScheme.outline,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isScanned ? packetNumber! : 'Scan barcode or tap to enter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isScanned ? Colors.black87 : colorScheme.onSurfaceVariant,
                      fontFamily: isScanned ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
            ),
            if (!isScanned)
              Icon(
                Icons.keyboard,
                size: 20,
                color: colorScheme.primary.withValues(alpha: 0.5),
              )
            else
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                onPressed: onDelete,
                tooltip: 'Remove barcode',
              ),
          ],
        ),
      ),
    );
  }
}

class RFIDScannerView extends StatefulWidget {
  const RFIDScannerView({super.key});

  @override
  State<RFIDScannerView> createState() => _RFIDScannerViewState();
}

class _RFIDScannerViewState extends State<RFIDScannerView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String?> _promptJobNo(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Job No'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. JOB-1042'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptPacketCode(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Packet Code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. PKT-001',
            labelText: 'Packet Code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<RFIDScannerBloc>();

    return BlocListener<RFIDScannerBloc, RFIDScannerState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          _showSnackBar(context, state.errorMessage!, isError: true);
        }
        if (state.successMessage != null) {
          _showSnackBar(context, state.successMessage!);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          title: BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
            buildWhen: (p, c) => p.isConnected != c.isConnected,
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Tag Admin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  if (state.isConnected)
                    Text(
                      'Ready to scan',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              );
            },
          ),
          actions: [
            BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
              builder: (context, state) {
                if (state.scannedTags.isEmpty) return const SizedBox.shrink();
                return Row(
                  children: [
                    state.isUploading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : IconButton.filledTonal(
                            onPressed: () => bloc.add(UploadTags()),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            tooltip: 'Upload',
                          ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: () async {
                        final jobNo = await _promptJobNo(context);
                        if (jobNo != null && jobNo.trim().isNotEmpty) {
                          bloc.add(SaveSession(jobNo.trim()));
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        }
                      },
                      tooltip: 'Save Session',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: () => bloc.add(ClearTags()),
                      tooltip: 'Clear',
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
              buildWhen: (p, c) =>
                  p.packetNumber != c.packetNumber ||
                  p.isBarcodeScanned != c.isBarcodeScanned ||
                  p.isCheckingPacket != c.isCheckingPacket ||
                  p.isValidPacket != c.isValidPacket,
              builder: (context, state) {
                return _BarcodeStatusCard(
                  packetNumber: state.packetNumber,
                  isScanned: state.isBarcodeScanned,
                  isChecking: state.isCheckingPacket,
                  isValid: state.isValidPacket,
                  onDelete: () => bloc.add(ClearBarcode()),
                  onTap: () async {
                    final code = await _promptPacketCode(context);
                    if (code != null && code.trim().isNotEmpty) {
                      bloc.add(BarcodeReceived(code.trim()));
                    }
                  },
                );
              },
            ),
            BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
              buildWhen: (p, c) =>
                  p.connectionStatus != c.connectionStatus ||
                  p.isConnected != c.isConnected,
              builder: (context, state) {
                return StatusCard(
                  connectionStatus: state.connectionStatus,
                  isConnected: state.isConnected,
                  onInitialize: () => bloc.add(InitializeReader()),
                  onConnect: () => bloc.add(ConnectReader()),
                  onDisconnect: () => bloc.add(DisconnectReader()),
                );
              },
            ),
            BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
              buildWhen: (p, c) =>
                  p.isConnected != c.isConnected ||
                  p.isScanning != c.isScanning ||
                  p.isBarcodeScanned != c.isBarcodeScanned ||
                  p.isValidPacket != c.isValidPacket,
              builder: (context, state) {
                return ScanButton(
                  isConnected: state.isConnected && 
                               state.isBarcodeScanned && 
                               state.isValidPacket == true,
                  isScanning: state.isScanning,
                  onStart: () => bloc.add(StartScanning()),
                  onStop: () => bloc.add(StopScanning()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Text(
                    'SCANNED TAGS',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
                    buildWhen: (p, c) => p.scannedTags.length != c.scannedTags.length,
                    builder: (context, state) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          state.scannedTags.length.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanSessionsListPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
                    buildWhen: (p, c) => p.isScanning != c.isScanning,
                    builder: (context, state) {
                      if (!state.isScanning) return const SizedBox.shrink();
                      return FadeTransition(
                        opacity: _pulseAnimation,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SCANNING...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
                buildWhen: (p, c) => p.scannedTags != c.scannedTags,
                builder: (context, state) {
                  return TagsList(
                    tags: state.scannedTags,
                    onTagTap: (tag) {
                      // Potential navigation to details
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

