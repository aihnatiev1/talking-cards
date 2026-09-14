import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../services/profile_service.dart';

/// One picture this child has brought back to colour (experience audit
/// 2026-09-13, п. 24).
class ColoringAlbumEntry {
  const ColoringAlbumEntry({
    required this.cardId,
    required this.image,
    required this.revealedAt,
  });

  final String cardId;

  /// The webp name — the album is keyed on the picture, not the word, so a
  /// language switch does not empty it (same reasoning as
  /// [CardModel.calmingExcludedImages]).
  final String image;
  final DateTime revealedAt;

  String encode() =>
      '$cardId|$image|${revealedAt.toIso8601String()}';

  static ColoringAlbumEntry? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final at = DateTime.tryParse(parts[2]);
    if (at == null || parts[1].isEmpty) return null;
    return ColoringAlbumEntry(
      cardId: parts[0],
      image: parts[1],
      revealedAt: at,
    );
  }
}

/// The colouring tab's own memory: what has been revealed, whether the
/// finger demonstration has been seen, and which picture was left unfinished.
class ColoringAlbumState {
  const ColoringAlbumState({
    this.entries = const [],
    this.handHintSeen = false,
    this.unfinishedCardId,
    this.loaded = false,
  });

  /// Newest first.
  final List<ColoringAlbumEntry> entries;

  /// The ghost finger runs once per profile, never again.
  final bool handHintSeen;

  /// The picture the child was on when they last left, if they had not
  /// finished it — the tab resumes it instead of dealing a stranger.
  final String? unfinishedCardId;

  /// False until SharedPreferences has been read once; the UI must not
  /// decide "no album, no hint seen" on an empty initial state.
  final bool loaded;

  bool get isEmpty => entries.isEmpty;

  ColoringAlbumState copyWith({
    List<ColoringAlbumEntry>? entries,
    bool? handHintSeen,
    String? unfinishedCardId,
    bool clearUnfinished = false,
    bool? loaded,
  }) =>
      ColoringAlbumState(
        entries: entries ?? this.entries,
        handHintSeen: handHintSeen ?? this.handHintSeen,
        unfinishedCardId:
            clearUnfinished ? null : (unfinishedCardId ?? this.unfinishedCardId),
        loaded: loaded ?? this.loaded,
      );
}

final coloringAlbumProvider =
    StateNotifierProvider<ColoringAlbumNotifier, ColoringAlbumState>(
  (ref) => ColoringAlbumNotifier(),
);

/// Persists the album under the active profile's prefix, like every other
/// per-child store in the app ([ProfileService.prefix]).
class ColoringAlbumNotifier extends StateNotifier<ColoringAlbumState> {
  ColoringAlbumNotifier() : super(const ColoringAlbumState()) {
    _ready = _load();
  }

  static const _keyAlbum = 'coloring_album';
  static const _keyHandHint = 'coloring_hand_hint_seen';
  static const _keyUnfinished = 'coloring_unfinished_card';

  /// The album is a keepsake, not a log: the most recent [maxEntries]
  /// pictures, one row per picture.
  static const maxEntries = 60;

  late final Future<void> _ready;

  /// Completes when the first read from disk has been applied — tests and
  /// the screen's first frame both need to wait for it rather than guess.
  Future<void> get ready => _ready;

  String _key(String key) => '${ProfileService.prefix}$key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(_keyAlbum)) ?? const [];
    final entries = [
      for (final line in raw)
        if (ColoringAlbumEntry.decode(line) case final e?) e,
    ];
    if (!mounted) return;
    state = ColoringAlbumState(
      entries: entries,
      handHintSeen: prefs.getBool(_key(_keyHandHint)) ?? false,
      unfinishedCardId: prefs.getString(_key(_keyUnfinished)),
      loaded: true,
    );
  }

  /// A picture has been fully revealed: it joins the album and stops being
  /// the unfinished one.
  Future<void> record(CardModel card) async {
    final image = card.image;
    if (image == null) return;
    final entry = ColoringAlbumEntry(
      cardId: card.id,
      image: image,
      revealedAt: DateTime.now(),
    );
    final entries = [
      entry,
      for (final e in state.entries)
        if (e.image != image) e,
    ].take(maxEntries).toList();

    state = state.copyWith(entries: entries, clearUnfinished: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(_keyAlbum),
      [for (final e in entries) e.encode()],
    );
    await prefs.remove(_key(_keyUnfinished));
  }

  /// Remembers the picture currently on the canvas so the next visit can
  /// offer to continue it. Pass null when there is nothing to come back to.
  Future<void> setUnfinished(String? cardId) async {
    if (state.unfinishedCardId == cardId) return;
    state = cardId == null
        ? state.copyWith(clearUnfinished: true)
        : state.copyWith(unfinishedCardId: cardId);
    final prefs = await SharedPreferences.getInstance();
    if (cardId == null) {
      await prefs.remove(_key(_keyUnfinished));
    } else {
      await prefs.setString(_key(_keyUnfinished), cardId);
    }
  }

  /// The ghost finger has run (or the child started drawing before it
  /// finished — either way they have seen what to do).
  Future<void> markHandHintSeen() async {
    if (state.handHintSeen) return;
    state = state.copyWith(handHintSeen: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_keyHandHint), true);
  }
}
