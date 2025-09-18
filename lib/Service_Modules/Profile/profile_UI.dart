// Service_Modules/Profile/profile_UI.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

class PrimaryButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: padding,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: Text(text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
    );
  }
}

class DetailsCard extends StatelessWidget {
  final List<Widget> children;

  const DetailsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        border: Border.all(color: kAgilaBlue, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const InfoCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kAgilaBlue, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16, color: kAgilaBlue)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ReadonlyTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const ReadonlyTile({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: kAgilaBlue),
      title: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(value ?? '—', style: GoogleFonts.poppins()),
    );
  }
}

/// Same visual as ReadonlyTile but with a trailing pencil to edit.
class EditableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onEdit;

  const EditableTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: kAgilaBlue),
      title: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(value ?? '—', style: GoogleFonts.poppins()),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: kAgilaBlue),
        tooltip: 'Edit',
        onPressed: onEdit,
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onUpload;

  const ProfileAvatar({super.key, required this.imageUrl, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: kAgilaBlue.withOpacity(.08),
          backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty) ? NetworkImage(imageUrl!) : null,
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? Icon(Icons.person, color: kAgilaBlue.withOpacity(.6), size: 42)
              : null,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAgilaGold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text('Upload Profile Photo', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}

class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? subtitle;
  final VoidCallback onEditPhoto;
  final String? imageUrl; // NEW: optional URL for the avatar

  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.subtitle,
    required this.onEditPhoto,
    this.imageUrl,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kAgilaBlue, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: kAgilaGold.withOpacity(.15),
                  backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? NetworkImage(imageUrl!)
                      : null,
                  child: (imageUrl == null || imageUrl!.isEmpty)
                      ? Text(initials,
                      style: GoogleFonts.poppins(
                          fontSize: 22, fontWeight: FontWeight.w700))
                      : null,
                ),
                // Pencil edit button over the avatar (top-right)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onEditPhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit, size: 16, color: kAgilaBlue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + role chip
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kAgilaBlue.withOpacity(.08),
                          border: Border.all(color: kAgilaBlue, width: 1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: kAgilaBlue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if ((subtitle ?? '').isNotEmpty)
                    Text(
                      subtitle!,
                      style: GoogleFonts.poppins(color: Colors.black.withOpacity(.65)),
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
