import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../models/play_topic.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'animal_friend_art.dart';
import 'bloom_mascot.dart';
import 'cue_pill.dart';
import 'kid_tap.dart';
import 'play_components.dart';

/// One animal of «Лужок»: its clay friend, the sound card that gives it a
/// voice, and how the sound is written (for the grown-up to say along).
class MeadowAnimal {
  const MeadowAnimal({
    required this.key,
    required this.card,
    required this.soundUk,
    required this.soundEn,
    this.earned = false,
  });

  /// The clay friend: `assets/images/friends/<key>.webp` and its
  /// mouth-open pose in `friends/talk/`.
  final String key;

  /// The animal-sound card: the narrator's word, then the real voice.
  final CardModel card;
  final String soundUk;
  final String soundEn;

  /// Brought by a lesson — it wears a star.
  final bool earned;

  String sound(bool isEn) => isEn ? soundEn : soundUk;
}

/// The twelve animals with a voice, in meadow order: the sound card's
/// picture name and how the sound is written.
const meadowVoices = <String, (String card, String uk, String en)>{
  'cat': ('ph_cat', 'няв-няв', 'meow'),
  'dog': ('ph_dog', 'гав-гав', 'woof'),
  'cow': ('ph_cow', 'му-у', 'moo'),
  'horse': ('ph_horse', 'і-го-го', 'neigh'),
  'pig': ('ph_pig', 'рох-рох', 'oink'),
  'chicken': ('ph_hen', 'ко-ко-ко', 'cluck'),
  'duck': ('ph_duck', 'кря-кря', 'quack'),
  'frog': ('ph_frog', 'ква-ква', 'ribbit'),
  'sheep': ('ph_sheep', 'бе-е', 'baa'),
  'rooster': ('ph_rooster', 'ку-ку-рі-ку', 'cock-a-doodle-doo'),
  'bird': ('ph_bird', 'цвірінь', 'tweet'),
  'owl': ('ph_owl', 'пу-гу', 'hoo-hoo'),
};

/// The five that live on the meadow from the start — the animal-sound
/// pack's free preview.
const meadowFree = <String>{'cat', 'dog', 'cow', 'horse', 'pig'};

/// Who lives on the meadow.
///
/// With the animal-sound pack open (Pro) every animal is there. Without
/// it: the five free ones, and every friend a lesson brought — and that
/// friend has its voice even when the voice is in the paid pack, because
/// the child earned it. Lesson friends come first and wear a star.
List<MeadowAnimal> meadowAnimals({
  required List<PackModel> packs,
  required Set<String> rewards,
}) {
  final soundPack = packs
      .where((p) => p.id == 'animal_sounds' || p.id == 'en_animal_sounds')
      .firstOrNull;
  if (soundPack == null) return const [];
  final earned = <String>{
    for (final topic in PlayTopic.all)
      if (rewards.contains(topic.id))
        AnimalFriendArt.friendOf(topic.images.first),
  };
  final animals = <MeadowAnimal>[];
  for (final entry in meadowVoices.entries) {
    final key = entry.key;
    final isEarned = earned.contains(key);
    if (soundPack.isLocked && !meadowFree.contains(key) && !isEarned) {
      continue;
    }
    final (image, uk, en) = entry.value;
    final card = soundPack.cards
        .where((c) => c.image == image && c.audioKey != null)
        .firstOrNull;
    if (card == null) continue;
    animals.add(
      MeadowAnimal(
        key: key,
        card: card,
        soundUk: uk,
        soundEn: en,
        earned: isEarned,
      ),
    );
  }
  // Lesson friends first; otherwise meadow order.
  animals.sort((a, b) => (b.earned ? 1 : 0) - (a.earned ? 1 : 0));
  return animals;
}

