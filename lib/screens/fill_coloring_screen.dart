import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coloring_sheet.dart';
import '../providers/coloring_sheets_provider.dart';
import '../providers/filled_sheets_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/ambient_loop.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/crayon_palette.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

/// Tap a colour, tap a part of the picture, the whole part fills.
///
/// The first drawing screen where the child *chooses*: the water mode
/// reveals a painting that was already made, this one asks what colour
/// the mane should be. A purple lion is a right answer — there is no
/// reference to match and nothing here can be wrong.
///
/// When every part has a colour the drawing comes alive: it breathes and
/// hops, it blinks, and it pops on its own name. All three work on any
/// picture without anyone rigging it — see [_AlivePicture].
class FillColoringScreen extends ConsumerStatefulWidget {
  /// A single drawing to open, instead of the ones in the index. Tests
  /// and deep links; normally the screen takes what the folder holds.
  final String? sheetId;

  /// Bloom names the colour and the child has to find it by ear.
  ///
  /// The same picture and the same filling; what changes is that the
  /// crayon is chosen by listening rather than by looking. This is the
  /// one drawing mode that is an exercise — and it needs no new content,
  /// because all ten colour words are already recorded as cards.
  final bool byEar;

  const FillColoringScreen({
    super.key,
    this.sheetId,
    this.byEar = false,
  });

  @override
  ConsumerState<FillColoringScreen> createState() => _FillColoringScreenState();
}

