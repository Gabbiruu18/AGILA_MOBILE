import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewRequestModal extends StatelessWidget {
  final Map<String, dynamic> data;
  final String role;
  final String uid;
  final String requestId;

  const ViewRequestModal({
    super.key,
    required this.data,
    required this.role,
    required this.uid,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Request Details',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0045A2),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("Type:", data['type']),
            _detailRow("To:", data['to']),
            _detailRow("Status:", data['status']),
            _detailRow("Reason:", data['reason']),
            if ((data['attachmentUrl'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: TextButton(
                  onPressed: () {
                    // View attachment (implement later if needed)
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attachment viewing not implemented')),
                    );
                  },
                  child: const Text("View Attachment"),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (role == 'teacher' && data['status'] == 'Pending') ...[
          TextButton(
            onPressed: () => _updateStatus(context, 'Approved'),
            child: const Text('Approve', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () => _updateStatus(context, 'Rejected'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Close"),
        ),
      ],
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    final firestore = FirebaseFirestore.instance;

    final senderRole = data['role'];
    final senderUid = data['senderUid'];
    final receiverRole = role;
    final receiverUid = uid;

    final historyData = {
      'type': data['type'],
      'status': newStatus,
      'reason': data['reason'],
      'to': data['to'],
      'name': data['name'],
      'role': senderRole,
      'senderUid': senderUid,
      'attachmentUrl': data['attachmentUrl'] ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      // Update the status in Request
      await firestore
          .collection('users')
          .doc(senderRole)
          .collection('accounts')
          .doc(senderUid)
          .collection('Request')
          .doc(requestId)
          .update({'status': newStatus});

      // Add to sender's History
      await firestore
          .collection('users')
          .doc(senderRole)
          .collection('accounts')
          .doc(senderUid)
          .collection('History')
          .add(historyData);

      // Add to receiver's History
      await firestore
          .collection('users')
          .doc(receiverRole)
          .collection('accounts')
          .doc(receiverUid)
          .collection('History')
          .add(historyData);

      // Delete from active Request list
      await firestore
          .collection('users')
          .doc(senderRole)
          .collection('accounts')
          .doc(senderUid)
          .collection('Request')
          .doc(requestId)
          .delete();

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request marked as $newStatus')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }
}
