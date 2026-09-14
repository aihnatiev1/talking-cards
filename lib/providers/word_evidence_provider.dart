import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// What the app actually observed about one word.
///
/// Three signals that used to be blurred into one number called "learned":
///
///  * [recognized]   — the child picked this card correctly in a game
///                     (quiz, memory). The app saw a choice, not speech.
///  * [parentMarked] — a grown-up tapped «Вийшло!» in "Repeat after me".
///                     The only human judgement in the app.
///
/// A card *view* is deliberately not here: views live in
/// `packProgressProvider` / `dailyStatsProvider` and must stay a separate,
/// weaker signal. Seeing a card is not knowing a word.
class WordEvidence {
  final int recognized;
  final int parentMarked;

  /// Days since epoch of the last event of each kind; -1 when never.
  final int recognizedDay;
  final int parentMarkedDay;

  const WordEvidence({
    this.recognized = 0,
    this.parentMarked = 0,
    this.recognizedDay = -1,
    this.parentMarkedDay = -1,
  });

  bool get isRecognized => recognized > 0;
  bool get isParentMarked => parentMarked > 0;

  WordEvidence copyWith({
    int? recognized,
    int? parentMarked,
    int? recognizedDay,
    int? parentMarkedDay,
  }) => WordEvidence(
    recognized: recognized ?? this.recognized,
    parentMarked: parentMarked ?? this.parentMarked,
    recognizedDay: recognizedDay ?? this.recognizedDay,
    parentMarkedDay: parentMarkedDay ?? this.parentMarkedDay,
  );

  /// Compact on purpose: this map is rewritten on every correct answer.
  List<int> toJson() => [
    recognized,
    parentMarked,
    recognizedDay,
    parentMarkedDay,
  ];

  factory WordEvidence.fromJson(List<dynamic> j) => WordEvidence(
    recognized: j.isNotEmpty ? j[0] as int : 0,
    parentMarked: j.length > 1 ? j[1] as int : 0,
    recognizedDay: j.length > 2 ? j[2] as int : -1,
    parentMarkedDay: j.length > 3 ? j[3] as int : -1,
  );
}

/// Local day index — no clock-time arithmetic across DST.
int dayIndex(DateTime d) =>
    DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

extension WordEvidenceStats on Map<String, WordEvidence> {
  Set<String> get recognizedIds => entries
      .where((e) => e.value.isRecognized)
      .map((e) => e.key)
      .toSet();

  Set<String> get parentMarkedIds => entries
      .where((e) => e.value.isParentMarked)
      .map((e) => e.key)
      .toSet();

  /// Words with any human/game evidence — the honest "word chest" set.
  Set<String> get evidencedIds => {...recognizedIds, ...parentMarkedIds};

  int recognizedSince(int days, {DateTime? now}) {
    final from = dayIndex(now ?? DateTime.now()) - (days - 1);
    return values.where((e) => e.recognizedDay >= from).length;
  }

  int parentMarkedSince(int days, {DateTime? now}) {
    final from = dayIndex(now ?? DateTime.now()) - (days - 1);
    return values.where((e) => e.parentMarkedDay >= from).length;
  }
}

final wordEvidenceProvider =
    StateNotifierProvider<WordEvidenceNotifier, Map<String, WordEvidence>>(
      (ref) => WordEvidenceNotifier(),
    );

class WordEvidenceNotifier extends StateNotifier<Map<String, WordEvidence>> {
  WordEvidenceNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'word_evidence_v1';
  String get _prefixedKey => '${ProfileService.prefix}$_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefixedKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      state = map.map(
        (k, v) => MapEntry(k, WordEvidence.fromJson(v as List<dynamic>)),
      );
    } catch (_) {
      // Corrupt data — start fresh rather than crash a parent screen.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefixedKey,
      json.encode(state.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// The child answered correctly in a game.
  Future<void> recordRecognized(String cardId, {DateTime? at}) async {
    final current = state[cardId] ?? const WordEvidence();
    state = {
      ...state,
      cardId: current.copyWith(
        recognized: current.recognized + 1,
        recognizedDay: dayIndex(at ?? DateTime.now()),
      ),
    };
    await _save();
  }

  /// A grown-up tapped «Вийшло!» while practising together.
  Future<void> recordParentMark(String cardId, {DateTime? at}) async {
    final current = state[cardId] ?? const WordEvidence();
    state = {
      ...state,
      cardId: current.copyWith(
        parentMarked: current.parentMarked + 1,
        parentMarkedDay: dayIndex(at ?? DateTime.now()),
      ),
    };
    await _save();
  }
}