/// «Лужок» — the free play: a wide meadow to walk with a finger, the
/// animals on it breathing; a tap and the animal opens its mouth, its
/// sound appears in a cloud by it and the recording plays — the name,
/// then the real voice. Bloom then invites the child to say it too, and
/// waits: no microphone, no verdict.
class MeadowWorld extends StatefulWidget {
  const MeadowWorld({super.key, required this.animals, required this.isEn});

  final List<MeadowAnimal> animals;
  final bool isEn;

  /// Height of the meadow strip.
  static const height = 330.0;

  @override
  State<MeadowWorld> createState() => _MeadowWorldState();
}

class _MeadowWorldState extends State<MeadowWorld> {
  /// The animal speaking now, by key.
  String? _speaking;

  /// The animal whose sound cloud is showing.
  String? _cloud;

  /// Taps per animal, to hop it again each time.
  final Map<String, int> _hops = {};

  /// Bloom's line: the invitation to repeat after an animal has spoken.
  MeadowAnimal? _invite;

  int _fishPops = 0;
  int _turn = 0;
  Timer? _cloudTimer;
  Timer? _inviteTimer;

  @override
  void dispose() {
    _cloudTimer?.cancel();
    _inviteTimer?.cancel();
    _turn++;
    super.dispose();
  }

