import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_bloc.dart';
import '../blocs/rfid_scanner/rfid_scanner_event.dart';
import '../blocs/rfid_scanner/rfid_scanner_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<RFIDScannerBloc>();

    return BlocBuilder<RFIDScannerBloc, RFIDScannerState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.packetNumber ?? 'No Packet',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Packet Number',
                  style: TextStyle(fontSize: 10, color: colorScheme.outline, fontWeight: FontWeight.normal),
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
                      color: state.scannedTags.length != 50 ? Colors.grey : Colors.blue,
                      size: 28,
                    ),
                    onPressed: state.scannedTags.length != 50
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.scannedTags.length < 50 
                                    ? 'Need ${50 - state.scannedTags.length} more tags to upload'
                                    : 'Excess tags! Remove ${state.scannedTags.length - 50} tags to upload'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: state.scannedTags.length == 50 
                          ? Colors.green.shade700 
                          : (state.scannedTags.length > 50 ? Colors.red.shade700 : Colors.blue.shade700),
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
              if (state.isScanning)
                LinearProgressIndicator(
                  backgroundColor: colorScheme.primaryContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              Expanded(
                child: TagsList(
                  tags: state.scannedTags,
                  onTagTap: (tag) {
                    // Detail view if needed
                  },
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
        );
      },
    );
  }
}
