# Implementation Plan - Tag Serial Number Lookup API

Add an API service method to lookup a tag's serial number from the Java backend using its EPC and TID.

## User Review Required

> [!IMPORTANT]
> The exact API endpoint for the serial number lookup was not provided. I have assumed a POST request to `$_baseUrl/api/v1/toll-level/tags/lookup` that uses the same encryption mechanism as `sendTagData`. Please confirm if the endpoint, method, or security requirements are different.

## Proposed Changes

### [RFID-tag-scanner]

#### [MODIFY] [rfid_tag.dart](file:///home/dabba/Office/RFID-tag-scanner/lib/models/rfid_tag.dart)
- Add a nullable `serialNumber` field to the `RFIDTag` class.

#### [MODIFY] [api_service.dart](file:///home/dabba/Office/RFID-tag-scanner/lib/services/api_service.dart)
- Implement `fetchSerialNumber` method.
- This method will take `userName`, `epc`, and `tid`.
- It will use `EncryptionHelperRecharge.prepareRechargeRequest` to secure the request.
- It will decrypt the response if the backend returns an encrypted payload.

## Verification Plan

### Manual Verification
- I will verify the code syntax and structure.
- The user can verify by calling the new service method with valid EPC/TID and checking if the serial number is correctly returned from their Java backend.
