import 'dart:async'; // Import the async library for the Timer

import 'package:flutter/material.dart';
import 'package:project_agila/Service_Modules/Request/request_UI.dart';
import 'package:project_agila/Service_Modules/Request/request_controller.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_agila/Service_Modules/Request/addRequest.dart';
import 'history.dart';

class RequestListScreen extends StatefulWidget {
  final String uid;
  final String role;
  final String name;
  final String academicYearId;
  final String acadYear;
  final String semesterId;
  final String semesterName;

  const RequestListScreen({
    Key? key,
    required this.uid,
    required this.role,
    required this.name,
    required this.academicYearId,
    required this.acadYear,
    required this.semesterId,
    required this.semesterName,
  }) : super(key: key);



  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  late final RequestController _controller;
  Timer? _debounce; // Add a Timer for debouncing

  @override
  void initState() {
    super.initState();
    _controller = RequestController(
      uid: widget.uid,
      role: widget.role,
      name: widget.name,
      onStateUpdate: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Important: cancel the timer to avoid memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const RequestScreenTitle(),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.secondary),
            tooltip: 'Add Request',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddRequestModal(
                uid: widget.uid,
                role: widget.role,
                name: widget.name,
                academicYearId: widget.academicYearId,
                acadYear: widget.acadYear,
                semesterId: widget.semesterId,
                semesterName: widget.semesterId,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
            tooltip: 'History',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => RequestHistoryModal(
                uid: widget.uid,
                role: widget.role,
                name: widget.name,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          if (_controller.isStaff)
            RequestTabs(
              sentQuery: _controller.sentQuery(),
              receivedQuery: _controller.receivedQuery(),
              showSent: _controller.showSent,
              onTabSelected: (isSent) => _controller.setShowSent(isSent),
              pendingCountFromSnap: _controller.pendingCountFromSnap,
            ),
          RequestToolbar(
            onQueryChanged: (q) {
              // Debounce logic: wait for 500ms of inactivity before searching
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                _controller.setQuery(q);
              });
            },
            onSortChanged: (isNewest) => _controller.setNewestFirst(isNewest),
            newestFirst: _controller.newestFirst,
          ),
          RequestFilterChips(
            statusFilter: _controller.statusFilter,
            onFilterChanged: (status) => _controller.setStatusFilter(status),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: (_controller.showSent || !_controller.isStaff)
                  ? _controller.sentQuery().snapshots()
                  : _controller.receivedQuery().snapshots(),
              builder: (context, snapshot) {
                final filteredDocs = snapshot.hasData
                    ? _controller.filterDocuments(snapshot.data!.docs)
                    : <DocumentSnapshot>[];

                return RequestList(
                  snapshot: snapshot,
                  filteredDocs: filteredDocs,
                  itemBuilder: _controller.buildRequestItem,
                  showCTA: !_controller.isStaff || _controller.showSent,
                  onCreate: () => showDialog(
                    context: context,
                    builder: (_) => AddRequestModal(
                      uid: widget.uid,
                      role: widget.role,
                      name: widget.name,
                      academicYearId: widget.academicYearId,
                      acadYear: widget.acadYear,
                      semesterId: widget.semesterId,
                      semesterName: widget.semesterId,
                    ),
                  ),
                  onRefresh: () async {
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}