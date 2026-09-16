import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/sticker_scene_provider.dart';

/// The meadow a child fills with stickers is a place she comes back to,
/// not a screen that resets behind her.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PlacedSticker sticker(String id, {double x = .5, double y = .5}) =>
      PlacedSticker(cardId: id, x: x, y: y, scale: 1, angle: 0);

  test('stickers stay put, and survive a restart', () async {
    final first = ProviderContainer();
    await first
        .read(stickerSceneProvider.notifier)
        .place(sticker('a01', x: .25, y: .75));
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    for (var i = 0; i < 5 && second.read(stickerSceneProvider).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final back = second.read(stickerSceneProvider).single;
    expect(back.cardId, 'a01');
    // Fractions, so the same scene lands right on any screen.
    expect(back.x, .25);
    expect(back.y, .75);
  });

  test('undo takes the last one off, and only that one', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(stickerSceneProvider.notifier);
    await n.place(sticker('a01'));
    await n.place(sticker('a02'));
    await n.removeLast();
    expect(c.read(stickerSceneProvider).map((s) => s.cardId), ['a01']);
  });

  test('a scene, not a pile: the oldest fall off past the cap', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(stickerSceneProvider.notifier);
    for (var i = 0; i < StickerSceneNotifier.maxStickers + 5; i++) {
      await n.place(sticker('card$i'));
    }
    final scene = c.read(stickerSceneProvider);
    expect(scene, hasLength(StickerSceneNotifier.maxStickers));
    expect(scene.first.cardId, 'card5', reason: 'the first five fell off');
  });

  test('an unreadable scene starts empty instead of failing a launch',
      () async {
    SharedPreferences.setMockInitialValues({'sticker_scene': 'not json'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(stickerSceneProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(stickerSceneProvider), isEmpty);
  });
}
