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
    controller = ProfileController();
    controller.addListener(_onChanged);
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

  // Helper: treat these roles as staff (Tools card visible)
  bool _isStaffRole(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    const staff = {
      'teacher',
      'teachers',        // tolerate plural
      'program head',
      'program_head',
      'academic head',
      'academic_head',
      'acadamic head',   // tolerate your earlier typo
    };
    return staff.contains(r);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = controller.isLoading;
    final data = controller.profileData;
    final roleRaw = controller.role;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final roleLabel = switch ((roleRaw).toLowerCase()) {
      'student' => 'Student',
      'teacher' => 'Teacher',
      'program_head' || 'program head' => 'Program Head',
      'academic_head' || 'academic head' => 'Academic Head',
      _ => 'User',
    };

    final isStudent = roleRaw.toLowerCase() == 'student';

    // Avoid stray bullet if either course/section is missing
    final headerSubtitle = isStudent
        ? [data['role'], data['sectionName']]
        .where((e) => (e != null && e.toString().trim().isNotEmpty))
        .join(' • ')
        : (data['departmentName'] as String?);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF0058CE),
        title: Text('Profile', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          ProfileHeaderCard(
            name: controller.displayName,
            roleLabel: roleLabel,
            subtitle: headerSubtitle,
            onEditPhoto: () async {
              await controller.pickAndUploadImage(context);
            },
          ),
          const SizedBox(height: 16),

          // Personal Info
          InfoCard(
            title: 'Personal Info',
            children: [
              ReadonlyTile(icon: Icons.badge_outlined, label: 'Name', value: controller.displayName),
              ReadonlyTile(icon: Icons.mail_outline, label: 'Email', value: data['email']),
              ReadonlyTile(icon: Icons.phone_outlined, label: 'Contact', value: data['contact'] ?? data['phone']),
            ],
          ),
          const SizedBox(height: 16),

          // School Info
          InfoCard(
            title: 'School Info',
            children: isStudent
                ? [
              ReadonlyTile(icon: Icons.computer_outlined, label: 'Course', value: data['courseAcronym']),
              ReadonlyTile(icon: Icons.calendar_month_outlined, label: 'Year Level', value: data['yearLevelName']),
              ReadonlyTile(icon: Icons.group_outlined, label: 'Section', value: data['sectionName']),
            ]
                : [
              ReadonlyTile(icon: Icons.apartment_outlined, label: 'Department', value: data['department']),
              if ((data['subjects'] is List) && (data['subjects'] as List).isNotEmpty)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book_outlined, color: Color(0xFF0058CE)),
                  title: Text('Subjects Handled', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text((data['subjects'] as List).join(' • '), style: GoogleFonts.poppins()),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Tools — visible only to staff roles
          if (_isStaffRole(roleRaw))
            InfoCard(
              title: 'Tools',
              children: [
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural, color: Color(0xFF0058CE)),
                  title: Text('Face Recognition Tester', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/face-recognition-tester');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Open Face Recognition Tester')),
                    );
                  },
                ),
              ],
            ),
          if (_isStaffRole(roleRaw)) const SizedBox(height: 16),

          // Account
          InfoCard(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text('Logout', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
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
