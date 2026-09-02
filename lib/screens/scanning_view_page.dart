import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_event.dart';
import '../blocs/rfid_scanner/rfid_scanner_state.dart';
import '../models/rfid_tag.dart';
import '../widgets/tags_list.dart';

class ScanningViewPage extends StatelessWidget {
  const ScanningViewPage({super.key});

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

  void _showIssuesDialog(
    BuildContext context, {
    List<TIDConflict> tidConflicts = const [],
    List<InvalidEPC> invalidEpcs = const [],
    List<SkippedTag> skippedTags = const [],
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text('Upload Issues Detected'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tidConflicts.isNotEmpty) ...[
                  Text(
                    'TID Conflicts (${tidConflicts.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ...tidConflicts.map((c) => _buildIssueItem(c.epcHex, c.tid)),
                  const SizedBox(height: 16),
                ],
                if (invalidEpcs.isNotEmpty) ...[
                  Text(
                    'Invalid EPCs (${invalidEpcs.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  ...invalidEpcs.map((c) => _buildIssueItem(c.epcHex, c.tid)),
                  const SizedBox(height: 16),
                ],
                if (skippedTags.isNotEmpty) ...[
                  Text(
                    'Skipped (Packet Limit) (${skippedTags.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  ...skippedTags.map((c) => _buildIssueItem(c.epcHex, c.tid)),
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

  Widget _buildIssueItem(String epc, String tid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EPC: $epc',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'TID: $tid',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
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
          ((previous.tidConflicts != current.tidConflicts ||
                  previous.invalidEpcs != current.invalidEpcs ||
                  previous.skippedTags != current.skippedTags) &&
              (current.tidConflicts.isNotEmpty ||
                  current.invalidEpcs.isNotEmpty ||
                  current.skippedTags.isNotEmpty)) ||
          (previous.errorMessage != current.errorMessage &&
              current.errorMessage != null),
      listener: (context, state) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (!isCurrent) return;

        if (state.tidConflicts.isNotEmpty ||
            state.invalidEpcs.isNotEmpty ||
            state.skippedTags.isNotEmpty) {
          _showIssuesDialog(
            context,
            tidConflicts: state.tidConflicts,
            invalidEpcs: state.invalidEpcs,
            skippedTags: state.skippedTags,
          );
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      child: BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
        builder: (context, state) {
        final duplicateTags = state.scannedTags
            .where((t) => t.epcCollision)
            .toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.packetNumber ?? 'No Packet',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Packet Number',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.outline,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              bottom: TabBar(
                tabs: [
                  const Tab(text: 'All Tags'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Duplicate EPCs'),
                        if (duplicateTags.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              duplicateTags.length.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (state.scannedTags.isNotEmpty) ...[
                  if (state.isUploading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.cloud_upload_outlined,
                        color: state.scannedTags.length != 50
                            ? Colors.grey
                            : Colors.blue,
                        size: 28,
                      ),
                      onPressed: state.scannedTags.length != 50
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    state.scannedTags.length < 50
                                        ? 'Need ${50 - state.scannedTags.length} more tags to upload'
                                        : 'Excess tags! Remove ${state.scannedTags.length - 50} tags to upload',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : () => bloc.add(UploadTags()),
                      tooltip: 'Send to Server',
                    ),
                  IconButton(
                    icon: const Icon(Icons.save_outlined, size: 28),
                    onPressed: () async {
                      final jobNo = await _promptJobNo(context);
                      if (jobNo != null && jobNo.trim().isNotEmpty) {
                        bloc.add(SaveSession(jobNo.trim()));
                        if (!context.mounted) return;
                        Navigator.pop(context); // Go back after saving
                      }
                    },
                    tooltip: 'Save Locally',
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: state.scannedTags.length == 50
                            ? Colors.green.shade700
                            : (state.scannedTags.length > 50
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.scannedTags.length.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                if (duplicateTags.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${duplicateTags.length} duplicate EPC(s) detected',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (state.isScanning)
                  LinearProgressIndicator(
                    backgroundColor: colorScheme.primaryContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      TagsList(
                        tags: state.scannedTags,
                        onTagTap: (tag) {
                          // Detail view if needed
                        },
                      ),
                      TagsList(
                        tags: duplicateTags,
                        onTagTap: (tag) {
                          // Detail view if needed
                        },
                      ),
                    ],
                  ),
                ),
                if (state.isScanning)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () => bloc.add(StopScanning()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.stop),
                        label: const Text(
                          'STOP SCANNING',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}