  Future<void> _tap(MeadowAnimal animal) async {
    final turn = ++_turn;
    _cloudTimer?.cancel();
    _inviteTimer?.cancel();
    setState(() {
      _speaking = animal.key;
      _cloud = animal.key;
      _invite = null;
      _hops[animal.key] = (_hops[animal.key] ?? 0) + 1;
    });
    await AudioService.instance.speakCard(
      animal.card.audioKey,
      animal.card.sound,
      animal.card.text,
    );
    if (!mounted || turn != _turn) return;
    setState(() {
      _speaking = null;
      _invite = animal;
    });
    // The cloud stays a little while the child answers.
    _cloudTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && turn == _turn) setState(() => _cloud = null);
    });
    _inviteTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && turn == _turn) setState(() => _invite = null);
    });
  }

  void _tapFish() {
    FeedbackService.instance.event(FeedbackEvent.bubblePop);
    setState(() => _fishPops++);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn);
    final invite = _invite;
    final line = invite == null
        ? s('Торкнись друга й послухай', 'Tap a friend and listen')
        : s(
            'А ти скажи: «${invite.soundUk}»!',
            'Now you say: «${invite.soundEn}»!',
          );
    return Column(
      children: [
        // Bloom and his line.
        SizedBox(
          height: 96,
          child: Row(
            children: [
              BloomMascot(
                size: 88,
                state: BloomState(
                  emotion: invite == null
                      ? BloomEmotion.wave
                      : BloomEmotion.listen,
                ),
                interactive: false,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MotionPolicy.of(
                    context,
                  ).dur(DT.motion.selectionChange),
                  child: Align(
                    key: ValueKey(line),
                    alignment: Alignment.centerLeft,
                    child: CueBubble(
                      tailRight: false,
                      child: Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.caption.copyWith(
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: DT.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(DT.rLg),
          child: SizedBox(
            height: MeadowWorld.height,
            child: _MeadowStrip(
              animals: widget.animals,
              friend: (animal) => _MeadowFriend(
                key: ValueKey('meadow-${animal.key}'),
                animal: animal,
                isEn: widget.isEn,
                speaking: _speaking == animal.key,
                cloud: _cloud == animal.key,
                hops: _hops[animal.key] ?? 0,
                phase: widget.animals.indexOf(animal),
                onTap: () => _tap(animal),
              ),
              fish: _Pond(pops: _fishPops, onTap: _tapFish),
            ),
          ),
        ),
      ],
    );
  }
}

/// One animal: breathing at rest, a hop on a tap, the mouth-open pose
/// while its recording plays and its sound in a cloud beside it.
class _MeadowFriend extends StatelessWidget {
  const _MeadowFriend({
    super.key,
    required this.animal,
    required this.isEn,
    required this.speaking,
    required this.cloud,
    required this.hops,
    required this.phase,
    required this.onTap,
  });

  final MeadowAnimal animal;
  final bool isEn;
  final bool speaking;
  final bool cloud;
  final int hops;
  final int phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    final art = speaking
        ? 'assets/images/friends/talk/${animal.key}.webp'
        : 'assets/images/friends/${animal.key}.webp';
    return Semantics(
      button: true,
      label: animal.card.sound,
      child: KidTap(
        // The animal itself answers — no tock over its voice.
        sound: null,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AmbientLoop(
                // Each breathes at its own pace, so the meadow is not a
                // row of metronomes.
                period: DT.motion.speakerPulse * (3 + .3 * (phase % 5)),
                builder: (_, t, child) => Transform.scale(
                  scale: 1 + .025 * t,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: TweenAnimationBuilder<double>(
                  // A new key per tap: it hops again.
                  key: ValueKey(hops),
                  tween: Tween(begin: hops == 0 ? 1 : 0, end: 1),
                  duration: policy.dur(DT.motion.slow),
                  builder: (_, t, child) => Transform.translate(
                    offset: Offset(0, -26 * math.sin(t * math.pi)),
                    child: child,
                  ),
                  child: Image.asset(
                    art,
                    gaplessPlayback: true,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) =>
                        AnimalFriendArt(animal: animal.key),
                  ),
                ),
              ),
            ),
            if (animal.earned)
              const Positioned(
                left: 4,
                top: 4,
                child: IgnorePointer(child: AppArtStar()),
              ),
            // Above the head, centred: at the side it ran off the meadow's
            // edge for the animals nearest it.
            Positioned(
              left: -30,
              right: -30,
              top: -34,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedScale(
                    scale: cloud ? 1 : 0,
                    duration: policy.dur(DT.motion.successPop),
                    curve: Curves.easeOutBack,
                    alignment: Alignment.bottomCenter,
                    child: _SoundCloud(text: animal.sound(isEn)),
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

/// The small painted star on a lesson friend.
class AppArtStar extends StatelessWidget {
  const AppArtStar({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/icons/star.webp',
    width: 30,
    height: 30,
    errorBuilder: (_, __, ___) => const SizedBox.square(dimension: 30),
  );
}

/// The animal's sound written in a white cloud, with three little waves —
/// the waves say «it is speaking» to a child, the word tells the grown-up
/// what to say along.
class _SoundCloud extends StatelessWidget {
  const _SoundCloud({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    decoration: BoxDecoration(
      color: DT.surfaceWhite,
      borderRadius: BorderRadius.circular(20),
      boxShadow: DT.shadowSoft(DT.brand),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: DT.tileTitle.copyWith(fontSize: 18, color: DT.brand)),
        const SizedBox(width: 6),
        const _Waves(),
      ],
    ),
  );
}

class _Waves extends StatelessWidget {
  const _Waves();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(16, 20), painter: _WavesPainter());
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      paint.color = [DT.coral, DT.sky, DT.sunBurst][i];
      final r = 4.0 + i * 4;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, size.height / 2), radius: r),
        -.8,
        1.6,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => false;
}

/// The pond: water and the clay fish; a tap and it jumps, with bubbles.
class _Pond extends StatelessWidget {
  const _Pond({required this.pops, required this.onTap});
  final int pops;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    return KidTap(
      key: const ValueKey('meadow-fish'),
      sound: null,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final fish = box.maxHeight * 1.1;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Half in the water: the painted pond shows through below.
              Positioned(
                left: (box.maxWidth - fish) / 2,
                bottom: box.maxHeight * .35,
                width: fish,
                height: fish,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(pops),
                  tween: Tween(begin: pops == 0 ? 1 : 0, end: 1),
                  duration: policy.dur(DT.motion.celebrate),
                  builder: (_, t, child) => Transform.translate(
                    offset: Offset(0, -34 * math.sin(t * math.pi)),
                    child: child,
                  ),
                  child: ClipRect(
                    clipper: const _AboveWater(),
                    child: const AnimalFriendArt(animal: 'fish'),
                  ),
                ),
              ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: box.maxWidth * (.3 + .17 * i),
                  bottom: box.maxHeight * .6,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('bubble-$pops-$i'),
                    tween: Tween(begin: pops == 0 ? 1 : 0, end: 1),
                    duration: policy.dur(
                      DT.motion.celebrate + DT.motion.instant * i,
                    ),
                    builder: (_, t, child) => Opacity(
                      opacity: pops == 0 ? 0 : (1 - t),
                      child: Transform.translate(
                        offset: Offset(0, -50 * t),
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: 12.0 + 4 * i,
                      height: 12.0 + 4 * i,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: DT.sky, width: 2),
                        color: DT.surfaceWhite.withValues(alpha: .5),
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

/// The part of the fish above the water line (its lower quarter is under).
class _AboveWater extends CustomClipper<Rect> {
  const _AboveWater();
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    -size.width,
    -size.height,
    size.width * 3,
    size.height * 1.75,
  );
  @override
  bool shouldReclip(_AboveWater old) => false;
}

/// The painted meadow, as wide as its animals need: the panorama repeats
/// sideways, and every repeat ends in its pond. The animals stand in one
/// row on the lawn, each on its own patch of grass and never on the water;
/// the fish lives in the last pond.
class _MeadowStrip extends StatelessWidget {
  const _MeadowStrip({
    required this.animals,
    required this.friend,
    required this.fish,
  });

  final List<MeadowAnimal> animals;
  final Widget Function(MeadowAnimal animal) friend;
  final Widget fish;

  /// The panorama is 4 : 1.
  static const _aspect = 4.0;

  /// Where the pond is on one panorama, as fractions of its width/height.
  static const _pondLeft = .835;
  static const _pondTop = .67;
  static const _pondBottom = .9;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight;
      final tile = h * _aspect;
      final size = h * .5;
      final step = size + 14;
      // One row, left to right, stepping over each pond.
      final xs = <double>[];
      var x = 16.0;
      for (var i = 0; i < animals.length; i++) {
        final inTile = x % tile;
        if (inTile + size > tile * _pondLeft) {
          x += tile - inTile + 16;
        }
        xs.add(x);
        x += step;
      }
      final tiles = math.max(1, ((x + 16) / tile).ceil());
      final width = math.max(box.maxWidth, tiles * tile);
      final pond = Rect.fromLTRB(
        (tiles - 1) * tile + tile * _pondLeft,
        h * _pondTop,
        tiles * tile,
        h * _pondBottom,
      );
      return SingleChildScrollView(
        key: const ValueKey('meadow-scroll'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: DT.skyTint,
                    image: DecorationImage(
                      image: const AssetImage(
                        'assets/images/backdrops/meadow_panorama.webp',
                      ),
                      fit: BoxFit.fitHeight,
                      alignment: Alignment.centerLeft,
                      repeat: ImageRepeat.repeatX,
                      filterQuality: FilterQuality.medium,
                      onError: (_, __) {},
                    ),
                  ),
                ),
              ),
              for (final (i, animal) in animals.indexed)
                Positioned(
                  left: xs[i],
                  // Standing on the lawn, feet a little above the flowers.
                  bottom: h * .06,
                  width: size,
                  height: size,
                  child: friend(animal),
                ),
              Positioned.fromRect(rect: pond, child: fish),
            ],
          ),
        ),
      );
    },
  );
}

/// Kept so a screen can show an empty meadow while the catalogue loads.
class MeadowPlaceholder extends StatelessWidget {
  const MeadowPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: MeadowWorld.height,
    child: PlayPanel(child: SizedBox.expand()),
  );
}
