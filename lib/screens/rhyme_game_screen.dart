import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/shake_animation_mixin.dart';

// ─────────────────────────────────────────────
//  Rhyme groups — Ukrainian
// ─────────────────────────────────────────────

class _RhymeWord {
  final String word;
  final String emoji;
  final String groupId;

  const _RhymeWord(this.word, this.emoji, this.groupId);
}

const _rhymeWords = [
  // -АК
  _RhymeWord('РАК',    '🦞', 'ak'),
  _RhymeWord('МАК',    '🌺', 'ak'),
  _RhymeWord('БАК',    '🪣', 'ak'),
  // -ОН
  _RhymeWord('СЛОН',   '🐘', 'on'),
  _RhymeWord('БАЛОН',  '🎈', 'on'),
  _RhymeWord('ЛИМОН',  '🍋', 'on'),
  // -АМА
  _RhymeWord('МАМА',   '👩', 'ama'),
  _RhymeWord('РАМА',   '🖼️', 'ama'),
  _RhymeWord('ЯМА',    '🕳️', 'ama'),
  // -УК
  _RhymeWord('ЖУК',    '🪲', 'uk'),
  _RhymeWord('БУК',    '🌳', 'uk'),
  _RhymeWord('ЛУК',    '🧅', 'uk'),
  // -ОЗА
  _RhymeWord('КОЗА',   '🐐', 'oza'),
  _RhymeWord('РОЗА',   '🌹', 'oza'),
  _RhymeWord('ГРОЗА',  '⛈️', 'oza'),
  // -АЙКА
  _RhymeWord('ЗАЙКА',  '🐰', 'ayka'),
  _RhymeWord('МАЙКА',  '👕', 'ayka'),
  _RhymeWord('ЧАЙКА',  '🦅', 'ayka'),
  // -ОТ
  _RhymeWord('КОТ',     '🐱',  'ot'),
  _RhymeWord('РОТ',     '👄',  'ot'),
  _RhymeWord('МОТ',     '🧶',  'ot'),
  // -АЙ
  _RhymeWord('ЧАЙ',    '🫖',  'ay'),
  _RhymeWord('КРАЙ',   '🗺️',  'ay'),
  _RhymeWord('ГАЙ',    '🌳',  'ay'),
  // -ОЧКА
  _RhymeWord('БОЧКА',  '🪣',  'ochka'),
  _RhymeWord('ДОЧКА',  '👧',  'ochka'),
  _RhymeWord('НОЧКА',  '🌙',  'ochka'),
  // -УШКА
  _RhymeWord('ПОДУШКА','🛏️', 'ushka'),
  _RhymeWord('ГРУШКА', '🍐',  'ushka'),
  _RhymeWord('МУШКА',  '🪰',  'ushka'),
  // -ИЦЯ
  _RhymeWord('ЛИСИЦЯ', '🦊',  'ytsia'),
  _RhymeWord('ПТИЦЯ',  '🐦',  'ytsia'),
  _RhymeWord('ГОРЛИЦЯ','🕊️', 'ytsia'),
];

// ─────────────────────────────────────────────
//  Game screen
// ─────────────────────────────────────────────

class RhymeGameScreen extends ConsumerStatefulWidget {
  const RhymeGameScreen({super.key});

  @override
  ConsumerState<RhymeGameScreen> createState() => _RhymeGameScreenState();
}

