import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

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
  _RhymeWord('МАЙ',    '🌷',  'ay'),
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
    with SingleTickerProviderStateMixin {
  int _score = 0;
  bool _answered = false;
  String? _tappedWord;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  late _Round _round;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingWord;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _shakeCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _shakeCtrl.reset();
        setState(() => _shakingWord = null);
      }
    });
    AnalyticsService.instance.logGameStart('rhyme_game');
    _buildRound();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _confettiEntry?.remove();
    super.dispose();
  }

  void _buildRound() {
    // Group words by groupId
    final groups = <String, List<_RhymeWord>>{};
    for (final w in _rhymeWords) {
      groups.putIfAbsent(w.groupId, () => []).add(w);
    }
    final validGroups = groups.values.where((g) => g.length >= 2).toList();

    final rng = Random();
    // Pick question group
    final qGroup = validGroups[rng.nextInt(validGroups.length)];
    final qGroupShuffled = List<_RhymeWord>.from(qGroup)..shuffle(rng);
    final question = qGroupShuffled[0];
    final correctAnswer = qGroupShuffled[1];

    // Pick 2 distractors from other groups
    final otherWords = _rhymeWords.where((w) => w.groupId != question.groupId).toList()..shuffle(rng);
    final distractors = otherWords.take(2).toList();

    final options = [correctAnswer, ...distractors]..shuffle(rng);

    setState(() {
      _round = _Round(question: question, correct: correctAnswer, options: options);
      _answered = false;
      _tappedWord = null;
      _shakingWord = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _speakWord(question.word));
  }

  void _speakWord(String word) {
    TtsService.instance.speak(word, locale: 'uk-UA');
  }

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
      _score++;
      _showConfetti();
      Future.delayed(const Duration(milliseconds: 300), () {
        final isEn = ref.read(languageProvider) == 'en';
        TtsService.instance.speak(
          isEn ? 'Great!' : 'Молодець!',
          locale: isEn ? 'en-US' : 'uk-UA',
        );
      });
      if (!_questDone && _score >= 3) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
        AnalyticsService.instance.logGameComplete('rhyme_game', _score);
      }
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _buildRound();
      });
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _shakingWord = word.word);
      _shakeCtrl.forward();
    }
  }

  void _showConfetti() {
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    _confettiEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(origin: Offset(size.width / 2, size.height / 3)),
      ),
    );
    Overlay.of(context).insert(_confettiEntry!);
    Future.delayed(const Duration(milliseconds: 1500), () {
      _confettiEntry?.remove();
      _confettiEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');
    final question = _round.question;

    return Scaffold(
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
                '⭐ $_score',
                style: const TextStyle(
                  fontSize: 16,
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
                  Text('🎵', style: const TextStyle(fontSize: 20)),
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
                    final isShaking = _shakingWord == w.word;

                    final state = isCorrect
                        ? _WordState.correct
                        : isWrong
                            ? _WordState.wrong
                            : _WordState.option;

                    Widget tile = Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WordCard(
                          rhymeWord: w,
                          state: state,
                          onTap: () => _onTap(w),
                        ),
                      ),
                    );

                    if (isShaking) {
                      tile = Expanded(
                        child: AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (_, child) {
                            final offset = 8 *
                                (0.5 - (_shakeAnim.value % 0.25) / 0.25)
                                    .abs() *
                                2 -
                                4;
                            return Transform.translate(
                                offset: Offset(offset, 0), child: child);
                          },
                          child: (tile as Expanded).child,
                        ),
                      );
                    }

                    return tile;
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
                      style: TextStyle(
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
