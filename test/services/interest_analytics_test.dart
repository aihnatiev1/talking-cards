import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/analytics_service.dart';

/// The events that answer "what do families actually reach for". Each one
/// is only useful if it carries the dimension it was added for, so that is
/// what is pinned here — a parameter quietly dropped in a refactor would
/// leave the dashboards looking healthy and saying nothing.
void main() {
  late List<({String name, Map<String, Object> params})> events;

  setUp(() {
    events = [];
    AnalyticsService.debugSink = (name, params) =>
        events.add((name: name, params: params));
  });

  tearDown(() => AnalyticsService.debugSink = null);

  test('pack_open names the door, not only the pack', () async {
    await AnalyticsService.instance.logPackOpen(
      'animals',
      source: 'library_grid',
      position: 4,
      locked: false,
    );
    expect(events.single.name, 'pack_open');
    expect(events.single.params, {
      'pack_id': 'animals',
      'source': 'library_grid',
      'position': 4,
      'locked': false,
    });
  });

  test('pack_open still works with the pack alone', () async {
    await AnalyticsService.instance.logPackOpen('animals');
    expect(events.single.params, {'pack_id': 'animals'});
  });

  test('pack_close carries depth, not just the exit', () async {
    await AnalyticsService.instance.logPackClose(
      'animals',
      cardsViewed: 3,
      cardsTotal: 24,
      seconds: 41,
    );
    expect(events.single.name, 'pack_close');
    expect(events.single.params['cards_viewed'], 3);
    expect(events.single.params['cards_total'], 24);
    expect(events.single.params['seconds'], 41);
  });

  test('a tile tap is recorded even when the game cannot be played', () async {
    await AnalyticsService.instance.logGameTileTap(
      'odd_one_out',
      playable: false,
      section: 'advanced',
      position: 0,
    );
    expect(events.single.name, 'game_tile_tap');
    expect(events.single.params['playable'], false);
    expect(events.single.params['game_id'], 'odd_one_out');
    expect(events.single.params['section'], 'advanced');
  });

  test('game_start can say where it was started from', () async {
    await AnalyticsService.instance.logGameStart('quiz', source: 'games_tab');
    expect(events.single.params, {'game_id': 'quiz', 'source': 'games_tab'});
  });
}
