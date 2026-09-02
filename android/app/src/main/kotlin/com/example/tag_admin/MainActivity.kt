package com.example.tag_admin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.AsyncTask
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.zebra.rfid.api3.*

class MainActivity : FlutterActivity(), RfidEventsListener {
    private val CHANNEL = "rfid_scanner_channel"
    private val EVENT_CHANNEL = "rfid_scanner_events"
    private val TAG = "RFIDScanner"

    // Zebra DataWedge constants
    private val BARCODE_ACTION = "com.example.tag_admin.BARCODE_ACTION"
    private val DATAWEDGE_DATA_STRING = "com.symbol.datawedge.data_string"

    private var readers: Readers? = null
    private var availableRFIDReaderList: ArrayList<ReaderDevice>? = null
    private var readerDevice: ReaderDevice? = null
    private var reader: RFIDReader? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isUsingAccessSequence = false
    private var isReceiverRegistered = false

    private val barcodeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BARCODE_ACTION) {
                val barcode = intent.getStringExtra(DATAWEDGE_DATA_STRING) ?: ""
                if (barcode.isNotEmpty()) {
                    Log.d(TAG, "Barcode received from DataWedge: $barcode")
                    sendEvent(mapOf("barcode" to barcode))
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (!isReceiverRegistered) {
            Log.d(TAG, "Registering barcode receiver")
            val filter = IntentFilter(BARCODE_ACTION)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(barcodeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(barcodeReceiver, filter)
            }
            isReceiverRegistered = true
        }
    }

    override fun onPause() {
        super.onPause()
        if (isReceiverRegistered) {
            Log.d(TAG, "Unregistering barcode receiver")
            unregisterReceiver(barcodeReceiver)
            isReceiverRegistered = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeReader" -> {
                    initializeReader()
                    result.success("Reader initialization started")
                }
                "connectReader" -> {
                    connectReader(result)
                }
                "disconnectReader" -> {
                    disconnectReader()
                    result.success("Reader disconnected")
                }
                "startInventory" -> {
                    startInventory(result)
                }
                "stopInventory" -> {
                    stopInventory(result)
                }
                "getReaderStatus" -> {
                    val status = if (reader?.isConnected == true) "connected" else "disconnected"
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "EventChannel: Flutter is listening")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "EventChannel: Flutter cancelled listener")
                    eventSink = null
                }
            }
        )
    }

    private fun initializeReader() {
        try {
            if (readers == null) {
                readers = Readers(applicationContext, ENUM_TRANSPORT.ALL)
            }
        } catch (e: InvalidUsageException) {
            Log.e(TAG, "Error initializing readers: ${e.message}")
            sendEvent(mapOf("error" to "Failed to initialize: ${e.message}"))
        }
    }

    private fun connectReader(result: MethodChannel.Result) {
        ConnectTask(result).execute()
    }

    inner class ConnectTask(private val result: MethodChannel.Result) : AsyncTask<Void, Void, String>() {
        override fun doInBackground(vararg params: Void?): String {
            return try {
                if (readers == null) {
                    initializeReader()
                }

                availableRFIDReaderList = readers?.GetAvailableRFIDReaderList()

                if (availableRFIDReaderList == null || availableRFIDReaderList!!.isEmpty()) {
                    return "No readers available"
                }

                readerDevice = availableRFIDReaderList!![0]
                reader = readerDevice?.rfidReader

                reader?.connect()

                if (reader?.isConnected == true) {
                    configureReader()
                    "Reader connected successfully"
                } else {
                    "Failed to connect to reader"
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error connecting reader: ${e.message}")
                "Error: ${e.message}"
            }
        }

        override fun onPostExecute(resultMessage: String) {
            result.success(resultMessage)
            sendEvent(mapOf("status" to resultMessage))
        }
    }

    private fun configureReader() {
        try {
            Log.d(TAG, "===== CONFIGURING READER =====")

            reader?.Events?.addEventsListener(this)
            Log.d(TAG, "Event listener added")

            reader?.Events?.setTagReadEvent(true)
            Log.d(TAG, "Tag read event enabled")

            reader?.Events?.setAttachTagDataWithReadEvent(true)
            Log.d(TAG, "Attach tag data with read event enabled")

            reader?.Events?.setHandheldEvent(true)
            Log.d(TAG, "Handheld trigger event enabled")

            reader?.Events?.setInventoryStartEvent(true)
            reader?.Events?.setInventoryStopEvent(true)
            Log.d(TAG, "Inventory events enabled")

            // Configure tag storage settings to include all fields
            try {
                val tagStorageSettings = reader?.Config?.getTagStorageSettings()
                tagStorageSettings?.setTagFields(TAG_FIELD.ALL_TAG_FIELDS)
                reader?.Config?.setTagStorageSettings(tagStorageSettings)
                Log.d(TAG, "Tag storage settings configured for all fields")
            } catch (e: Exception) {
                Log.e(TAG, "Error configuring tag storage: ${e.message}")
            }

            // DEBUG: LOG POWER CAPABILITIES
            val powerLevels = reader?.ReaderCapabilities?.transmitPowerLevelValues
            val maxIndex = if (powerLevels != null) powerLevels.size - 1 else 30
            
            if (powerLevels != null) {
                Log.d(TAG, "Available Power Levels (dBm * 100): ${powerLevels.joinToString(", ")}")
                Log.d(TAG, "Max Power Index: $maxIndex (${powerLevels.last() / 100.0} dBm)")
            }

            // Configure antenna settings
            val antennaConfig = reader?.Config?.Antennas?.getAntennaRfConfig(1)
            antennaConfig?.setrfModeTableIndex(0)
            
            // SETTING RANGE HERE: Reducing power index by 30 units (~3dBm reduction) from maximum
            val targetPowerIndex = if (maxIndex > 30) maxIndex - 30 else 0
            antennaConfig?.transmitPowerIndex = targetPowerIndex
            
            reader?.Config?.Antennas?.setAntennaRfConfig(1, antennaConfig)
            
            val actualDbm = if (powerLevels != null && targetPowerIndex < powerLevels.size) powerLevels[targetPowerIndex] / 100.0 else "unknown"
            Log.d(TAG, "===== POWER CONFIGURED: Index $targetPowerIndex ($actualDbm dBm) =====")

            reader?.Config?.setTriggerMode(ENUM_TRIGGER_MODE.RFID_MODE, true)
            Log.d(TAG, "Trigger mode set to RFID_MODE")

            val triggerInfo = TriggerInfo()
            triggerInfo.StartTrigger.triggerType = START_TRIGGER_TYPE.START_TRIGGER_TYPE_IMMEDIATE
            triggerInfo.StopTrigger.triggerType = STOP_TRIGGER_TYPE.STOP_TRIGGER_TYPE_IMMEDIATE
            reader?.Config?.startTrigger = triggerInfo.StartTrigger
            reader?.Config?.stopTrigger = triggerInfo.StopTrigger
            Log.d(TAG, "Trigger info configured")

            Log.d(TAG, "===== READER CONFIGURED SUCCESSFULLY =====")
            sendEvent(mapOf("status" to "Reader configured at $actualDbm dBm"))

        } catch (e: Exception) {
            Log.e(TAG, "Error configuring reader: ${e.message}")
            e.printStackTrace()
            sendEvent(mapOf("error" to "Configuration failed: ${e.message}"))
        }
    }

    private fun startInventory(result: MethodChannel.Result) {
        try {
            if (reader?.isConnected == true) {
                // Use Access Sequence to read TID and User memory
                configureAccessSequence()
                reader?.Actions?.TagAccess?.OperationSequence?.performSequence()
                isUsingAccessSequence = true
                result.success("Inventory started with TID/User reading")
                sendEvent(mapOf("status" to "Scanning started"))
            } else {
                result.error("NOT_CONNECTED", "Reader not connected", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting inventory: ${e.message}")
            result.error("INVENTORY_ERROR", e.message, null)
        }
    }

    private fun configureAccessSequence() {
        try {
            Log.d(TAG, "Configuring Access Sequence for TID and User memory reading")

            // Clear any existing operations
            reader?.Actions?.TagAccess?.OperationSequence?.deleteAll()

            val tagAccess = TagAccess()
            val sequence = tagAccess.Sequence(tagAccess)

            // Add operation to read TID memory bank
            val tidOperation = sequence.Operation()
            tidOperation.accessOperationCode = ACCESS_OPERATION_CODE.ACCESS_OPERATION_READ
            tidOperation.ReadAccessParams.memoryBank = MEMORY_BANK.MEMORY_BANK_TID
            tidOperation.ReadAccessParams.offset = 0
            tidOperation.ReadAccessParams.count = 6 // 6 words = 12 bytes of TID
            tidOperation.ReadAccessParams.accessPassword = 0
            reader?.Actions?.TagAccess?.OperationSequence?.add(tidOperation)
            Log.d(TAG, "TID read operation added to sequence")

            // Add operation to read User memory bank
            val userOperation = sequence.Operation()
            userOperation.accessOperationCode = ACCESS_OPERATION_CODE.ACCESS_OPERATION_READ
            userOperation.ReadAccessParams.memoryBank = MEMORY_BANK.MEMORY_BANK_USER
            userOperation.ReadAccessParams.offset = 0
            userOperation.ReadAccessParams.count = 8 // 8 words = 16 bytes of User memory
            userOperation.ReadAccessParams.accessPassword = 0
            reader?.Actions?.TagAccess?.OperationSequence?.add(userOperation)
            Log.d(TAG, "User memory read operation added to sequence")

            Log.d(TAG, "Access Sequence configured successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error configuring access sequence: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun stopInventory(result: MethodChannel.Result) {
        try {
            if (reader?.isConnected == true) {
                if (isUsingAccessSequence) {
                    reader?.Actions?.TagAccess?.OperationSequence?.stopSequence()
                    isUsingAccessSequence = false
                } else {
                    reader?.Actions?.Inventory?.stop()
                }
                result.success("Inventory stopped")
                sendEvent(mapOf("status" to "Scanning stopped"))
            } else {
                result.error("NOT_CONNECTED", "Reader not connected", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping inventory: ${e.message}")
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun disconnectReader() {
        try {
            if (reader?.isConnected == true) {
                reader?.Events?.removeEventsListener(this)
                reader?.disconnect()
            }
            sendEvent(mapOf("status" to "Reader disconnected"))
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting reader: ${e.message}")
        }
    }

    override fun eventReadNotify(readEventData: RfidReadEvents?) {
        try {
            Log.d(TAG, "=== eventReadNotify CALLED ===")

            if (readEventData == null) {
                Log.w(TAG, "readEventData is NULL")
                return
            }

            val readEventDataObj = readEventData.readEventData
            if (readEventDataObj == null) {
                Log.w(TAG, "readEventDataObj is NULL")
                return
            }

            val tagDataObj = readEventDataObj.tagData
            if (tagDataObj == null) {
                Log.w(TAG, "tagData is NULL")
                return
            }

            Log.d(TAG, "tagData type: ${tagDataObj.javaClass.name}")
            Log.d(TAG, "tagData isArray: ${tagDataObj.javaClass.isArray}")

            when {
                tagDataObj is TagData -> {
                    Log.d(TAG, "Processing single TagData object")
                    processTag(tagDataObj)
                }
                tagDataObj.javaClass.isArray -> {
                    val length = java.lang.reflect.Array.getLength(tagDataObj)
                    Log.d(TAG, "Processing TagData array with $length items")

                    for (i in 0 until length) {
                        val tag = java.lang.reflect.Array.get(tagDataObj, i)
                        if (tag is TagData) {
                            processTag(tag)
                        }
                    }
                }
                else -> {
                    Log.w(TAG, "Unknown tagData type: ${tagDataObj.javaClass.name}")
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "EXCEPTION in eventReadNotify: ${e.message}")
            e.printStackTrace()
        }
    }

    // Map to store tag data temporarily as we receive TID and User memory separately
    private val tagDataMap = mutableMapOf<String, MutableMap<String, String>>()
    private val tagReadCount = mutableMapOf<String, Int>() // Track how many reads completed per tag
    private val epcToTids = mutableMapOf<String, MutableSet<String>>() // Track distinct TIDs for each EPC

    private fun processTag(tagData: TagData) {
        try {
            val epc = tagData.tagID ?: ""
            val opCode = tagData.opCode
            val opStatus = tagData.opStatus

            Log.d(TAG, "Processing Tag - EPC: $epc")
            Log.d(TAG, "OpCode: $opCode, OpStatus: $opStatus")

            // Initialize tag data if not exists
            if (!tagDataMap.containsKey(epc)) {
                tagDataMap[epc] = mutableMapOf(
                    "epc" to epc,
                    "tid" to "",
                    "user" to "",
                    "rssi" to (tagData.peakRSSI?.toString() ?: ""),
                    "count" to (tagData.tagSeenCount?.toString() ?: "1"),
                    "antenna" to (tagData.antennaID?.toString() ?: "")
                )
                tagReadCount[epc] = 0
            }

            // Update RSSI and count if available
            if (tagData.peakRSSI != null) {
                tagDataMap[epc]!!["rssi"] = tagData.peakRSSI.toString()
            }
            if (tagData.tagSeenCount != null) {
                tagDataMap[epc]!!["count"] = tagData.tagSeenCount.toString()
            }

            // Check if this is from an access read operation
            if (opCode == ACCESS_OPERATION_CODE.ACCESS_OPERATION_READ &&
                opStatus == ACCESS_OPERATION_STATUS.ACCESS_SUCCESS) {

                val memoryBankData = tagData.memoryBankData ?: ""

                if (memoryBankData.isNotEmpty()) {
                    // Increment read count
                    tagReadCount[epc] = (tagReadCount[epc] ?: 0) + 1

                    // First read is TID, second read is User memory (based on sequence order)
                    if (tagDataMap[epc]!!["tid"]!!.isEmpty()) {
                        tagDataMap[epc]!!["tid"] = memoryBankData
                        Log.d(TAG, "TID read: $memoryBankData")
                    } else if (tagDataMap[epc]!!["user"]!!.isEmpty()) {
                        tagDataMap[epc]!!["user"] = memoryBankData
                        Log.d(TAG, "User memory read: $memoryBankData")
                    }
                }
            }

            // Only send data to Flutter when both TID and User memory have been read (2 operations complete)
            val readsCompleted = tagReadCount[epc] ?: 0
            if (readsCompleted >= 2) {
                val tid = tagDataMap[epc]!!["tid"] ?: ""
                
                // Track TID for this EPC to detect collisions
                if (tid.isNotEmpty()) {
                    if (!epcToTids.containsKey(epc)) {
                        epcToTids[epc] = mutableSetOf()
                    }
                    epcToTids[epc]!!.add(tid)
                }

                val tidsForEpc = epcToTids[epc]
                val isCollision = tidsForEpc != null && tidsForEpc.size > 1
                
                // Add collision flag and unique key
                tagDataMap[epc]!!["epcCollision"] = isCollision.toString()
                tagDataMap[epc]!!["uniqueKey"] = "${epc}_$tid"

                val tagInfo = tagDataMap[epc]!!.toMap()

                Log.d(TAG, "╔════════════════════════════════")
                Log.d(TAG, "║ TAG COMPLETE - SENDING TO FLUTTER")
                Log.d(TAG, "╠════════════════════════════════")
                Log.d(TAG, "║ EPC: ${tagInfo["epc"]}")
                Log.d(TAG, "║ TID: ${tagInfo["tid"]}")
                Log.d(TAG, "║ User: ${tagInfo["user"]}")
                Log.d(TAG, "║ RSSI: ${tagInfo["rssi"]} dBm")
                Log.d(TAG, "║ Count: ${tagInfo["count"]}")
                Log.d(TAG, "║ Antenna: ${tagInfo["antenna"]}")
                Log.d(TAG, "╚════════════════════════════════")

                sendEvent(mapOf("tag" to tagInfo))

                // Reset for next scan of this tag
                tagReadCount[epc] = 0
            } else {
                Log.d(TAG, "Waiting for more reads... ($readsCompleted/2 complete)")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error processing tag: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun eventStatusNotify(rfidStatusEvents: RfidStatusEvents?) {
        val statusEvent = rfidStatusEvents?.StatusEventData
        if (statusEvent != null) {
            val status = when (statusEvent.statusEventType) {
                STATUS_EVENT_TYPE.DISCONNECTION_EVENT -> "Reader disconnected"
                STATUS_EVENT_TYPE.BATTERY_EVENT -> "Battery event"
                STATUS_EVENT_TYPE.INVENTORY_START_EVENT -> "Inventory started"
                STATUS_EVENT_TYPE.INVENTORY_STOP_EVENT -> {
                    // Clear the tag data map and read counts when inventory stops
                    tagDataMap.clear()
                    tagReadCount.clear()
                    epcToTids.clear()
                    "Inventory stopped"
                }
                STATUS_EVENT_TYPE.HANDHELD_TRIGGER_EVENT -> {
                    val triggerData = statusEvent.HandheldTriggerEventData
                    if (triggerData.handheldEvent == HANDHELD_TRIGGER_EVENT_TYPE.HANDHELD_TRIGGER_PRESSED) {
                        Log.d(TAG, "Hardware trigger PRESSED - Starting inventory with access sequence")
                        try {
                            configureAccessSequence()
                            reader?.Actions?.TagAccess?.OperationSequence?.performSequence()
                            isUsingAccessSequence = true
                            sendEvent(mapOf("status" to "Hardware trigger pressed - Scanning started"))
                        } catch (e: Exception) {
                            Log.e(TAG, "Error starting inventory on trigger: ${e.message}")
                        }
                        "Trigger pressed - Scanning"
                    } else {
                        Log.d(TAG, "Hardware trigger RELEASED - Stopping inventory")
                        try {
                            if (isUsingAccessSequence) {
                                reader?.Actions?.TagAccess?.OperationSequence?.stopSequence()
                                isUsingAccessSequence = false
                            } else {
                                reader?.Actions?.Inventory?.stop()
                            }
                            sendEvent(mapOf("status" to "Hardware trigger released - Scanning stopped"))
                        } catch (e: Exception) {
                            Log.e(TAG, "Error stopping inventory on trigger: ${e.message}")
                        }
                        "Trigger released - Stopped"
                    }
                }
                else -> "Status: ${statusEvent.statusEventType}"
            }
            Log.d(TAG, "Status event: $status")
            sendEvent(mapOf("status" to status))
        }
    }

    private fun sendEvent(data: Map<String, Any>) {
        runOnUiThread {
            if (eventSink != null) {
                eventSink?.success(data)
            } else {
                Log.w(TAG, "Cannot send event, eventSink is NULL. Data: $data")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            disconnectReader()
            readers?.Dispose()
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy: ${e.message}")
        }
    }
}
