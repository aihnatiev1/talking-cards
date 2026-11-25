import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/play_topic.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/play_session_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../tabs/play_tab.dart';
import '../utils/game_state_mixin.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/cue_pill.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/meadow_world.dart';

/// Where each animal lives on the farm picture: the middle of its feet as
/// fractions of the picture (x of its width, y of its height) and its size
/// as a fraction of the picture's height. Back row along the fence, middle
/// row on the meadow, the front row by the pond and in the mud — placed so
/// no two overlap.
const farmSpots = <String, (double x, double y, double size)>{
  'horse': (.33, .58, .25),
  'cow': (.50, .58, .25),
  'sheep': (.67, .58, .25),
  'bird': (.80, .50, .19),
  'owl': (.91, .44, .19),
  'chicken': (.10, .80, .22),
  'dog': (.28, .80, .22),
  'cat': (.56, .80, .22),
  'rooster': (.74, .80, .22),
  'frog': (.41, .96, .19),
  'duck': (.66, .99, .19),
  'pig': (.89, .97, .24),
};

/// The fish's patch of the pond, as fractions of the picture.
const farmPond = (left: .48, top: .80, right: .58, bottom: .99);

/// The two ways to play the farm, chosen with the big buttons at the side.
enum FarmMode { listen, riddle }

/// «Ферма» — a toy farm board, like the talking toy tablets: the whole farm
/// at once, on its side so it is wide enough, every animal in its place.
///
/// * **Слухай** — tap an animal: it opens its mouth, its sound appears in a
///   cloud and the recording says its name and its real voice; Bloom then
///   invites the child to say it too.
/// * **Загадка** — a voice without the name: who says that? A wrong tap is
///   not wrong — that animal just says its own sound. After four found the
///   farm cheers and goes back to listening.
///
/// Animals of the paid pack that the child has not earned stand asleep in
/// grey; a tap on one asks a grown-up (parental gate) before the offer.
class FarmScreen extends ConsumerStatefulWidget {
  const FarmScreen({super.key});

  /// Found animals that end a riddle round.
  static const riddlesPerRound = 4;

