import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Query sentQuery(String role, String uid, bool newestFirst) => _db
      .collection('users')
      .doc(role)
      .collection('accounts')
      .doc(uid)
      .collection('Request')
      .orderBy('createdAt', descending: newestFirst);

  Query receivedQuery(String role, String uid, bool newestFirst) => _db
      .collection('users')
      .doc(role)
      .collection('accounts')
      .doc(uid)
      .collection('received_request')
      .orderBy('createdAt', descending: newestFirst);

  Future<void> updateStatus({
    required String newStatus,
    required String receiverRole,
    required String receiverUid,
    required String receiverName, // Added to store in the decision map
    required String senderRole,
    required String senderUid,
    required String requestId,
    String? reason,
  }) async {
    final receiverRef = _db
        .collection('users')
        .doc(receiverRole)
        .collection('accounts')
        .doc(receiverUid)
        .collection('received_request')
        .doc(requestId);

    final senderRef = _db
        .collection('users')
        .doc(senderRole)
        .collection('accounts')
        .doc(senderUid)
        .collection('Request')
        .doc(requestId);

    // Create the new decision map
    final decisionData = {
      'by': receiverUid,
      'byName': receiverName,
      'decidedAt': FieldValue.serverTimestamp(),
      'type': newStatus,
      'remarks': reason ?? '', // Store remarks, even if empty
    };

    // Prepare the data for update. Keep top-level status for filtering.
    final updateData = {
      'status': newStatus,
      'teacherDecision': decisionData,
    };

    // Use a batch write to update both documents atomically.
    final batch = _db.batch();

    final receiverDoc = await receiverRef.get();
    if (receiverDoc.exists) {
      batch.update(receiverRef, updateData);
    }

    final senderDoc = await senderRef.get();
    if (senderDoc.exists) {
      batch.update(senderRef, updateData);
    }

    await batch.commit();
  }
}