import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

/// Per-game statistics stored in SharedPreferences.
class GameStat {
  final String id;
  final String emoji;
  final String labelUk;
  final String labelEn;
  final int plays;
  final int bestScore;

  const GameStat({
    required this.id,
    required this.emoji,
    required this.labelUk,
    required this.labelEn,
    required this.plays,
    required this.bestScore,
  });
}

/// Ordered list of all games in the app.
const gameDefinitions = [
  (id: 'quiz',          emoji: '🎧', uk: 'Вгадай звук',     en: 'Guess the word'),
  (id: 'memory',        emoji: '🧠', uk: 'Знайди пару',      en: 'Find the pair'),
  (id: 'sort',          emoji: '🗂️', uk: 'По купках',       en: 'Sort it!'),
  (id: 'odd_one_out',   emoji: '🔍', uk: 'Знайди зайве',    en: 'Odd one out'),
  (id: 'opposite_game', emoji: '↔️', uk: 'Протилежності',   en: 'Opposites'),
  (id: 'syllable_game', emoji: '🥁', uk: 'Рахуй склади',    en: 'Count syllables'),
  (id: 'repeat_game',   emoji: '🎤', uk: 'Повтори за мною', en: 'Repeat after me'),
];

final gameStatsProvider =
    AsyncNotifierProvider<GameStatsNotifier, List<GameStat>>(
  GameStatsNotifier.new,
);

class GameStatsNotifier extends AsyncNotifier<List<GameStat>> {
  String get _p => ProfileService.prefix;

  String _playsKey(String id) => '${_p}game_plays_$id';
  String _bestKey(String id) => '${_p}game_best_$id';

  @override
  Future<List<GameStat>> build() async {
    return _load();
  }

  Future<List<GameStat>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return gameDefinitions.map((g) {
      return GameStat(
        id: g.id,
        emoji: g.emoji,
        labelUk: g.uk,
        labelEn: g.en,
        plays: prefs.getInt(_playsKey(g.id)) ?? 0,
        bestScore: prefs.getInt(_bestKey(g.id)) ?? 0,
      );
    }).toList();
  }

  /// Call this when a game session ends with a score.
  Future<void> record(String gameId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final plays = (prefs.getInt(_playsKey(gameId)) ?? 0) + 1;
    final best = (prefs.getInt(_bestKey(gameId)) ?? 0);
    await prefs.setInt(_playsKey(gameId), plays);
    if (score > best) {
      await prefs.setInt(_bestKey(gameId), score);
    }
    state = AsyncData(await _load());
  }
}
