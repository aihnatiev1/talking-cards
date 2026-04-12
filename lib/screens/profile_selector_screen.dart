import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_model.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';

// ─────────────────────────────────────────────
//  Profile selector bottom sheet
// ─────────────────────────────────────────────

/// Shows the profile list + add/edit actions as a modal bottom sheet.
Future<void> showProfileSelector(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ProfileSelectorSheet(),
  );
}

class _ProfileSelectorSheet extends ConsumerWidget {
  const _ProfileSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final s = AppS(ref.watch(languageProvider) == 'en');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s('Профілі', 'Profiles'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 16),
          // Profile list
          ...state.profiles.map((profile) => _ProfileTile(
                profile: profile,
                isActive: profile.id == state.activeId,
                onTap: () {
                  ref.read(profileProvider.notifier).switchProfile(profile.id);
                  Navigator.of(context).pop();
                },
                onEdit: () => _showEditDialog(context, ref, profile, s.isEn),
                onDelete: state.profiles.length > 1
                    ? () => _confirmDelete(context, ref, profile, s.isEn)
                    : null,
              )),
          if (state.profiles.length < 3) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCreateDialog(context, ref, s.isEn),
                icon: const Icon(Icons.add_rounded),
                label: Text(s('Додати профіль', 'Add profile')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref, bool isEn) async {
    final loc = AppS(isEn);
    final result = await showDialog<(String, String, String)?>(
      context: context,
      builder: (_) => _ProfileEditDialog(title: loc('Новий профіль', 'New profile'), isEn: isEn),
    );
    if (result != null) {
      await ref
          .read(profileProvider.notifier)
          .addProfile(result.$1, result.$2, language: result.$3);
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, ProfileModel profile, bool isEn) async {
    final loc = AppS(isEn);
    final result = await showDialog<(String, String, String)?>(
      context: context,
      builder: (_) => _ProfileEditDialog(
        title: loc('Редагувати', 'Edit'),
        initialName: profile.name,
        initialAvatar: profile.avatarEmoji,
        initialLanguage: profile.language,
        isEn: isEn,
      ),
    );
    if (result != null) {
      await ref
          .read(profileProvider.notifier)
          .updateProfile(profile.id, result.$1, result.$2);
      if (result.$3 != profile.language) {
        await ref
            .read(profileProvider.notifier)
            .setLanguage(profile.id, result.$3);
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ProfileModel profile, bool isEn) async {
    final s = AppS(isEn);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('Видалити профіль?', 'Delete profile?')),
        content: Text(s(
          'Весь прогрес "${profile.name}" буде видалено. Це незворотно.',
          'All progress for "${profile.name}" will be deleted. This cannot be undone.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s('Скасувати', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s('Видалити', 'Delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(profileProvider.notifier).deleteProfile(profile.id);
    }
  }
}

// ─────────────────────────────────────────────
//  Profile tile
// ─────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final ProfileModel profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? kAccent.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: kAccent.withValues(alpha: 0.35), width: 1.5)
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? kAccent.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(profile.avatarEmoji,
                style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(
          profile.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? kAccent : null,
          ),
        ),
        subtitle: Text(
          profile.flagEmoji +
              (profile.language == 'en' ? ' English' : ' Українська'),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Icon(Icons.check_circle_rounded,
                  color: kAccent, size: 20),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: Colors.grey[500]),
              onPressed: onEdit,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Edit / Create dialog
// ─────────────────────────────────────────────

class _ProfileEditDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialAvatar;
  final String? initialLanguage;
  final bool isEn;

  const _ProfileEditDialog({
    required this.title,
    this.initialName,
    this.initialAvatar,
    this.initialLanguage,
    this.isEn = false,
  });

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedAvatar;
  late String _selectedLang;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _selectedAvatar = widget.initialAvatar ?? kAvatarEmojis.first;
    _selectedLang = widget.initialLanguage ?? 'uk';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameCtrl,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: s("Ім'я дитини", "Child's name"),
                border: const OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            // Language selector
            Text(s('Мова карток', 'Card language'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _langChip('uk', '🇺🇦 Українська'),
                const SizedBox(width: 8),
                _langChip('en', '🇬🇧 English'),
              ],
            ),
            const SizedBox(height: 16),
            // Avatar grid
            Text(s('Аватар', 'Avatar'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAvatarEmojis.map((emoji) {
                final isSelected = emoji == _selectedAvatar;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAvatar = emoji);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kAccent.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: kAccent, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s('Скасувати', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _nameCtrl.text.trim().isEmpty
              ? null
              : () => Navigator.of(context)
                  .pop((_nameCtrl.text.trim(), _selectedAvatar, _selectedLang)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: Colors.white,
          ),
          child: Text(s('Зберегти', 'Save')),
        ),
      ],
    );
  }

  Widget _langChip(String lang, String label) {
    final selected = _selectedLang == lang;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedLang = lang);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? kAccent.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: kAccent, width: 2) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? kAccent : null,
          ),
        ),
      ),
    );
  }
}