class _RhymeGameScreenState extends ConsumerState<RhymeGameScreen>
    with
        TickerProviderStateMixin,
        ShakeAnimationMixin,
        ConfettiOverlayMixin,
        GameStateMixin {
  @override
  String get gameId => 'rhyme_game';

  // rhyme_game doesn't track per-game plays/bestScore in gameStatsProvider
  // (not declared in gameDefinitions).
  @override
  bool get recordToStats => false;

  bool _answered = false;
  String? _tappedWord;

  late _Round _round;

  @override
  void initState() {
    super.initState();
    initShake();
    startGame();
    _buildRound();
  }

  @override
  void dispose() {
    disposeShake();
    disposeConfetti();
    super.dispose();
  }

  void _buildRound() {
    if (!nextRound()) return;

    // Group words by groupId
    final groups = <String, List<_RhymeWord>>{};
    for (final w in _rhymeWords) {
      groups.putIfAbsent(w.groupId, () => []).add(w);
    }
    final validGroups = groups.values.where((g) => g.length >= 2).toList();

    final rng = Random();
    final qGroup = validGroups[rng.nextInt(validGroups.length)];
    final qGroupShuffled = List<_RhymeWord>.from(qGroup)..shuffle(rng);
    final question = qGroupShuffled[0];
    final correctAnswer = qGroupShuffled[1];

    // 2 distractors from other groups
    final otherWords = _rhymeWords
        .where((w) => w.groupId != question.groupId)
        .toList()
      ..shuffle(rng);
    final distractors = otherWords.take(2).toList();

    final options = [correctAnswer, ...distractors]..shuffle(rng);

    setState(() {
      _round = _Round(question: question, correct: correctAnswer, options: options);
      _answered = false;
      _tappedWord = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _speakWord(question.word));
  }

  // TTS removed per user feedback — rhyme game has no recorded audio; stays
  // silent. Game is hidden from games tab anyway.
  void _speakWord(String word) {}

  void _onTap(_RhymeWord word) {
    if (_answered) return;
    final isCorrect = word.groupId == _round.question.groupId;

    setState(() {
      _answered = true;
      _tappedWord = word.word;
    });

    _speakWord(word.word);

    if (isCorrect) {
      HapticFeedback.lightImpact();
      scorePoint();
      showConfetti();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _buildRound();
      });
    } else {
      HapticFeedback.mediumImpact();
      shake(id: word.word);
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() { _answered = false; _tappedWord = null; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');

    if (finished) return _buildFinishScreen(s);

    final question = _round.question;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0FB),
      appBar: AppBar(
        title: Text(
          s('Знайди риму', 'Find the rhyme'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⭐ $score  $roundsPlayed/$maxRounds',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kAccent,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Question card
              GestureDetector(
                onTap: () => _speakWord(question.word),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _WordCard(
                    key: ValueKey(question.word),
                    rhymeWord: question,
                    state: _WordState.question,
                    onTap: null,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎵', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    s('Що римується з цим словом?',
                        'What rhymes with this word?'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Options — vertical stack for big tap targets
              Expanded(
                child: Column(
                  children: _round.options.map((w) {
                    final isCorrect = _answered && w.groupId == question.groupId;
                    final isTapped = _tappedWord == w.word;
                    final isWrong = _answered && isTapped && w.groupId != question.groupId;

                    final state = isCorrect
                        ? _WordState.correct
                        : isWrong
                            ? _WordState.wrong
                            : _WordState.option;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: wrapShake(
                          _WordCard(
                            rhymeWord: w,
                            state: state,
                            onTap: () => _onTap(w),
                          ),
                          id: w.word,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishScreen(AppS s) {
    final pct = score / maxRounds;
    final stars = pct >= 0.8 ? 3 : pct >= 0.5 ? 2 : 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stars == 3
                      ? s('Чудово! 🎉', 'Excellent! 🎉')
                      : stars == 2
                          ? s('Молодець! 👍', 'Well done! 👍')
                          : s('Спробуй ще! 💪', 'Keep trying! 💪'),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Text(
                      i < stars ? '⭐' : '☆',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s('$score з $maxRounds рим', '$score of $maxRounds rhymes'),
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      s('Готово', 'Done'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    resetGame();
                    _buildRound();
                  },
                  child: Text(
                    s('Грати ще раз 🔄', 'Play again 🔄'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────

class _Round {
  final _RhymeWord question;
  final _RhymeWord correct;
  final List<_RhymeWord> options;

  _Round({
    required this.question,
    required this.correct,
    required this.options,
  });
}

enum _WordState { question, option, correct, wrong }

// ─────────────────────────────────────────────
//  Word card widget
// ─────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  final _RhymeWord rhymeWord;
  final _WordState state;
  final VoidCallback? onTap;

  const _WordCard({
    super.key,
    required this.rhymeWord,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isQuestion = state == _WordState.question;
    final isCorrect = state == _WordState.correct;
    final isWrong = state == _WordState.wrong;

    final bg = isCorrect
        ? const Color(0xFFE8F5E9)
        : isWrong
            ? const Color(0xFFFFEBEE)
            : isQuestion
                ? kAccent.withValues(alpha: 0.07)
                : Colors.grey.withValues(alpha: 0.06);

    final border = isCorrect
        ? const Color(0xFF43A047)
        : isWrong
            ? const Color(0xFFE53935)
            : isQuestion
                ? kAccent.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: isQuestion ? 160 : double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: border,
            width: isCorrect || isWrong || isQuestion ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isQuestion
            // Question: centered vertical layout
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(rhymeWord.emoji,
                        style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 10),
                    Text(
                      rhymeWord.word,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volume_up_rounded,
                            size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('торкнись',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              )
            // Option: horizontal layout — emoji left, word right
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(rhymeWord.emoji,
                        style: const TextStyle(fontSize: 44)),
                    const SizedBox(width: 16),
                    Text(
                      rhymeWord.word,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? const Color(0xFF2E7D32)
                            : isWrong
                                ? const Color(0xFFC62828)
                                : Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    if (isCorrect)
                      const Text('✅', style: TextStyle(fontSize: 22)),
                    if (isWrong)
                      const Text('❌', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
      ),
    );
  }
}
