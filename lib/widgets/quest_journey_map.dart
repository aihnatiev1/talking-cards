import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/daily_quest_provider.dart';
import '../utils/app_icons.dart';
import 'ambient_loop.dart';
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
// One paper sticker per stop: listen → cards → guess game → cards again
// (a star for the bigger batch) → say it again → the treasure.
const _icons = [
  AppIcon.stepListen,
  AppIcon.stepCards,
  AppIcon.gameGuess,
  AppIcon.star,
  AppIcon.gameRepeat,
  AppIcon.rewardGift,
];

/// The route and its hit targets share a single measured coordinate system.
/// Small windows scroll instead of shrinking text or overlapping waypoints.
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
    final current = _tasks.indexWhere((t) => !q.completed.contains(t));
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF7F1), Color(0xFFF6F5DA), Color(0xFFDFEECF)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, viewport) {
          final wide = viewport.maxWidth > viewport.maxHeight * 1.25;
          final rows = wide ? 2 : 6;
          return SingleChildScrollView(
            key: const ValueKey('journey-scroll'),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1040 : 560),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const AppIconView(AppIcon.stepQuest, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    q.allDone
                                        ? s(
                                            'Ура! Ти дістався скарбу!',
                                            'You reached the treasure!',
                                          )
                                        : s(
                                            'Маленькі кроки до скарбу',
                                            'Little steps to treasure',
                                          ),
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      color: _ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${q.doneCount}/5',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    color: _ink,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      height: 7,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: q.completed.contains(_tasks[i])
                                            ? const Color(0xFF60AE89)
                                            : const Color(0xFFE3EDE5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, bounds) {
                        final width = bounds.maxWidth;
                        final nodeWidth = math.min(
                          wide ? width / 3 - 24 : width * .46,
                          180.0,
                        );
                        double measure(
                          String text,
                          double fontSize,
                          double? lineHeight,
                        ) {
                          final painter = TextPainter(
                            text: TextSpan(
                              text: text,
                              style: DefaultTextStyle.of(context).style
                                  .copyWith(
                                    fontFamily: 'Nunito',
                                    fontSize: fontSize,
                                    height: lineHeight,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout(maxWidth: nodeWidth);
                          final result = painter.height;
                          painter.dispose();
                          return result;
                        }

                        final labelHeight = labels
                            .map((l) => measure(l, 14, 1.15))
                            .reduce(math.max);
                        final statusHeight = measure(
                          s('Заверши 5 зупинок', 'Finish all 5 stops'),
                          10,
                          null,
                        );
                        final rowHeight = math.max(
                          112.0,
                          88 + labelHeight + statusHeight,
                        );
                        final height = math.max(
                          rows * rowHeight + 40,
                          viewport.maxHeight - 108,
                        );
                        final cell = (height - 40) / rows;
                        final positions = List.generate(6, (i) {
                          if (wide) {
                            final col = i < 3 ? i : 5 - i;
                            return Offset(
                              width * (col + .5) / 3,
                              20 + (i ~/ 3) * cell,
                            );
                          }
                          return Offset(
                            width * (i.isEven ? .28 : .72),
                            20 + i * cell,
                          );
                        });
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
                                  height: cell - 6,
                                  child: _JourneyStop(
                                    key: ValueKey('journey-stop-$i'),
                                    index: i,
                                    label: labels[i],
                                    done: i < 5
                                        ? q.completed.contains(_tasks[i])
                                        : q.rewardClaimed,
                                    active:
                                        i == current ||
                                        (i == 5 &&
                                            q.allDone &&
                                            !q.rewardClaimed),
                                    status: i == 5 && !q.allDone
                                        ? s(
                                            'Заверши 5 зупинок',
                                            'Finish all 5 stops',
                                          )
                                        : i == current
                                        ? s('Нумо сюди!', 'Let’s go!')
                                        : null,
                                    onTap: i == 5
                                        ? (q.allDone && !q.rewardClaimed
                                              ? onClaimTreasure
                                              : null)
                                        : q.completed.contains(_tasks[i])
                                        ? null
                                        : () => onStopTap(_tasks[i]),
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

class _JourneyStop extends StatelessWidget {
  final int index;
  final String label;
  final String? status;
  final bool done, active;
  final VoidCallback? onTap;
  const _JourneyStop({
    super.key,
    required this.index,
    required this.label,
    required this.done,
    required this.active,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF79BC89) : _colors[index];
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '${index + 1}. $label',
      child: KidTap(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 68,
              // The active stop hops (-3 px sine over a 3 s pass); the
              // others stand still, so at most one loop ticks per map.
              // Under reduced motion the glow and "Нумо сюди!" mark it.
              child: AmbientLoop(
                period: const Duration(seconds: 3),
                curve: Curves.linear,
                enabled: active,
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(0, -3 * math.sin(t * math.pi)),
                  child: child,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
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
                      // Sticker-edged art on the coloured plate; a finished
                      // stop shows a white paper check instead.
                      child: done
                          ? const AppIconView(
                              AppIcon.check,
                              size: 36,
                              color: Colors.white,
                            )
                          : AppIconView(_icons[index], size: 38, sticker: true),
                    ),
                    Positioned(
                      right: -7,
                      top: -5,
                      child: Container(
                        width: 23,
                        height: 23,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: index == 5
                            ? AppIconView(
                                onTap == null && !done
                                    ? AppIcon.lock
                                    : AppIcon.star,
                                size: 16,
                              )
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: _ink,
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (status != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    status!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      color: Color(0xFF557A64),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
    final paint = Paint();
    // Soft meadow banks, kept behind the route and all hit targets.
    for (var i = 0; i < 4; i++) {
      paint.color = i.isEven
          ? const Color(0xFFCEE5BC)
          : const Color(0xFFDCEBC7);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(i.isEven ? 0 : size.width, size.height * (i + .6) / 4),
          width: size.width * .75,
          height: size.height * .32,
        ),
        paint,
      );
    }
    final centers = positions.map((p) => p + const Offset(0, 32)).toList();
    for (var i = 0; i < 5; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      final path = Path()..moveTo(a.dx, a.dy);
      if (wide && i != 2) {
        path.cubicTo(
          (a.dx + b.dx) / 2,
          a.dy - 28,
          (a.dx + b.dx) / 2,
          b.dy + 28,
          b.dx,
          b.dy,
        );
      } else {
        path.cubicTo(
          a.dx,
          (a.dy + b.dy) / 2,
          b.dx,
          (a.dy + b.dy) / 2,
          b.dx,
          b.dy,
        );
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 23
        ..color = const Color(0xFFD2C69D);
      canvas.drawPath(path.shift(const Offset(0, 4)), paint);
      paint
        ..strokeWidth = 21
        ..color = const Color(0xFFFFF9DF);
      canvas.drawPath(path, paint);
      paint
        ..strokeWidth = 3
        ..color = completed[i]
            ? const Color(0xFF7DB493)
            : const Color(0xFFD9CDA5);
      for (final metric in path.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 14) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 5, metric.length)),
            paint,
          );
        }
      }
    }
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      paint.color = const Color(0xFFACC991);
      canvas.drawOval(
        Rect.fromCenter(
          center: p + const Offset(0, 66),
          width: 104,
          height: 23,
        ),
        paint,
      );
      paint.color = const Color(0xFFC2DDA0);
      canvas.drawOval(
        Rect.fromCenter(
          center: p + const Offset(0, 62),
          width: 106,
          height: 21,
        ),
        paint,
      );
      if (!wide) {
        final tree = Offset(size.width * (i.isEven ? .84 : .12), p.dy + 40);
        paint.color = const Color(0xFF91B781);
        canvas.drawOval(
          Rect.fromCenter(
            center: tree + const Offset(0, 25),
            width: 39,
            height: 10,
          ),
          paint,
        );
        paint.color = const Color(0xFFA78760);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(tree.dx - 3, tree.dy, 6, 25),
            const Radius.circular(3),
          ),
          paint,
        );
        paint.color = const Color(0xFF6BA989);
        canvas.drawCircle(tree, 18, paint);
        paint.color = const Color(0xFF90C39A);
        canvas.drawCircle(tree + const Offset(-5, -6), 12, paint);
        paint.color = const Color(0xFFC2DDA0);
        canvas.drawCircle(tree + const Offset(-8, -10), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandscapePainter old) =>
      old.wide != wide ||
      old.positions.toString() != positions.toString() ||
      old.completed.toString() != completed.toString();
}
