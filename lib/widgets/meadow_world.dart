import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../models/play_topic.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'ambient_loop.dart';
import 'animal_friend_art.dart';
import 'kid_tap.dart';
import '../utils/app_icons.dart';

/// One animal of «Лужок»: its clay friend, the sound card that gives it a
/// voice, and how the sound is written (for the grown-up to say along).
class MeadowAnimal {
  const MeadowAnimal({
    required this.key,
    required this.card,
    required this.soundUk,
    required this.soundEn,
    this.earned = false,
    this.locked = false,
    this.hasVoice = true,
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

  /// Lives in the paid pack and has not been earned: it stands on the farm
  /// as a grey silhouette with a padlock.
  final bool locked;

  /// The card is the real voice (name, then the animal). False when the
  /// sound card is out of the catalogue (the English owl, say): the animal
  /// still says its name from the animals pack, but a riddle never asks
  /// for a voice that is not there.
  final bool hasVoice;

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
///
/// [withLocked] keeps the rest too, marked [MeadowAnimal.locked] — the farm
/// shows every animal in its place and the locked ones asleep in grey.
List<MeadowAnimal> meadowAnimals({
  required List<PackModel> packs,
  required Set<String> rewards,
  bool withLocked = false,
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
    final locked = soundPack.isLocked && !meadowFree.contains(key) && !isEarned;
    if (locked && !withLocked) continue;
    final (image, uk, en) = entry.value;
    final voice = soundPack.cards
        .where((c) => c.image == image && c.audioKey != null)
        .firstOrNull;
    final card =
        voice ??
        packs
            .where((p) => p.id == 'animals' || p.id == 'en_animals')
            .expand((p) => p.cards)
            .where((c) => c.image == key && c.audioKey != null)
            .firstOrNull;
    if (card == null) continue;
    animals.add(
      MeadowAnimal(
        key: key,
        card: card,
        soundUk: uk,
        soundEn: en,
        earned: isEarned,
        locked: locked,
        hasVoice: voice != null,
      ),
    );
  }
  // Lesson friends first; otherwise meadow order.
  animals.sort((a, b) => (b.earned ? 1 : 0) - (a.earned ? 1 : 0));
  return animals;
}

/// One animal: breathing at rest, a hop on a tap, the mouth-open pose
/// while its recording plays and its sound in a cloud beside it.
class MeadowFriend extends StatelessWidget {
  const MeadowFriend({
    super.key,
    required this.animal,
    required this.isEn,
    required this.speaking,
    required this.cloud,
    required this.hops,
    required this.phase,
    required this.onTap,
    this.wiggles = 0,
  });

  final MeadowAnimal animal;
  final bool isEn;
  final bool speaking;
  final bool cloud;
  final int hops;
  final int phase;
  final VoidCallback onTap;

  /// Bumped on a tap of a locked animal: it shakes its head, asleep.
  final int wiggles;

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    final locked = animal.locked;
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
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('wiggle-$wiggles'),
                    tween: Tween(begin: wiggles == 0 ? 1 : 0, end: 1),
                    duration: policy.dur(DT.motion.slow),
                    builder: (_, t, child) => Transform.rotate(
                      angle: .08 * math.sin(t * math.pi * 4) * (1 - t),
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                    child: _sleepy(
                      locked,
                      Image.asset(
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
              ),
            ),
            if (locked)
              const Positioned(
                right: 0,
                bottom: 0,
                child: IgnorePointer(child: AppArt('padlock', size: 34)),
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

/// A locked animal: a soft grey silhouette, asleep until it is opened.
Widget _sleepy(bool locked, Widget art) => !locked
    ? art
    : Opacity(
        opacity: .75,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            .30, .55, .15, 0, 20, //
            .30, .55, .15, 0, 20,
            .30, .55, .15, 0, 20,
            0, 0, 0, 1, 0,
          ]),
          child: art,
        ),
      );

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
class MeadowPond extends StatelessWidget {
  const MeadowPond({super.key, required this.pops, required this.onTap});
  final int pops;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final policy = MotionPolicy.of(context);
    return KidTap(
      key: const ValueKey('farm-fish'),
      sound: null,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final fish = box.maxHeight * .85;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Half in the water: the painted pond shows through below.
              Positioned(
                left: (box.maxWidth - fish) / 2,
                bottom: box.maxHeight * .12,
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
                  // Whole: a straight cut across a fish read as a sliced
                  // fish, not one in the water.
                  child: const AnimalFriendArt(animal: 'fish'),
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
