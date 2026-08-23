import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rfid_tag.dart';
import '../models/scan_sessions.dart';
import '../services/api_service.dart';
import '../services/rfid_service.dart';
import '../services/scan_storage_service.dart';
import '../widgets/scan_button.dart';
import '../widgets/status_card.dart';
import '../widgets/tags_list.dart';

class RFIDScannerPage extends StatefulWidget {
  const RFIDScannerPage({super.key});

  @override
  State<RFIDScannerPage> createState() => _RFIDScannerPageState();
}

class _RFIDScannerPageState extends State<RFIDScannerPage>
    with SingleTickerProviderStateMixin {
  final RFIDService _rfidService = RFIDService();
  final ScanStorageService _storage = ScanStorageService();

  String _connectionStatus = 'Disconnected';
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isUploading = false;
  final List<RFIDTag> _scannedTags = [];
  final Map<String, RFIDTag> _tagMap = {};
  final ApiService _apiService = ApiService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rfidService.requestPermissions();
    _listenToEvents();


    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _listenToEvents() {
    _rfidService.getEventStream().listen(
      (event) {
        if (event is Map) {
          if (event.containsKey('tag')) {
            _handleTagData(event['tag']);
          } else if (event.containsKey('status')) {
            setState(() {
              _connectionStatus = event['status'];
              if (event['status'].toString().contains('Scanning started') ||
                  event['status'].toString().contains('trigger pressed')) {
                _isScanning = true;
              } else if (event['status'].toString().contains(
                    'Scanning stopped',
                  ) ||
                  event['status'].toString().contains('trigger released')) {
                _isScanning = false;
              }
            });
          } else if (event.containsKey('error')) {
            _showSnackBar(event['error'], isError: true);
          }
        }
      },
      onError: (error) {
        _showSnackBar('Event stream error: $error', isError: true);
      },
    );
  }

  void _handleTagData(dynamic tagData) {
    if (tagData is Map) {
      final epc = tagData['epc'] ?? '';
      if (epc.isEmpty) return;

      final tid = tagData['tid'] ?? '';
      final rssi = tagData['rssi']?.toString() ?? '';

      setState(() {
        if (_tagMap.containsKey(epc)) {
          // no duplicate tag
          _tagMap[epc]!.count++;
          if (tid.isNotEmpty) _tagMap[epc]!.tid = tid;
          if (rssi.isNotEmpty) _tagMap[epc]!.rssi = rssi;
        } else {
          final tag = RFIDTag(
            epc: epc,
            tid: tid,
            user: tagData['user'] ?? '',
            rssi: rssi,
            antenna: tagData['antenna']?.toString() ?? '',
          );
          _tagMap[epc] = tag;
          _scannedTags.add(tag);
        }
      });
    }
  }

  Future<void> _initializeReader() async {
    try {
      await _rfidService.initializeReader();
      _showSnackBar('Reader initialized');
    } on PlatformException catch (e) {
      _showSnackBar('Failed to initialize: ${e.message}', isError: true);
    }
  }

  Future<void> _connectReader() async {
    try {
      setState(() => _connectionStatus = 'Connecting...');
      final result = await _rfidService.connectReader();
      setState(() {
        _connectionStatus = result;
        _isConnected = result.toString().contains('successfully');
      });
      _showSnackBar(result);
    } on PlatformException catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed';
        _isConnected = false;
      });
      _showSnackBar('Failed to connect: ${e.message}', isError: true);
    }
  }

  Future<void> _disconnectReader() async {
    try {
      await _rfidService.disconnectReader();
      setState(() {
        _isConnected = false;
        _isScanning = false;
        _connectionStatus = 'Disconnected';
      });
      _showSnackBar('Reader disconnected');
    } on PlatformException catch (e) {
      _showSnackBar('Failed to disconnect: ${e.message}', isError: true);
    }
  }

  Future<void> _startScanning() async {
    try {
      await _rfidService.startInventory();
      setState(() => _isScanning = true);
    } on PlatformException catch (e) {
      _showSnackBar('Failed to start scanning: ${e.message}', isError: true);
    }
  }

  Future<void> _stopScanning() async {
    try {
      await _rfidService.stopInventory();
      setState(() => _isScanning = false);
    } on PlatformException catch (e) {
      _showSnackBar('Failed to stop scanning: ${e.message}', isError: true);
    }
  }

  Future<void> _uploadTags() async {
    if (_scannedTags.isEmpty) {
      _showSnackBar('No tags to upload', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _apiService.uploadScannedTags(_scannedTags, isOffline: false);
      _showSnackBar('Successfully uploaded ${_scannedTags.length} tags to the server!');
      _clearTags(); 
    } catch (e) {
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _clearTags() {
    setState(() {
      _scannedTags.clear();
      _tagMap.clear();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
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

  //  Session save flow -
  Future<String?> _promptJobNo() {
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

  Future<void> _finishAndSave() async {
    if (_scannedTags.isEmpty) {
      _showSnackBar('No tags scanned yet', isError: true);
      return;
    }

    final jobNo = await _promptJobNo();
    if (jobNo == null || jobNo.trim().isEmpty) return;

    if (_isScanning) await _stopScanning();

    final session = ScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scanDate: DateTime.now(),
      jobNo: jobNo.trim(),
      tags: List.of(_scannedTags),
    );

    await _storage.saveSession(session);
    _showSnackBar(
      'Saved ${_scannedTags.length} tags under Job ${jobNo.trim()}',
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.inversePrimary,
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, size: 22),
            SizedBox(width: 8),
          ],
        ),
        actions: [
          if (_scannedTags.isNotEmpty) ...[

            _isUploading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: Colors.red),
                    ),
                  )
                : IconButton(
                    onPressed: _uploadTags,
                    icon: const Icon(Icons.cloud_upload),
                    tooltip: 'Upload to server..',
                  ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _finishAndSave,
              tooltip: 'Finish & Save',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearTags,
              tooltip: 'Clear tags',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          StatusCard(
            connectionStatus: _connectionStatus,
            isConnected: _isConnected,
            onInitialize: _initializeReader,
            onConnect: _connectReader,
            onDisconnect: _disconnectReader,
          ),

          ScanButton(
            isConnected: _isConnected,
            isScanning: _isScanning,
            onStart: _startScanning,
            onStop: _stopScanning,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _scannedTags.isEmpty
                      ? 'No tags scanned'
                      : '${_scannedTags.length} tag${_scannedTags.length == 1 ? '' : 's'} scanned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const Spacer(),
                if (_isScanning) ...[
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scanning...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: TagsList(
              tags: _scannedTags,
              onTagTap:
                  (
                    _,
                  ) {}, 
            ),
          ),
        ],
      ),
    );
  }
}
