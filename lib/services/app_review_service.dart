import 'package:in_app_review/in_app_review.dart';

/// Thin wrapper around the `in_app_review` plugin.
///
/// The prompt is only ever triggered by an explicit parent-initiated tap on the
/// "Rate the app" action in the Parent Dashboard, and it uses the OS-native,
/// in-app review sheet ([InAppReview.requestReview]). That sheet is rate-limited
/// by the OS and never leaves the app, so no custom frequency guard is needed.
///
/// Nothing here runs at startup — the plugin instance is created lazily on
/// first use.
class AppReviewService {
  AppReviewService._();
  static final AppReviewService instance = AppReviewService._();

  // Created lazily; the plugin does no work until touched.
  InAppReview? _plugin;
  InAppReview get _inAppReview => _plugin ??= InAppReview.instance;

  /// Fires the OS-native, in-app review sheet if the platform reports it as
  /// available. Returns true if the request was actually dispatched.
  ///
  /// Deliberately uses [InAppReview.requestReview] (in-app sheet), NOT
  /// [InAppReview.openStoreListing]: the trigger surface is not behind a
  /// parental gate, so we never navigate a child out to the external store.
  Future<bool> requestReview() async {
    final available = await _inAppReview.isAvailable();
    if (!available) return false;
    await _inAppReview.requestReview();
    return true;
  }
}
