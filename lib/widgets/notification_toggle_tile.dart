import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../services/notification_service.dart';
import '../utils/l10n.dart';

/// Row in the About sheet that toggles local notifications after a parental gate.
class NotificationToggleTile extends ConsumerStatefulWidget {
  const NotificationToggleTile({super.key});

  @override
  ConsumerState<NotificationToggleTile> createState() =>
      _NotificationToggleTileState();
}

class _NotificationToggleTileState
    extends ConsumerState<NotificationToggleTile> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await NotificationService.instance.isEnabled;
    if (mounted) setState(() { _enabled = enabled; _loaded = true; });
  }

  Future<void> _toggle() async {
    if (!mounted) return;
    final newValue = !_enabled;
    final lang = ref.read(languageProvider);
    await NotificationService.instance.setEnabled(newValue, lang: lang);
    if (mounted) setState(() => _enabled = newValue);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final s = AppS(ref.watch(languageProvider) == 'en');
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _enabled
            ? Icons.notifications_active
            : Icons.notifications_off_outlined,
        size: 18,
      ),
      label: Text(_enabled
          ? s('Сповіщення увімкнено', 'Notifications on')
          : s('Увімкнути сповіщення', 'Enable notifications')),
    );
  }
}
