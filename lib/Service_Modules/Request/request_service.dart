import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Query sentQuery(String role, String uid, bool newestFirst) {
    return _db
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .collection('Request')
        .orderBy('createdAt', descending: newestFirst);
  }

  Query receivedQuery(String role, String uid, bool newestFirst) {
    final receiverRoleKey = role.isNotEmpty ? role[0].toUpperCase() + role.substring(1).replaceAll('_', '') : '';

    return _db
        .collectionGroup('Request')
        .where('to${receiverRoleKey}Id', isEqualTo: uid)
        .orderBy('createdAt', descending: newestFirst);
  }

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

    await requestRef.update(updateData);
  }
}