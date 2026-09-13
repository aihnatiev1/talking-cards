import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import '../providers/daily_quest_provider.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'bloom_mascot.dart';
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

/// Half the stop plate, and the plate itself: a 80×80 target (G12).
const double _plate = 80;

/// Where the trail runs relative to a stop's [Positioned] box — the plate
/// sits at the top of that box, so its centre is 40 dp down. Shared by the
/// landscape painter and by Bloom, so the walker's feet stay on the path.
List<Offset> _centresOf(List<Offset> positions) =>
    [for (final p in positions) p + const Offset(0, _plate / 2)];

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
  path.cubicTo(a.dx + direction * w * .12, a.dy - 15, bend, mid - 45, bend, mid);
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

  const QuestJourneyMap({
    super.key,
    required this.quest,
    required this.isEn,
    required this.onStopTap,
    required this.onClaimTreasure,
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
          final wide = viewport.maxWidth > viewport.maxHeight * 1.25;
          return SingleChildScrollView(
            key: const ValueKey('journey-scroll'),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1100 : 800),
                child: Column(
                  children: [
                    _PawHeader(
                      done: [for (final t in _tasks) q.completed.contains(t)],
                      opened: q.allDone,
                      label: s(
                        'Кроків до скарбу: ${q.doneCount} з 5',
                        'Steps to the treasure: ${q.doneCount} of 5',
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, bounds) {
                        final width = bounds.maxWidth;
                        final nodeWidth = math.min(
                          wide ? width / 3 - 24 : width * .46,
                          180.0,
                        );
                        double measure(String text) {
                          final painter = TextPainter(
                            text: TextSpan(
                              text: text,
                              style: DefaultTextStyle.of(
                                context,
                              ).style.merge(labelStyle),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout(maxWidth: nodeWidth);
                          final result = painter.height;
                          painter.dispose();
                          return result;
                        }

                        final labelHeight = labels.map(measure).reduce(math.max);
                        final rowHeight = math.max(
                          112.0,
                          _plate + 12 + labelHeight,
                        );
                        // Unequal clearances and lateral offsets make a real trail,
                        // while measured text keeps every waypoint in its own space.
                        final height = math.max(
                          wide ? rowHeight * 2.7 + 80 : rowHeight * 8.1 + 100,
                          viewport.maxHeight - 108,
                        );
                        final cell = wide
                            ? (height - 80) / 2.7
                            : (height - 100) / 8.1;
                        const xs = [.24, .71, .35, .76, .23, .59];
                        const ys = [0.0, 1.25, 2.9, 4.35, 5.9, 7.05];
                        final positions = List.generate(6, (i) {
                          if (wide) {
                            final col = i < 3 ? i : 5 - i;
                            return Offset(
                              width * (col + .5) / 3,
                              34 +
                                  (i < 3
                                          ? (i == 1 ? .25 : 0)
                                          : (i == 4 ? 1.55 : 1.4)) *
                                      cell,
                            );
                          }
                          return Offset(width * xs[i], 40 + ys[i] * cell);
                        });
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
                                  child: CustomPaint(
                                    painter: _LandscapePainter(
                                      positions: positions,
                                      completed: _tasks
                                          .map(q.completed.contains)
                                          .toList(),
                                      wide: wide,
                                    ),
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
                                    labelStyle: labelStyle,
                                    done: i < 5
                                        ? q.completed.contains(_tasks[i])
                                        : q.rewardClaimed,
                                    active: i == current,
                                    opened: i == 5 && (q.allDone || q.rewardClaimed),
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
                                              arch: wide && current - 1 != 2,
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

  const _PawHeader({
    required this.done,
    required this.opened,
    required this.label,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < done.length; i++)
                _Paw(key: ValueKey('journey-paw-$i'), index: i, done: done[i]),
              const SizedBox(width: 8),
              AppIconView(
                opened ? AppIcon.rewardChestOpen : AppIcon.rewardChestClosed,
                size: 34,
              ),
            ],
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
  final TextStyle labelStyle;
  final bool done, active, opened;
  final VoidCallback? onTap;
  const _JourneyStop({
    super.key,
    required this.index,
    required this.label,
    required this.labelStyle,
    required this.done,
    required this.active,
    required this.opened,
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
                  Container(
                    width: _plate,
                    height: _plate,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.lerp(color, Colors.white, .48)!, color],
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
            const SizedBox(height: 6),
            Flexible(
              child: Text(label, textAlign: TextAlign.center, style: labelStyle),
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

class _LandscapePainter extends CustomPainter {
  final List<Offset> positions;
  final List<bool> completed;
  final bool wide;
  _LandscapePainter({
    required this.positions,
    required this.completed,
    required this.wide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = true;
    void oval(Offset c, double w, double h, Color color) {
      p
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), p);
    }

    void circle(Offset c, double r, Color color) =>
        oval(c, r * 2, r * 2, color);
    void line(Offset a, Offset b, Color color, double width) {
      p
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, p);
      p.style = PaintingStyle.fill;
    }

    final w = size.width;
    // Distinct storybook regions: sky, apricot meadow, lavender hills.
    oval(
      Offset(w * .05, size.height * .16),
      w * 1.08,
      size.height * .33,
      const Color(0xFFFCE4A5),
    );
    oval(
      Offset(w * .94, size.height * .48),
      w * .94,
      size.height * .36,
      const Color(0xFFE1D8F7),
    );
    oval(
      Offset(w * .12, size.height * .77),
      w * 1.0,
      size.height * .31,
      const Color(0xFFBFE5C1),
    );
    oval(
      Offset(w * .84, size.height * .96),
      w * 1.1,
      size.height * .29,
      const Color(0xFFF7D0BF),
    );

    final decoScale = (w / 430).clamp(.8, 1.5);
    void cloud(Offset c) {
      oval(
        c,
        76 * decoScale,
        19 * decoScale,
        Colors.white.withValues(alpha: .88),
      );
      circle(
        c + Offset(-17 * decoScale, -8 * decoScale),
        15 * decoScale,
        Colors.white,
      );
      circle(
        c + Offset(7 * decoScale, -14 * decoScale),
        21 * decoScale,
        Colors.white,
      );
    }

    final sun = Offset(w * .81, 45);
    circle(sun, 32 * decoScale, const Color(0xFFFFEAA3));
    circle(sun, 23 * decoScale, const Color(0xFFFFCD5F));
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      line(
        sun + Offset(math.cos(a), math.sin(a)) * 37 * decoScale,
        sun + Offset(math.cos(a), math.sin(a)) * 42 * decoScale,
        const Color(0xFFF7C557),
        3,
      );
    }
    cloud(Offset(w * .48, 43));

    final centers = _centresOf(positions);
    final riverY = (centers[1].dy + centers[2].dy) / 2;
    final river = Path()
      ..moveTo(-40, riverY - 42)
      ..cubicTo(
        w * .28,
        riverY + 65,
        w * .58,
        riverY - 75,
        w + 40,
        riverY + 36,
      );
    p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFDF5D9)
      ..strokeWidth = 76;
    canvas.drawPath(river, p);
    p
      ..color = const Color(0xFF61C5DD)
      ..strokeWidth = 57;
    canvas.drawPath(river, p);
    p
      ..color = const Color(0xFF9BE4EF)
      ..strokeWidth = 3;
    canvas.drawPath(river.shift(const Offset(0, -13)), p);
    canvas.drawPath(river.shift(const Offset(0, 13)), p);

    // Broad winding sand path with rounded bends and a dotted centre — the
    // very path Bloom walks, built by the shared `_trailSegment`.
    for (var i = 0; i < 5; i++) {
      final path = _trailSegment(
        centers[i],
        centers[i + 1],
        w,
        arch: wide && i != 2,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 29
        ..color = const Color(0xFFCBAB7B);
      canvas.drawPath(path.shift(const Offset(0, 5)), p);
      p
        ..strokeWidth = 27
        ..color = const Color(0xFFFFF8DE);
      canvas.drawPath(path, p);
      p
        ..strokeWidth = 3
        ..color = completed[i]
            ? const Color(0xFFEAA453)
            : const Color(0xFFD9BE8D);
      for (final metric in path.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 17) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 5, metric.length)),
            p,
          );
        }
      }
    }
    p.style = PaintingStyle.fill;
    // A little footbridge exactly where the trail intersects the stream.
    if (!wide) {
      final b = centers[2];
      final x = (b.dx - w * .13).clamp(28.0, w - 28);
      final c = Offset(x, riverY);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-.14);
      for (var j = -3; j <= 3; j++) {
        p.color = j.isEven ? const Color(0xFFDAA363) : const Color(0xFFECC18A);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-23, j * 11.0 - 4, 46, 10),
            const Radius.circular(3),
          ),
          p,
        );
      }
      line(
        const Offset(-25, -39),
        const Offset(-25, 39),
        const Color(0xFFA97142),
        4,
      );
      line(
        const Offset(25, -39),
        const Offset(25, 39),
        const Color(0xFFA97142),
        4,
      );
      canvas.restore();
    }
    void flower(Offset c, Color color, double r) {
      line(c, c + Offset(0, r * 2.2), const Color(0xFF629F73), 2.5);
      for (var k = 0; k < 5; k++) {
        final a = k * math.pi * 2 / 5;
        circle(c + Offset(math.cos(a), math.sin(a)) * r * .7, r * .55, color);
      }
      circle(c, r * .4, const Color(0xFFFFD365));
    }

    void tree(Offset c, bool pink) {
      oval(c + const Offset(0, 36), 57, 13, const Color(0x22805A35));
      line(
        c + const Offset(0, 3),
        c + const Offset(0, 34),
        const Color(0xFFAD7D53),
        8,
      );
      circle(c, 25, pink ? const Color(0xFFE68CAA) : const Color(0xFF56AB83));
      circle(
        c + const Offset(-12, -9),
        18,
        pink ? const Color(0xFFFFB6C8) : const Color(0xFF86CD9A),
      );
      circle(
        c + const Offset(8, -17),
        16,
        pink ? const Color(0xFFFAC5D1) : const Color(0xFFA9DE9B),
      );
      if (!pink) {
        for (final delta in [
          const Offset(-9, 9),
          const Offset(12, 1),
          const Offset(0, -14),
        ]) {
          circle(c + delta, 4, const Color(0xFFEF8871));
        }
      }
    }

    for (var i = 0; i < positions.length; i++) {
      final c = positions[i];
      final color = _colors[i];
      oval(
        c + const Offset(0, 68),
        115,
        28,
        Color.lerp(color, const Color(0xFF916C55), .3)!,
      );
      oval(
        c + const Offset(0, 61),
        120,
        27,
        Color.lerp(color, Colors.white, .45)!,
      );
      if (!wide) {
        final d = Offset(w * (i.isEven ? .83 : .12), c.dy + 55);
        if (i == 0 || i == 3) {
          tree(d, i == 3);
        } else if (i == 1 || i == 4) {
          flower(d, const Color(0xFFF186AB), 12 * decoScale);
          flower(
            d + Offset(23 * decoScale, 22),
            const Color(0xFFAF91D9),
            9 * decoScale,
          );
          flower(
            d + const Offset(-18, 30),
            const Color(0xFFFFFAE3),
            8 * decoScale,
          );
        } else if (i == 2) {
          p.color = const Color(0xFFFFF2D6);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(d.dx - 5, d.dy, 10, 24),
              const Radius.circular(4),
            ),
            p,
          );
          oval(d, 47, 27, const Color(0xFFEF8A73));
          circle(d + const Offset(-10, -2), 4, Colors.white);
          circle(d + const Offset(9, -6), 5, Colors.white);
        } else {
          // Rainbow beside the treasure meadow.
          for (var k = 0; k < 3; k++) {
            p
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7
              ..color = [
                const Color(0xFFF49BA6),
                const Color(0xFFFFD174),
                const Color(0xFF9ABCE7),
              ][k];
            canvas.drawArc(
              Rect.fromCircle(
                center: d + const Offset(0, 14),
                radius: 35 - k * 8,
              ),
              math.pi,
              math.pi,
              false,
              p,
            );
          }
          p.style = PaintingStyle.fill;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandscapePainter old) =>
      old.wide != wide ||
      old.positions.toString() != positions.toString() ||
      old.completed.toString() != completed.toString();
}
