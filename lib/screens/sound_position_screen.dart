import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

// ─── Pack ID → target sound letter ───────────
const _soundMap = {
  'sound_r':    'Р',
  'sound_l':    'Л',
  'sound_sh':   'Ш',
  'sound_s':    'С',
  'sound_z':    'З',
  'sound_zh':   'Ж',
  'sound_ch':   'Ч',
  'sound_shch': 'Щ',
  'sound_ts':   'Ц',
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
          final soundPacks = packs
              .where((p) => _soundMap.containsKey(p.id))
              .toList();

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
                    childAspectRatio: 1.0,
                  ),
                  itemCount: soundPacks.length,
                  itemBuilder: (_, i) {
                    final pack = soundPacks[i];
                    final letter = _soundMap[pack.id]!;
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SoundPositionGameScreen(
                            pack: pack,
                            targetSound: letter,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: pack.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: pack.color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(pack.icon,
                                style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text(
                              letter,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: pack.color,
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
  final PackModel pack;
  final String targetSound;

  const SoundPositionGameScreen({
    super.key,
    required this.pack,
    required this.targetSound,
  });

  @override
  ConsumerState<SoundPositionGameScreen> createState() =>
      _SoundPositionGameScreenState();
}

class _SoundPositionGameScreenState
    extends ConsumerState<SoundPositionGameScreen>
    with SingleTickerProviderStateMixin {
  late List<CardModel> _deck;
  int _index = 0;
  int _score = 0;
  bool _answered = false;
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

    // Filter cards that actually contain the target sound
    _deck = widget.pack.cards
        .where((c) => c.sound.toUpperCase().contains(widget.targetSound))
        .toList()
      ..shuffle(Random());

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
    AudioService.instance.speakCard(
      _current.audioKey,
      _current.sound,
      _current.text,
    );
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
      if (!_questDone && _score >= 5) {
        _questDone = true;
        ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.reviewOldCard);
        AnalyticsService.instance.logGameComplete('sound_position', _score);
      }
      Future.delayed(const Duration(milliseconds: 900), _nextCard);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _shakingPos = position);
      _shakeCtrl.forward();
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
    final card = _current;
    final correctPos = _getPosition(card.sound);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.pack.icon,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              s('Де звук ${widget.targetSound}?',
                  'Where is ${widget.targetSound}?'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
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

              // Position buttons
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _posBtn('beginning', s('ПОЧАТОК', 'START'),
                        Icons.first_page_rounded, correctPos),
                    const SizedBox(width: 10),
                    _posBtn('middle', s('СЕРЕДИНА', 'MIDDLE'),
                        Icons.linear_scale_rounded, correctPos),
                    const SizedBox(width: 10),
                    _posBtn('end', s('КІНЕЦЬ', 'END'),
                        Icons.last_page_rounded, correctPos),
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

  Widget _posBtn(String position, String label, IconData icon,
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
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : isWrong
                        ? Icons.cancel_rounded
                        : icon,
                color: isCorrect
                    ? const Color(0xFF43A047)
                    : isWrong
                        ? const Color(0xFFE53935)
                        : kAccent,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
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
