# Walkthrough - Tag Serial Number Lookup Implementation

I have implemented the API service to lookup a tag's serial number from the Java backend.

## Changes

### [RFID-tag-scanner]

#### [rfid_tag.dart](file:///home/dabba/Office/RFID-tag-scanner/lib/models/rfid_tag.dart)
- Added `serialNumber` property to the `RFIDTag` model.

#### [api_service.dart](file:///home/dabba/Office/RFID-tag-scanner/lib/services/api_service.dart)
- Added `fetchSerialNumber` method.
- Integrated with `EncryptionHelperRecharge` to encrypt the request (EPC/TID) and decrypt the response.
- Assumed endpoint: `$_baseUrl/api/v1/toll-level/tags/lookup`.

## How to use

You can now call the `fetchSerialNumber` method from your UI components:

```dart
final apiService = ApiService();
try {
  final serialNumber = await apiService.fetchSerialNumber(
    userName: 'your_user',
    epc: tag.epc,
    tid: tag.tid,
  );
  setState(() {
    tag.serialNumber = serialNumber;
  });
} catch (e) {
  print('Error fetching serial number: $e');
}
```

## Verification Results
- Code structure and encryption logic verified to match existing patterns in `ApiService`.
