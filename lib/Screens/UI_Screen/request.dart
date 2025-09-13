import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'addRequest.dart';
import 'history.dart';
import 'viewRequest.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

class RequestListScreen extends StatefulWidget {
  final String uid;
  final String role;
  final String name;

  const RequestListScreen({
    Key? key,
    required this.uid,
    required this.role,
    required this.name,
  }) : super(key: key);

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  bool showSent = true;            // Sent vs Received
  String statusFilter = 'All';     // All | Pending | Approved | Rejected
  String query = '';               // search
  bool newestFirst = true;         // sort

  bool get isStaff =>
      widget.role == 'teacher' ||
          widget.role == 'admin' ||
          widget.role == 'academic' ||
          widget.role == 'program';

  // Queries (recreated when sort direction changes)
  Query _sentQuery() => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.role)
      .collection('accounts')
      .doc(widget.uid)
      .collection('Request')
      .orderBy('timestamp', descending: newestFirst);

  Query _receivedQuery() => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.role)
      .collection('accounts')
      .doc(widget.uid)
      .collection('received_request')
      .orderBy('timestamp', descending: newestFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Requests',
          style: GoogleFonts.poppins(
            fontSize: 24,
            color: kAgilaBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: kAgilaGold),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AddRequestModal(
                  uid: widget.uid,
                  role: widget.role,
                  name: widget.name, // TODO: replace with real name
                ),
              );
            },
            tooltip: 'Add Request',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF0045A2)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => RequestHistoryModal(
                  uid: widget.uid,
                  role: widget.role,
                  name: widget.name,
                ),
              );
            },
            tooltip: 'History',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),

          // Tabs with live pending badges (staff only)
          if (isStaff)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => showSent = true),
                        borderRadius: BorderRadius.circular(12),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _sentQuery().snapshots(),
                          builder: (_, snap) {
                            final count = _pendingCountFromSnap(snap);
                            final selected = showSent;
                            return _TabItem(
                              label: 'Sent',
                              selected: selected,
                              badge: count,
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => showSent = false),
                        borderRadius: BorderRadius.circular(12),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _receivedQuery().snapshots(),
                          builder: (_, snap) {
                            final count = _pendingCountFromSnap(snap);
                            final selected = !showSent;
                            return _TabItem(
                              label: 'Received',
                              selected: selected,
                              badge: count,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Search + Sort
          Padding(

            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(

              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  onSelected: (v) => setState(() => newestFirst = v == 'Newest'),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Newest', child: Text('Newest first')),
                    PopupMenuItem(value: 'Oldest', child: Text('Oldest first')),
                  ],
                  child: _SortChip(label: newestFirst ? 'Newest' : 'Oldest'),

                ),
              ],
            ),
          ),

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['All', 'Pending', 'Approved', 'Rejected']
                  .map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  backgroundColor: const Color(0xFFFFFFFF),
                  selectedColor: const Color(0xFFE9F1FF),
                  label: Text(s),
                  selected: statusFilter == s,
                  onSelected: (_) => setState(() => statusFilter = s),
                ),
              ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Main list (Sent or Received stream)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: (showSent || !isStaff)
                  ? _sentQuery().snapshots()
                  : _receivedQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _EmptyState(
                    showCTA: !isStaff || showSent,
                    onCreate: () {
                      showDialog(
                        context: context,
                        builder: (_) => AddRequestModal(
                          uid: widget.uid,
                          role: widget.role,
                          name: "YourName", // TODO: replace with real name
                        ),
                      );
                    },
                  );
                }

                // Map + local filters (status + search)
                final allDocs = snapshot.data!.docs;
                final filtered = allDocs.where((doc) {
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

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("No requests match your filters.",
                        style: TextStyle(color: Colors.black54)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = (data['type'] ?? 'Unknown').toString();
                    final status = (data['status'] ?? 'Pending').toString();
                    final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                    // For received: show From & inline actions (Pending)
                    final senderUid = (data['senderUid'] ?? '').toString();
                    final senderRole = (data['role'] ?? '').toString();
                    final fromName = (data['name'] ?? data['fromName'] ?? 'Unknown').toString();
                    final toName = (data['to'] ?? '—').toString();

                    final isSentView = (showSent || !isStaff);
                    final canAct = !isSentView && status == 'Pending';

                    return Dismissible(
                      key: ValueKey(doc.id),
                      background: _slideApprove(),
                      secondaryBackground: _slideReject(),
                      confirmDismiss: (dir) async {
                        if (!canAct) return false;
                        if (dir == DismissDirection.startToEnd) {
                          await _updateStatus('Approved', senderRole, senderUid, doc.id);
                        } else {
                          await _updateStatus('Rejected', senderRole, senderUid, doc.id);
                        }
                        return false; // keep item (we move to history, list will refresh)
                      },
                      child: _RequestCard(
                        type: type,
                        status: status,
                        toText: 'To: $toName',
                        fromText: 'From: $fromName (${senderRole.isEmpty ? '—' : senderRole})',
                        timestamp: ts,
                        isSentView: isSentView,
                        onTap: () {
                          // Use your existing dialog OR the new bottom sheet.
                          // 1) Keep your existing:
                          // showDialog(
                          //   context: context,
                          //   builder: (_) => ViewRequestModal(
                          //     data: data,
                          //     requestId: doc.id,
                          //     role: widget.role,
                          //     uid: widget.uid,
                          //   ),
                          // );

                          // 2) New lightweight details sheet (recommended):
                          _openDetailsSheet(
                            data: data,
                            requestId: doc.id,
                            isReceived: !isSentView,
                            senderRole: senderRole,
                            senderUid: senderUid,
                          );
                        },
                        onApprove: canAct
                            ? () => _updateStatus('Approved', senderRole, senderUid, doc.id)
                            : null,
                        onReject: canAct
                            ? () => _updateStatus('Rejected', senderRole, senderUid, doc.id)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _pendingCountFromSnap(AsyncSnapshot<QuerySnapshot> snap) {
    if (!snap.hasData) return 0;
    return snap.data!.docs.where((d) {
      final s = ((d.data() as Map<String, dynamic>)['status'] ?? 'Pending').toString();
      return s == 'Pending';
    }).length;
  }

  void _openDetailsSheet({
    required Map<String, dynamic> data,
    required String requestId,
    required bool isReceived,
    required String senderRole,
    required String senderUid,
  }) {
    final type = (data['type'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'Pending').toString();
    final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final reason = (data['reason'] ?? '').toString();
    final toName = (data['to'] ?? '—').toString();
    final fromName = (data['name'] ?? data['fromName'] ?? 'Unknown').toString();
    final attachment = (data['attachmentUrl'] ?? '—').toString();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(status: status),
            const SizedBox(height: 8),
            ListTile(
              title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_formatDate(ts)),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied details')),
                  );
                },
              ),
            ),
            const Divider(),
            _kv('To', toName),
            _kv('From', '$fromName (${senderRole.isEmpty ? '—' : senderRole})'),
            _kv('Reason', reason.isEmpty ? '—' : reason),
            _kv('Attachment', attachment.isEmpty ? '—' : attachment),
            const SizedBox(height: 12),
            if (status == 'Pending' && isStaff && isReceived)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateStatus('Rejected', senderRole, senderUid, requestId);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateStatus('Approved', senderRole, senderUid, requestId);
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  // ---- Original move-to-history logic (kept) ----
  Future<void> _updateStatus(
      String newStatus,
      String senderRole,
      String senderUid,
      String requestId,
      ) async {
    final receiverRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.role)
        .collection('accounts')
        .doc(widget.uid)
        .collection('received_request')
        .doc(requestId);

    final senderRef = FirebaseFirestore.instance
        .collection('users')
        .doc(senderRole)
        .collection('accounts')
        .doc(senderUid)
        .collection('Request')
        .doc(requestId);

    final receiverHistoryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.role)
        .collection('accounts')
        .doc(widget.uid)
        .collection('History')
        .doc(requestId);

    final senderHistoryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(senderRole)
        .collection('accounts')
        .doc(senderUid)
        .collection('History')
        .doc(requestId);

    try {
      final receiverSnap = await receiverRef.get();
      final senderSnap = await senderRef.get();

      if (!receiverSnap.exists || !senderSnap.exists) {
        throw Exception("Request not found.");
      }

      final receiverData = receiverSnap.data()!;
      final senderData = senderSnap.data()!;

      // Update / move
      await receiverRef.delete(); // optional: delete from received_request
      await senderRef.delete();   // optional: delete from Request

      await receiverHistoryRef.set({...receiverData, 'status': newStatus});
      await senderHistoryRef.set({...senderData, 'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request $newStatus')),
        );
        setState(() {}); // refresh streams/sort toggle
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${e.toString()}')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.blueAccent;
    }
  }

  // Small helper: key–value row
  Widget _kv(String keyLabel, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              keyLabel,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== UI WIDGETS =====================

class _RequestCard extends StatelessWidget {
  final String type;
  final String status;
  final String toText;     // "To: ..."
  final String fromText;   // "From: ..."
  final DateTime timestamp;
  final bool isSentView;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.type,
    required this.status,
    required this.toText,
    required this.fromText,
    required this.timestamp,
    required this.isSentView,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = isSentView ? toText : fromText;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Type & Status
              Row(
                children: [
                  Expanded(
                    child: Text(type,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        )),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 6),

              // Secondary line: To/From + time
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.access_time, size: 14, color: Colors.black38),
                  const SizedBox(width: 2),
                  Text(_tinyTime(timestamp),
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),

              // Inline actions for staff on Received + Pending
              if (onApprove != null && onReject != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        onPressed: onReject,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kAgilaGold, foregroundColor: Colors.white),
                        onPressed: onApprove,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _tinyTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    switch (s) {
      case 'approved':
        bg = const Color(0xFFE6F6EA);
        fg = const Color(0xFF1F8E3A);
        break;
      case 'rejected':
        bg = const Color(0xFFFDEBEC);
        fg = const Color(0xFFD12D33);
        break;
      default:
        bg = const Color(0xFFE9F1FF);
        fg = kAgilaBlue;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg, fontWeight: FontWeight.w600, fontSize: 12,
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  const _SortChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showCTA;
  final VoidCallback onCreate;
  const _EmptyState({required this.showCTA, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined, size: 64, color: Colors.black26),
        const SizedBox(height: 12),
        const Text('No requests found', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Try adjusting filters or create a new request.',
            style: TextStyle(color: Colors.black54)),
        if (showCTA) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Request'),
            style: ElevatedButton.styleFrom(
                backgroundColor: kAgilaGold, foregroundColor: Colors.white),
            onPressed: onCreate,
          ),
        ]
      ]),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE9F1FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                color: selected ? kAgilaBlue : Colors.black87,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 6),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kAgilaBlue, borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// Optional slide backgrounds for swipe actions
Widget _slideApprove() => Container(
  decoration: BoxDecoration(
    color: const Color(0xFFE6F6EA), borderRadius: BorderRadius.circular(12),
  ),
  alignment: Alignment.centerLeft,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: const Row(
    children: [Icon(Icons.check, color: Colors.green), SizedBox(width: 6), Text('Approve')],
  ),
);

Widget _slideReject() => Container(
  decoration: BoxDecoration(
    color: const Color(0xFFFDEBEC), borderRadius: BorderRadius.circular(12),
  ),
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: const Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [Text('Reject'), SizedBox(width: 6), Icon(Icons.close, color: Colors.red)],
  ),
);
