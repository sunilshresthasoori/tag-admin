# Implementation Plan - EPC Collision Handling

Implement EPC collision detection and handling in the Kotlin RFID scanner and Flutter UI. This ensures that physically distinct tags with the same EPC (but different TIDs) are distinguishable and flagged to the operator.

## Proposed Changes

### Kotlin (Android Native)

#### [MODIFY] [MainActivity.kt](file:///home/dabba/office/tag-admin/android/app/src/main/kotlin/com/example/tag_admin/MainActivity.kt)
- Add `epcToTids: MutableMap<String, MutableSet<String>>` to track TIDs per EPC.
- Update `processTag` to:
    - Track distinct TIDs for each EPC.
    - Add `epcCollision` boolean flag (true if `epcToTids[epc].size > 1`).
    - Compute `uniqueKey` as `${epc}_${tid}`.
    - Include `uniqueKey` and `epcCollision` in the tag data sent to Flutter.
- Clear `epcToTids` in `eventStatusNotify` when `INVENTORY_STOP_EVENT` occurs.

---

### Dart Models

#### [MODIFY] [rfid_tag.dart](file:///home/dabba/office/tag-admin/lib/models/rfid_tag.dart)
- Add `uniqueKey` (String) and `epcCollision` (bool) fields.
- Update constructor.

#### [MODIFY] [scan_sessions.dart](file:///home/dabba/office/tag-admin/lib/models/scan_sessions.dart)
- Update `toJson` and `fromJson` to include `uniqueKey` and `epcCollision`.

---

### Dart BLoC & Services

#### [MODIFY] [rfid_scanner_bloc.dart](file:///home/dabba/office/tag-admin/lib/blocs/rfid_scanner/rfid_scanner_bloc.dart)
- Update `_onTagReceived` to use `uniqueKey` (EPC+TID) as the key in the in-memory `tagMap` instead of just EPC.
- Ensure tags with the same EPC but different TIDs are treated as separate entries.

---

### Dart UI

#### [MODIFY] [tags_list.dart](file:///home/dabba/office/tag-admin/lib/widgets/tags_list.dart)
- Add a warning badge (Icons.warning_amber_rounded) for tags where `epcCollision == true`.

#### [MODIFY] [scanning_view_page.dart](file:///home/dabba/office/tag-admin/lib/screens/scanning_view_page.dart)
- Implement `DefaultTabController` with two tabs: "All Tags" and "Duplicate EPCs".
- "Duplicate EPCs" tab will filter tags by `epcCollision == true` and group them by EPC.
- Add a summary banner at the top if duplicate EPCs are detected.

## Verification Plan

### Manual Verification
1. Start scanning with multiple tags having the same EPC but different TIDs.
2. Verify that the "Duplicate EPCs" tab shows the count of conflicting tags.
3. Verify that the warning icon appears next to those tags in the main list.
4. Verify that the uniqueKey correctly distinguishes the tags (no overwriting).
5. Stop scanning and verify that collision tracking resets.
