import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ========== APP BAR & TOOLBAR WIDGETS ==========

class RequestScreenTitle extends StatelessWidget {
  const RequestScreenTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
        'Requests',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith
          (color: Theme.of(context).colorScheme.primary,
            fontSize: 24, fontWeight: FontWeight.w700)
    );
  }
}

class RequestTabs extends StatelessWidget {
  final Query sentQuery;
  final Query receivedQuery;
  final bool showSent;
  final Function(bool) onTabSelected;
  final int Function(AsyncSnapshot<QuerySnapshot>) pendingCountFromSnap;

  const RequestTabs({
    super.key,
    required this.sentQuery,
    required this.receivedQuery,
    required this.showSent,
    required this.onTabSelected,
    required this.pendingCountFromSnap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => onTabSelected(true),
                borderRadius: BorderRadius.circular(12),
                child: StreamBuilder<QuerySnapshot>(
                  stream: sentQuery.snapshots(),
                  builder: (_, snap) => TabItem(
                    label: 'Sent',
                    selected: showSent,
                    badge: pendingCountFromSnap(snap),
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => onTabSelected(false),
                borderRadius: BorderRadius.circular(12),
                child: StreamBuilder<QuerySnapshot>(
                  stream: receivedQuery.snapshots(),
                  builder: (_, snap) => TabItem(
                    label: 'Received',
                    selected: !showSent,
                    badge: pendingCountFromSnap(snap),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestToolbar extends StatelessWidget {
  final Function(String) onQueryChanged;
  final Function(bool) onSortChanged;
  final bool newestFirst;

  const RequestToolbar({
    super.key,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.newestFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
            onSelected: (v) => onSortChanged(v == 'Newest'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Newest', child: Text('Newest first')),
              PopupMenuItem(value: 'Oldest', child: Text('Oldest first')),
            ],
            child: SortChip(label: newestFirst ? 'Newest' : 'Oldest'),
          ),
        ],
      ),
    );
  }
}

class RequestFilterChips extends StatelessWidget {
  final String statusFilter;
  final Function(String) onFilterChanged;

  const RequestFilterChips({super.key, required this.statusFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: ['All', 'Pending', 'Approved', 'Rejected']
            .map((s) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedColor: Theme.of(context).colorScheme.surfaceContainer,
            label: Text(s),
            selected: statusFilter == s,
            onSelected: (_) => onFilterChanged(s),
          ),
        ))
            .toList(),
      ),
    );
  }
}

// ========== CARD & LIST ITEM WIDGETS ==========

class RequestCard extends StatelessWidget {
  final String type;
  final String status;
  final String toText;
  final String fromText;
  final DateTime timestamp;
  final String remarks;
  final bool isSentView;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const RequestCard({
    super.key,
    required this.type,
    required this.status,
    required this.toText,
    required this.fromText,
    required this.timestamp,
    required this.remarks,
    required this.isSentView,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = isSentView ? toText : fromText;
    final showRemarks = (status == 'Approved' || status == 'Rejected') && remarks.isNotEmpty;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.surface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(type,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        )),
                  ),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.access_time, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    _formatTimestamp(timestamp), // Use new timestamp formatter
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              if (showRemarks) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Remarks: $remarks',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                            backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white),
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
}

/// A placeholder card to show while content is loading.
class RequestCardSkeleton extends StatelessWidget {
  const RequestCardSkeleton({super.key});

  Widget _buildPlaceholder(BuildContext context, {double? width, double height = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildPlaceholder(context, width: 150)),
              const SizedBox(width: 16),
              _buildPlaceholder(context, width: 80, height: 28),
            ],
          ),
          const SizedBox(height: 10),
          _buildPlaceholder(context, width: 220),
        ],
      ),
    );
  }
}


// ========== CHIP & BADGE WIDGETS ==========

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    switch (s) {
      case 'approved':
        bg = Theme.of(context).colorScheme.surface;
        fg = const Color(0xFF1F8E3A);
        break;
      case 'rejected':
        bg = Theme.of(context).colorScheme.surface;
        fg = const Color(0xFFD12D33);
        break;
      default:
        bg = Theme.of(context).colorScheme.surface;
        fg = Theme.of(context).colorScheme.primary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class SortChip extends StatelessWidget {
  final String label;
  const SortChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer),
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

class TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;

  const TabItem({
    super.key,
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
        color: selected ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 6),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$badge',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ========== STATE & LAYOUT WIDGETS ==========

class RequestList extends StatelessWidget {
  final AsyncSnapshot<QuerySnapshot> snapshot;
  final List<DocumentSnapshot> filteredDocs;
  final Widget Function(BuildContext, DocumentSnapshot) itemBuilder;
  final bool showCTA;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  const RequestList({
    super.key,
    required this.snapshot,
    required this.filteredDocs,
    required this.itemBuilder,
    required this.showCTA,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(child: Text('Something went wrong: ${snapshot.error}'));
    }
    // Show skeleton loaders when waiting for data
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: 5, // Show 5 skeleton cards
        itemBuilder: (context, index) => const RequestCardSkeleton(),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
      );
    }
    if (filteredDocs.isEmpty) {
      return EmptyState(showCTA: showCTA, onCreate: onCreate);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filteredDocs.length,
        itemBuilder: (context, index) => itemBuilder(context, filteredDocs[index]),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final bool showCTA;
  final VoidCallback onCreate;
  const EmptyState({super.key, required this.showCTA, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inbox_outlined, size: 64),
        const SizedBox(height: 12),
        const Text('No requests found', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Try adjusting filters or create a new request.'),
        if (showCTA) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Create Request'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white),
            onPressed: onCreate,
          ),
        ]
      ]),
    );
  }
}

class RequestDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isStaff;
  final bool isReceived;
  final Function(String, String?) onUpdateStatus;

  const RequestDetailsSheet({
    super.key,
    required this.data,
    required this.isStaff,
    required this.isReceived,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    // --- Start of fix ---
    // Safely parse sender and recipient info
    String senderRole = data['role'] ?? '';
    String recipientRole = data['recipientRole'] ?? '';

    // Fallback for older documents: Intelligently find roles from keys
    if (senderRole.isEmpty) {
      final fromKey = data.keys.firstWhere((k) => k.startsWith('from') && k.endsWith('Id'), orElse: () => '');
      if (fromKey.isNotEmpty) {
        senderRole = fromKey.replaceAll('from', '').replaceAll('Id', '').toLowerCase();
      }
    }
    if (recipientRole.isEmpty) {
      final toKey = data.keys.firstWhere((k) => k.startsWith('to') && k.endsWith('Id'), orElse: () => '');
      if (toKey.isNotEmpty) {
        recipientRole = toKey.replaceAll('to', '').replaceAll('Id', '').toLowerCase();
      }
    }

    final senderRoleKey = senderRole.isNotEmpty ? senderRole[0].toUpperCase() + senderRole.substring(1) : '';
    final recipientRoleKey = recipientRole.isNotEmpty ? recipientRole[0].toUpperCase() + recipientRole.substring(1).replaceAll('_', '') : '';

    final fromName = data['from${senderRoleKey}Name'] ?? 'Unknown';
    final toName = data['to${recipientRoleKey}Name'] ?? '—';
    // --- End of fix ---

    final type = (data['type'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'Pending').toString();
    final ts = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final reason = (data['reason'] ?? '').toString();

    final decision = data['teacherDecision'] as Map<String, dynamic>? ?? {};
    final decisionRemarks = (decision['remarks'] ?? '').toString();

    final attachments = (data['attachments'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: StatusChip(status: status)),
          const SizedBox(height: 8),
          ListTile(
            title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat.yMMMd().add_jm().format(ts)),
          ),
          const Divider(),
          _kv('To', toName),
          _kv('From', '$fromName (${senderRole.isEmpty ? '—' : senderRole})'),
          _kv('Reason', reason.isEmpty ? '—' : reason),
          if (decisionRemarks.isNotEmpty) _kv('Decision Remarks', decisionRemarks),
          _buildAttachmentsList(context, attachments),
          const SizedBox(height: 12),
          if (status == 'Pending' && isStaff && isReceived)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    onPressed: () async {
                      final reason = await showDialog<String>(
                        context: context,
                        builder: (context) => DecisionRemarksDialog(isApproved: false),
                      );
                      if (reason != null) {
                        onUpdateStatus('Rejected', reason);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    onPressed: () async {
                      final reason = await showDialog<String>(
                        context: context,
                        builder: (context) => DecisionRemarksDialog(isApproved: true),
                      );
                      if (reason != null) {
                        onUpdateStatus('Approved', reason);
                      }
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAttachmentsList(BuildContext context, List<dynamic> attachments) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 90,
            child: Text(
              'Attachments',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: attachments.isEmpty
                ? const Text('—')
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: attachments.map((attachment) {
                final String name = attachment['name'] ?? 'Unknown file';
                final String url = attachment['url'] ?? '';

                if (url.isEmpty) {
                  return Text(name, style: const TextStyle(color: Colors.grey));
                }

                return InkWell(
                  onTap: () async {
                    final Uri uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open attachment: $url')),
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, softWrap: true)),
        ],
      ),
    );
  }
}

// ========== DISMISSIBLE BACKGROUNDS ==========

Widget slideApprove() => Container(
  decoration: BoxDecoration(
    color: const Color(0xFFE6F6EA),
    borderRadius: BorderRadius.circular(12),
  ),
  alignment: Alignment.centerLeft,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: const Row(
    children: [Icon(Icons.check, color: Colors.green), SizedBox(width: 6), Text('Approve')],
  ),
);

Widget slideReject() => Container(
  decoration: BoxDecoration(
    color: const Color(0xFFFDEBEC),
    borderRadius: BorderRadius.circular(12),
  ),
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: const Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [Text('Reject'), SizedBox(width: 6), Icon(Icons.close, color: Colors.red)],
  ),
);

/// A dialog that prompts the user for remarks for a decision.
class DecisionRemarksDialog extends StatefulWidget {
  final bool isApproved;
  const DecisionRemarksDialog({super.key, required this.isApproved});

  @override
  State<DecisionRemarksDialog> createState() => _DecisionRemarksDialogState();
}

class _DecisionRemarksDialogState extends State<DecisionRemarksDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isApproved ? 'Approve with Remarks' : 'Reject with Remarks'),
      content: TextFormField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Provide remarks (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

// ========== HELPERS ==========

/// Formats a timestamp into a more readable, relative format.
String _formatTimestamp(DateTime ts) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final date = DateTime(ts.year, ts.month, ts.day);

  if (date == today) {
    return DateFormat.jm().format(ts); // '4:30 PM'
  }
  if (date == yesterday) {
    return 'Yesterday';
  }
  // If within the last week, show weekday
  if (now.difference(ts).inDays < 7) {
    return DateFormat.EEEE().format(ts); // 'Tuesday'
  }
  // Otherwise, show the date
  return DateFormat.yMMMd().format(ts); // 'Sep 21, 2025'
}