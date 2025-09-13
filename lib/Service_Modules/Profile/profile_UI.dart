import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onUpload;

  const ProfileAvatar({super.key, required this.imageUrl, required this.onUpload});


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 100,
          backgroundColor: Colors.grey[400],
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child: imageUrl == null
              ? const Icon(Icons.person, size: 60, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC88000),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text('Upload Profile Photo', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}

class DetailsCard extends StatelessWidget {
  final List<Widget> children;

  const DetailsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        border: Border.all(color: const Color(0xFF0058CE), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class LabeledText extends StatelessWidget {
  final String label;
  final String value;

  const LabeledText({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text('$label: $value', style: GoogleFonts.poppins(fontSize: 14)),
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry radius;

  const PrimaryActionButton({
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EEF5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: kAgilaBlue)),
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

class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String roleLabel;     // Student | Teacher | Program Head | Academic Head
  final String? subtitle;     // Student: "Course • Section" ; Teacher/Heads: Department
  final VoidCallback onEditPhoto;

  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.subtitle,
    required this.onEditPhoto,
  });

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EEF5)),
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
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                // Pencil edit button (over the avatar, top-right)
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
                // Role pill (kept on avatar, bottom-right)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kAgilaGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      roleLabel,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Name + subtitle expand naturally now that the trailing button is gone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
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