  @override
  ConsumerState<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends ConsumerState<FarmScreen> with GameStateMixin {
  @override
  String get gameId => 'farm';

  @override
  Null get questTask => null;

  /// A free play board, like «Торкнись!»: no round a parent watched won.
  @override
  bool get recordToStats => false;

  final _random = math.Random();
  FarmMode _mode = FarmMode.listen;

  String? _speaking;
  String? _cloud;
  final Map<String, int> _hops = {};
  final Map<String, int> _wiggles = {};
  int _fishPops = 0;

  /// The line in Bloom's bubble, and how Bloom looks while it shows.
  String? _line;
  BloomEmotion _bloom = BloomEmotion.wave;

  /// The animal the riddle asks for, and how many were found this round.
  MeadowAnimal? _asked;
  int _found = 0;
  bool _cheering = false;

  int _turn = 0;
  Timer? _cloudTimer;
  Timer? _lineTimer;
  bool _phone = false;
  bool _oriented = false;

  @override
  void initState() {
    super.initState();
    startGame();
    // Bloom says what the farm is for, then lets the animals talk.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppS(ref.read(languageProvider) == 'en');
      _say(
        s('Торкнись тваринку й послухай', 'Tap an animal and listen'),
        BloomEmotion.wave,
        forHowLong: const Duration(seconds: 5),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_oriented) return;
    _oriented = true;
    // On a phone the farm is on its side — the only screen that is: the
    // board is wide like the toy and holds the whole farm. A tablet is big
    // enough either way and keeps whatever way it is held.
    _phone = MediaQuery.sizeOf(context).shortestSide < 600;
    if (_phone) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    if (_phone) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    _cloudTimer?.cancel();
    _lineTimer?.cancel();
    _turn++;
    AudioService.instance.stop();
    super.dispose();
  }

  List<MeadowAnimal> _animals() {
    final packs = ref.read(packsProvider).valueOrNull ?? const [];
    final rewards =
        ref.read(playSessionProvider).valueOrNull?.rewards ?? const <String>{};
    return meadowAnimals(packs: packs, rewards: rewards, withLocked: true);
  }

  void _say(String? line, BloomEmotion emotion, {Duration? forHowLong}) {
    _lineTimer?.cancel();
    setState(() {
      _line = line;
      _bloom = emotion;
    });
    if (forHowLong != null) {
      final turn = _turn;
      _lineTimer = Timer(forHowLong, () {
        if (mounted && turn == _turn) {
          setState(() {
            _line = null;
            _bloom = BloomEmotion.idle;
          });
        }
      });
    }
  }

  /// The animal speaks: mouth open, its cloud, its name and voice.
  Future<int> _speak(MeadowAnimal animal) async {
    final turn = ++_turn;
    _cloudTimer?.cancel();
    setState(() {
      _speaking = animal.key;
      _cloud = animal.key;
      _hops[animal.key] = (_hops[animal.key] ?? 0) + 1;
    });
    await AudioService.instance.speakCard(
      animal.card.audioKey,
      animal.card.sound,
      animal.card.text,
    );
    if (!mounted) return turn;
    if (turn == _turn) setState(() => _speaking = null);
    _cloudTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && turn == _turn) setState(() => _cloud = null);
    });
    return turn;
  }

  Future<void> _tap(MeadowAnimal animal) async {
    if (animal.locked) return _tapLocked(animal);
    if (_cheering) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    final asked = _asked;
    if (_mode == FarmMode.riddle && asked != null) {
      if (animal.key == asked.key) return _foundIt(animal);
      // Not the one asked — that is fine: this one says who it is, and the
      // voice asked for comes again.
      FeedbackService.instance.event(FeedbackEvent.cardTouch);
      final turn = await _speak(animal);
      if (!mounted || turn != _turn || _asked?.key != asked.key) return;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || turn != _turn || _asked?.key != asked.key) return;
      _askAgain();
      return;
    }
    _say(null, BloomEmotion.listen);
    final turn = await _speak(animal);
    if (!mounted || turn != _turn) return;
    _say(
      s(
        'А ти скажи: «${animal.soundUk}»!',
        'Now you say: «${animal.soundEn}»!',
      ),
      BloomEmotion.happy,
      forHowLong: const Duration(seconds: 5),
    );
  }

  Future<void> _tapLocked(MeadowAnimal animal) async {
    FeedbackService.instance.event(FeedbackEvent.lockedHint);
    setState(() => _wiggles[animal.key] = (_wiggles[animal.key] ?? 0) + 1);
    // Asleep, not for sale: a child's way to wake a friend is to play the
    // lesson that brings it — no grown-up screen on the child's farm.
    final packs = ref.read(packsProvider).valueOrNull ?? const [];
    final topic = PlayTopic.bringing(animal.key, packs);
    if (topic == null) return;
    final isEn = ref.read(languageProvider) == 'en';
    final play = await Navigator.of(
      context,
    ).push<bool>(KidRoutes.overlay(_WakeAsk(animal: animal, isEn: isEn)));
    if (play != true || !mounted) return;
    _turn++;
    AudioService.instance.stop();
    // The lessons are built upright; the farm turns back on its side after.
    if (_phone) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    await openPlayLesson(context, ref, topic, packs);
    if (!mounted) return;
    if (_phone) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // ── Riddle ─────────────────────────────────────────────

  void _setMode(FarmMode mode) {
    final s = AppS(ref.read(languageProvider) == 'en');
    if (mode == FarmMode.listen) {
      _turn++;
      AudioService.instance.stop();
      setState(() {
        _mode = mode;
        _asked = null;
        _speaking = null;
        _cheering = false;
      });
      _say(
        s('Торкнись тваринку й послухай', 'Tap an animal and listen'),
        BloomEmotion.wave,
        forHowLong: const Duration(seconds: 4),
      );
      return;
    }
    if (_mode == FarmMode.riddle && _asked != null) {
      // The riddle button again: the same voice once more.
      _askAgain();
      return;
    }
    setState(() {
      _mode = mode;
      _found = 0;
    });
    _ask();
  }

  void _ask() {
    final open = _animals().where((a) => !a.locked).toList();
    if (open.isEmpty) return;
    final last = _asked;
    if (open.length > 1 && last != null) {
      open.removeWhere((a) => a.key == last.key);
    }
    setState(() => _asked = open[_random.nextInt(open.length)]);
    _askAgain();
  }

  Future<void> _askAgain() async {
    final asked = _asked;
    if (asked == null) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    final turn = ++_turn;
    _say(s('Хто так каже?', 'Who says that?'), BloomEmotion.listen);
    // No cloud left on the last animal: the voice now is nobody's yet —
    // with «oink» still over the pig, the horse's neigh sounded like hers.
    _cloudTimer?.cancel();
    setState(() {
      _speaking = null;
      _cloud = null;
    });
    final result = await AudioService.instance.playAfterWord(
      asked.card.audioKey,
    );
    if (!mounted || turn != _turn) return;
    if (result == AfterWord.unavailable) {
      // No voice without the name on this device: ask by the name.
      await AudioService.instance.playWordOnly(
        asked.card.audioKey,
        asked.card.sound,
      );
      if (!mounted || turn != _turn) return;
      _say(
        s(
          'Де ${asked.card.sound.toLowerCase()}?',
          'Where is the ${asked.card.sound.toLowerCase()}?',
        ),
        BloomEmotion.listen,
      );
    }
  }

  Future<void> _foundIt(MeadowAnimal animal) async {
    final s = AppS(ref.read(languageProvider) == 'en');
    FeedbackService.instance.event(FeedbackEvent.correct);
    setState(() {
      _asked = null;
      _found++;
    });
    _say(
      s(
        'Так! Це ${animal.card.sound.toLowerCase()}!',
        'Yes! The ${animal.card.sound.toLowerCase()}!',
      ),
      BloomEmotion.happy,
    );
    final turn = await _speak(animal);
    if (!mounted || turn != _turn) return;
    if (_found < FarmScreen.riddlesPerRound) {
      // A breath between the answer and the next riddle.
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || turn != _turn) return;
      _ask();
      return;
    }
    // Four found: the farm cheers, then it is a listening farm again.
    FeedbackService.instance.event(FeedbackEvent.roundDone);
    if (!finished) completeGame(finalScore: _found);
    setState(() => _cheering = true);
    _say(s('Молодець!', 'Well done!'), BloomEmotion.cheer);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || turn != _turn) return;
    _setMode(FarmMode.listen);
  }

  /// The fish has no voice of its own: it jumps with bubbles and says its
  /// name — «Рибка», «Fish» — from the animals pack.
  Future<void> _tapFish() async {
    FeedbackService.instance.event(FeedbackEvent.bubblePop);
    setState(() => _fishPops++);
    if (_cheering) return;
    final fish = (ref.read(packsProvider).valueOrNull ?? const [])
        .where((p) => p.id == 'animals' || p.id == 'en_animals')
        .expand((p) => p.cards)
        .where((c) => c.image == 'fish' && c.audioKey != null)
        .firstOrNull;
    if (fish == null) return;
    final turn = ++_turn;
    await AudioService.instance.playWordOnly(fish.audioKey, fish.sound);
    if (!mounted || turn != _turn) return;
    final s = AppS(ref.read(languageProvider) == 'en');
    final word = fish.sound.toLowerCase();
    if (_mode == FarmMode.riddle && _asked != null) {
      _askAgain();
      return;
    }
    _say(
      s('А ти скажи: «$word»!', 'Now you say: «$word»!'),
      BloomEmotion.happy,
      forHowLong: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    // Rebuild when the catalogue or the friends change (a purchase, say).
    ref.watch(packsProvider);
    ref.watch(playSessionProvider);
    final animals = _animals();
    final policy = MotionPolicy.of(context);
    final line = _line;
    // The shell without its header band: on a phone on its side every
    // point of height belongs to the farm, so the close control sits on
    // the sky instead.
    return KidScreen.game(
      showLeading: false,
      edgeToEdge: true,
      background: DT.farmSky,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _FarmBoard(
                    animals: animals,
                    onTop: _cloud ?? _speaking,
                    friend: (animal, phase) => MeadowFriend(
                      key: ValueKey('farm-${animal.key}'),
                      animal: animal,
                      isEn: s.isEn,
                      speaking: _speaking == animal.key,
                      cloud: _cloud == animal.key,
                      hops: _hops[animal.key] ?? 0,
                      wiggles: _wiggles[animal.key] ?? 0,
                      phase: phase,
                      onTap: () => _tap(animal),
                    ),
                    fish: MeadowPond(pops: _fishPops, onTap: _tapFish),
                  ),
                ),
                // Close, Bloom and his line — over the sky.
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    right: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(DT.sp8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KidCloseButton(accent: DT.brand),
                          const SizedBox(width: 4),
                          BloomMascot(
                            size: 68,
                            state: BloomState(emotion: _bloom),
                            interactive: false,
                            semanticsLabel: s('Блум', 'Bloom'),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: policy.dur(DT.motion.selectionChange),
                              child: line == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      key: ValueKey(line),
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Semantics(
                                        liveRegion: true,
                                        child: CueBubble(
                                          tailRight: false,
                                          child: Text(
                                            line,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: DT.caption.copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: DT.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (_mode == FarmMode.riddle)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 10),
                              child: _Stars(found: _found),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The toy's buttons: big, round, no words.
          _FarmButtons(
            mode: _mode,
            onListen: () => _setMode(FarmMode.listen),
            onRiddle: () => _setMode(FarmMode.riddle),
            isEn: s.isEn,
          ),
        ],
      ),
    );
  }
}

/// The farm picture fitted to the width and standing on the bottom edge —
/// a phone on its side crops a little of the sky, a tablet shows more sky
/// above it — with every animal on its spot.
class _FarmBoard extends StatelessWidget {
  const _FarmBoard({
    required this.animals,
    required this.friend,
    required this.fish,
    this.onTop,
  });

  final List<MeadowAnimal> animals;

  /// The animal speaking: drawn over its neighbours, so its cloud is never
  /// hidden behind the one standing next to it.
  final String? onTop;
  final Widget Function(MeadowAnimal animal, int phase) friend;
  final Widget fish;

  /// The picture is 2752 × 1536.
  static const _aspect = 2752 / 1536;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final h = w / _aspect;
      final top = box.maxHeight - h;
      Rect spot(double x, double y, double size) {
        final side = size * h;
        return Rect.fromLTWH(x * w - side / 2, top + y * h - side, side, side);
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: top,
            width: w,
            height: h,
            child: Image.asset(
              'assets/images/backdrops/farm_scene.webp',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: DT.mintTint),
            ),
          ),
          Positioned(
            left: farmPond.left * w,
            top: top + farmPond.top * h,
            width: (farmPond.right - farmPond.left) * w,
            height: (farmPond.bottom - farmPond.top) * h,
            child: fish,
          ),
          for (final (i, animal) in [
            ...animals.indexed.where((e) => e.$2.key != onTop),
            ...animals.indexed.where((e) => e.$2.key == onTop),
          ])
            if (farmSpots[animal.key] case (final x, final y, final size))
              Positioned.fromRect(
                // Keyed: the speaking animal moves to the top of the pile,
                // and unkeyed spots handed its neighbours a fresh state —
                // they hopped again with it.
                key: ValueKey('spot-${animal.key}'),
                rect: spot(x, y, size),
                child: friend(animal, i),
              ),
        ],
      );
    },
  );
}

