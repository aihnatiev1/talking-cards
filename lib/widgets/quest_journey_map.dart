import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import '../providers/daily_quest_provider.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'bloom_mascot.dart';
import 'card_image.dart';
import 'kid_tap.dart';

const _ink = Color(0xFF254F49);
const _tasks = [
  QuestTask.listenCardOfDay,
  QuestTask.viewCards3,
  QuestTask.playQuiz,
  QuestTask.viewCards5,
  QuestTask.reviewOldCard,
];
const _colors = [
  Color(0xFFF29269),
  Color(0xFF68B9DD),
  Color(0xFFB59ADE),
  Color(0xFFEAC45D),
  Color(0xFF6FBEA7),
  Color(0xFFE9B64F),
];
// One drawn landmark per stop (ux-gap-audit G13): an ear to listen with,
// a tree hung with cards, a bell to guess by, a star for the bigger batch
// of cards, a flower-microphone to say it again — and the chest.
const _icons = [
  AppIcon.stepListen,
  AppIcon.stopCardTree,
  AppIcon.stopBell,
  AppIcon.star,
  AppIcon.stopMicFlower,
  AppIcon.rewardChestClosed,
];

/// A child-sized icon plate inside an 80×80 touch target.
const double _plate = 72;

/// Where the trail runs relative to a stop's [Positioned] box — the plate
/// sits at the top of that box. The artwork and Bloom use the same anchors.
List<Offset> _centresOf(List<Offset> positions) => [
  for (final p in positions) p + const Offset(0, _plate / 2),
];

/// One segment of the sand path. [arch] is the wide-layout flyover; the
/// phone layout switchbacks down the meadow.
Path _trailSegment(Offset a, Offset b, double w, {required bool arch}) {
  final path = Path()..moveTo(a.dx, a.dy);
  if (arch) {
    path.cubicTo(
      a.dx + (b.dx - a.dx) * .3,
      a.dy - 70,
      b.dx - (b.dx - a.dx) * .3,
      b.dy + 65,
      b.dx,
      b.dy,
    );
    return path;
  }
  final direction = b.dx > a.dx ? 1.0 : -1.0;
  final mid = (a.dy + b.dy) / 2;
  final bend = (b.dx + direction * w * .13).clamp(28.0, w - 28);
  path.cubicTo(
    a.dx + direction * w * .12,
    a.dy - 15,
    bend,
    mid - 45,
    bend,
    mid,
  );
  path.cubicTo(
    bend,
    mid + 48,
    b.dx - direction * w * .17,
    b.dy + 12,
    b.dx,
    b.dy,
  );
  return path;
}

/// The route and its hit targets share a single measured coordinate system.
/// Small windows scroll instead of shrinking text or overlapping waypoints.
///
/// Bloom is the traveller: he stands at the stop the child is on and walks
/// the trail to the next one when it is finished (G13). He is *decorative*
/// here — a frozen [BloomState], never the live scene — so the mascot on
/// the host screen keeps its own brain.
class QuestJourneyMap extends StatelessWidget {
  final DailyQuestState quest;
  final bool isEn;
  final ValueChanged<QuestTask> onStopTap;
  final VoidCallback onClaimTreasure;

  /// The picture of the day's theme (a [CardImage] asset name), drawn in
  /// the header medallion. Null keeps the old wordless header.
  final String? themeImage;

  /// What assistive tech reads for that medallion.
  final String? themeLabel;

  /// A stop that has just been finished elsewhere: it pops once when the
  /// child comes back, so returning to the map shows her what changed.
  final QuestTask? justCompleted;

  const QuestJourneyMap({
    super.key,
    required this.quest,
    required this.isEn,
    required this.onStopTap,
    required this.onClaimTreasure,
    this.themeImage,
    this.themeLabel,
    this.justCompleted,
  });

