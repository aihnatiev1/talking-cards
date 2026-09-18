import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/crayon_palette.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

/// One drawn line, in the colour it was drawn with.
class _Stroke {
  final List<Offset> points;
  final Color color;
  const _Stroke(this.points, this.color);
}

/// Free drawing that cannot come out ugly.
///
/// Everything the child draws on one half appears mirrored on the other,
/// so a scribble becomes a butterfly, a face, a tree. That is the whole
/// idea: at two, a child's own line is a scribble and they know it —
/// symmetry hands back something that looks made on purpose, without the
/// app ever correcting anything.
///
/// No picture to fill, so no asset to draw, and nothing here can be wrong.
class MirrorDrawScreen extends ConsumerStatefulWidget {
  const MirrorDrawScreen({super.key});

  @override
  ConsumerState<MirrorDrawScreen> createState() => _MirrorDrawScreenState();
}

class _MirrorDrawScreenState extends ConsumerState<MirrorDrawScreen> {
  final List<_Stroke> _strokes = [];
  List<Offset> _current = [];
  Crayon _crayon = kCrayons.first;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart('mirror_draw');
  }

  void _start(Offset p) {
    setState(() => _current = [p]);
  }

  void _extend(Offset p) {
    setState(() => _current = [..._current, p]);
  }

  void _end() {
    if (_current.length < 2) {
      setState(() => _current = []);
      return;
    }
    FeedbackService.instance.event(FeedbackEvent.tap, haptic: false);
    ref.read(dailyQuestProvider.notifier).recordDrawing();
    setState(() {
      _strokes.add(_Stroke(_current, _crayon.color));
      _current = [];
    });
  }

  void _clear() {
    if (_strokes.isEmpty && _current.isEmpty) return;
    FeedbackService.instance.event(FeedbackEvent.tap);
    setState(() {
      _strokes.clear();
      _current = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    return KidScreen.game(
      accent: DT.brand,
      background: DT.violetTint,
      title: Text(
        s('Дзеркальце', 'Mirror'),
        style: DT.tileTitle.copyWith(color: DT.textPrimary),
      ),
      trailing: KidTap(
        onTap: _clear,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.refresh_rounded,
            size: 28,
            color: _strokes.isEmpty ? DT.textMuted : DT.brand,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DT.rLg),
                child: ColoredBox(
                  color: DT.surfaceWhite,
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _start(d.localPosition),
                      onPanUpdate: (d) => _extend(d.localPosition),
                      onPanEnd: (_) => _end(),
                      onPanCancel: _end,
                      // A tap is a dot, not nothing: a child who pokes the
                      // paper should see paint.
                      onTapDown: (d) => _start(d.localPosition),
                      onTapUp: (d) {
                        _extend(d.localPosition + const Offset(0.5, 0.5));
                        _end();
                      },
                      child: CustomPaint(
                        size: Size(box.maxWidth, box.maxHeight),
                        painter: _MirrorPainter(
                          strokes: _strokes,
                          current: _current,
                          currentColor: _crayon.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          CrayonPalette(
            selectedId: _crayon.id,
            isEn: isEn,
            onSelected: (c) => setState(() => _crayon = c),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MirrorPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset> current;
  final Color currentColor;

  const _MirrorPainter({
    required this.strokes,
    required this.current,
    required this.currentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The fold. Dashed and pale: it explains the screen without becoming
    // part of the drawing.
    final fold = Paint()
      ..color = DT.textPrimary.withValues(alpha: 0.10)
      ..strokeWidth = 2;
    const dash = 10.0;
    for (var y = 0.0; y < size.height; y += dash * 2) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dash).clamp(0, size.height)),
        fold,
      );
    }

    for (final stroke in strokes) {
      _paintPair(canvas, size, stroke.points, stroke.color);
    }
    if (current.isNotEmpty) {
      _paintPair(canvas, size, current, currentColor);
    }
  }

  /// The line, and the same line flipped about the vertical fold.
  void _paintPair(Canvas canvas, Size size, List<Offset> points, Color color) {
    final paint = Paint()
      ..color = color
      // Fat and round: a two-year-old's line, not a pencil's.
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(_pathOf(points), paint);
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(_pathOf(points), paint);
    canvas.restore();
  }

  Path _pathOf(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      path.lineTo(points.first.dx, points.first.dy);
      return path;
    }
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_MirrorPainter old) =>
      old.strokes.length != strokes.length ||
      old.current.length != current.length ||
      old.currentColor != currentColor;
}
