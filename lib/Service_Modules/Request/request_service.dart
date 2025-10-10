import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a query for all requests sent by the current user.
  /// This queries the specific user's 'Request' subcollection.
  Query sentQuery(String role, String uid, bool newestFirst) {
    return _db
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .collection('Request')
        .orderBy('createdAt', descending: newestFirst);
  }

  /// Returns a query for all requests received by the current user.
  /// This uses a collection group query to search across all 'Request' subcollections.
  Query receivedQuery(String role, String uid, bool newestFirst) {
    // The 'role' passed here is the role of the current user (the receiver).
    final receiverRoleKey = role.isNotEmpty ? role[0].toUpperCase() + role.substring(1).replaceAll('_', '') : '';

    // Use a collectionGroup query to find 'Request' documents across all users.
    return _db
        .collectionGroup('Request')
        .where('to${receiverRoleKey}Id', isEqualTo: uid) // Find requests where the user is the recipient.
        .orderBy('createdAt', descending: newestFirst);
  }

  /// Updates the status of a single request document.
  Future<void> updateStatus({
    required String newStatus,
    required String receiverRole,
    required String receiverUid,
    required String receiverName,
    required String senderRole,
    required String senderUid,
    required String requestId,
    String? reason,
  }) async {
    // To update a document, we still need the full path to the sender's subcollection.
    final requestRef = _db
        .collection('users')
        .doc(senderRole)
        .collection('accounts')
        .doc(senderUid)
        .collection('Request')
        .doc(requestId);

    final decisionData = {
      'by': receiverUid,
      'byName': receiverName,
      'decidedAt': FieldValue.serverTimestamp(),
      'type': newStatus,
      'remarks': reason ?? '',
    };

    final updateData = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'teacherDecision': decisionData,
    };

    // The update logic remains the same, targeting that single source of truth.
    await requestRef.update(updateData);
  }
}