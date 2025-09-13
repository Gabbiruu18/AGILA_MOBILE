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

  /// Fetch user document under: users/{role}/accounts/{uid}
  Future<Map<String, dynamic>?> fetchUserData({
    required String role,
    required String uid,
  }) async {
    final snap = await db
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .get();

    return snap.data();
  }

  /// Decide what to use as storage id (employeeNumber or studentNumber)
  String? deriveStorageId({
    required String role,
    required Map<String, dynamic>? userData,
  }) {
    if (userData == null) return null;
    final isStaff = role == 'teacher' || role == 'program_head' || role == 'academic_head';;
    return isStaff ? userData['employeeNumber'] as String? : userData['studentNumber'] as String?;
  }

  /// Where we store the profile photo. Change here once, apply everywhere.
  Reference _photoRef(String id) =>
      storage.ref().child('profilePhotos/$id/profile.jpg'); // rename as you like

  /// Try to get a download URL. Returns null if not found.
  Future<String?> getProfilePhotoUrlIfAny(String id) async {
    try {
      return await _photoRef(id).getDownloadURL();
    } catch (_) {
      return null; // likely not uploaded yet
    }
  }

  /// Pick from gallery and upload. Returns the new download URL, or null if cancelled.
  Future<String?> uploadProfileImageFromGallery(
      String id, {
        int imageQuality = 60,
      }) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: imageQuality);
    if (picked == null) return null;

    final file = File(picked.path);
    await _photoRef(id).putFile(file);
    return _photoRef(id).getDownloadURL();
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