/// The two round buttons at the side, like the toy's.
class _FarmButtons extends StatelessWidget {
  const _FarmButtons({
    required this.mode,
    required this.onListen,
    required this.onRiddle,
    required this.isEn,
  });

  final FarmMode mode;
  final VoidCallback onListen;
  final VoidCallback onRiddle;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    // Up to the screen's edge, its buttons clear of the rounded corner.
    final inset = MediaQuery.paddingOf(context);
    return Container(
      width: 104 + inset.right,
      padding: EdgeInsets.only(right: inset.right),
      decoration: const BoxDecoration(
        color: DT.peachTint,
        border: Border(left: BorderSide(color: DT.outline, width: 2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundButton(
            key: const ValueKey('farm-listen'),
            art: 'listen',
            label: s('Слухай', 'Listen'),
            on: mode == FarmMode.listen,
            color: DT.sky,
            onTap: onListen,
          ),
          const SizedBox(height: 20),
          _RoundButton(
            key: const ValueKey('farm-riddle'),
            art: 'question',
            label: s('Загадка', 'Riddle'),
            on: mode == FarmMode.riddle,
            color: DT.sunBurst,
            onTap: onRiddle,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.art,
    required this.label,
    required this.on,
    required this.color,
    required this.onTap,
  });

  final String art;
  final String label;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: label,
    child: KidTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MotionPolicy.of(context).dur(DT.motion.selectionChange),
        width: 84,
        height: 84,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? color : DT.surfaceWhite,
          border: Border.all(
            color: on ? DT.surfaceWhite : DT.outline,
            width: 4,
          ),
          boxShadow: DT.shadowSoft(color),
        ),
        child: AppArt(art, size: 56),
      ),
    ),
  );
}

