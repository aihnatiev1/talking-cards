import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';

/// Asks the parent about daily reminders — once, in the app, with a reason.
///
/// The OS permission dialog used to be awaited inside the splash init, so a
/// fresh install met an unexplained system prompt over a loading screen;
/// analytics named `notifications` as the service that blew the splash
/// budget on 1.3.6. Now the system dialog only appears after the parent has
/// said yes here, and a "not now" is remembered so we never nag again.
Future<void> maybeAskNotificationOptIn(
    BuildContext context, WidgetRef ref) async {
  if (await NotificationService.instance.permissionAsked) return;
  if (!context.mounted) return;

  final lang = ref.read(languageProvider);
  final s = AppS(lang == 'en');
  AnalyticsService.instance.logNotifOptInShown();

  final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => _NotificationOptInDialog(s: s),
      ) ??
      false;

  if (!accepted) {
    await NotificationService.instance.declinePermission();
    AnalyticsService.instance
        .logNotifOptInResult(accepted: false, granted: false);
    return;
  }

  final granted =
      await NotificationService.instance.requestPermission(lang: lang);
  AnalyticsService.instance
      .logNotifOptInResult(accepted: true, granted: granted);

  // Splash schedules the day-3 paywall reminder, but it ran before there was
  // any permission to schedule under — catch it up now instead of waiting
  // for the next cold start.
  if (granted && !ref.read(isProProvider)) {
    await NotificationService.instance.schedulePaywallReminderIfNeeded();
  }
}

class _NotificationOptInDialog extends StatelessWidget {
  final AppS s;

  const _NotificationOptInDialog({required this.s});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              s('Нагадувати про заняття?', 'A daily reminder?'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              s(
                'Одне коротке нагадування на день — щоб пʼять хвилин карток '
                'не губилися в буденності.\n\nВимкнути можна будь-коли '
                'в налаштуваннях.',
                'One short nudge a day, so five minutes of cards don\'t get '
                'lost in the shuffle.\n\nYou can turn it off any time '
                'in settings.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  s('Так, нагадуйте', 'Yes, remind me'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                s('Не зараз', 'Not now'),
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
