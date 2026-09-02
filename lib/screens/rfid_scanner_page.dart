import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_event.dart';
import '../blocs/rfid_scanner/rfid_scanner_state.dart';
import '../models/rfid_tag.dart';
import '../services/api_service.dart';
import '../services/rfid_service.dart';
import '../services/scan_storage_service.dart';
import '../widgets/scan_button.dart';
import '../widgets/status_card.dart';
import '../widgets/tags_list.dart';
import 'dispatch_tags_page.dart';
import 'scan_sessions_list_page.dart';
import 'scanning_view_page.dart';

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
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      );
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
          border: Border.all(color: borderColor, width: 1),
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
                      color: isScanned
                          ? Colors.green.shade800
                          : colorScheme.outline,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isScanned ? packetNumber! : 'Scan barcode or tap to enter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isScanned
                          ? Colors.black87
                          : colorScheme.onSurfaceVariant,
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

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
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
        duration: const Duration(seconds: 1),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 8,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                prefixText: 'PKT',
                hintText: '00000001',
                labelText: 'Packet ID',
                helperText: 'Enter the 8 characters after PKT',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, 'PKT$value');
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog(
    BuildContext context,
    List<TIDConflict> conflicts,
    List<InvalidEPC> invalidEpcs,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Upload Issues Detected',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (conflicts.isNotEmpty) ...[
                  Text(
                    'TID Conflicts (${conflicts.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...conflicts.map(
                    (conflict) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EPC: ${conflict.epcHex}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'TID: ${conflict.tid}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (invalidEpcs.isNotEmpty) ...[
                  Text(
                    'Invalid EPCs (${invalidEpcs.length}):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...invalidEpcs.map(
                    (invalid) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EPC: ${invalid.epcHex}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'TID: ${invalid.tid}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<RFIDScannerBloc>().add(ClearConflicts());
              Navigator.pop(context);
            },
            child: const Text('DISMISS'),
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
      listenWhen: (previous, current) =>
          (previous.errorMessage != current.errorMessage &&
              current.errorMessage != null) ||
          (previous.successMessage != current.successMessage &&
              current.successMessage != null) ||
          (previous.tidConflicts != current.tidConflicts &&
              current.tidConflicts.isNotEmpty) ||
          (previous.invalidEpcs != current.invalidEpcs &&
              current.invalidEpcs.isNotEmpty) ||
          (!previous.isScanning && current.isScanning),
      listener: (context, state) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;

        if (state.tidConflicts.isNotEmpty || state.invalidEpcs.isNotEmpty) {
          if (isCurrent) {
            _showConflictDialog(context, state.tidConflicts, state.invalidEpcs);
          }
        }
        if (state.errorMessage != null &&
            state.tidConflicts.isEmpty &&
            state.invalidEpcs.isEmpty) {
          if (isCurrent) {
            _showSnackBar(context, state.errorMessage!, isError: true);
          }
        }
        if (state.successMessage != null) {
          if (isCurrent) {
            _showSnackBar(context, state.successMessage!);
          }
        }
        if (state.isScanning) {
          // Only push if we are currently on this page to avoid duplicates
          if (isCurrent) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: bloc,
                  child: const ScanningViewPage(),
                ),
              ),
            );
          }
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
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DispatchTagsPage()),
                );
              },
              tooltip: 'Dispatch Tags',
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScanSessionsListPage()),
                );
              },
              tooltip: 'Saved Sessions',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<AuthBloc>().add(LogoutRequested());
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Logout',
            ),
            BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
              builder: (context, state) {
                if (state.scannedTags.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    state.isUploading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : IconButton.filledTonal(
                            onPressed: state.scannedTags.length != 50
                                ? () {
                                    _showSnackBar(
                                      context,
                                      state.scannedTags.length < 50
                                          ? 'Need ${50 - state.scannedTags.length} more tags'
                                          : 'Remove ${state.scannedTags.length - 50} tags',
                                      isError: true,
                                    );
                                  }
                                : () => bloc.add(UploadTags()),
                            icon: Icon(
                              Icons.cloud_upload_outlined,
                              color: state.scannedTags.length == 50
                                  ? null
                                  : Colors.grey,
                            ),
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
                  isConnected:
                      state.isConnected &&
                      state.isBarcodeScanned &&
                      state.isValidPacket == true,
                  isScanning: state.isScanning,
                  onStart: () => bloc.add(StartScanning()),
                  onStop: () => bloc.add(StopScanning()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              // Reduced horizontal padding
              child: Row(
                children: [
                  Text(
                    'TAGS', // Shortened from 'SCANNED TAGS'
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 6),
                  BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
                    buildWhen: (p, c) =>
                        p.scannedTags.length != c.scannedTags.length,
                    builder: (context, state) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: state.scannedTags.length == 50
                              ? Colors.green.shade600
                              : (state.scannedTags.length > 50
                                    ? Colors.red.shade600
                                    : colorScheme.primaryContainer),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.scannedTags.length.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: state.scannedTags.length >= 50
                                ? Colors.white
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
                    buildWhen: (p, c) => p.isScanning != c.isScanning,
                    builder: (context, state) {
                      if (!state.isScanning) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: bloc,
                                    child: const ScanningViewPage(),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text(
                              'RESUME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          FadeTransition(
                            opacity: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
