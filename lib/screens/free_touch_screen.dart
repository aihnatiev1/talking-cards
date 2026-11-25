import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/card_image.dart';
import '../widgets/cue_pill.dart';
import '../widgets/kid_screen.dart';

String _sentence(String word) => word.isEmpty
    ? word
    : word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase();

/// «Торкнись!» — the youngest child's game: every touch, anywhere, makes a
/// picture appear under the finger and says its word.
///
/// There is nothing to get wrong and nothing to finish. A one-year-old's
/// first lesson with a screen is that *I did that*; here what "that" is is
/// always a word. Touch a picture that is already there and it says its
/// word again — the same word twice is how a word is learned.
///
/// No round, no score, no celebration to interrupt the play: the game is
/// counted as played after [touchesToCount] touches and simply goes on.
class FreeTouchScreen extends ConsumerStatefulWidget {
  const FreeTouchScreen({super.key, required this.cards});

  /// The words to deal — a few are enough; they come round again.
  final List<CardModel> cards;

  /// Pictures on the meadow at once; the oldest leaves for a new one.
  static const maxPictures = 5;

  /// Touches after which the game counts as played (`game_complete`).
  static const touchesToCount = 10;

  @override
  ConsumerState<FreeTouchScreen> createState() => _FreeTouchScreenState();
}

class _Picture {
  _Picture(this.id, this.card, this.center);
  final int id;
  final CardModel card;
  final Offset center;

  /// Bumped when it is touched again, to pop it once more.
  int pops = 0;
  bool leaving = false;
  Timer? timer;
}

class _FreeTouchScreenState extends ConsumerState<FreeTouchScreen>
    with GameStateMixin {
  @override
  String get gameId => 'free_touch';

  // No daily-quest task is about free touching.
  @override
  Null get questTask => null;

  final _random = math.Random();
  final List<_Picture> _pictures = [];
  List<CardModel> _deck = const [];
  int _next = 0;
  int _serial = 0;
  int _touches = 0;
  CardModel? _lastSaid;

  @override
  void initState() {
    super.initState();
    startGame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.cards.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      AudioService.instance.playInstruction(
        'free_touch',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
  }

  @override
  void dispose() {
    for (final p in _pictures) {
      p.timer?.cancel();
    }
    AudioService.instance.stop();
    super.dispose();
  }

  /// The next word: the deck goes round in a shuffled order, so nothing is
  /// repeated until everything has been seen.
  CardModel _deal() {
    if (_next >= _deck.length) {
      final last = _deck.isEmpty ? null : _deck.last;
      _deck = List<CardModel>.from(widget.cards)..shuffle(_random);
      // Not the same word on both sides of the reshuffle.
      if (_deck.length > 1 && _deck.first.id == last?.id) {
        _deck.add(_deck.removeAt(0));
      }
      _next = 0;
    }
    return _deck[_next++];
  }

  void _say(CardModel card) {
    AudioService.instance.playWordOnly(card.audioKey, card.sound);
    setState(() => _lastSaid = card);
  }

  void _count() {
    _touches++;
    if (_touches == FreeTouchScreen.touchesToCount && !finished) {
      completeGame(finalScore: _touches);
    }
  }

  /// A finger came down at [at] in a board of [size] whose pictures are
  /// [side] across.
  void _touch(Offset at, Size size, double side) {
    // On a picture that is already there: its word again.
    for (final picture in _pictures.reversed) {
      if (!picture.leaving && (picture.center - at).distance <= side / 2) {
        FeedbackService.instance.event(FeedbackEvent.cardTouch);
        _count();
        setState(() => picture.pops++);
        _stay(picture);
        _say(picture.card);
        return;
      }
    }

    // Anywhere else: a new picture, kept wholly on the board.
    final half = side / 2;
    final center = Offset(
      at.dx.clamp(half, math.max(half, size.width - half)),
      at.dy.clamp(half, math.max(half, size.height - half)),
    );
    final picture = _Picture(_serial++, _deal(), center);
    FeedbackService.instance.event(FeedbackEvent.cardTouch);
    _count();
    setState(() {
      _pictures.add(picture);
      // Room for the new one: the oldest still standing goes.
      final standing = _pictures.where((p) => !p.leaving).toList();
      if (standing.length > FreeTouchScreen.maxPictures) _leave(standing.first);
    });
    _stay(picture);
    _say(picture.card);
  }

  /// (Re)starts the time a picture stays before it drifts away.
  void _stay(_Picture picture) {
    picture.timer?.cancel();
    picture.timer = Timer(DT.motion.lessonHint, () {
      if (mounted) setState(() => _leave(picture));
    });
  }

  void _leave(_Picture picture) {
    if (picture.leaving) return;
    picture.leaving = true;
    picture.timer?.cancel();
    picture.timer = Timer(DT.motion.slow, () {
      if (mounted) setState(() => _pictures.remove(picture));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    final said = _lastSaid;
    final cue = said == null
        ? s('Торкнись будь-де', 'Touch anywhere')
        : '${_sentence(said.sound)}!';
    final companion = DT.size.mascotCompanionOf(context);
    final strip =
        math.max(companion, DT.size.tapMin) +
        BloomMascot.hopClearance +
        DT.sp16;
    final policy = MotionPolicy.of(context);
    return KidScreen.game(
      accent: DT.brand,
      meadow: true,
      backdrop: 'assets/images/backdrops/guess_sky.webp',
      mascotCorner: BloomMascot(
        size: companion,
        semanticsLabel: s('Блум', 'Bloom'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              // The board stops above Bloom's corner: a picture never
              // lands on him or on his words.
              padding: EdgeInsets.only(bottom: strip),
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = Size(box.maxWidth, box.maxHeight);
                  // Big enough to be a picture, small enough for five.
                  final side = (size.shortestSide * .36).clamp(96.0, 168.0);
                  return Listener(
                    key: const ValueKey('free-touch-board'),
                    behavior: HitTestBehavior.opaque,
                    // Every finger counts — a toddler uses the whole hand.
                    onPointerDown: (e) => _touch(e.localPosition, size, side),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final picture in _pictures)
                          Positioned(
                            key: ValueKey('picture-${picture.id}'),
                            left: picture.center.dx - side / 2,
                            top: picture.center.dy - side / 2,
                            width: side,
                            height: side,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: picture.leaving ? 0 : 1,
                                duration: policy.dur(DT.motion.slow),
                                child: TweenAnimationBuilder<double>(
                                  // A new key per touch: it pops again.
                                  key: ValueKey(picture.pops),
                                  tween: Tween(begin: .6, end: 1),
                                  duration: policy.dur(DT.motion.successPop),
                                  curve: Curves.easeOutBack,
                                  builder: (_, t, child) =>
                                      Transform.scale(scale: t, child: child),
                                  child: _PictureDisc(card: picture.card),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: companion + 14,
            bottom: 30,
            child: IgnorePointer(
              child: Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: policy.dur(DT.motion.selectionChange),
                  child: Align(
                    key: ValueKey(cue),
                    alignment: Alignment.centerRight,
                    child: CueBubble(
                      child: Text(
                        cue,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.caption.copyWith(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: DT.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card's picture as a round sticker with a thick white rim.
class _PictureDisc extends StatelessWidget {
  const _PictureDisc({required this.card});
  final CardModel card;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DT.surfaceWhite,
        border: Border.all(color: DT.surfaceWhite, width: 6),
        boxShadow: DT.shadowSoft(card.colorAccent),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: card.colorBg,
          child: CardImage.forCard(
            card,
            fit: BoxFit.cover,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    ),
  );
}
