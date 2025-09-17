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

  String get courseAcronym =>
      _toAcronym((userData?['courseName'] ?? '').toString());

  String get departmentAcronym =>
      _toAcronym((userData?['departmentName'] ?? userData?['department'] ?? '').toString());

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
    "courseName": userData?['courseName'],
    "departmentName": userData?['departmentName'] ?? userData?['department'],
    "courseAcronym": courseAcronym,           // e.g., "Bachelor of Science in IT" -> "BSIT"
    "departmentAcronym": departmentAcronym,
    "yearLevelName": userData?['yearLevelName'],
    "sectionName": userData?['sectionName'],
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


  String _toAcronym(String input, {bool removeStopWords = true, int? maxLetters}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Normalize: replace punctuation/hyphens/underscores with spaces
    final normalized =
    trimmed.replaceAll(RegExp(r"[^\p{L}\p{N}]+", unicode: true), " ").trim();

    const stop = {
      'a','an','and','of','the','to','for','in','on','at','by','with','from','de','la','da','di'
    };

    final parts = normalized
        .split(RegExp(r"\s+"))
        .where((w) => w.isNotEmpty)
        .where((w) => !removeStopWords || !stop.contains(w.toLowerCase()))
        .map((w) => w[0].toUpperCase())
        .toList();

    if (parts.isEmpty) return '';

    final joined = parts.join();
    if (maxLetters != null && maxLetters > 0 && joined.length > maxLetters) {
      return joined.substring(0, maxLetters);
    }
    return joined;
  }

}
