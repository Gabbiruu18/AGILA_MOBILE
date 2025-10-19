import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_agila/Service_Modules/Request/request_UI.dart';
import 'package:project_agila/Service_Modules/Request/request_service.dart';

// Helper class to parse request data safely.
// This can be in the same file or moved to a separate helpers file.
class _RequestDataParser {
  final Map<String, dynamic> data;

  String senderName = 'Unknown';
  String senderId = '';
  String senderRole = '';
  String recipientName = '—';
  String recipientId = '';
  String recipientRole = '';

  _RequestDataParser(this.data) {
    _parse();
  }

  void _parse() {
    // --- Sender Parsing ---
    senderRole = data['role'] ?? '';
    if (senderRole.isEmpty) {
      final fromKey = data.keys.firstWhere((k) => k.startsWith('from') && k.endsWith('Id'), orElse: () => '');
      if (fromKey.isNotEmpty) {
        senderRole = fromKey.replaceAll('from', '').replaceAll('Id', '').toLowerCase();
      }
    }

    if (senderRole.isNotEmpty) {
      final senderRoleKey = senderRole[0].toUpperCase() + senderRole.substring(1);
      senderId = (data['from${senderRoleKey}Id'] ?? '').toString();
      senderName = (data['from${senderRoleKey}Name'] ?? 'Unknown').toString();
    }

    // --- Recipient Parsing ---
    recipientRole = data['recipientRole'] ?? '';
    if (recipientRole.isEmpty) {
      final toKey = data.keys.firstWhere((k) => k.startsWith('to') && k.endsWith('Id'), orElse: () => '');
      if (toKey.isNotEmpty) {
        recipientRole = toKey.replaceAll('to', '').replaceAll('Id', '').toLowerCase().replaceAll('_', '');
      }
    }

    if (recipientRole.isNotEmpty) {
      final recipientRoleKey = recipientRole[0].toUpperCase() + recipientRole.substring(1).replaceAll('_', '');
      recipientId = (data['to${recipientRoleKey}Id'] ?? '').toString();
      recipientName = (data['to${recipientRoleKey}Name'] ?? '—').toString();
    }
  }
}


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
        final parser = _RequestDataParser(data);
        final type = (data['type'] ?? '').toString().toLowerCase();

        if (!(type.contains(q) || parser.senderName.toLowerCase().contains(q) || parser.recipientName.toLowerCase().contains(q))) return false;
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
    String? originalStatus,
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

      if (originalStatus != null && context.mounted) {
        final snackBar = SnackBar(
          content: Text('Request ${newStatus.toLowerCase()}d.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _updateStatus(
                context: context,
                newStatus: originalStatus,
                senderRole: senderRole,
                senderUid: senderUid,
                requestId: requestId,
                reason: '',
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
  }) {
    final parser = _RequestDataParser(data);
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
            senderRole: parser.senderRole,
            senderUid: parser.senderId,
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
    final parser = _RequestDataParser(data);

    final type = (data['type'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'Pending').toString();
    final ts = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final decision = data['teacherDecision'] as Map<String, dynamic>? ?? {};
    final remarks = (decision['remarks'] ?? '').toString();

    final isSentView = (showSent || !isStaff);
    final canAct = !isSentView && status == 'Pending';

    Future<void> handleDecision(bool isApproved) async {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => DecisionRemarksDialog(isApproved: isApproved),
      );
      if (reason != null) {
        await _updateStatus(
          context: context,
          newStatus: isApproved ? 'Approved' : 'Rejected',
          senderRole: parser.senderRole,
          senderUid: parser.senderId,
          requestId: doc.id,
          reason: reason,
          originalStatus: status,
        );
      }
    }

    final card = RequestCard(
      type: type,
      status: status,
      toText: 'To: ${parser.recipientName}',
      fromText: 'From: ${parser.senderName} (${parser.senderRole.isEmpty ? '—' : parser.senderRole})',
      timestamp: ts,
      remarks: remarks,
      isSentView: isSentView,
      onTap: () => openDetailsSheet(
        context: context,
        data: data,
        requestId: doc.id,
        isReceived: !isSentView,
      ),
      onApprove: canAct ? () => handleDecision(true) : null,
      onReject: canAct ? () => handleDecision(false) : null,
    );

    if (canAct) {
      return Dismissible(
        key: ValueKey(doc.id),
        background: slideApprove(),
        secondaryBackground: slideReject(),
        confirmDismiss: (dir) async {
          final isApproved = dir == DismissDirection.startToEnd;
          await handleDecision(isApproved);
          return false;
        },
        child: card,
      );
    }

    return card;
  }
}