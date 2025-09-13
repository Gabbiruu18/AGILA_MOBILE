import 'package:cloud_firestore/cloud_firestore.dart';

class HomeService {
  final FirebaseFirestore _db;
  HomeService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc({
    required String role,
    required String uid,
  }) {
    return _db.collection('users').doc(role).collection('accounts').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _noteDoc({
    required String role,
    required String uid,
  }) {
    return _userDoc(role: role, uid: uid).collection('notes').doc('note');
  }

  /// users/{role}/accounts/{uid}
  Future<Map<String, dynamic>?> fetchUserDetails({
    required String role,
    required String uid,
  }) async {
    final snap = await _userDoc(role: role, uid: uid).get();
    return snap.data();
  }

  /// Get or create notes/{note} and return text ('' if none)
  Future<String> getOrCreateNote({
    required String role,
    required String uid,
  }) async {
    final ref = _noteDoc(role: role, uid: uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({'text': ''});
      return '';
    }
    return (snap.data()?['text']?.toString() ?? '');
  }

  Future<void> saveNote({
    required String role,
    required String uid,
    required String text,
  }) async {
    final ref = _noteDoc(role: role, uid: uid);
    await ref.set({'text': text});
  }

  Future<void> resetNote({
    required String role,
    required String uid,
  }) async {
    final ref = _noteDoc(role: role, uid: uid);
    await ref.delete();
  }

  Stream<int> streamUnreadCount({required String role, required String uid}) {
    return _db
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }
}
