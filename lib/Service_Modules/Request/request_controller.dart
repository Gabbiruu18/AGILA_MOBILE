import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_agila/Service_Modules/Request/request_UI.dart';
import 'package:project_agila/Service_Modules/Request/request_service.dart';

class RequestController {
  final String uid;
  final String role;
  final String name;
  final VoidCallback onStateUpdate;
  final RequestService _service;

  bool showSent = true;
  String statusFilter = 'All';
  String query = '';
  bool newestFirst = true;

  RequestController({
    required this.uid,
    required this.role,
    required this.name,
    required this.onStateUpdate,
  }) : _service = RequestService();

  bool get isStaff =>
      role == 'teacher' ||
          role == 'admin' ||
          role == 'academic' ||
          role == 'program';

  Query sentQuery() => _service.sentQuery(role, uid, newestFirst);
  Query receivedQuery() => _service.receivedQuery(role, uid, newestFirst);

  void setShowSent(bool value) {
    if (showSent != value) {
      showSent = value;
      onStateUpdate();
    }
  }

  void setStatusFilter(String value) {
    if (statusFilter != value) {
      statusFilter = value;
      onStateUpdate();
    }
  }

  void setQuery(String value) {
    if (query != value) {
      query = value;
      onStateUpdate();
    }
  }

  void setNewestFirst(bool value) {
    if (newestFirst != value) {
      newestFirst = value;
      onStateUpdate();
    }
  }

  List<DocumentSnapshot> filterDocuments(List<DocumentSnapshot> allDocs) {
    return allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'Pending').toString();
      if (statusFilter != 'All' && status != statusFilter) return false;

      if (query.trim().isNotEmpty) {
        final q = query.toLowerCase();
        final type = (data['type'] ?? '').toString().toLowerCase();
        final to = (data['to'] ?? '').toString().toLowerCase();
        final name = (data['name'] ?? data['fromName'] ?? '').toString().toLowerCase();
        if (!(type.contains(q) || to.contains(q) || name.contains(q))) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _updateStatus({
    required BuildContext context,
    required String newStatus,
    required String senderRole,
    required String senderUid,
    required String requestId,
    String? reason,
    String? originalStatus, // Added for the "Undo" feature
  }) async {
    try {
      await _service.updateStatus(
        newStatus: newStatus,
        receiverRole: role,
        receiverUid: uid,
        receiverName: name,
        senderRole: senderRole,
        senderUid: senderUid,
        requestId: requestId,
        reason: reason,
      );

      // If this was an undoable action, show the SnackBar
      if (originalStatus != null && context.mounted) {
        final snackBar = SnackBar(
          content: Text('Request ${newStatus.toLowerCase()}d.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Reverse the action by setting status back to original
              _updateStatus(
                context: context,
                newStatus: originalStatus,
                senderRole: senderRole,
                senderUid: senderUid,
                requestId: requestId,
                reason: '', // Clear the reason on undo
              );
            },
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      onStateUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${e.toString()}')),
        );
      }
    }
  }


  void openDetailsSheet({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String requestId,
    required bool isReceived,
    required String senderRole,
    required String senderUid,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => RequestDetailsSheet(
        data: data,
        isStaff: isStaff,
        isReceived: isReceived,

        onUpdateStatus: (newStatus, reason) {
          Navigator.pop(context);
          _updateStatus(
            context: context,
            newStatus: newStatus,
            senderRole: senderRole,
            senderUid: senderUid,
            requestId: requestId,
            reason: reason,
            originalStatus: (data['status'] ?? 'Pending').toString(),
          );
        },
      ),
    );
  }

  int pendingCountFromSnap(AsyncSnapshot<QuerySnapshot> snap) {
    if (!snap.hasData) return 0;
    return snap.data!.docs.where((d) {
      final s = ((d.data() as Map<String, dynamic>)['status'] ?? 'Pending').toString();
      return s == 'Pending';
    }).length;
  }

  Widget buildRequestItem(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = (data['type'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'Pending').toString();
    final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final senderUid = (data['senderUid'] ?? '').toString();
    final senderRole = (data['role'] ?? '').toString();
    final fromName = (data['name'] ?? data['fromName'] ?? 'Unknown').toString();
    final toName = (data['to'] ?? '—').toString();

    final decision = data['decision'] as Map<String, dynamic>?;
    final remarks = (decision?['remarks'] ?? '').toString();

    final isSentView = (showSent || !isStaff);
    final canAct = !isSentView && status == 'Pending';

    // Helper function to show dialog and update status
    Future<void> handleDecision(bool isApproved) async {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => DecisionRemarksDialog(isApproved: isApproved),
      );
      if (reason != null) {
        await _updateStatus(
          context: context,
          newStatus: isApproved ? 'Approved' : 'Rejected',
          senderRole: senderRole,
          senderUid: senderUid,
          requestId: doc.id,
          reason: reason,
          originalStatus: status, // Pass the original status for undo
        );
      }
    }

    // Build the card widget first
    final card = RequestCard(
      type: type,
      status: status,
      toText: 'To: $toName',
      fromText: 'From: $fromName (${senderRole.isEmpty ? '—' : senderRole})',
      timestamp: ts,
      remarks: remarks,
      isSentView: isSentView,
      onTap: () => openDetailsSheet(
        context: context,
        data: data,
        requestId: doc.id,
        isReceived: !isSentView,
        senderRole: senderRole,
        senderUid: senderUid,
      ),
      onApprove: canAct ? () => handleDecision(true) : null,
      onReject: canAct ? () => handleDecision(false) : null,
    );

    // Only wrap the card with Dismissible if the user can act on it
    if (canAct) {
      return Dismissible(
        key: ValueKey(doc.id),
        background: slideApprove(),
        secondaryBackground: slideReject(),
        confirmDismiss: (dir) async {
          final isApproved = dir == DismissDirection.startToEnd;
          await handleDecision(isApproved);
          return false; // Do not dismiss, list will refresh
        },
        child: card,
      );
    }

    // Otherwise, return the plain card
    return card;
  }
}