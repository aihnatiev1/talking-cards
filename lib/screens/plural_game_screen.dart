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
//  Word pairs — verified Ukrainian grammar
// ─────────────────────────────────────────────

class _WordPair {
  final String singular;
  final String plural;
  final String emoji;

  const _WordPair(this.singular, this.plural, this.emoji);
}

/// Verified against Ukrainian morphology rules.
/// Source: Ukrainian SLP practice + standard grammar.
const _pairs = [
  _WordPair('КІТ',       'КОТИ',       '🐱'),
  _WordPair('СОБАКА',    'СОБАКИ',     '🐶'),
  _WordPair('ПТАХ',      'ПТАХИ',      '🐦'),
  _WordPair('РИБА',      'РИБИ',       '🐟'),
  _WordPair('СЛОН',      'СЛОНИ',      '🐘'),
  _WordPair('ЖАБА',      'ЖАБИ',       '🐸'),
  _WordPair('КРОЛИК',    'КРОЛИКИ',    '🐇'),
  _WordPair('КАЧКА',     'КАЧКИ',      '🦆'),
  _WordPair('ЯБЛУКО',    'ЯБЛУКА',     '🍎'),
  _WordPair('БАНАН',     'БАНАНИ',     '🍌'),
  _WordPair('ПОЛУНИЦЯ',  'ПОЛУНИЦІ',   '🍓'),
  _WordPair('МОРКВА',    'МОРКВИ',     '🥕'),
  _WordPair('БУДИНОК',   'БУДИНКИ',    '🏠'),
  _WordPair('ЗІРКА',     'ЗІРКИ',      '⭐'),
  _WordPair('КВІТКА',    'КВІТКИ',     '🌸'),
  _WordPair('МАШИНА',    'МАШИНИ',     '🚗'),
  _WordPair('КУЛЬКА',    'КУЛЬКИ',     '🎈'),
  _WordPair('КНИЖКА',    'КНИЖКИ',     '📖'),
  _WordPair('ЛЯЛЬКА',    'ЛЯЛЬКИ',     '🪆'),
  _WordPair('ВЕДМЕДИК',  'ВЕДМЕДИКИ',  '🧸'),
  _WordPair('ГРИБ',      'ГРИБИ',      '🍄'),
  _WordPair('ДЕРЕВО',    'ДЕРЕВА',     '🌳'),
  _WordPair('ГРИБ',      'ГРИБИ',      '🍄'),
];

// ─────────────────────────────────────────────
//  Game screen — tap to multiply
// ─────────────────────────────────────────────

class PluralGameScreen extends ConsumerStatefulWidget {
  const PluralGameScreen({super.key});

  @override
  ConsumerState<PluralGameScreen> createState() => _PluralGameScreenState();
}

class _PluralGameScreenState extends ConsumerState<PluralGameScreen>
    with TickerProviderStateMixin {
  late List<_WordPair> _deck;
  int _index = 0;
  bool _isPlural = false; // false = showing singular, true = showing plural
  int _seen = 0;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  // Scale animation for the multiplication effect
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _deck = List<_WordPair>.from(_pairs)
      ..remove(const _WordPair('ГРИБ', 'ГРИБИ', '🍄')) // remove duplicate
      ..shuffle(Random());

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.elasticOut,
    );

    AnalyticsService.instance.logGameStart('plural_game');
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakSingular());
  }

  @override
  void dispose() {
    _confettiEntry?.remove();
    _scaleCtrl.dispose();
    super.dispose();
  }

  _WordPair get _current => _deck[_index % _deck.length];

  void _speakSingular() {
    TtsService.instance.speak(_current.singular, locale: 'uk-UA');
  }

  void _speakPlural() {
    TtsService.instance.speak(_current.plural, locale: 'uk-UA');
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    if (!_isPlural) {
      // 1 → many
      setState(() => _isPlural = true);
      _scaleCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 100), _speakPlural);
      _showConfetti();
      _seen++;
      if (!_questDone && _seen >= 5) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.playQuiz);
        AnalyticsService.instance.logGameComplete('plural_game', _seen);
      }
    } else {
      // many → 1 (toggle back)
      setState(() => _isPlural = false);
      _scaleCtrl.reverse();
      Future.delayed(const Duration(milliseconds: 100), _speakSingular);
    }
  }

  void _nextCard() {
    setState(() {
      _index++;
      _isPlural = false;
    });
    _scaleCtrl.reset();
    Future.delayed(const Duration(milliseconds: 200), _speakSingular);
  }

  void _showConfetti() {
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    _confettiEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(
            origin: Offset(size.width / 2, size.height / 2.5)),
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
          s('Один — Багато', 'One — Many'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⭐ $_seen',
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
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Instruction
            Text(
              _isPlural
                  ? s('Торкнись — повернись до одного', 'Tap to go back to one')
                  : s('Торкнись — стане багато! 👇', 'Tap to multiply! 👇'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 16),

            // Main tap area
            Expanded(
              child: GestureDetector(
                onTap: _onTap,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: _isPlural
                      ? _PluralView(
                          key: const ValueKey('plural'),
                          pair: pair,
                          scaleAnim: _scaleAnim,
                        )
                      : _SingularView(
                          key: const ValueKey('singular'),
                          pair: pair,
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Next button — only visible after seeing plural
            AnimatedOpacity(
              opacity: _isPlural ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPlural ? _nextCard : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      s('Далі ▶', 'Next ▶'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Singular view — 1 big emoji
// ─────────────────────────────────────────────

class _SingularView extends StatelessWidget {
  final _WordPair pair;
  const _SingularView({super.key, required this.pair});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Number indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '1',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kAccent,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Single big emoji
        Text(pair.emoji, style: const TextStyle(fontSize: 110)),

        const SizedBox(height: 20),

        // Singular word
        Text(
          pair.singular,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 24),

        // Tap hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: kAccent.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pair.emoji, style: const TextStyle(fontSize: 28)),
              Text(pair.emoji,
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black.withValues(alpha: 0.3))),
              Text(pair.emoji,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.15))),
              const SizedBox(width: 10),
              const Icon(Icons.touch_app_rounded,
                  color: kAccent, size: 22),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Plural view — 3 emojis + plural word
// ─────────────────────────────────────────────

class _PluralView extends StatelessWidget {
  final _WordPair pair;
  final Animation<double> scaleAnim;
  const _PluralView({super.key, required this.pair, required this.scaleAnim});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Number indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF43A047).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '3+',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Three emojis with scale animation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: scaleAnim,
              child: Text(pair.emoji,
                  style: const TextStyle(fontSize: 72)),
            ),
            const SizedBox(width: 8),
            ScaleTransition(
              scale: CurvedAnimation(
                parent: scaleAnim,
                curve: const Interval(0.1, 1.0,
                    curve: Curves.elasticOut),
              ),
              child: Text(pair.emoji,
                  style: const TextStyle(fontSize: 72)),
            ),
            const SizedBox(width: 8),
            ScaleTransition(
              scale: CurvedAnimation(
                parent: scaleAnim,
                curve: const Interval(0.2, 1.0,
                    curve: Curves.elasticOut),
              ),
              child: Text(pair.emoji,
                  style: const TextStyle(fontSize: 72)),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Plural word with green highlight
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF43A047).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            pair.plural,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }
}
