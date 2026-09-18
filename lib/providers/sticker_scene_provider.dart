import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// One sticker, where the child put it.
///
/// Positions are stored as fractions of the meadow, not pixels: the same
/// scene has to come back right on a phone held in a different hand, and
/// on a tablet.
class PlacedSticker {
  final String cardId;
  final double x, y, scale, angle;

  const PlacedSticker({
    required this.cardId,
    required this.x,
    required this.y,
    required this.scale,
    required this.angle,
  });

  Map<String, Object> toJson() => {
    'id': cardId,
    'x': x,
    'y': y,
    's': scale,
    'a': angle,
  };

  static PlacedSticker? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String) return null;
    double num_(Object? v, double fallback) =>
        v is num ? v.toDouble() : fallback;
    return PlacedSticker(
      cardId: id,
      x: num_(j['x'], .5),
      y: num_(j['y'], .5),
      scale: num_(j['s'], 1),
      angle: num_(j['a'], 0),
    );
  }
}

/// The meadow the child has been filling with stickers.
///
/// It used to vanish the moment she left the screen, which made it the one
/// thing in «Малюємо» that could not be come back to — the filled drawings
/// keep, the finished ones stand on the meadow, and this was thrown away.
/// Per profile, like everything a child makes.
final stickerSceneProvider =
    StateNotifierProvider<StickerSceneNotifier, List<PlacedSticker>>(
      (ref) => StickerSceneNotifier(),
    );

class StickerSceneNotifier extends StateNotifier<List<PlacedSticker>> {
  StickerSceneNotifier() : super(const []) {
    _load();
  }

  static const _key = 'sticker_scene';

  /// A scene, not a scrapbook: past this many the oldest fall off, so the
  /// meadow stays a place and not a pile.
  static const maxStickers = 60;

  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefixedKey);
    if (raw == null) return;
    try {
      state = [
        for (final e in (json.decode(raw) as List<dynamic>))
          if (PlacedSticker.fromJson(e as Map<String, dynamic>) case final s?)
            s,
      ];
    } catch (_) {
      state = const [];
    }
  }

  Future<void> place(PlacedSticker sticker) async {
    final next = [...state, sticker];
    state = next.length > maxStickers
        ? next.sublist(next.length - maxStickers)
        : next;
    await _save();
  }

  Future<void> removeLast() async {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
    await _save();
  }

  Future<void> clear() async {
    if (state.isEmpty) return;
    state = const [];
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefixedKey,
      json.encode([for (final s in state) s.toJson()]),
    );
  }
}
