import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/game_state_mixin.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/animal_friend_art.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/cue_pill.dart';
import '../widgets/game_celebration_overlay.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/listen_button.dart';
import '../widgets/quiz_options_board.dart';

/// The animals that can hide: the clay friends that have a card — and so a
/// recorded name — in the free animals pack. No fish (it does not hide in
/// a bush) and no rabbit (Bloom is one).
const hideSeekAnimals = <String>{
  'cat',
  'dog',
  'cow',
  'horse',
  'pig',
  'chicken',
  'duck',
  'frog',
};

/// The free animals packs, by language.
const hideSeekPackIds = <String>{'animals', 'en_animals'};

/// The cards «Хованки» can play with: one per clay friend, with a name
/// that is recorded and on the device.
List<CardModel> hideSeekPool(PackModel pack) => [
  for (final card in pack.cards)
    if (hideSeekAnimals.contains(card.image) &&
        AudioService.instance.hasSound(card.audioKey) &&
        AudioService.instance.isWordAvailable(card.audioKey))
      card,
];

String _lower(String word) => word.toLowerCase();
String _sentence(String word) => word.isEmpty
    ? word
    : word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase();

/// «Котик ховається!» — the animal is the subject, so its name stays in
/// the nominative, which is the only form that is recorded and written.
String hideSeekHiding(CardModel card, {required bool isEn}) => isEn
    ? 'The ${_lower(card.sound)} is hiding!'
    : '${_sentence(card.sound)} ховається!';

String hideSeekWhere(CardModel card, {required bool isEn}) =>
    isEn ? 'Where is the ${_lower(card.sound)}?' : 'Де ${_lower(card.sound)}?';

String hideSeekHere(CardModel card, {required bool isEn}) =>
    isEn ? 'Here is the ${_lower(card.sound)}!' : 'Ось ${_lower(card.sound)}!';

/// «Хованки» — an animal hides behind a bush, a crate or a haystack, and
/// the child finds it by name.
///
/// Peek-a-boo with a word in it. For a child of 1–3 one friend shows
/// itself, is named, and ducks behind one of two places with its ears
/// still showing: «Де котик?» is answered by remembering, and that is the
/// game at that age. From three, two friends hide at once behind three
/// places and only one is asked for — now the word decides.
///
/// Nothing is ever wrong: an empty place wiggles, the other friend pops up
/// to say hello, and the word is said again.
class HideSeekScreen extends ConsumerStatefulWidget {
  const HideSeekScreen({super.key, required this.cards});

  /// The pool, from [hideSeekPool]. At least two cards.
  final List<CardModel> cards;

  /// Animals found in one round of play.
  static const rounds = 5;

  @override
  ConsumerState<HideSeekScreen> createState() => _HideSeekScreenState();
}

enum _Step { showing, asking, found }

