import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final ImagePicker _picker = ImagePicker();

  ProfileService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : db = db ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance,
        auth = auth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _userRef({
    required String role,
    required String uid,
  }) {
    return db.collection('users').doc(role).collection('accounts').doc(uid);
  }

  Future<Map<String, dynamic>?> fetchUserData({
    required String role,
    required String uid,
  }) async {
    final snap = await _userRef(role: role, uid: uid).get();
    return snap.data();
  }

  String? deriveStorageId({
    required String role,
    required Map<String, dynamic>? userData,
    String? fallbackUid,
  }) {
    final sNum = (userData?['studentNumber'] ?? '').toString().trim();
    final eNum = (userData?['employeeNumber'] ?? '').toString().trim();
    if (sNum.isNotEmpty) return sNum;
    if (eNum.isNotEmpty) return eNum;
    return fallbackUid;
  }

  String _roleFolder(String role) {
    switch (role.toLowerCase().replaceAll(' ', '_')) {
      case 'student':
        return 'studentsPhoto';
      case 'teacher':
        return 'teachersPhoto';
      case 'program_head':
        return 'programHeadsPhoto';
      default:
        return '${role.toLowerCase()}Photo';
    }
  }

  Stream<Map<String, dynamic>?> watchUser({
    required String role,
    required String uid,
  }) {
    return db
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .snapshots()
        .map((s) => s.data());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserRaw({
    required String role,
    required String uid,
  }) {
    return db
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .snapshots();
  }


  Reference _folderRef(String id, String role) =>
      storage.ref('${_roleFolder(role)}/$id');

  Reference _photoRef(String id, String role, String fileName) =>
      storage.ref('${_roleFolder(role)}/$id/$fileName');

  Future<XFile?> pickImage({int imageQuality = 60}) async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
  }

  Future<String> uploadAndGetUrl(
      String id,
      String role,
      File file, {
        String? fileNameOverride,
      }) async {
    final sep = Platform.pathSeparator;
    final raw = fileNameOverride ?? file.path.split(sep).last;
    final fileName = raw.isEmpty ? 'picture' : raw;

    final ref = _photoRef(id, role, fileName);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String?> getProfilePhotoUrlIfAny(String id, String role) async {
    try {
      final list = await _folderRef(id, role).listAll();
      if (list.items.isNotEmpty) {
        return await list.items.first.getDownloadURL();
      }
    } catch (_) {
    }

    const guesses = <String>['picture', 'profile.jpg', 'profile.png', 'profile.jpeg'];
    for (final name in guesses) {
      try {
        final url = await _photoRef(id, role, name).getDownloadURL();
        return url;
      } catch (_) {
      }
    }
    return null;
  }

  Future<void> saveProfileImage({
    required String role,
    required String uid,
    required String url,
  }) async {
    await _userRef(role: role, uid: uid).update({
      'photoURL': url,
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateContact({
    required String role,
    required String uid,
    required String contact,
  }) async {
    await _userRef(role: role, uid: uid).update({'contact': contact});
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
