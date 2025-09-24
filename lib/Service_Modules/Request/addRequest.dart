import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p; // For getting file extension
import 'package:mime/mime.dart';


class AddRequestModal extends StatefulWidget {
  final String uid;
  final String role;
  final String name;
  final String academicYearId;
  final String acadYear;
  final String semesterId;
  final String semesterName;

  const AddRequestModal({
    super.key,
    required this.uid,
    required this.role,
    required this.name,
    required this.academicYearId,
    required this.acadYear,
    required this.semesterId,
    required this.semesterName,
  });

  @override
  State<AddRequestModal> createState() => _AddRequestModalState();
}

class _AddRequestModalState extends State<AddRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedType = 'To be Excused';
  bool _isSubmitting = false;

  PlatformFile? _selectedFile;
  UploadTask? _uploadTask;

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
    if (!mounted) return;
    setState(() => _isLoadingTeachers = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc('teacher')
        .collection('accounts')
        .get();
    if (!mounted) return;
    setState(() {
      _teacherNames = snapshot.docs.map((doc) {
        final data = doc.data();
        return '${data['firstName']} ${data['lastName']}'.trim();
      }).toList();
      _isLoadingTeachers = false;
    });
  }

  Future<void> _loadAdmins() async {
    if (!mounted) return;
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
    if (!mounted) return;
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result == null) return;

    final file = result.files.single;

    const maxSizeInBytes = 200 * 1024 * 1024;
    if (file.size > maxSizeInBytes) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is too large (Max 200 MB).')),
        );
      }
      return;
    }

    setState(() {
      _selectedFile = file;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please review your request details:'),
            const SizedBox(height: 16),
            _buildConfirmationDetail('Type:', _selectedType),
            _buildConfirmationDetail('To:', _toController.text),
            _buildConfirmationDetail('Reason:', _reasonController.text),
            _buildConfirmationDetail('Attachment:', _selectedFile?.name ?? 'None'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
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

      if (recipientSnap.docs.isEmpty) throw Exception('Recipient not found.');
      final recipientDoc = recipientSnap.docs.first;
      final recipientUid = recipientDoc.id;

      final sentRequestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.role)
          .collection('accounts')
          .doc(widget.uid)
          .collection('Request')
          .doc();
      final requestId = sentRequestRef.id;

      Map<String, dynamic>? attachmentData;

      // ✅ **FIXED**: Correctly handle the async file upload.
      if (_selectedFile != null) {
        final file = File(_selectedFile!.path!);
        final path = 'attachments/${widget.role}_to_$recipientRole/${widget.uid}/$requestId/${_selectedFile!.name}';
        final storageRef = FirebaseStorage.instance.ref().child(path);

        // 1. Set the upload task in state to show the progress bar.
        UploadTask uploadTask = storageRef.putFile(file);
        setState(() {
          _uploadTask = uploadTask;
        });

        // 2. Await the upload completion.
        TaskSnapshot snapshot = await uploadTask;
        final attachmentUrl = await snapshot.ref.getDownloadURL();

        // 3. Create the attachment data map.
        attachmentData = {
          'name': _selectedFile!.name,
          'size': _selectedFile!.size,
          'contentType': lookupMimeType(_selectedFile!.path!),
          'url': attachmentUrl,
        };

        // 4. Update the state to hide the progress bar.
        setState(() {
          _uploadTask = null;
        });
      }

      final data = {
        'type': _selectedType,
        'reason': _reasonController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'acadYear': widget.acadYear,
        'academicYearId': widget.academicYearId,
        'semesterId': widget.semesterId,
        'semesterName': widget.semesterName,
        'fromStudentId': widget.uid,
        'fromStudentName': widget.name,
        'toTeacherId': recipientUid,
        'toTeacherName': rawTo,
        'attachments': attachmentData != null ? [attachmentData] : [],
        // Legacy fields
        'senderUid': widget.uid,
        'role': widget.role,
        'name': widget.name,
        'to': rawTo,
        'timestamp': FieldValue.serverTimestamp(),
        'attachmentUrl': attachmentData?['url'] ?? '',
      };

      final batch = FirebaseFirestore.instance.batch();

      final receivedRequestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(recipientRole)
          .collection('accounts')
          .doc(recipientUid)
          .collection('received_request')
          .doc(requestId);

      batch.set(sentRequestRef, data);
      batch.set(receivedRequestRef, data);

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildConfirmationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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
                          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          items: const [
                            DropdownMenuItem(value: 'To be Excused', child: Text('To be Excused')),
                            DropdownMenuItem(value: 'Permission', child: Text('Permission')),
                            DropdownMenuItem(value: 'Submit Documents', child: Text('Submit Documents')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setState(() => _selectedType = val!),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
                          popupProps: const PopupProps.menu(showSearchBox: true, searchFieldProps: TextFieldProps(autofocus: true)),
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
                      const SizedBox(height: 8),
                      _buildAttachmentSection(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                              : const Text('Submit Request', style: TextStyle(fontSize: 16)),
                        ),
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

  Widget _buildAttachmentSection() {
    if (_uploadTask != null) {
      return StreamBuilder<TaskSnapshot>(
        stream: _uploadTask!.snapshotEvents,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final progress = snapshot.data!.bytesTransferred / snapshot.data!.totalBytes;
            return Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text('Uploading... ${(progress * 100).toStringAsFixed(0)}%'),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    if (_selectedFile != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(_getIconForFile(p.extension(_selectedFile!.name)), color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedFile!.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text('(${( _selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB)', style: Theme.of(context).textTheme.bodySmall),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _uploadTask = null;
                });
              },
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _pickFile,
      icon: const Icon(Icons.attach_file),
      label: const Text('Attach File (Optional)'),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }

  IconData _getIconForFile(String? extension) {
    switch (extension?.toLowerCase()) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.png':
      case '.jpg':
      case '.jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _styledField({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12)
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    border: InputBorder.none,
    labelText: label,
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    ),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
  );
}