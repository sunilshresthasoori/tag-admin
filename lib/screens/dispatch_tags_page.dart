import 'package:flutter/material.dart';
 import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dispatch_tags/dispatch_tags_bloc.dart';
import '../blocs/dispatch_tags/dispatch_tags_event.dart';
import '../blocs/dispatch_tags/dispatch_tags_state.dart';
import '../services/api_service.dart';
import '../services/rfid_service.dart';

class DispatchTagsPage extends StatelessWidget {
  const DispatchTagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DispatchTagsBloc(
        rfidService: context.read<RFIDService>(),
        apiService: context.read<ApiService>(),
      ),
      child: const DispatchTagsView(),
    );
  }
}

class DispatchTagsView extends StatefulWidget {
  const DispatchTagsView({super.key});

  @override
  State<DispatchTagsView> createState() => _DispatchTagsViewState();
}

class _DispatchTagsViewState extends State<DispatchTagsView> {
  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: isError ? 3000 : 700),
      ),
    );
  }

  Future<void> _showManualEntryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final bloc = context.read<DispatchTagsBloc>();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Barcode Manually'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter barcode (e.g. PKT00000A12)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                bloc.add(AddBarcodeManually(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bloc = context.read<DispatchTagsBloc>();

    return BlocListener<DispatchTagsBloc, DispatchTagsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          _showSnackBar(context, state.errorMessage!, isError: true);
          bloc.add(ClearMessages());
        }
        if (state.successMessage != null) {
          _showSnackBar(context, state.successMessage!);
          bloc.add(ClearMessages());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dispatch Tags'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => bloc.add(ClearBarcodes()),
              tooltip: 'Clear All',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: BlocBuilder<DispatchTagsBloc, DispatchTagsState>(
                builder: (context, state) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (state.isScanning) {
                                  bloc.add(StopBarcodeScanning());
                                } else {
                                  bloc.add(StartBarcodeScanning());
                                }
                              },
                              icon: Icon(state.isScanning ? Icons.stop : Icons.barcode_reader),
                              label: Text(state.isScanning ? 'Stop Scanning' : 'Start Scanning'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: state.isScanning ? Colors.red.shade100 : colorScheme.primaryContainer,
                                foregroundColor: state.isScanning ? Colors.red.shade900 : colorScheme.onPrimaryContainer,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => _showManualEntryDialog(context),
                            icon: const Icon(Icons.add),
                            padding: const EdgeInsets.all(16),
                          ),
                        ],
                      ),
                      if (state.isScanning)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Scanner active. Use hardware trigger or scan barcode.',
                            style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            Expanded(
              child: BlocBuilder<DispatchTagsBloc, DispatchTagsState>(
                builder: (context, state) {
                  if (state.barcodes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.barcode_reader, size: 64, color: colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          const Text('No barcodes scanned yet'),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: state.barcodes.length,
                    itemBuilder: (context, index) {
                      final barcode = state.barcodes[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2),
                        title: Text(barcode, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => bloc.add(RemoveBarcode(barcode)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: BlocBuilder<DispatchTagsBloc, DispatchTagsState>(
                builder: (context, state) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total Items: ${state.barcodes.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: state.barcodes.isEmpty || state.isDispatching
                            ? null
                            : () => bloc.add(DispatchBarcodes()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: state.isDispatching
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Dispatch Tags'),
                      ),
                    ],
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
