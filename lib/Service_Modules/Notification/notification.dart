import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationModal extends StatefulWidget {
  final String uid;
  final String role;

  const NotificationModal({super.key, required this.uid, required this.role});

  @override
  State<NotificationModal> createState() => _NotificationModalState();
}

class _NotificationModalState extends State<NotificationModal> {
  Key _futureBuilderKey = UniqueKey();
  bool _isClearing = false;

  // Helper to get the correct collection reference
  CollectionReference get _notificationsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.role)
      .collection('accounts')
      .doc(widget.uid)
      .collection('notifications');

  Future<void> _clearAllNotifications() async {
    setState(() => _isClearing = true);

    try {
      final snapshot = await _notificationsCollection.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _isClearing = false);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      setState(() {
        _futureBuilderKey = UniqueKey();
        _isClearing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.')),
        );
      }

    } catch (e) {
      setState(() => _isClearing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Notifications',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF0045A2),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                key: _futureBuilderKey,
                // --- MODIFIED: Point directly to the user's subcollection ---
                future: _notificationsCollection
                    .orderBy('timestamp', descending: true)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: GoogleFonts.poppins(),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications found.',
                        style: GoogleFonts.poppins(),
                      ),
                    );
                  }

                  final notifications = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final data = notifications[index].data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'] as Timestamp?;
                      final dateTime = timestamp?.toDate();

                      return ListTile(
                        title: Text(
                          data['title'] ?? 'No Title',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['message'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            if (dateTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  // Simple date/time formatting
                                  '${dateTime.toLocal().day}/${dateTime.toLocal().month} at ${dateTime.toLocal().hour.toString().padLeft(2, '0')}:${dateTime.toLocal().minute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isClearing ? null : _clearAllNotifications,
                    child: _isClearing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(
                      'Clear All',
                      style: GoogleFonts.poppins(color: Colors.red.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(color: const Color(0xFF0045A2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}