  String s(String uk, String en) => isEn ? en : uk;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final labels = [
      s('Послухай!', 'Listen!'),
      s('Знайди 3 картки', 'Find 3 cards'),
      s('Вгадай звук', 'Guess the sound'),
      s('Переглянь 5 карток', 'View 5 cards'),
      s('Повтори за мною', 'Repeat after me'),
      q.rewardClaimed
          ? s('Скарб знайдено!', 'Treasure found!')
          : q.allDone
          ? s('Відкрий скарб!', 'Open the treasure!')
          : s('Скарб чекає', 'Treasure awaits'),
    ];
    final firstOpen = _tasks.indexWhere((t) => !q.completed.contains(t));
    // Where the traveller stands: the first unfinished stop, or the chest.
    final current = firstOpen < 0 ? 5 : firstOpen;
    final labelStyle = DT.tileTitle.copyWith(fontSize: 14, color: _ink);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2F5FF), Color(0xFFFFF4D8), Color(0xFFF8E5F2)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, viewport) {
          return SingleChildScrollView(
            key: const ValueKey('journey-scroll'),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    _PawHeader(
                      done: [for (final t in _tasks) q.completed.contains(t)],
                      opened: q.allDone,
                      themeImage: themeImage,
                      themeLabel: themeLabel,
                      label: s(
                        'Кроків до скарбу: ${q.doneCount} з 5',
                        'Steps to the treasure: ${q.doneCount} of 5',
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, bounds) {
                        final width = bounds.maxWidth;
                        // Keep the complete book visible at its original aspect ratio.
                        // Only the icon targets sit on the artwork; the current
                        // instruction lives below it so large text cannot collide.
                        const nodeWidth = 80.0;
                        const rowHeight = 80.0;
                        final height = width * 1.5;
                        const anchors = [
                          Offset(.26, .27),
                          Offset(.60, .40),
                          Offset(.28, .53),
                          Offset(.76, .60),
                          Offset(.30, .74),
                          Offset(.78, .81),
                        ];
                        final positions = [
                          for (final anchor in anchors)
                            Offset(
                              width * anchor.dx,
                              height * anchor.dy - _plate / 2,
                            ),
                        ];
                        final centres = _centresOf(positions);
                        // Bloom stands beside the plate, on whichever side
                        // keeps him inside the map.
                        Offset shift(int i) =>
                            centres[i].dx + _plate + 30 > width
                            ? const Offset(-52, 6)
                            : const Offset(52, 6);
                        return SizedBox(
                          height: height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: Image.asset(
                                    'assets/images/journey_storybook.webp',
                                    key: const ValueKey('journey-storybook'),
                                    fit: BoxFit.contain,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ),
                              for (var i = 0; i < 6; i++)
                                Positioned(
                                  left: positions[i].dx - nodeWidth / 2,
                                  top: positions[i].dy,
                                  width: nodeWidth,
                                  height: rowHeight,
                                  child: _JourneyStop(
                                    key: ValueKey('journey-stop-$i'),
                                    index: i,
                                    label: labels[i],
                                    done: i < 5
                                        ? q.completed.contains(_tasks[i])
                                        : q.rewardClaimed,
                                    active: i == current,
                                    celebrate:
                                        i < 5 && _tasks[i] == justCompleted,
                                    opened:
                                        i == 5 &&
                                        (q.allDone || q.rewardClaimed),
                                    onTap: i == 5
                                        ? (q.allDone && !q.rewardClaimed
                                              ? onClaimTreasure
                                              : null)
                                        : q.completed.contains(_tasks[i])
                                        ? null
                                        : () => onStopTap(_tasks[i]),
                                  ),
                                ),
                              // The moving layer: its own repaint boundary
                              // over the static landscape.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: RepaintBoundary(
                                    child: _Traveller(
                                      index: current,
                                      anchor: centres[current] + shift(current),
                                      route: current == 0
                                          ? null
                                          : _trailSegment(
                                              centres[current - 1],
                                              centres[current],
                                              width,
                                              arch: false,
                                            ),
                                      fromShift: current == 0
                                          ? Offset.zero
                                          : shift(current - 1),
                                      toShift: shift(current),
                                      cheering: q.allDone,
                                      semanticsLabel: s('Блюм', 'Bloom'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: AnimatedSwitcher(
                        duration: MotionPolicy.of(context).dur(DT.motion.base),
                        child: Text(
                          labels[current],
                          key: ValueKey(labels[current]),
                          textAlign: TextAlign.center,
                          style: labelStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// «Маленькі кроки до скарбу»: five paw prints that fill in, and the chest
/// they lead to. No counter, no words — rule 4.
class _PawHeader extends StatelessWidget {
  final List<bool> done;
  final bool opened;

  /// Spoken by assistive tech in place of the counter that used to be text.
  final String label;

  /// The day's subject, as a picture. The five stops all work with it, and
  /// this medallion is the only place that says so — in the one language a
  /// two-year-old reads (п. 25 + rule 4).
  final String? themeImage;
  final String? themeLabel;

  const _PawHeader({
    required this.done,
    required this.opened,
    required this.label,
    this.themeImage,
    this.themeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Semantics(
        label: label,
        container: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10254F49),
                offset: Offset(0, 5),
                blurRadius: 15,
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (themeImage != null) ...[
                  _ThemeMedallion(
                    key: const ValueKey('journey-theme'),
                    image: themeImage!,
                    label: themeLabel,
                  ),
                  const SizedBox(width: 10),
                ],
                for (var i = 0; i < done.length; i++)
                  _Paw(
                    key: ValueKey('journey-paw-$i'),
                    index: i,
                    done: done[i],
                  ),
                const SizedBox(width: 8),
                AppIconView(
                  opened ? AppIcon.rewardChestOpen : AppIcon.rewardChestClosed,
                  size: 34,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The day's picture in a white ring — a sticker of the theme, not a label.
class _ThemeMedallion extends StatelessWidget {
  final String image;
  final String? label;
  const _ThemeMedallion({super.key, required this.image, this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFE2A8), width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A254F49),
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: ClipOval(
          // Play may still be delivering the artwork; CardImage answers
          // with a placeholder instead of throwing (CLAUDE.md).
          child: CardImage(
            name: image,
            fallbackEmoji: '🗺️',
            padding: const EdgeInsets.all(3),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _Paw extends StatelessWidget {
  final int index;
  final bool done;
  const _Paw({super.key, required this.index, required this.done});

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Transform.rotate(
        angle: index.isEven ? -0.16 : 0.16,
        child: AnimatedScale(
          duration: motion.dur(DT.motion.base),
          curve: DT.motion.emphasized,
          scale: done ? 1 : 0.82,
          child: AnimatedOpacity(
            duration: motion.dur(DT.motion.base),
            opacity: done ? 1 : 0.45,
            child: AppIconView(
              AppIcon.pawStep,
              size: 28,
              color: done ? null : DT.textPrimary.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyStop extends StatelessWidget {
  final int index;
  final String label;
  final bool done, active, opened;

  /// This stop was finished on the screen the child has just come back
  /// from: the plate hops once so the change has a place on the map
  /// (п. 25). Purely visual — the host screen owns the sound.
  final bool celebrate;
  final VoidCallback? onTap;
  const _JourneyStop({
    super.key,
    required this.index,
    required this.label,
    required this.done,
    required this.active,
    required this.opened,
    this.celebrate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF79BC89) : _colors[index];
    final icon = index == 5 && opened ? AppIcon.rewardChestOpen : _icons[index];
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: KidTap(
        onTap: onTap,
        // The map already answers with Bloom and the paw prints; a tock on
        // top of the screen it opens would be one sound too many.
        sound: null,
        child: Column(
          children: [
            SizedBox(
              height: _plate,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _ArrivalPop(
                    play: celebrate,
                    child: Container(
                      width: _plate,
                      height: _plate,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(color, Colors.white, .48)!,
                            color,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .95),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color.lerp(color, _ink, .3)!,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: _ink.withValues(alpha: .18),
                            offset: const Offset(0, 11),
                            blurRadius: 10,
                          ),
                          if (active)
                            BoxShadow(
                              color: color.withValues(alpha: .4),
                              blurRadius: 22,
                              spreadRadius: 5,
                            ),
                        ],
                      ),
                      alignment: Alignment.center,
                      // The landmark stays when the stop is finished — a bare
                      // check says "something happened" but not what; the
                      // check rides as a small badge instead.
                      child: AppIconView(icon, size: 46, sticker: true),
                    ),
                  ),
                  if (done || (index == 5 && onTap == null && !opened))
                    Positioned(
                      right: -6,
                      top: -5,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: AppIconView(
                          done ? AppIcon.check : AppIcon.lock,
                          size: 18,
                          color: done ? DT.success : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloom walking the trail (G13).
///
/// He rests at [anchor]. When [index] changes he walks [route] — the sand
/// path between the two stops, shifted from [fromShift] to [toShift] so his
/// feet leave one plate and arrive at the next — over
/// [DTMotion.journeyStep], with sparks on arrival. Under reduced motion the
/// walk collapses to zero and he simply appears at the new stop; the
/// success sound still plays, because that is feedback, not motion.
/// One hop of a stop plate when the child comes back having finished it.
///
/// The map used to change silently: you left, you played, you returned and
/// a plate was green — the moment of "I did that" happened on another
/// screen. This gives it a place on the route. Reduced motion keeps the
/// plate still; the check badge is the state, this is only its arrival.
class _ArrivalPop extends StatefulWidget {
  final bool play;
  final Widget child;
  const _ArrivalPop({required this.play, required this.child});

  @override
  State<_ArrivalPop> createState() => _ArrivalPopState();
}

class _ArrivalPopState extends State<_ArrivalPop>
    with SingleTickerProviderStateMixin {
  // Built in initState, not lazily: a stop that never pops is still
  // disposed, and a `late` controller born inside dispose() looks up a
  // deactivated ancestor.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: DT.motion.celebrate);
    if (widget.play) _c.forward();
  }

  @override
  void didUpdateWidget(_ArrivalPop old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) {
      _c
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPolicy.of(context).reduce) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        if (t == 0 || t == 1) return child!;
        final pop = math.sin(t * math.pi);
        return Transform.scale(
          scale: 1 + 0.18 * pop,
          child: Transform.rotate(
            angle: 0.08 * math.sin(t * math.pi * 2),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _Traveller extends StatefulWidget {
  final int index;
  final Offset anchor;
  final Path? route;
  final Offset fromShift, toShift;
  final bool cheering;
  final String semanticsLabel;

  const _Traveller({
    required this.index,
    required this.anchor,
    required this.route,
    required this.fromShift,
    required this.toShift,
    required this.cheering,
    required this.semanticsLabel,
  });

  @override
  State<_Traveller> createState() => _TravellerState();
}

class _TravellerState extends State<_Traveller>
    with SingleTickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: DT.motion.journeyStep,
    // Rests at the end of the walk: the sparks are gone and Bloom stands.
    value: 1,
  );
  PathMetric? _metric;

  @override
  void didUpdateWidget(_Traveller old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    final route = widget.route;
    if (route == null || widget.index < old.index) {
      _metric = null;
      _walk.value = 1;
      return;
    }
    // The step is worth a sound whatever the motion setting; the walk and
    // the sparks are what reduced motion drops.
    FeedbackService.instance.event(FeedbackEvent.correct);
    if (MotionPolicy.of(context).reduce) {
      _metric = null;
      _walk.value = 1;
      return;
    }
    _metric = route.computeMetrics().firstOrNull;
    _walk.forward(from: 0);
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  /// Where Bloom is at `t`, and which way he faces.
  (Offset, BloomFacing) _pose(double t) {
    final metric = _metric;
    if (metric == null || t >= 1) {
      return (
        widget.anchor,
        widget.toShift.dx < 0 ? BloomFacing.right : BloomFacing.left,
      );
    }
    final eased = DT.motion.standard.transform(t);
    final tangent = metric.getTangentForOffset(metric.length * eased);
    final on = tangent?.position ?? widget.anchor;
    final shift = Offset.lerp(widget.fromShift, widget.toShift, eased)!;
    final dx = tangent?.vector.dx ?? 0;
    return (on + shift, dx < 0 ? BloomFacing.right : BloomFacing.left);
  }

  @override
  Widget build(BuildContext context) {
    final size = DT.size.mascotCompanion;
    return AnimatedBuilder(
      animation: _walk,
      builder: (context, _) {
        final t = _walk.value;
        final (position, facing) = _pose(t);
        final walking = t < 1;
        return Stack(
          children: [
            Positioned(
              left: position.dx - size / 2,
              top: position.dy - size,
              width: size,
              height: size,
              child: CustomPaint(
                foregroundPainter: _SparkPainter(t),
                child: BloomMascot(
                  size: size,
                  facing: facing,
                  interactive: false,
                  semanticsLabel: widget.semanticsLabel,
                  state: BloomState.still(
                    walking
                        ? BloomEmotion.happy
                        : widget.cheering
                        ? BloomEmotion.cheer
                        : BloomEmotion.idle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Six sparks around the traveller as he lands on the new stop; nothing
/// before the walk is half over and nothing at rest.
class _SparkPainter extends CustomPainter {
  final double t;
  const _SparkPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= .5 || t >= 1) return;
    final v = (t - .5) / .5;
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide * (0.45 + 0.35 * v);
    final alpha = 1 - v;
    final paint = Paint()..color = DT.sunBurst.withValues(alpha: alpha);
    final core = Paint()..color = Colors.white.withValues(alpha: alpha);
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * reach;
      canvas.drawCircle(p, 3.5 * (1 - 0.5 * v), paint);
      canvas.drawCircle(p, 1.4 * (1 - 0.5 * v), core);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.t != t;
}
