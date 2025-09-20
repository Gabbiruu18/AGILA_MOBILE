// Service_Modules/Profile/profile_UI.dart
import 'package:flutter/material.dart';
const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

class PrimaryButton extends StatelessWidget {
  final String text;
  final Color? color; // make optional
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  const PrimaryButton({
    super.key,
    required this.text,
    this.color,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? cs.primary,
        padding: padding,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onPrimary, // text for primary-colored button
          fontSize: 16,
        ),
      ),
    );
  }
}


class DetailsCard extends StatelessWidget {
  final List<Widget> children;
  const DetailsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      // no color: uses CardTheme.color (we set it to neutral in your theme)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.6), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
    final cs = Theme.of(context).colorScheme;
    return Card(
      // color: cs.surface, // optional; CardTheme already supplies neutral surface
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.6), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                // use primary if you want colored title that adapts per theme
                color: cs.primary,
              ),
            ),
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
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(value ?? '—', style: Theme.of(context).textTheme.bodyMedium?.copyWith()),
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
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(value ?? '—', style: Theme.of(context).textTheme.bodyMedium?.copyWith()),
      trailing: IconButton(
        icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
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
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.08),
          backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty) ? NetworkImage(imageUrl!) : null,
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary.withOpacity(.6), size: 42)
              : null,
        ),
        SizedBox(height: 12),
        ElevatedButton(
          onPressed: onUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text('Upload Profile Photo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
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
  final Color? subtitleColor; // ✅ NEW


  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.subtitle,
    required this.onEditPhoto,
    this.imageUrl,
    this.subtitleColor, // ✅ NEW


  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;


    return Card(
      // color: cs.surface, // optional; let CardTheme handle it
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.6), width: 1.2),
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
                  backgroundColor: cs.secondary.withOpacity(.15),
                  backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? NetworkImage(imageUrl!)
                      : null,
                  child: (imageUrl == null || imageUrl!.isEmpty)
                      ? Text(
                    initials,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 22, fontWeight: FontWeight.w700,
                    ),
                  )
                      : null,
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Material(
                    color: cs.surface, // not onPrimary; matches card
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: CircleBorder(),
                      onTap: onEditPhoto,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary), // inherits iconTheme color
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(.08),
                          border: Border.all(color: cs.primary, width: 1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: subtitleColor ?? cs.onSurface.withOpacity(.65), // ✅ color override
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
