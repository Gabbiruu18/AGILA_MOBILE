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
  final String semesterId;
  final String semesterName;
  final String acadYear;

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

  List<PlatformFile> _selectedFiles = [];
  Map<String, UploadTask> _uploadTasks = {};

  List<String> _teacherNames = [];
  List<String> _adminNames = [];
  bool _isLoadingTeachers = false;
  bool _isLoadingAdmins = false;

  // New state variables for fetching academic data
  Map<String, String>? _academicData;
  String? _loadingError;

  @override
  void initState() {
    super.initState();

    _selectedType = _getDefaultTypeForRole(widget.role);
    // Fetch academic data and recipient lists when the dialog opens
    _initializeData();
  }


  String _getDefaultTypeForRole(String role) {
    if (role == 'teacher' || role == 'program_head') {
      return 'Permission'; // Default for teachers and program heads
    } else {
      return 'To be Excused'; // Default for students and others
    }
  }

  Future<void> _initializeData() async {
    await _fetchActiveAcademicData();
    if (widget.role == 'student') {
      _loadTeachers();
    } else if (widget.role == 'teacher') {
      _loadAdmins();
    }
  }


  List<DropdownMenuItem<String>> _getDropdownItemsForRole(String role) {
    if (role == 'teacher' || role == 'program_head') {
      // Teacher and program_head specific options as seen in the image
      return const [
        DropdownMenuItem(value: 'Permission', child: Text('Permission')),
        DropdownMenuItem(value: 'Schedule Adjustment', child: Text('Schedule Adjustment')),
        DropdownMenuItem(value: 'Document Request', child: Text('Document Request')),
        DropdownMenuItem(value: 'Other', child: Text('Other')),
      ];
    } else {
      // Default options for students and other roles
      return const [
        DropdownMenuItem(value: 'To be Excused', child: Text('To be Excused')),
        DropdownMenuItem(value: 'Permission', child: Text('Permission')),
        DropdownMenuItem(value: 'Submit Documents', child: Text('Submit Documents')),
        DropdownMenuItem(value: 'Other', child: Text('Other')),
      ];
    }
  }

  /// Fetches the active academic year and semester from Firestore.
  Future<void> _fetchActiveAcademicData() async {
    final firestore = FirebaseFirestore.instance;
    try {
      // 1. Find the active academic year
      final yearQuery = await firestore
          .collection('academic_years')
          .where('status', isEqualTo: 'Active')
          .limit(1)
          .get();

      if (yearQuery.docs.isEmpty) {
        throw Exception("No active academic year found.");
      }

      final yearDoc = yearQuery.docs.first;
      final academicYearId = yearDoc.id;
      final acadYear = yearDoc.data()['acadYear'] as String;

      // 2. Find the active semester within that year
      final semesterQuery = await firestore
          .collection('academic_years')
          .doc(academicYearId)
          .collection('semesters')
          .where('status', isEqualTo: 'Active')
          .limit(1)
          .get();

      if (semesterQuery.docs.isEmpty) {
        throw Exception("No active semester found for the current academic year.");
      }

      final semesterDoc = semesterQuery.docs.first;
      final semesterId = semesterDoc.id;
      final semesterName = semesterDoc.data()['semesterName'] as String;

      // 3. Set the data to the state
      if (mounted) {
        setState(() {
          _academicData = {
            'academicYearId': academicYearId,
            'acadYear': acadYear,
            'semesterId': semesterId,
            'semesterName': semesterName,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = "Failed to load academic data: ${e.toString()}";
        });
      }
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
      case 'academic_head': return 'Academic Head';
      default: return 'Admin';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
    );

    if (result == null) return;

    const maxSizeInBytes = 200 * 1024 * 1024;
    List<PlatformFile> newFiles = [];
    for (var file in result.files) {
      if (file.size > maxSizeInBytes) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} is too large (Max 200 MB).')),
          );
        }
      } else {
        newFiles.add(file);
      }
    }

    setState(() {
      _selectedFiles.addAll(newFiles);
    });
  }

  Future<void> _submitRequest() async {
    // Prevent submission if academic data is not loaded
    if (_academicData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_loadingError ?? 'Academic data is not loaded yet.')),
      );
      return;
    }

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
            _buildConfirmationDetail('Attachments:', _selectedFiles.isNotEmpty ? _selectedFiles.map((f) => f.name).join(', ') : 'None'),
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
      if (_toController.text.contains('Academic Head:')) recipientRole = 'academic_head';
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

      List<Map<String, dynamic>> attachmentsData = [];

      if (_selectedFiles.isNotEmpty) {
        Map<String, UploadTask> uploadTasks = {};
        for (var selectedFile in _selectedFiles) {
          final file = File(selectedFile.path!);
          final path = 'attachments/${widget.role}_to_$recipientRole/${widget.uid}/$requestId/${selectedFile.name}';
          final storageRef = FirebaseStorage.instance.ref().child(path);
          uploadTasks[selectedFile.name] = storageRef.putFile(file);
        }
        setState(() {
          _uploadTasks = uploadTasks;
        });

        await Future.wait(_uploadTasks.values);

        for (var selectedFile in _selectedFiles) {
          final task = _uploadTasks[selectedFile.name]!;
          final snapshot = await task;
          final attachmentUrl = await snapshot.ref.getDownloadURL();
          attachmentsData.add({
            'name': selectedFile.name,
            'size': selectedFile.size,
            'contentType': lookupMimeType(selectedFile.path!),
            'url': attachmentUrl,
          });
        }

        setState(() {
          _uploadTasks = {};
        });
      }

      final senderRoleKey = widget.role[0].toUpperCase() + widget.role.substring(1);
      final recipientRoleKey = recipientRole[0].toUpperCase() + recipientRole.substring(1).replaceAll('_', '');

      final data = {
        'type': _selectedType,
        'reason': _reasonController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Use the fetched academic data from the state
        'acadYear': _academicData!['acadYear'],
        'academicYearId': _academicData!['academicYearId'],
        'semesterId': _academicData!['semesterId'],
        'semesterName': _academicData!['semesterName'],
        'from${senderRoleKey}Id': widget.uid,
        'from${senderRoleKey}Name': widget.name,
        'to${recipientRoleKey}Id': recipientUid,
        'to${recipientRoleKey}Name': rawTo,
        'attachments': attachmentsData,
        'role': widget.role,
        'recipientRole': recipientRole,
        'teacherDecision': {}, // Initialize with an empty map for consistency
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

  /// Builds the main content of the form, handling loading and error states.
  Widget _buildFormContent() {
    // While fetching academic data, show a loading indicator
    if (_academicData == null && _loadingError == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading active academic period...'),
          ],
        ),
      );
    }

    // If there was an error fetching data, show the error message
    if (_loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _loadingError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Once data is loaded, show the form
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _styledField(
              child: DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: _inputDecoration('Type of Request'),
                dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                items: _getDropdownItemsForRole(widget.role), // Use the helper method here
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
              child: _buildFormContent(), // Use the new builder method here
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      children: [
        if (_selectedFiles.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final uploadTask = _uploadTasks[file.name];

              if (uploadTask != null) {
                return StreamBuilder<TaskSnapshot>(
                  stream: uploadTask.snapshotEvents,
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
                          Text('Uploading ${file.name}... ${(progress * 100).toStringAsFixed(0)}%'),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(_getIconForFile(p.extension(file.name)), color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('(${(file.size / 1024 / 1024).toStringAsFixed(2)} MB)', style: Theme.of(context).textTheme.bodySmall),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _selectedFiles.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        if (!_isSubmitting)
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach Files'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
      ],
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