class _HideSeekScreenState extends ConsumerState<HideSeekScreen>
    with GameStateMixin {
  @override
  String get gameId => 'hide_seek';

  @override
  int get maxRounds => HideSeekScreen.rounds;

  // No daily-quest task is about hide and seek.
  @override
  Null get questTask => null;

  final _random = math.Random();
  late final BloomReactions _bloom = ref.read(bloomReactionsProvider.notifier);

  /// Who is behind each place this turn (`null` — nobody).
  List<CardModel?> _places = const [];
  late CardModel _target;
  CardModel? _lastTarget;
  _Step _step = _Step.showing;

  /// Places whose friend is up and visible right now.
  final Set<int> _up = {};

  /// Bumped on every turn, so a late timer or clip cannot move a screen
  /// that has moved on.
  int _turn = 0;
  int _misses = 0;
  final Map<int, int> _nudges = {};
  bool _celebrationShown = false;
  Timer? _timer;

  static const _places3 = ['bush', 'crate', 'hay'];

  int get _level => ref.read(profileProvider).active?.level ?? 2;

  @override
  void initState() {
    super.initState();
    _bloom.sceneEntered(this, BloomScene.game);
    startGame();
    _deal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.cards.length < 2) {
        Navigator.of(context).pop();
        return;
      }
      AudioService.instance.playInstruction(
        'hide_seek',
        isEn: ref.read(languageProvider) == 'en',
      );
      _show();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turn++;
    _bloom.sceneLeft(this);
    AudioService.instance.stop();
    super.dispose();
  }

  /// Who hides where this turn. Not the friend that was just found.
  void _deal() {
    final pool = List<CardModel>.from(widget.cards)..shuffle(_random);
    final target = pool.firstWhere(
      (c) => c.id != _lastTarget?.id,
      orElse: () => pool.first,
    );
    final older = _level > 2 && pool.length >= 2;
    final count = older ? 3 : 2;
    final places = List<CardModel?>.filled(count, null);
    final order = List<int>.generate(count, (i) => i)..shuffle(_random);
    places[order[0]] = target;
    if (older) {
      places[order[1]] = pool.firstWhere((c) => c.id != target.id);
    }
    _target = target;
    _lastTarget = target;
    _places = places;
    _up
      ..clear()
      ..addAll([
        for (final (i, c) in places.indexed)
          if (c != null) i,
      ]);
    _step = _Step.showing;
    _misses = 0;
    _nudges.clear();
  }

  // ── The turn ────────────────────────────────────────────────────────

  /// The friends stand up where they are about to hide. With one friend,
  /// it is named now; with two, naming one would give the answer away.
  void _show() {
    final turn = ++_turn;
    if (_places.whereType<CardModel>().length == 1) {
      AudioService.instance.playWordOnly(_target.audioKey, _target.sound);
    }
    _timer?.cancel();
    _timer = Timer(DT.motion.pairHold, () {
      if (!mounted || turn != _turn) return;
      setState(() {
        _up.clear();
        _step = _Step.asking;
      });
      _scheduleWord(DT.motion.slow);
    });
  }

  void _scheduleWord(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (mounted && _step == _Step.asking) _sayWord();
    });
  }

  void _sayWord() {
    if (_step != _Step.asking) return;
    AudioService.instance.playWordOnly(_target.audioKey, _target.sound);
  }

  Future<void> _tapPlace(int index) async {
    if (_step != _Step.asking) return;
    final who = _places[index];

    if (who?.id != _target.id) {
      FeedbackService.instance.event(FeedbackEvent.wrong);
      final turn = _turn;
      setState(() {
        _misses++;
        _nudges[index] = (_nudges[index] ?? 0) + 1;
        // Someone else is here: it pops up to say hello and ducks again.
        if (who != null) _up.add(index);
      });
      if (_misses == 2) {
        FeedbackService.instance.event(FeedbackEvent.lockedHint);
        final at = _places.indexWhere((c) => c?.id == _target.id);
        if (at >= 0) _bloom.nudged(quizOptionDirection(at, _places.length));
      }
      _timer?.cancel();
      _timer = Timer(DT.motion.quizRetell, () {
        if (!mounted || turn != _turn || _step != _Step.asking) return;
        setState(() => _up.remove(index));
        _sayWord();
      });
      return;
    }

    _timer?.cancel();
    final turn = ++_turn;
    FeedbackService.instance.event(FeedbackEvent.correct);
    scorePoint();
    setState(() {
      _step = _Step.found;
      _up.add(index);
    });
    // The whole clip — the name and its phrase — while the friend is out.
    await Future.wait([
      Future<void>.delayed(DT.motion.pairHold),
      AudioService.instance
          .speakCard(_target.audioKey, _target.sound, _target.text)
          .timeout(_clipCap, onTimeout: () {}),
    ]);
    if (!mounted || turn != _turn) return;
    if (!nextRound() || roundsPlayed >= HideSeekScreen.rounds) {
      if (!finished) completeGame();
      _celebrate();
      return;
    }
    setState(_deal);
    _show();
  }

  static const _clipCap = Duration(seconds: 6);

  void _celebrate() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    showGameCelebration(
      context,
      isEn: ref.read(languageProvider) == 'en',
      childName: ref.read(profileProvider).active?.name ?? '',
      onAgain: () {
        resetGame();
        setState(() {
          _celebrationShown = false;
          _deal();
        });
        _show();
      },
      onDone: () => Navigator.of(context).pop(),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final single = _places.whereType<CardModel>().length == 1;
    final cue = switch (_step) {
      // Two friends: no name yet — the question will choose.
      _Step.showing =>
        single
            ? hideSeekHiding(_target, isEn: isEn)
            : s('Хто ховається?', 'Who is hiding?'),
      _Step.found => hideSeekHere(_target, isEn: isEn),
      _Step.asking =>
        _misses >= 2
            ? s('Дивись, я підкажу', 'Look, I’ll show you')
            : _misses > 0
            ? s('Послухай ще раз', 'Listen once more')
            : hideSeekWhere(_target, isEn: isEn),
    };
    final companion = DT.size.mascotCompanionOf(context);
    final strip =
        math.max(companion, DT.size.tapMin) +
        BloomMascot.hopClearance +
        DT.sp16;
    return KidScreen.game(
      accent: DT.brand,
      meadow: true,
      backdrop: 'assets/images/backdrops/guess_sky.webp',
      title: ListenButton(
        key: const ValueKey('hide-seek-word'),
        label: s('Послухати ще раз', 'Listen again'),
        onTap: () {
          if (_step != _Step.asking) return;
          _timer?.cancel();
          _sayWord();
        },
      ),
      progress: roundsPlayed / HideSeekScreen.rounds,
      mascotCorner: BloomMascot(
        size: companion,
        semanticsLabel: s('Блум', 'Bloom'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, strip),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final height = math.min(box.maxHeight, 340.0);
                    return SizedBox(
                      height: height,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, who) in _places.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _Place(
                                key: ValueKey('place-$i'),
                                art: _places3[i % _places3.length],
                                who: who,
                                up: _up.contains(i),
                                // After two misses the right friend shows
                                // a little more of itself.
                                peeking:
                                    _step == _Step.asking &&
                                    _misses >= 2 &&
                                    who?.id == _target.id,
                                nudge: _nudges[i] ?? 0,
                                onTap: () => _tapPlace(i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
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
                  duration: MotionPolicy.of(
                    context,
                  ).dur(DT.motion.selectionChange),
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

/// One hiding place with whoever is behind it.
///
/// The friend is drawn under the place's picture and slides up behind it:
/// ears only while hidden, a little more as a hint, almost all of it when
/// it stands up. The whole cell is the tap target.
class _Place extends StatefulWidget {
  const _Place({
    super.key,
    required this.art,
    required this.who,
    required this.up,
    required this.peeking,
    required this.nudge,
    required this.onTap,
  });

  final String art;
  final CardModel? who;
  final bool up;
  final bool peeking;
  final int nudge;
  final VoidCallback onTap;

  @override
  State<_Place> createState() => _PlaceState();
}

class _PlaceState extends State<_Place> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: DT.motion.slow,
  );

  @override
  void didUpdateWidget(_Place old) {
    super.didUpdateWidget(old);
    if (widget.nudge > old.nudge && !MotionPolicy.of(context).reduce) {
      _wiggle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.who;
    final policy = MotionPolicy.of(context);
    return KidTap(
      onTap: widget.onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          // The place: as wide as the cell, standing on its bottom edge.
          final placeHeight = math.min(w * .8, h * .5);
          final friend = math.min(w * .78, h * .5);
          // How far the friend's feet are above the ground. Hidden, only
          // its ears clear the top of the place; as a hint, its eyes do;
          // standing up, nearly all of it.
          final lift = widget.up
              ? placeHeight - friend * .22
              : widget.peeking
              ? placeHeight - friend * .58
              : placeHeight - friend * .84;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (who != null)
                AnimatedPositioned(
                  duration: policy.dur(DT.motion.slow),
                  curve: Curves.easeOutBack,
                  bottom: lift,
                  width: friend,
                  height: friend,
                  child: AnimalFriendArt(
                    key: ValueKey('hider-${who.image}'),
                    animal: who.image!,
                  ),
                ),
              Positioned(
                bottom: 0,
                width: w,
                height: placeHeight,
                child: AnimatedBuilder(
                  animation: _wiggle,
                  builder: (_, child) => Transform.rotate(
                    angle: math.sin(_wiggle.value * math.pi * 4) * .06,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                  child: Image.asset(
                    'assets/images/hide/${widget.art}.webp',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: DT.mint,
                        borderRadius: BorderRadius.circular(DT.rLg),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
