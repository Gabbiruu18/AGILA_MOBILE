// ✅ Updated addRequest.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AddRequestModal extends StatefulWidget {
  final String uid;
  final String role;
  final String name;

  const AddRequestModal({
    Key? key,
    required this.uid,
    required this.role,
    required this.name,
  }) : super(key: key);

  @override
  State<AddRequestModal> createState() => _AddRequestModalState();
}

class _AddRequestModalState extends State<AddRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedType = 'To be Excused';
  String? _uploadedFileUrl;
  bool _isSubmitting = false;

  List<String> _teacherNames = [];
  List<String> _adminNames = [];
  bool _isLoadingTeachers = false;
  bool _isLoadingAdmins = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'student') {
      _loadTeachers();
    } else if (widget.role == 'teacher') {
      _loadAdmins();
    }
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoadingTeachers = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc('teacher')
        .collection('accounts')
        .get();
    _teacherNames = snapshot.docs.map((doc) {
      final data = doc.data();
      return '${data['firstName']} ${data['lastName']}'.trim();
    }).toList();
    setState(() => _isLoadingTeachers = false);
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoadingAdmins = true);
    final List<String> names = [];
    for (final role in ['program_head', 'academic_head', 'admin']) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(role)
          .collection('accounts')
          .get();
      names.addAll(snap.docs.map((doc) {
        final data = doc.data();
        return '${_capitalizeRole(role)}: ${data['firstName']} ${data['lastName']}'.trim();
      }));
    }
    setState(() {
      _adminNames = names;
      _isLoadingAdmins = false;
    });
  }

  String _capitalizeRole(String role) {
    switch (role) {
      case 'program_head': return 'Program Head';
      case 'academic_head': return 'Academic Coordinator';
      default: return 'Admin';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('request_attachments/${widget.uid}/$fileName');
      final uploadTask = await storageRef.putFile(file);
      _uploadedFileUrl = await uploadTask.ref.getDownloadURL();
      setState(() {});
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final rawTo = _toController.text.contains(':')
        ? _toController.text.split(':').last.trim()
        : _toController.text.trim();

    String recipientRole = 'teacher';
    if (_toController.text.contains('Program Head:')) recipientRole = 'program_head';
    if (_toController.text.contains('Academic Coordinator:')) recipientRole = 'academic_head';
    if (_toController.text.contains('Admin:')) recipientRole = 'admin';

    final parts = rawTo.split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final recipientSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientRole)
        .collection('accounts')
        .where('firstName', isEqualTo: firstName)
        .where('lastName', isEqualTo: lastName)
        .get();

    if (recipientSnap.docs.isEmpty) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient not found.')),
      );
      return;
    }

    final recipientDoc = recipientSnap.docs.first;
    final recipientUid = recipientDoc.id;

    final newRequestRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.role)
        .collection('accounts')
        .doc(widget.uid)
        .collection('Request')
        .doc();

    final requestId = newRequestRef.id;

    final data = {
      'type': _selectedType,
      'to': rawTo,
      'reason': _reasonController.text.trim(),
      'attachmentUrl': _uploadedFileUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Pending',
      'name': widget.name,
      'role': widget.role,
      'senderUid': widget.uid,
    };

    try {
      await newRequestRef.set(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientRole)
          .collection('accounts')
          .doc(recipientUid)
          .collection('received_request')
          .doc(requestId)
          .set(data);

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF2F5FA),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0045A2))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _styledField(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: _inputDecoration('Type of Request'),
                          items: const [
                            DropdownMenuItem(value: 'To be Excused', child: Text('To be Excused')),
                            DropdownMenuItem(value: 'Permission', child: Text('Permission')),
                            DropdownMenuItem(value: 'Submit Documents', child: Text('Submit Documents')),
                          ],
                          onChanged: (val) => setState(() => _selectedType = val!),
                        ),
                      ),
                      _styledField(
                        child: (_isLoadingTeachers || _isLoadingAdmins)
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownSearch<String>(
                          items: widget.role == 'student' ? _teacherNames : _adminNames,
                          selectedItem: _toController.text.isNotEmpty ? _toController.text : null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: _inputDecoration('To'),
                          ),
                          popupProps: const PopupProps.menu(showSearchBox: true),
                          onChanged: (val) => setState(() => _toController.text = val ?? ''),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                      _styledField(
                        child: TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: _inputDecoration('Reason/Description'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_uploadedFileUrl == null ? 'Attach File' : 'File Attached'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC88000), foregroundColor: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Request'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0058CE), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styledField({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    border: InputBorder.none,
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF0045A2), fontWeight: FontWeight.bold),
  );
}
