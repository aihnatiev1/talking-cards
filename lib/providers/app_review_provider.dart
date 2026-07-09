import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/app_review_service.dart';

/// Single entry point for triggering the app-store review flow. Exposed as a
/// plain [Provider] (matching the repo's manual Riverpod style).
final appReviewControllerProvider = Provider<AppReviewController>(
  (ref) => const AppReviewController(),
);

class AppReviewController {
  const AppReviewController();

  /// Triggered by an explicit parent tap on the "Rate the app" action.
  ///
  /// Design rationale — the app has NO parental gate (the Parent Dashboard is
  /// reachable by a child via long-press on the About icon):
  ///  * It only fires on an explicit user tap, never automatically, so it can
  ///    never appear in front of a child unprompted.
  ///  * It uses the OS-native, in-app review sheet, which is rate-limited by the
  ///    OS and never leaves the app — child-safe even on an accidental tap.
  ///  * We never navigate out to the external store listing.
  Future<void> requestReview() async {
    final requested = await AppReviewService.instance.requestReview();
    if (requested) {
      AnalyticsService.instance.logEvent('review_prompt_requested');
    }
  }
}
