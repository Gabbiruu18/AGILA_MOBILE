import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static Future<bool> isFingerprintRegistered(String uid) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.exists && userDoc.data() != null && (userDoc.data() as Map<String, dynamic>)['fingerprintRegistered'];
  }

  static Future<void> saveFingerprintRegistration(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'fingerprintRegistered': true}, SetOptions(merge: true));
  }
}
