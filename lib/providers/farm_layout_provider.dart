import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// Where an animal stands on the farm, as fractions of the farm picture:
/// the middle of its feet.
typedef FarmSpot = ({double x, double y});

/// The child's own farm: who they moved where, and who rests in the barn.
///
/// Only what the child changed is kept. An animal with no entry stands in
/// its home spot (the farm's own twelve) or waits in the barn (a guest the
/// streak just brought); an entry of `null` means «in the barn».
class FarmLayout {
  const FarmLayout([this.places = const {}]);

  final Map<String, FarmSpot?> places;

  bool has(String key) => places.containsKey(key);

  /// The child's spot for [key], or null when it is in the barn.
  FarmSpot? spotOf(String key) => places[key];
}

final farmLayoutProvider =
    StateNotifierProvider<FarmLayoutNotifier, FarmLayout>(
      (ref) => FarmLayoutNotifier(),
    );

class FarmLayoutNotifier extends StateNotifier<FarmLayout> {
  FarmLayoutNotifier() : super(const FarmLayout()) {
    _load();
  }

  static const _key = 'farm_layout_v1';
  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefixedKey);
    if (raw == null) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      state = FarmLayout({
        for (final e in map.entries)
          e.key: switch (e.value) {
            [final num x, final num y] => (x: x.toDouble(), y: y.toDouble()),
            _ => null,
          },
      });
    } catch (_) {
      // A broken entry is not worth a broken farm: start from the default.
    }
  }

  /// The child put [key] down at [spot].
  Future<void> place(String key, FarmSpot spot) =>
      _set({...state.places, key: spot});

  /// The child took [key] into the barn.
  Future<void> rest(String key) => _set({...state.places, key: null});

  Future<void> _set(Map<String, FarmSpot?> places) async {
    state = FarmLayout(places);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefixedKey,
      json.encode({
        for (final e in places.entries)
          e.key: switch (e.value) {
            (:final x, :final y) => [
              double.parse(x.toStringAsFixed(4)),
              double.parse(y.toStringAsFixed(4)),
            ],
            null => null,
          },
      }),
    );
  }
}
