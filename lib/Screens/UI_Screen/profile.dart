import 'package:flutter/material.dart';
import 'package:project_agila/Screens/UI_Screen/settings.dart';
import 'package:project_agila/Service_Modules/Profile/profile_controller.dart';
import 'package:project_agila/Service_Modules/Profile/profile_UI.dart';


const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

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
    // kick off load
    controller.init(role: widget.role, uid: widget.uid);
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose(); // <-- add this
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
      // prettify whatever was stored in DB (e.g., "registrar head")
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



// ✅ compute staff here (now you have the role)
    final isStaff = normalizedRole == 'teacher'
        || normalizedRole == 'teachers'
        || normalizedRole == 'program_head'
        || normalizedRole == 'programhead'
        || normalizedRole == 'academic_head'
        || normalizedRole == 'academichead';

// keep your subtitle as-is
    final studheaderSubtitle = data['sectionName'] as String?;
    final staffheaderSubtitle = data['departmentName'] as String?;


    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
        //backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Theme.of(context).colorScheme.primary,
        title: Text('Profile', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 24, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              showSettingsSheet(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 5),
        children: [
          if (controller.isSyncing)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SizedBox(height: 12),

          // Header
          ProfileHeaderCard(
            name: controller.displayName,
            roleLabel: roleLabel,
            subtitle: isStaff ? staffheaderSubtitle : studheaderSubtitle,
            imageUrl: controller.profileImageUrl,
            onEditPhoto: () async => controller.pickAndUploadImage(context),
            subtitleColor: Theme.of(context).colorScheme.primary,

          ),
          SizedBox(height: 16),

          // Personal Info
          InfoCard(
            title: 'Personal Info',
            children: [
              ReadonlyTile(
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: controller.displayName),
              ReadonlyTile(
                  icon: Icons.mail_outline, label: 'Email', value: data['email']),
              // NEW: make Contact editable with a pencil
              EditableTile(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: data['contact'] ?? data['phone'],
                onEdit: () => controller.editContact(context),
              ),
            ],
          ),
          SizedBox(height: 16),

          // School / Work Info
          InfoCard(
            title: isStudent ? 'School Info' : 'Work Info',
            children: isStudent
                ? [
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
                  icon: Icons.apartment_outlined,
                  label: 'Department',
                  value: data['department']),
              if ((data['subjects'] is List) &&
                  (data['subjects'] as List).isNotEmpty)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.menu_book_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text('Subjects Handled',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text((data['subjects'] as List).join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith()),
                ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