class _FillColoringScreenState extends ConsumerState<FillColoringScreen>
    with SingleTickerProviderStateMixin, ConfettiOverlayMixin {
  /// Level three: one squash-and-pop the moment the picture is finished,
  /// on the same beat as the sound. Motion that lands with a noise reads
  /// as intent; the same motion in silence reads as a glitch.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: DT.motion.successPop,
  );

  ColoringSheet? _sheet;
  Crayon _crayon = kCrayons.first;

  /// The colour each area has been painted, if any.
  final Map<int, Color> _filled = {};

  /// The painted layer, rebuilt when an area changes.
  ui.Image? _paint;
  Uint32List? _buffer;
  bool _rebuilding = false;
  bool _done = false;

  /// The colour Bloom is asking for, when [FillColoringScreen.byEar].
  Crayon? _asked;

  /// Wrong crayons tried since the ask. After two, the right one glows —
  /// a child who cannot find it must not be left tapping for ever, and a
  /// hint is not a correction.
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart(
      widget.byEar ? 'fill_coloring_by_ear' : 'fill_coloring',
    );
    _load();
  }

  /// Every drawing in the folder, and which one is on the table.
  List<String> _ids = const [];
  int _at = 0;

  Future<void> _load() async {
    final only = widget.sheetId;
    final ids = only != null
        ? [only]
        : await ref.read(coloringSheetsProvider.future);
    if (!mounted || ids.isEmpty) return;
    // Start somewhere random so the same lion is not the first thing
    // every single time.
    _ids = ids;
    _at = math.Random().nextInt(ids.length);
    await _open(_ids[_at]);
  }

  Future<void> _open(String id) async {
    final sheet = await ColoringSheet.load(id);
    if (!mounted) return;
    final buffer = Uint32List(sheet.width * sheet.height);
    setState(() {
      _sheet?.lineArt.dispose();
      _sheet = sheet;
      _buffer = buffer;
      _paint?.dispose();
      _paint = null;
      _filled.clear();
      _done = false;
      _found = false;
    });
    await _restore(sheet, buffer);
    if (widget.byEar) _ask();
  }

  /// Put back what the child painted last time.
  ///
  /// Replayed from stored colours rather than saved pixels: a handful of
  /// numbers per drawing, and it still works if the artwork is redrawn.
  Future<void> _restore(ColoringSheet sheet, Uint32List buffer) async {
    final saved = ref.read(filledSheetsProvider.notifier).of(sheet.id);
    if (saved.isEmpty) return;
    for (final entry in saved.entries) {
      final pixels = sheet.pixelsOf[entry.key];
      final crayon = kCrayons.where((c) => c.id == entry.value).firstOrNull;
      if (pixels == null || crayon == null) continue;
      final packed = _packed(crayon.color);
      for (final i in pixels) {
        buffer[i] = packed;
      }
      _filled[entry.key] = crayon.color;
    }
    await _repaint();
    if (!mounted) return;
    // A picture that was already finished is alive the moment it opens —
    // it was finished, and nothing about closing the screen undid that.
    if (_paintedShare(sheet) >= _doneShare) setState(() => _done = true);
  }

  static int _packed(Color c) =>
      (0xFF << 24) |
      ((c.b * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.r * 255).round();

  /// A fresh drawing, in the order the index lists them so a child works
  /// through the whole folder instead of meeting the same three.
  void _newPicture() {
    if (_ids.length < 2) return;
    FeedbackService.instance.event(FeedbackEvent.tap);
    _at = (_at + 1) % _ids.length;
    _open(_ids[_at]);
  }

  /// Pick a colour that is not the one just asked for and say it.
  void _ask() {
    final pool = kCrayons.where((c) => c.id != _asked?.id).toList();
    final next = pool[math.Random().nextInt(pool.length)];
    setState(() {
      _asked = next;
      _misses = 0;
      // Nothing is in hand until it is found by ear.
      _crayon = next;
    });
    _sayAsked();
  }

  void _sayAsked() {
    final asked = _asked;
    if (asked == null) return;
    // The colour words are cards like any other: `colors` pack, English
    // audio keys (red, blue…), Ukrainian voice behind them.
    AudioService.instance.playWordOnly(
      asked.audio,
      asked.localizedName(ref.read(languageProvider) == 'en'),
    );
  }

  /// In by-ear mode the crayon is the answer: it is only picked up when
  /// it is the one that was named. A wrong one is never called wrong —
  /// Bloom simply says the colour again.
  void _chooseCrayon(Crayon crayon) {
    if (!widget.byEar) {
      setState(() => _crayon = crayon);
      return;
    }
    if (crayon.id == _asked?.id) {
      FeedbackService.instance.event(FeedbackEvent.correct);
      setState(() {
        _crayon = crayon;
        _found = true;
      });
      return;
    }
    setState(() => _misses++);
    _sayAsked();
  }

  /// The named crayon is in hand and the child may paint with it.
  bool _found = false;

  @override
  void dispose() {
    _pop.dispose();
    _paint?.dispose();
    disposeConfetti();
    super.dispose();
  }

  Future<void> _fill(int area) async {
    final sheet = _sheet;
    final buffer = _buffer;
    if (sheet == null || buffer == null || area == 0) return;
    final pixels = sheet.pixelsOf[area];
    if (pixels == null) return;
    if (widget.byEar && !_found) {
      // The crayon has not been found yet: the picture is not the
      // question. Say the colour again rather than doing nothing, which
      // a child reads as the screen being broken.
      _sayAsked();
      return;
    }

    final c = _crayon.color;
    // decodeImageFromPixels wants ABGR little-endian, not ARGB.
    final packed = _packed(c);
    for (final i in pixels) {
      buffer[i] = packed;
    }
    _filled[area] = c;
    ref.read(filledSheetsProvider.notifier).record(
          sheet.id,
          area,
          _crayon.id,
        );
    FeedbackService.instance.event(FeedbackEvent.tap, haptic: false);
    await _repaint();

    if (!_done && _paintedShare(sheet) >= _doneShare) {
      _finish();
      return;
    }
    // One colour, one area: the next ask comes after the paint lands, so
    // the child hears the new word with a finished stroke behind them.
    if (widget.byEar) {
      setState(() => _found = false);
      await Future<void>.delayed(DT.motion.successPop);
      if (mounted) _ask();
    }
  }

  Future<void> _repaint() async {
    final sheet = _sheet;
    final buffer = _buffer;
    if (sheet == null || buffer == null || _rebuilding) return;
    _rebuilding = true;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      buffer.buffer.asUint8List(),
      sheet.width,
      sheet.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    _rebuilding = false;
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _paint?.dispose();
      _paint = image;
    });
  }

  void _finish() {
    setState(() => _done = true);
    _pop.duration = MotionPolicy.of(context).dur(DT.motion.successPop);
    _pop.forward(from: 0);
    FeedbackService.instance.event(FeedbackEvent.correct);
    showConfetti();
    _sayTheWord();
    AnalyticsService.instance.logGameComplete(
      'fill_coloring',
      _filled.length,
    );
  }

  /// Finished when this much of the drawing has colour on it.
  ///
  /// Not every area: a picture can hold forty of them, several the size
  /// of a bow, and demanding all of them means the celebration never
  /// comes. Most of the paper covered is what "done" looks like to a
  /// child, which is the same rule the water mode uses.
  static const _doneShare = 0.85;

  double _paintedShare(ColoringSheet sheet) {
    var painted = 0, total = 0;
    for (final entry in sheet.pixelsOf.entries) {
      total += entry.value.length;
      if (_filled.containsKey(entry.key)) painted += entry.value.length;
    }
    return total == 0 ? 0 : painted / total;
  }

  /// Eyes are open nearly all the time; a blink is a fast down-and-up at
  /// the end of each cycle. Anything slower reads as sleepy, not alive.
  static double _lidAt(double t) {
    const start = 0.92;
    if (t < start) return 0;
    final k = (t - start) / (1 - start);
    return k < 0.5 ? k * 2 : (1 - k) * 2;
  }

  /// The finished picture says what it is. Level three of coming alive is
  /// the pop, and this is the sound it lands on — a squash in silence
  /// reads as a glitch, the same squash with «лев» on it reads as the
  /// drawing speaking.
  void _sayTheWord() {
    final word = _sheet?.word;
    if (word == null) return;
    final packs = ref.read(packsProvider).valueOrNull ?? const [];
    for (final pack in packs) {
      final card = pack.cards.where((c) => c.id == word).firstOrNull;
      if (card != null) {
        AudioService.instance.playWordOnly(card.audioKey, card.sound);
        return;
      }
    }
  }

  void _clear() {
    final buffer = _buffer;
    final sheet = _sheet;
    if (buffer == null || sheet == null || _filled.isEmpty) return;
    ref.read(filledSheetsProvider.notifier).clear(sheet.id);
    buffer.fillRange(0, buffer.length, 0);
    _filled.clear();
    setState(() => _done = false);
    _repaint();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final sheet = _sheet;

    return KidScreen.game(
      accent: DT.brand,
      background: DT.violetTint,
      trailing: sheet == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: s('Спочатку', 'Start over'),
                  onPressed: _clear,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 28,
                    color: _filled.isEmpty ? DT.textMuted : DT.brand,
                  ),
                ),
                if (_ids.length > 1)
                  IconButton(
                    tooltip: s('Нова картинка', 'New picture'),
                    onPressed: _newPicture,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 26),
                    color: DT.brand,
                  ),
              ],
            ),
      body: sheet == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final scale = math.min(
                          box.maxWidth / sheet.width,
                          box.maxHeight / sheet.height,
                        );
                        final w = sheet.width * scale;
                        final h = sheet.height * scale;
                        return Center(
                          child: _AlivePicture(
                            alive: _done,
                            pop: _pop,
                            child: SizedBox(
                              width: w,
                              height: h,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (d) => _fill(
                                  sheet.areaNear(
                                    (d.localPosition.dx / scale).round(),
                                    (d.localPosition.dy / scale).round(),
                                  ),
                                ),
                                child: AmbientLoop(
                                  period: DT.motion.drawingBlink,
                                  enabled: _done,
                                  builder: (_, t, __) => CustomPaint(
                                    painter: _SheetPainter(
                                      sheet: sheet,
                                      layer: _paint,
                                      filled: _filled,
                                      lid: _lidAt(t),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (widget.byEar) _AskBanner(
                  crayon: _asked,
                  found: _found,
                  isEn: isEn,
                  onRepeat: _sayAsked,
                ),
                // Finished: Bloom says so, and the one thing to do next is
                // a button a child can read without words on it. The
                // header icons above are a grown-up's affordance — a
                // two-year-old does not know a circular arrow means
                // "again", and until this panel existed there was nothing
                // else to press.
                if (_done)
                  _FinishedPanel(
                    isEn: isEn,
                    onAnother: _ids.length > 1 ? _newPicture : null,
                    onAgain: _clear,
                  )
                else
                  CrayonPalette(
                    selectedId: widget.byEar && !_found ? '' : _crayon.id,
                    isEn: isEn,
                    hintId: widget.byEar && _misses >= 2 && !_found
                        ? _asked?.id
                        : null,
                    onSelected: _chooseCrayon,
                  ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

/// Levels one and three of coming alive, and they work on any drawing.
///
/// A finished picture breathes from its own feet and hops, and pops once
/// when it is finished. Neither knows anything about what is drawn — the
/// life is in the timing, which is why this needs no rigging and cannot
/// look broken. (Level two, the blink, belongs to the painter: it has to
/// be drawn in the colour the child chose for the face.)
class _AlivePicture extends StatelessWidget {
  final bool alive;
  final Animation<double> pop;
  final Widget child;

  const _AlivePicture({
    required this.alive,
    required this.pop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pop,
      builder: (_, child) {
        // Down, then past the resting size, then settle — the shape of
        // something that just did a thing.
        final t = pop.value;
        final squash = t == 0 || t == 1
            ? 1.0
            : 1 - 0.12 * math.sin(t * math.pi) * math.cos(t * math.pi * 2);
        return Transform.scale(
          scaleY: squash,
          scaleX: 2 - squash,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: _breathing(),
    );
  }

  Widget _breathing() {
    return AmbientLoop(
      period: DT.motion.drawingBreath,
      enabled: alive,
      builder: (_, t, child) {
        // One breath in and out, with a small hop at the top of it.
        final breath = math.sin(t * math.pi * 2);
        final hop = math.max(0.0, math.sin(t * math.pi * 2)) * 6;
        return Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.scale(
            scaleX: 1 + breath * 0.012,
            scaleY: 1 + breath * 0.02,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SheetPainter extends CustomPainter {
  final ColoringSheet sheet;
  final ui.Image? layer;
  final Map<int, Color> filled;

  /// How far the eyelids are down, 0..1. Level two of coming alive, and
  /// the one that does the most work: a lid is simply the face's own
  /// colour drawn over the eye, so it only exists once a child has
  /// painted the face.
  final double lid;

  const _SheetPainter({
    required this.sheet,
    required this.layer,
    required this.filled,
    required this.lid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final src = Rect.fromLTWH(
      0,
      0,
      sheet.width.toDouble(),
      sheet.height.toDouble(),
    );
    final brush = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawRect(dst, Paint()..color = DT.surfaceWhite);
    if (layer != null) canvas.drawImageRect(layer!, src, dst, brush);
    canvas.drawImageRect(sheet.lineArt, src, dst, brush);

    if (lid <= 0) return;
    final sx = size.width / sheet.width;
    final sy = size.height / sheet.height;
    for (final eye in sheet.eyes) {
      final face = filled[eye.hostArea];
      if (face == null) continue;
      // The lid comes down from just above the eye and stops when the eye
      // is covered; the outline is drawn under it, so nothing peeks.
      final top = (eye.cy - eye.ry - 2) * sy;
      final height = (eye.ry * 2 + 4) * sy * lid;
      canvas.drawOval(
        Rect.fromLTWH(
          (eye.cx - eye.rx - 2) * sx,
          top,
          (eye.rx * 2 + 4) * sx,
          height,
        ),
        Paint()..color = face,
      );
    }
  }

  @override
  bool shouldRepaint(_SheetPainter old) =>
      old.layer != layer ||
      old.filled.length != filled.length ||
      old.lid != lid;
}

/// What Bloom is asking for, and a way to hear it again.
///
/// The colour is never shown as a swatch here — that would answer the
/// question. It is a word, and the tap-to-repeat is the whole help the
/// screen offers until the third try.
class _AskBanner extends StatelessWidget {
  final Crayon? crayon;
  final bool found;
  final bool isEn;
  final VoidCallback onRepeat;

  const _AskBanner({
    required this.crayon,
    required this.found,
    required this.isEn,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final asked = crayon;
    if (asked == null) return const SizedBox.shrink();
    final s = AppS(isEn);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: KidTap(
        onTap: onRepeat,
        sound: null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: DT.surfaceWhite,
            borderRadius: BorderRadius.circular(DT.rMd),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                found ? Icons.check_circle_rounded : Icons.volume_up_rounded,
                size: 22,
                color: found ? DT.success : DT.brand,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  found
                      ? s(
                          'Тепер тисни на картинку',
                          'Now tap the picture',
                        )
                      : s('Знайди колір', 'Find the colour'),
                  textAlign: TextAlign.center,
                  style: DT.tileTitle.copyWith(
                    fontSize: 15,
                    color: DT.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a child sees when the drawing is done.
///
/// Bloom, one word of praise, and a big button that starts another
/// picture. No icons to decode: at two, «Ще малюнок» with a picture on it
/// is the only kind of instruction that lands.
class _FinishedPanel extends StatelessWidget {
  final bool isEn;
  final VoidCallback? onAnother;
  final VoidCallback onAgain;

  const _FinishedPanel({
    required this.isEn,
    required this.onAnother,
    required this.onAgain,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BloomMascot(
                size: 72,
                state: BloomState.still(BloomEmotion.happy),
                interactive: false,
                semanticsLabel: 'Bloom',
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  s('Круто!', 'Awesome!'),
                  style: DT.h1.copyWith(fontSize: 28, color: DT.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BigButton(
                  label: s('Ще раз', 'Again'),
                  icon: AppIcon.replay,
                  background: DT.surfaceWhite,
                  foreground: DT.brand,
                  onTap: onAgain,
                ),
              ),
              if (onAnother != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _BigButton(
                    label: s('Ще малюнок', 'New picture'),
                    icon: AppIcon.navColoring,
                    background: DT.brand,
                    foreground: Colors.white,
                    onTap: onAnother!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final AppIcon icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: onTap,
      child: Container(
        height: DT.size.tapMin,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: background.withValues(alpha: .35),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconView(icon, size: 30),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.tileTitle.copyWith(fontSize: 17, color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
