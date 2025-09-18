// Screens/UI_Screen/profile.dart (or Service_Modules/Profile/profile.dart if that's your path)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      case 'academic_head':
      case 'academichead':
        return 'Academic Head';
      case 'admin':
      case 'administrator':
        return 'Admin';
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


    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7FB),
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
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: kAgilaBlue,
        title: Text('Profile',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
        // NEW: settings button (top-right)
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              //route to your settings screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings tapped')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          if (controller.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 12),

          // Header (kept your visual style; now also shows photo if any)
          ProfileHeaderCard(
            name: controller.displayName,
            roleLabel: roleLabel,
            subtitle: isStaff ? staffheaderSubtitle : studheaderSubtitle,
            imageUrl: controller.profileImageUrl, // NEW
            onEditPhoto: () async => controller.pickAndUploadImage(context),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 16),

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
                  leading: const Icon(Icons.menu_book_outlined, color: kAgilaBlue),
                  title: Text('Subjects Handled',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text((data['subjects'] as List).join(' • '),
                      style: GoogleFonts.poppins()),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Tools (show for staff or everyone if you prefer)
          InfoCard(
            title: 'Tools',
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text('Logout',
                    style: GoogleFonts.poppins(
                        color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () async {
                  await controller.logout(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
