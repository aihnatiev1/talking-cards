import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';

class SyllableGameScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards;

  const SyllableGameScreen({super.key, required this.cards});

  @override
  ConsumerState<SyllableGameScreen> createState() => _SyllableGameScreenState();
}

class _SyllableGameScreenState extends ConsumerState<SyllableGameScreen>
    with TickerProviderStateMixin {
  late List<CardModel> _deck;
  int _index = 0;
  int _taps = 0;
  int _score = 0;
  bool _evaluated = false;
  bool _correct = false;
  bool _questDone = false;

  Timer? _evalTimer;

  // Ripple animations for each tap
  final List<_RippleDot> _ripples = [];

  // Scale bounce on tap
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  // Result scale-in
  late AnimationController _resultCtrl;
  late Animation<double> _resultAnim;

  static const _vowels = {'А', 'Е', 'И', 'І', 'О', 'У', 'Є', 'Ї', 'Ю', 'Я'};

  static int _syllables(String word) =>
      word.toUpperCase().split('').where(_vowels.contains).length.clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _deck = List<CardModel>.from(widget.cards)..shuffle(Random());

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut),
    );

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resultAnim = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);

    AnalyticsService.instance.logGameStart('syllable_game');
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _evalTimer?.cancel();
    _bounceCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  CardModel get _current => _deck[_index];
  int get _expected => _syllables(_current.sound);

  void _speakCurrent() {
    AudioService.instance.speakCard(
      _current.audioKey,
      _current.sound,
      _current.text,
    );
  }

  void _onTap() {
    if (_evaluated) return;

    HapticFeedback.lightImpact();
    _bounceCtrl.forward().then((_) => _bounceCtrl.reverse());

    setState(() {
      _taps++;
      _ripples.add(_RippleDot());
      if (_ripples.length > 6) _ripples.removeAt(0);
    });

    // Reset the auto-evaluate timer on each tap
    _evalTimer?.cancel();
    _evalTimer = Timer(const Duration(milliseconds: 1400), _evaluate);
  }

  void _evaluate() {
    if (_evaluated) return;
    final isCorrect = _taps == _expected;
    setState(() {
      _evaluated = true;
      _correct = isCorrect;
    });
    _resultCtrl.forward(from: 0);

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _score++;
      if (!_questDone && _score >= 3) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.reviewOldCard);
        AnalyticsService.instance.logGameComplete('syllable_game', _score);
        ref.read(gameStatsProvider.notifier).record('syllable_game', _score);
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _nextCard() {
    _evalTimer?.cancel();
    setState(() {
      _index = (_index + 1) % _deck.length;
      _taps = 0;
      _evaluated = false;
      _correct = false;
      _ripples.clear();
    });
    _resultCtrl.reset();
    _speakCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.read(languageProvider) == 'en');
    final card = _current;
    final syllableCount = _expected;

    // Build syllable dots to show expected count
    final syllableDots = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        syllableCount,
        (i) => Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _evaluated
                ? (_correct ? const Color(0xFF43A047) : const Color(0xFFE53935))
                : Colors.grey[300],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s('Порахуй склади', 'Count syllables'),
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
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Card
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: _speakCurrent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: card.colorBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: card.colorAccent.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (card.image != null)
                          SizedBox(
                            height: 110,
                            child: Image.asset(
                              'assets/images/webp/${card.image}.webp',
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          Text(card.emoji,
                              style: const TextStyle(fontSize: 80)),
                        const SizedBox(height: 14),
                        // Word split into syllables when evaluated
                        _SyllableWord(
                          word: card.sound,
                          syllableCount: syllableCount,
                          revealed: _evaluated,
                          color: card.colorAccent,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up_rounded,
                                color: Colors.grey[400], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              s('Торкнись, щоб послухати',
                                  'Tap to listen'),
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
            ),

            const SizedBox(height: 16),

            // Tap counter row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s('Тапів: ', 'Taps: '),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Text(
                    '$_taps',
                    key: ValueKey(_taps),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _evaluated
                          ? (_correct
                              ? const Color(0xFF43A047)
                              : const Color(0xFFE53935))
                          : kAccent,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Result feedback
            AnimatedBuilder(
              animation: _resultAnim,
              builder: (_, child) => Transform.scale(
                scale: _evaluated ? _resultAnim.value : 1.0,
                child: child,
              ),
              child: _evaluated
                  ? Column(
                      children: [
                        Text(
                          _correct
                              ? s('Чудово! ✅', 'Perfect! ✅')
                              : s(
                                  'У слові $_syllableCount склад${_ru(syllableCount)}, а не $_taps',
                                  '$syllableCount syllable${syllableCount == 1 ? '' : 's'}, not $_taps',
                                ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _correct
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                        ),
                        const SizedBox(height: 8),
                        syllableDots,
                      ],
                    )
                  : syllableDots,
            ),

            const SizedBox(height: 20),

            // Big drum tap button
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _evaluated
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextCard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(
                            s('Далі ▶', 'Next ▶'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _onTap,
                        child: AnimatedBuilder(
                          animation: _bounceAnim,
                          builder: (_, child) => Transform.scale(
                            scale: _bounceAnim.value,
                            child: child,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ripple dots
                              ..._ripples.asMap().entries.map((e) =>
                                  _RippleWidget(dot: e.value)),

                              // Main button
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: kAccent.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🥁',
                                        style: TextStyle(fontSize: 52)),
                                    const SizedBox(height: 8),
                                    Text(
                                      s('Тап на кожен склад',
                                          'Tap for each syllable'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: kAccent.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Ukrainian syllable ending helper
  String _ru(int n) {
    if (n == 1) return '';
    if (n >= 2 && n <= 4) return 'и';
    return 'ів';
  }

  // Unused variable fix
  int get _syllableCount => _expected;
}

// ─────────────────────────────────────────────
//  Word widget that splits into syllables on reveal
// ─────────────────────────────────────────────

class _SyllableWord extends StatelessWidget {
  final String word;
  final int syllableCount;
  final bool revealed;
  final Color color;

  static const _vowels = {'А', 'Е', 'И', 'І', 'О', 'У', 'Є', 'Ї', 'Ю', 'Я'};

  const _SyllableWord({
    required this.word,
    required this.syllableCount,
    required this.revealed,
    required this.color,
  });

  // Split word into syllable groups (simple vowel-based split for Ukrainian)
  List<String> _split() {
    if (syllableCount <= 1) return [word];
    final upper = word.toUpperCase();
    final chars = upper.split('');
    final parts = <String>[];
    String current = '';
    int vowelsSeen = 0;
    final vowelsTotal = chars.where(_vowels.contains).length;

    for (int i = 0; i < chars.length; i++) {
      current += chars[i];
      if (_vowels.contains(chars[i])) {
        vowelsSeen++;
        // After each vowel except the last one, find a good split point
        if (vowelsSeen < vowelsTotal) {
          // Lookahead: if next char is a consonant followed by a vowel, split here
          // Simple rule: split after vowel if at least 1 more vowel remains
          final remaining = chars.sublist(i + 1);
          final nextVowelIdx = remaining.indexWhere(_vowels.contains);
          if (nextVowelIdx == 0) {
            // Next char is a vowel — split here
            parts.add(current);
            current = '';
          } else if (nextVowelIdx == 1) {
            // One consonant between vowels — move consonant to next syllable
            parts.add(current);
            current = '';
          } else if (nextVowelIdx >= 2) {
            // Multiple consonants — take first consonant(s) with current syllable
            // Simple: consume 1 consonant then split
            current += chars[i + 1];
            i++;
            parts.add(current);
            current = '';
          }
        }
      }
    }
    if (current.isNotEmpty) parts.add(current);
    return parts.isEmpty ? [word] : parts;
  }

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Text(
        word,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      );
    }

    final parts = _split();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: const ValueKey('split'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: parts.asMap().entries.map((e) {
          final i = e.key;
          final part = e.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                part,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (i < parts.length - 1)
                Text(
                  '-',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: color.withValues(alpha: 0.4),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Ripple dot data & widget
// ─────────────────────────────────────────────

class _RippleDot {
  final double dx;
  final double dy;
  _RippleDot()
      : dx = (Random().nextDouble() - 0.5) * 120,
        dy = (Random().nextDouble() - 0.5) * 60;
}

class _RippleWidget extends StatefulWidget {
  final _RippleDot dot;
  const _RippleWidget({required this.dot});

  @override
  State<_RippleWidget> createState() => _RippleWidgetState();
}

class _RippleWidgetState extends State<_RippleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween<double>(begin: 0.2, end: 1.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(widget.dot.dx, widget.dot.dy),
        child: Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccent.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
