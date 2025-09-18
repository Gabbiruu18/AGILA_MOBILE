import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    default:
      return Colors.black54;
  }
}

Stream<QuerySnapshot> requestHistoryStream({
  required String uid,
  required String role,
}) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(role)
      .collection('accounts')
      .doc(uid)
      .collection('History')
      .orderBy('timestamp', descending: true)
      .snapshots();
}
