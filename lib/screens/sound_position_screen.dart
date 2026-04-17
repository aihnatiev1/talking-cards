import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

/// Packs with abstract/emoji content excluded from sound position game
const _excludedFromSoundPos = {
  'rozmovlyalky', 'phrases', 'opposites', 'actions', 'adjectives',
  'sound_r', 'sound_l', 'sound_sh', 'sound_s', 'sound_z',
  'sound_zh', 'sound_ch', 'sound_shch', 'sound_ts',
  'en_actions', 'en_opposites', 'en_phrases', 'en_adjectives',
};

const _soundLetters = ['Р', 'Л', 'Ш', 'С', 'З', 'Ж', 'Ч', 'Щ', 'Ц'];

const _letterColors = {
  'Р': Color(0xFFE53935),
  'Л': Color(0xFF7B1FA2),
  'Ш': Color(0xFF00838F),
  'С': Color(0xFF1565C0),
  'З': Color(0xFF2E7D32),
  'Ж': Color(0xFFF57F17),
  'Ч': Color(0xFF37474F),
  'Щ': Color(0xFF004D40),
  'Ц': Color(0xFFAD1457),
};

// ─────────────────────────────────────────────
//  Setup screen — pick which sound to practice
// ─────────────────────────────────────────────

class SoundPositionSetupScreen extends ConsumerWidget {
  const SoundPositionSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    final packsAsync = ref.watch(packsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF5FF),
      appBar: AppBar(
        title: Text(
          s('Де живе звук?', 'Where is the sound?'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (packs) {
          // Collect illustrated cards from REAL packs (not emoji-only)
          final allIllustrated = packs
              .where((p) =>
                  !p.isLocked &&
                  !_excludedFromSoundPos.contains(p.id) &&
                  !p.id.startsWith('_'))
              .expand((p) => p.cards)
              .where((c) => c.image != null)
              .toList();

          // Build letter → cards map
          final Map<String, List<CardModel>> letterCards = {};
          for (final letter in _soundLetters) {
            final cards = allIllustrated
                .where((c) => c.sound.toUpperCase().contains(letter))
                .toList();
            if (cards.length >= 4) letterCards[letter] = cards;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  s('Оберіть звук для тренування',
                      'Choose a sound to practise'),
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: letterCards.length,
                  itemBuilder: (_, i) {
                    final letter = letterCards.keys.elementAt(i);
                    final cards = letterCards[letter]!;
                    final color = _letterColors[letter] ?? kAccent;
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SoundPositionGameScreen(
                            cards: cards,
                            targetSound: letter,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              letter,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cards.length} карток',
                              style: TextStyle(
                                fontSize: 11,
                                color: color.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Game screen
// ─────────────────────────────────────────────

class SoundPositionGameScreen extends ConsumerStatefulWidget {
  final List<CardModel> cards; // illustrated cards from main packs
  final String targetSound;

  const SoundPositionGameScreen({
    super.key,
    required this.cards,
    required this.targetSound,
  });

  @override
  ConsumerState<SoundPositionGameScreen> createState() =>
      _SoundPositionGameScreenState();
}

class _SoundPositionGameScreenState
    extends ConsumerState<SoundPositionGameScreen>
    with SingleTickerProviderStateMixin {
  static const _targetScore = 10;

  late List<CardModel> _deck;
  int _index = 0;
  int _score = 0;
  bool _answered = false;
  bool _done = false;
  String? _tappedPosition;
  bool _questDone = false;
  OverlayEntry? _confettiEntry;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingPos;

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
        setState(() => _shakingPos = null);
      }
    });

    // Cards already filtered for target sound + image in setup screen
    _deck = List<CardModel>.from(widget.cards)..shuffle(Random());

    AnalyticsService.instance.logGameStart('sound_position');
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _confettiEntry?.remove();
    super.dispose();
  }

  CardModel get _current => _deck[_index % _deck.length];

  String _getPosition(String word) {
    final upper = word.toUpperCase();
    final sound = widget.targetSound;
    final idx = upper.indexOf(sound);
    if (idx < 0) return 'middle';
    if (idx == 0) return 'beginning';
    if (idx >= upper.length - sound.length) return 'end';
    return 'middle';
  }

  void _speakCurrent() {
    AudioService.instance.playWordOnly(_current.audioKey, _current.sound);
  }

  void _onTap(String position) {
    if (_answered) return;
    final correct = _getPosition(_current.sound);
    final isCorrect = position == correct;

    setState(() {
      _answered = true;
      _tappedPosition = position;
    });

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
      if (!_questDone && _score >= 5) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.reviewOldCard);
        AnalyticsService.instance.logGameComplete('sound_position', _score);
      }
      if (_score >= _targetScore) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _done = true);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 900), _nextCard);
      }
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _shakingPos = position);
      _shakeCtrl.forward();
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() { _answered = false; _tappedPosition = null; });
      });
    }
  }

  void _nextCard() {
    if (!mounted) return;
    setState(() {
      _index++;
      _answered = false;
      _tappedPosition = null;
      _shakingPos = null;
    });
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
    final color = _letterColors[widget.targetSound] ?? kAccent;

    // Completion screen
    if (_done) {
      return Scaffold(
        backgroundColor: const Color(0xFFEEF5FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.targetSound,
                      style: TextStyle(
                          fontSize: 80, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 16),
                  const Text('🎉', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text(
                    s('Чудово! $_score / $_targetScore правильно!',
                        'Great! $_score / $_targetScore correct!'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(s('Назад', 'Back')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _score = 0;
                              _index = 0;
                              _done = false;
                              _answered = false;
                              _questDone = false;
                            });
                            _deck.shuffle(Random());
                            _speakCurrent();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(s('Ще раз 🔄', 'Again 🔄')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final card = _current;
    final correctPos = _getPosition(card.sound);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s('Де звук ${widget.targetSound}?',
              'Where is ${widget.targetSound}?'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _letterColors[widget.targetSound] ?? kAccent,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⭐ $_score/$_targetScore',
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
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _score / _targetScore,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),

              // Card — tappable for audio
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: _speakCurrent,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _CardView(
                      key: ValueKey(_index),
                      card: card,
                      targetSound: widget.targetSound,
                      revealed: _answered,
                      correctPos: correctPos,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Question label
              Text(
                s('Де звук «${widget.targetSound}» у цьому слові?',
                    'Where is «${widget.targetSound}» in this word?'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700]),
              ),

              const SizedBox(height: 20),

              // Position buttons — visual dots + label
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _posBtn('beginning', s('Початок', 'Start'),
                        [true, false, false], correctPos),
                    const SizedBox(width: 10),
                    _posBtn('middle', s('Середина', 'Middle'),
                        [false, true, false], correctPos),
                    const SizedBox(width: 10),
                    _posBtn('end', s('Кінець', 'End'),
                        [false, false, true], correctPos),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posBtn(String position, String label, List<bool> dots,
      String correctPos) {
    final isTapped = _tappedPosition == position;
    final isCorrect = _answered && position == correctPos;
    final isWrong = _answered && isTapped && position != correctPos;
    final isShaking = _shakingPos == position;

    Widget btn = Expanded(
      child: GestureDetector(
        onTap: () => _onTap(position),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isCorrect
                ? const Color(0xFFE8F5E9)
                : isWrong
                    ? const Color(0xFFFFEBEE)
                    : kAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCorrect
                  ? const Color(0xFF43A047)
                  : isWrong
                      ? const Color(0xFFE53935)
                      : kAccent.withValues(alpha: 0.2),
              width: isCorrect || isWrong ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCorrect)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF43A047), size: 32)
              else if (isWrong)
                const Icon(Icons.cancel_rounded,
                    color: Color(0xFFE53935), size: 32)
              else ...[
                // Position indicator: 3 squares, active one is filled
                // [■□□] beginning / [□■□] middle / [□□■] end
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = dots[i];
                    return Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: active
                            ? kAccent
                            : kAccent.withValues(alpha: 0.15),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCorrect
                      ? const Color(0xFF2E7D32)
                      : isWrong
                          ? const Color(0xFFC62828)
                          : kAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isShaking) {
      btn = Expanded(
        child: AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) {
            final offset =
                8 * (0.5 - (_shakeAnim.value % 0.25) / 0.25).abs() * 2 - 4;
            return Transform.translate(
                offset: Offset(offset, 0), child: child);
          },
          child: (btn as Expanded).child,
        ),
      );
    }

    return btn;
  }
}

// ─────────────────────────────────────────────
//  Card with highlighted target sound
// ─────────────────────────────────────────────

class _CardView extends StatelessWidget {
  final CardModel card;
  final String targetSound;
  final bool revealed;
  final String correctPos;

  const _CardView({
    super.key,
    required this.card,
    required this.targetSound,
    required this.revealed,
    required this.correctPos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card.colorBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: card.colorAccent.withValues(alpha: 0.25), width: 1.5),
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
            Text(card.emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 14),
          _HighlightedWord(
              word: card.sound,
              targetSound: targetSound,
              color: card.colorAccent),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_up_rounded,
                  color: Colors.grey[400], size: 14),
              const SizedBox(width: 4),
              Text(
                'торкнись, щоб послухати',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightedWord extends StatelessWidget {
  final String word;
  final String targetSound;
  final Color color;

  const _HighlightedWord({
    required this.word,
    required this.targetSound,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final upper = word.toUpperCase();
    final idx = upper.indexOf(targetSound);

    if (idx < 0) {
      return Text(word,
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: color));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: color),
        children: [
          if (idx > 0)
            TextSpan(text: word.substring(0, idx)),
          TextSpan(
            text: word.substring(idx, idx + targetSound.length),
            style: TextStyle(
              color: Colors.red[700],
              decoration: TextDecoration.underline,
              decorationColor: Colors.red[700],
              decorationThickness: 2.5,
            ),
          ),
          if (idx + targetSound.length < word.length)
            TextSpan(
                text:
                    word.substring(idx + targetSound.length)),
        ],
      ),
    );
  }
}
