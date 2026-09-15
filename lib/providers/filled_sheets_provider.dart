import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// What the child has painted, per drawing: area id → crayon id.
///
/// A picture a child spent five minutes on and then lost by pressing the
/// close button is the app throwing their work away. Colours are stored
/// rather than pixels — a few dozen small numbers per drawing — and the
/// screen repaints from them, so the store stays tiny and survives a new
/// version of the artwork.
///
/// Per profile, like everything a child makes.
final filledSheetsProvider =
    StateNotifierProvider<FilledSheetsNotifier, Map<String, Map<int, String>>>(
      (ref) => FilledSheetsNotifier(),
    );

class FilledSheetsNotifier
    extends StateNotifier<Map<String, Map<int, String>>> {
  FilledSheetsNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'filled_sheets';

  String get _prefixedKey => '${ProfileService.prefix}$_key';

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefixedKey);
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        state = {
          for (final sheet in decoded.entries)
            sheet.key: {
              for (final area in (sheet.value as Map<String, dynamic>).entries)
                int.parse(area.key): area.value as String,
            },
        };
      } catch (_) {
        // Unreadable means start over: this is a colouring book, not a
        // record worth failing a launch for.
        state = const {};
      }
    }
    _loaded = true;
  }

  Map<int, String> of(String sheetId) => state[sheetId] ?? const {};

  Future<void> record(String sheetId, int area, String crayonId) async {
    state = {
      ...state,
      sheetId: {...state[sheetId] ?? const {}, area: crayonId},
    };
    await _save();
  }

  Future<void> clear(String sheetId) async {
    if (!state.containsKey(sheetId)) return;
    state = {...state}..remove(sheetId);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefixedKey,
      json.encode({
        for (final sheet in state.entries)
          sheet.key: {
            for (final area in sheet.value.entries)
              area.key.toString(): area.value,
          },
      }),
    );
  }
}
