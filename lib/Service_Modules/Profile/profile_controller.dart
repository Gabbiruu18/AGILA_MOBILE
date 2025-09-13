import 'package:flutter/material.dart';
import 'profile_service.dart';

class ProfileController extends ChangeNotifier {
  final ProfileService _service;

  ProfileController({ProfileService? service}) : _service = service ?? ProfileService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? profileImageUrl;
  String? storageId;
  late String role;
  late String uid;

  /// Primary source of truth for showing the user's name.
  /// Builds "firstName lastName", then falls back to fullName/name/User.
  String get displayName {
    final first = (userData?['firstName'] ?? '').toString().trim();
    final last  = (userData?['lastName']  ?? '').toString().trim();
    final combined = ('$first $last').trim();
    if (combined.isNotEmpty) return combined;

    final fallback = (userData?['fullName'] ?? userData?['name'] ?? '').toString().trim();
    return fallback.isNotEmpty ? fallback : 'User';
  }

  Map<String, dynamic> get profileData => {
    "firstName": userData?['firstName'],
    "lastName": userData?['lastName'],
    "email": userData?['email'],
    "contact": userData?['contact'],
    "phone": userData?['phone'],
    "course": userData?['course'],
    "yearLevelName": userData?['yearLevelName'],
    "section": userData?['section'],
    "department": userData?['department'],
    "subjects": userData?['subjects'], // List<String>? if available
    "displayName": displayName,
  };

  Future<void> init({required String role, required String uid}) async {
    this.role = role;
    this.uid = uid;
    await _load();
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();

    final data = await _service.fetchUserData(role: role, uid: uid);
    final id = _service.deriveStorageId(role: role, userData: data);

    String? url;
    if (id != null) {
      url = await _service.getProfilePhotoUrlIfAny(id);
    }

    userData = data;
    storageId = id;
    profileImageUrl = url;
    isLoading = false;
    notifyListeners();
  }

  Future<void> pickAndUploadImage(BuildContext context) async {
    if (storageId == null) return;
    final url = await _service.uploadProfileImageFromGallery(storageId!);
    if (url != null) {
      profileImageUrl = url;
      notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo uploaded successfully!')),
        );
      }
    }
  }

  Future<void> logout(BuildContext context) async {
    await _service.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  bool get isAdminOrTeacher =>
      role == 'teacher' || role == 'program_head' || role == 'academic_head';
}
