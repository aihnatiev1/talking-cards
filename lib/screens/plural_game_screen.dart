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
//  Word pairs: singular → plural
// ─────────────────────────────────────────────

class _WordPair {
  final String singular;
  final String plural;
  final String emoji;

  const _WordPair(this.singular, this.plural, this.emoji);
}

const _pairs = [
  _WordPair('КІТ',       'КОТИ',       '🐱'),
  _WordPair('ПЕС',       'ПСИ',        '🐕'),
  _WordPair('ЯБЛУКО',    'ЯБЛУКА',     '🍎'),
  _WordPair('ЗІРКА',     'ЗІРКИ',      '⭐'),
  _WordPair('КВІТКА',    'КВІТКИ',     '🌸'),
  _WordPair('М\'ЯЧ',    'М\'ЯЧІ',    '⚽'),
  _WordPair('ДЕРЕВО',    'ДЕРЕВА',     '🌳'),
  _WordPair('РИБА',      'РИБИ',       '🐟'),
  _WordPair('ХМАРА',     'ХМАРИ',      '☁️'),
  _WordPair('БУДИНОК',   'БУДИНКИ',    '🏠'),
  _WordPair('КНИГА',     'КНИГИ',      '📖'),
  _WordPair('ЛІТАК',     'ЛІТАКИ',     '✈️'),
  _WordPair('МАШИНА',    'МАШИНИ',     '🚗'),
  _WordPair('СЛОН',      'СЛОНИ',      '🐘'),
  _WordPair('ОЛІВЕЦЬ',   'ОЛІВЦІ',     '✏️'),
  _WordPair('ЯЙЦЕ',      'ЯЙЦЯ',       '🥚'),
  _WordPair('КУРЧА',     'КУРЧАТА',    '🐥'),
  _WordPair('ВЕДМІДЬ',   'ВЕДМЕДІ',    '🐻'),
  _WordPair('ЖИРАФ',     'ЖИРАФИ',     '🦒'),
  _WordPair('ГРИБ',      'ГРИБИ',      '🍄'),
  _WordPair('КІСКА',     'КІСКИ',      '🎀'),
  _WordPair('СТІЛ',      'СТОЛИ',      '🪑'),
  _WordPair('ВІКНО',     'ВІКНА',      '🪟'),
  _WordPair('ЦУЦЕНЯ',    'ЦУЦЕНЯТА',   '🐶'),
];

// ─────────────────────────────────────────────
//  Game screen
// ─────────────────────────────────────────────

class PluralGameScreen extends ConsumerStatefulWidget {
  const PluralGameScreen({super.key});

  @override
  ConsumerState<PluralGameScreen> createState() => _PluralGameScreenState();
}

class _PluralGameScreenState extends ConsumerState<PluralGameScreen>
    with SingleTickerProviderStateMixin {
  late List<_WordPair> _deck;
  int _index = 0;
  int _score = 0;
  bool _answered = false;
  String? _tappedAnswer;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingAnswer;
  late List<String> _options;

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
        setState(() => _shakingAnswer = null);
      }
    });

    _deck = List<_WordPair>.from(_pairs)..shuffle(Random());
    AnalyticsService.instance.logGameStart('plural_game');
    _buildOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _confettiEntry?.remove();
    super.dispose();
  }

  _WordPair get _current => _deck[_index % _deck.length];

  void _buildOptions() {
    final rng = Random();
    final correct = _current.plural;
    // Pick 2 wrong plurals from other pairs
    final others = _pairs
        .where((p) => p.plural != correct)
        .map((p) => p.plural)
        .toList()
      ..shuffle(rng);
    _options = [correct, others[0], others[1]]..shuffle(rng);
  }

  void _speakCurrent() {
    TtsService.instance.speak(_current.singular, locale: 'uk-UA');
  }

  void _speakPlural(String word) {
    TtsService.instance.speak(word, locale: 'uk-UA');
  }

  void _onTap(String answer) {
    if (_answered) return;
    final isCorrect = answer == _current.plural;

    setState(() {
      _answered = true;
      _tappedAnswer = answer;
    });

    _speakPlural(answer);

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _score++;
      _showConfetti();
      if (!_questDone && _score >= 3) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
        AnalyticsService.instance.logGameComplete('plural_game', _score);
      }
      Future.delayed(const Duration(milliseconds: 1000), _nextCard);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _shakingAnswer = answer);
      _shakeCtrl.forward();
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() { _answered = false; _tappedAnswer = null; });
      });
    }
  }

  void _nextCard() {
    if (!mounted) return;
    setState(() {
      _index++;
      _answered = false;
      _tappedAnswer = null;
      _shakingAnswer = null;
    });
    _buildOptions();
    _speakCurrent();
  }

  void _showConfetti() {
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    _confettiEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(
            origin: Offset(size.width / 2, size.height / 3)),
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
    final pair = _current;

    return Scaffold(
      backgroundColor: const Color(0xFFE8FFF8),
      appBar: AppBar(
        title: Text(
          s('Один — багато', 'One — Many'),
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

              // Singular card
              GestureDetector(
                onTap: _speakCurrent,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey(_index),
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: kAccent.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(pair.emoji,
                            style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s('ОДИН:', 'ONE:'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pair.singular,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up_rounded,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              s('торкнись, щоб послухати',
                                  'tap to listen'),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Question
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pair.emoji,
                      style: const TextStyle(fontSize: 22)),
                  Text(pair.emoji,
                      style: const TextStyle(fontSize: 22)),
                  Text(pair.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    s('БАГАТО...?', 'MANY...?'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Options
              Expanded(
                child: Column(
                  children: _options.map((option) {
                    final isCorrect =
                        _answered && option == pair.plural;
                    final isTapped = _tappedAnswer == option;
                    final isWrong =
                        _answered && isTapped && option != pair.plural;
                    final isShaking = _shakingAnswer == option;

                    Widget btn = _OptionButton(
                      text: option,
                      emoji: pair.emoji,
                      isCorrect: isCorrect,
                      isWrong: isWrong,
                      onTap: () => _onTap(option),
                    );

                    if (isShaking) {
                      btn = AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) {
                          final offset = 8 *
                              (0.5 -
                                      (_shakeAnim.value % 0.25) /
                                          0.25)
                                  .abs() *
                              2 -
                              4;
                          return Transform.translate(
                              offset: Offset(offset, 0), child: child);
                        },
                        child: btn,
                      );
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: btn,
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String text;
  final String emoji;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback onTap;

  const _OptionButton({
    required this.text,
    required this.emoji,
    required this.isCorrect,
    required this.isWrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isCorrect
              ? const Color(0xFFE8F5E9)
              : isWrong
                  ? const Color(0xFFFFEBEE)
                  : kAccent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect
                ? const Color(0xFF43A047)
                : isWrong
                    ? const Color(0xFFE53935)
                    : kAccent.withValues(alpha: 0.18),
            width: isCorrect || isWrong ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            Text(emoji, style: const TextStyle(fontSize: 22)),
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isCorrect
                    ? const Color(0xFF2E7D32)
                    : isWrong
                        ? const Color(0xFFC62828)
                        : kAccent,
              ),
            ),
            const SizedBox(width: 8),
            if (isCorrect)
              const Text('✅', style: TextStyle(fontSize: 18)),
            if (isWrong)
              const Text('❌', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
