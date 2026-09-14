import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/analytics_service.dart';

/// Release A is judged by one number: did the session start from the card
/// that answers "what now?", or from browsing the library?
///
/// `logFirstAction` answers it once per launch — a long session is one
/// answer, not one per screen — so the ratio it feeds is a share of
/// sessions, not a share of taps.
void main() {
  setUp(AnalyticsService.instance.debugResetFirstAction);

  test('only the first action of a launch is recorded', () async {
    // No Firebase in tests: _safeLog no-ops, so this asserts the guard,
    // which is the part that would corrupt the metric.
    await AnalyticsService.instance.logFirstAction('hero_cta');
    await AnalyticsService.instance.logFirstAction('library_pack');
    await AnalyticsService.instance.logFirstAction('games_tab');
    expect(AnalyticsService.instance.debugFirstActionSource, 'hero_cta');
  });

  test('a new launch answers again', () async {
    await AnalyticsService.instance.logFirstAction('library_pack');
    AnalyticsService.instance.debugResetFirstAction();
    await AnalyticsService.instance.logFirstAction('hero_cta');
    expect(AnalyticsService.instance.debugFirstActionSource, 'hero_cta');
  });
}
