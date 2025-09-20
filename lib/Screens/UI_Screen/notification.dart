import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationModal extends StatelessWidget {
  final String uid;
  final String role;

  const NotificationModal({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      //backgroundColor: const Color(0xFFF2F5FA),
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
                future: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('recipientRole', isEqualTo: role)
                    .where('recipientUid', isEqualTo: uid)
                    .orderBy('timestamp', descending: true)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                      return ListTile(
                        title: Text(
                          data['title'] ?? 'No Title',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          data['message'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(color: const Color(0xFF0045A2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
