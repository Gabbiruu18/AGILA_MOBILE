import 'dart:async';
import 'package:flutter/material.dart';
import 'home_service.dart';

class HomeController extends ChangeNotifier {
  final HomeService _service;

  HomeController({HomeService? service}) : _service = service ?? HomeService();

  late String role;
  late String uid;
  late String name;

  String? course;
  String? section;
  String? department;
  String noteText = 'Tap to write notes';
  bool isLoading = true;

  int unreadCount = 0;
  StreamSubscription<int>? _unreadSub;




  Future<void> init({
    required String role,
    required String uid,
    required String name,
  }) async {
    this.role = role;
    this.uid = uid;
    this.name = name;
    await _loadAll();
  }

  Future<void> _loadAll() async {
    isLoading = true;
    notifyListeners();

    await Future.wait([_loadUserDetails(), _loadNote()]);

    isLoading = false;
    notifyListeners();
  }


  Future<void> _loadUserDetails() async {
    final data = await _service.fetchUserDetails(role: role, uid: uid);
    course = data?['course'];
    section = data?['section'];
    department = data?['department'];
  }

  Future<void> _loadNote() async {
    final text = await _service.getOrCreateNote(role: role, uid: uid);
    noteText = (text.trim().isNotEmpty) ? text : 'Tap to write notes';
  }

  Future<void> saveNote(BuildContext context, String text) async {
    final newText = text.trim();
    await _service.saveNote(role: role, uid: uid, text: newText);
    noteText = newText.isNotEmpty ? newText : 'Tap to write notes';
    notifyListeners();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }

  Future<void> resetNote(BuildContext context) async {
    await _service.resetNote(role: role, uid: uid);
    noteText = 'Tap to write notes';
    notifyListeners();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note reset successfully')),
      );
    }
  }
  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }
}
