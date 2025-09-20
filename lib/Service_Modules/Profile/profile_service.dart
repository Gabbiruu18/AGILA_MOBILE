// Service_Modules/Profile/profile_service.dart
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

  // ---------------- Firestore refs ----------------

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

  /// Prefer studentNumber/employeeNumber; else fallback to uid.
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

  // ---------------- Storage path helpers ----------------

  /// Map your role -> folder name used in Storage.
  /// Adjust strings here to exactly match your bucket folders.
  String _roleFolder(String role) {
    switch (role.toLowerCase().replaceAll(' ', '_')) {
      case 'student':
        return 'studentsPhoto';
      case 'teacher':
        return 'teachersPhoto';
      case 'program_head':
        return 'programHeadsPhoto';
      case 'academic_head':
        return 'academicHeadsPhoto';
      default:
        return '${role.toLowerCase()}Photo';
    }
  }

  // Real-time user doc stream
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


  /// Folder ref: "{$role}Photo/$id"
  Reference _folderRef(String id, String role) =>
      storage.ref('${_roleFolder(role)}/$id');

  /// File ref: "{$role}Photo/$id/$fileName"
  Reference _photoRef(String id, String role, String fileName) =>
      storage.ref('${_roleFolder(role)}/$id/$fileName');

  // ---------------- Image pick/upload ----------------

  /// Pick image from gallery (no upload).
  Future<XFile?> pickImage({int imageQuality = 60}) async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    // Note: On iOS, consider request permissions on your app side.
  }

  /// Upload to `{$role}Photo/$id/<fileName>` and return the **download URL**.
  /// If [fileNameOverride] is null, use the original picked filename.
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
    return await ref.getDownloadURL(); // e.g. ...?alt=media&token=...
  }

  // ---------------- Legacy / fallback URL discovery ----------------

  /// If Firestore has no `profileImage`, try to discover any file in "{$role}Photo/$id".
  /// 1) listAll() the folder and return the first item's URL (if allowed by Storage rules)
  /// 2) fallback to common names: picture / profile.jpg / profile.png
  Future<String?> getProfilePhotoUrlIfAny(String id, String role) async {
    // Try listing folder
    try {
      final list = await _folderRef(id, role).listAll();
      if (list.items.isNotEmpty) {
        return await list.items.first.getDownloadURL();
      }
    } catch (_) {
      // ignore; not all setups allow listAll
    }

    // Try common filenames
    const guesses = <String>['picture', 'profile.jpg', 'profile.png', 'profile.jpeg'];
    for (final name in guesses) {
      try {
        final url = await _photoRef(id, role, name).getDownloadURL();
        return url;
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  // ---------------- Firestore writes ----------------

  /// Save the download URL to the user's doc (field: profileImage).
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

  /// Update contact field.
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