/// Found animals of the riddle round, as stars.
class _Stars extends StatelessWidget {
  const _Stars({required this.found});
  final int found;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < FarmScreen.riddlesPerRound; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: AnimatedScale(
            scale: i < found ? 1 : .7,
            duration: MotionPolicy.of(context).dur(DT.motion.successPop),
            curve: Curves.easeOutBack,
            child: Opacity(
              opacity: i < found ? 1 : .35,
              child: const AppArt('star', size: 32),
            ),
          ),
        ),
    ],
  );
}

/// «This friend is asleep — shall we play to wake it?» A yes opens the
/// lesson that brings it; a no is just the farm again.
class _WakeAsk extends StatelessWidget {
  const _WakeAsk({required this.animal, required this.isEn});
  final MeadowAnimal animal;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DT.sp16),
        child: Material(
          color: DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rLg),
          child: Padding(
            padding: const EdgeInsets.all(DT.sp16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 120,
                  child: Image.asset(
                    'assets/images/friends/${animal.key}.webp',
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: DT.sp16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s(
                          'Цей друг ще спить. Пограємо, щоб його розбудити?',
                          'This friend is still asleep. Shall we play to wake it up?',
                        ),
                        textAlign: TextAlign.center,
                        style: DT.tileTitle.copyWith(fontSize: 19),
                      ),
                      const SizedBox(height: DT.sp16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AskButton(
                            key: const ValueKey('wake-yes'),
                            art: 'play',
                            label: s('Так', 'Yes'),
                            color: DT.mintTint,
                            onTap: () => Navigator.of(context).pop(true),
                          ),
                          const SizedBox(width: DT.sp16),
                          _AskButton(
                            key: const ValueKey('wake-no'),
                            art: null,
                            label: s('Ні', 'No'),
                            color: DT.surfaceWhite,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                    ],
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

class _AskButton extends StatelessWidget {
  const _AskButton({
    super.key,
    required this.art,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String? art;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = art;
    return Semantics(
      button: true,
      label: label,
      child: KidTap(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 110, minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: DT.sp16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(color: DT.outline, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (a != null) ...[AppArt(a, size: 40), const SizedBox(width: 6)],
              Text(label, style: DT.tileTitle),
            ],
          ),
        ),
      ),
    );
  }
}
