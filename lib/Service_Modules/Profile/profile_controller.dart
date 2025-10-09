// Service_Modules/Profile/profile_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

class ProfileController extends ChangeNotifier {
  final ProfileService _service;
  ProfileController({ProfileService? service}) : _service = service ?? ProfileService();

  Map<String, dynamic>? userData;
  bool isLoading = true;

  String? profileImageUrl; // Firestore URL field (e.g. 'profileImage')
  String? storageId;       // studentNumber/employeeNumber/uid
  late String role;
  late String uid;

  // Realtime sub
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  // Sync flags
  bool _isBusy = false;            // e.g. uploading image, saving contact
  bool _hasPendingWrites = false;  // from snapshot.metadata.hasPendingWrites
  bool get isSyncing => isLoading || _isBusy || _hasPendingWrites;

  // ----- Derived helpers -----
  String get courseAcronym => _toAcronym((userData?['courseName'] ?? '').toString());
  String get departmentAcronym =>
      _toAcronym((userData?['departmentName'] ?? userData?['department'] ?? '').toString());

  String get displayName {
    final first = (userData?['firstName'] ?? '').toString().trim();
    final last  = (userData?['lastName']  ?? '').toString().trim();
    final combined = ('$first $last').trim();
    if (combined.isNotEmpty) return combined;
    final fallback = (userData?['fullName'] ?? userData?['name'] ?? '').toString().trim();
    return fallback.isNotEmpty ? fallback : 'User';
  }

  Map<String, dynamic> get profileData => {
    'firstName': userData?['firstName'],
    'lastName': userData?['lastName'],
    'email': userData?['email'],
    'contact': userData?['contact'],
    'phone': userData?['phone'],
    'courseName': userData?['courseName'],
    'departmentName': userData?['departmentName'] ?? userData?['department'],
    'courseAcronym': courseAcronym,
    'departmentAcronym': departmentAcronym,
    'yearLevelName': userData?['yearLevelName'],
    'sectionName': userData?['sectionName'],
    'subjects': userData?['subjects'],
    'displayName': displayName,
    'department': userData?['departmentName'] ?? userData?['department'],
  };

  // ----- Lifecycle -----
  Future<void> init({required String role, required String uid}) async {
    this.role = role;
    this.uid = uid;
    _bindRealtime();
  }

  void _bindRealtime() {
    isLoading = true;
    notifyListeners();

    _userSub?.cancel();
    _userSub = _service.watchUserRaw(role: role, uid: uid).listen((snap) async {
      _hasPendingWrites = snap.metadata.hasPendingWrites;

      final data = snap.data();
      final id = _service.deriveStorageId(role: role, userData: data, fallbackUid: uid);

      // Prefer 'profileImage' (URL-only). Support 'profile' as legacy.
      String? imgUrl = (data?['photoURL'] as String?)?.trim()
          ?? (data?['profile']      as String?)?.trim();

      if ((imgUrl == null || imgUrl.isEmpty) && id != null) {
        try { imgUrl = await _service.getProfilePhotoUrlIfAny(id, role); } catch (_) {}
      }

      userData = data;
      storageId = id;
      profileImageUrl = imgUrl;

      isLoading = false;
      notifyListeners();
    }, onError: (_) {
      isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
  // Keep legacy method signature used by UI pencil
  Future<void> pickAndUploadImage(BuildContext context) =>
      changePhotoWithConfirmation(context);

  // ----- Actions -----
  Future<void> changePhotoWithConfirmation(BuildContext context) async {
    if (storageId == null) return;

    final picked = await _service.pickImage();
    if (picked == null) return;
    final file = File(picked.path);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        //backgroundColor: Color(0xFFFFFFFF),
        title: const Text('Use this photo?'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: kAgilaBlue, // kAgilaBlue
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              // fill + text color
              backgroundColor: kAgilaGold, // kAgilaGold
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),

        ],
      ),
    );
    if (confirmed != true) return;

    // Mark busy while uploading to Storage & writing Firestore
    _setBusy(true);
    try {
      final newUrl = await _service.uploadAndGetUrl(storageId!, role, file);
      await _service.saveProfileImage(role: role, uid: uid, url: newUrl);

      // Optimistic UI
      profileImageUrl = newUrl;
      userData = {...?userData, 'photoURL': newUrl};
      notifyListeners();
    } finally {
      _setBusy(false);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    }
  }

  Future<void> editContact(BuildContext context) async {
    final initial = (userData?['contact'] ?? userData?['phone'] ?? '').toString();

    final text = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Edit Contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: text,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  if (!RegExp(r'^[0-9+\-\s()]{7,}$').hasMatch(s)) return 'Enter a valid phone';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, text.text.trim());
                    }
                  },
                  child: const Text('Save'),
                ),
              ]),
            ]),
          ),
        );
      },
    );
    if (result == null) return;

    _setBusy(true);
    try {
      await _service.updateContact(role: role, uid: uid, contact: result);
      // Optimistic UI; stream will also refresh
      userData = {...?userData, 'contact': result};
      notifyListeners();
    } finally {
      _setBusy(false);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact updated')),
      );
    }
  }

  // ----- Utils -----
  void _setBusy(bool v) {
    if (_isBusy != v) {
      _isBusy = v;
      notifyListeners();
    }
  }

  String _toAcronym(String input, {bool removeStopWords = true, int? maxLetters}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final normalized =
    trimmed.replaceAll(RegExp(r"[^\p{L}\p{N}]+", unicode: true), " ").trim();
    const stop = {
      'a','an','and','of','the','to','for','in','on','at','by','with','from','de','la','da','di'
    };
    final parts = normalized
        .split(RegExp(r'\s+'))
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
