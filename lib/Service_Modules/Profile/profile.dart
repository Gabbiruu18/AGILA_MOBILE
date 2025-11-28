import 'package:flutter/material.dart';
import 'package:project_agila/Service_Modules/Settings/settings.dart';
import 'package:project_agila/Service_Modules/Profile/profile_controller.dart';
import 'package:project_agila/Service_Modules/Profile/profile_UI.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final String uid;

  const ProfileScreen({super.key, required this.role, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController controller;

  @override
  void initState() {
    super.initState();
    controller = ProfileController()..addListener(_onChanged);
    controller.init(role: widget.role, uid: widget.uid);
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _normalizeRole(String? role) =>
      (role ?? '').trim().toLowerCase().replaceAll(' ', '_');

  String _roleLabelFromRole(String normalizedRole) {
    switch (normalizedRole) {
      case 'student':
        return 'Student';
      case 'teacher':
      case 'teachers':
        return 'Teacher';
      case 'program_head':
      case 'programhead':
        return 'Program Head';
      default:
        return normalizedRole
            .split('_')
            .map((w) => w.isEmpty ? '' : (w[0].toUpperCase() + w.substring(1)))
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = controller.isLoading;
    final data = controller.profileData;
    final roleRaw = controller.role;
    final cs = Theme.of(context).colorScheme;



    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final normalizedRole = _normalizeRole(roleRaw);
    final isStudent = normalizedRole == 'student';

    final roleLabel = _roleLabelFromRole(normalizedRole);

    final isStaff = normalizedRole == 'teacher'
        || normalizedRole == 'teachers'
        || normalizedRole == 'program_head'
        || normalizedRole == 'programhead';

    final studheaderSubtitle = data['sectionName'] as String?;
    final staffheaderSubtitle = data['departmentName'] as String?;


    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Theme.of(context).colorScheme.primary,
        title: Text('Profile', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 24, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              showSettingsSheet(context, role: widget.role, uid: widget.uid);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 5),
        children: [
          if (controller.isBusy)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SizedBox(height: 12),
          ProfileHeaderCard(
            name: controller.displayName,
            roleLabel: roleLabel,
            subtitle: isStaff ? staffheaderSubtitle : studheaderSubtitle,
            imageUrl: controller.profileImageUrl,
            onEditPhoto: () async => controller.pickAndUploadImage(context),
            subtitleColor: Theme.of(context).colorScheme.primary,

          ),
          SizedBox(height: 16),

          InfoCard(
            title: 'Personal Info',
            children: [
              ReadonlyTile(
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: controller.displayName),
              ReadonlyTile(
                  icon: Icons.mail_outline, label: 'Email', value: data['email']),
              EditableTile(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: data['contact'] ?? data['phone'],
                onEdit: () => controller.editContact(context),
              ),
            ],
          ),
          SizedBox(height: 16),

          InfoCard(
            title: isStudent ? 'School Info' : 'Work Info',
            children: isStudent
                ? [
              ReadonlyTile(
                  icon: Icons.perm_identity_outlined,
                  label: 'Student No.',
                  value: data['studentNumber']),
              ReadonlyTile(
                  icon: Icons.card_membership,
                  label: 'Academic Status',
                  value: data['academicStatus']),
              ReadonlyTile(
                  icon: Icons.computer_outlined,
                  label: 'Course',
                  value: data['courseAcronym']),
              ReadonlyTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Year Level',
                  value: data['yearLevelName']),
              ReadonlyTile(
                  icon: Icons.group_outlined,
                  label: 'Section',
                  value: data['sectionName']),
            ]
                : [
              ReadonlyTile(
                  icon: Icons.perm_identity_outlined,
                  label: 'Employee No.',
                  value: data['employeeNumber']),
              ReadonlyTile(
                  icon: Icons.apartment_outlined,
                  label: 'Department',
                  value: data['department']),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}