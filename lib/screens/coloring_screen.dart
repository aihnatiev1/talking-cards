import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/paywall_flow.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';

/// Water-reveal coloring screen.
///
/// Two-layer rendering inside one [CustomPainter]:
///   • bottom: original colored webp drawn normally
///   • top:    same image with a desaturating [ColorFilter], clipped by
///             [BlendMode.dstOut] strokes drawn by the child's finger — the
///             strokes "erase" the faded layer so the color underneath
///             shows through, mimicking Water Wow / Aquadoodle toys.
///
/// Completion is detected by marking cells on a 24×24 grid overlaying the
/// fitted image rect; at ≥ 85% cells revealed we fire confetti and
/// [AudioService.playWordOnly] once.
class ColoringScreen extends ConsumerStatefulWidget {
  const ColoringScreen({super.key});

  @override
  ConsumerState<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends ConsumerState<ColoringScreen>
    with ConfettiOverlayMixin, TickerProviderStateMixin {
  static const int _gridCols = 24;
  static const int _gridRows = 24;
  static const double _completionRatio = 0.85;

  static const _completedCountKey = 'coloring_completed_count';
  static const _freeAllowance = 1;

  final math.Random _rng = math.Random();

  CardModel? _card;
  ui.Image? _image;
  int _loadGen = 0;

  final List<List<Offset>> _strokes = [];
  final List<Offset> _current = [];
  final Set<int> _revealedCells = {};

  Rect? _imageRect;
  bool _done = false;
  int _completedCount = 0;
  bool _paywallGated = false;

  /// 1.0 = overlay fully visible (not revealed), 0.0 = fully revealed.
  /// Once the child reaches 85%, we animate this to 0 so the remaining
  /// stubborn contour bits melt away on their own.
  late final AnimationController _revealCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    value: 1.0,
  );

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart('coloring');
    _loadCompletedCount();
    // packsProvider is async + language-aware (en_cards.json vs uk_cards.json).
    // Listen so we pick on first load AND reset if language changes out from
    // under us — otherwise a card picked in UA mode would still display its
    // Ukrainian sound label after switching to EN.
    ref.listenManual(packsProvider, (prev, next) {
      final packs = next.valueOrNull;
      if (packs == null || packs.isEmpty) return;
      final inPool = _card != null &&
          packs
              .expand((p) => p.cards)
              .any((c) => c.id == _card!.id && c.sound == _card!.sound);
      if (_card == null || !inPool) {
        _resetAndPick();
      }
    }, fireImmediately: true);
  }

  Future<void> _loadCompletedCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _completedCount = prefs.getInt(_completedCountKey) ?? 0;
    });
  }

  Future<void> _incrementCompletedCount() async {
    final prefs = await SharedPreferences.getInstance();
    _completedCount += 1;
    await prefs.setInt(_completedCountKey, _completedCount);
  }

  /// Returns true if the user has exhausted the free allowance and is not Pro.
  /// Callers should skip card-loading and let the build show the paywall banner.
  bool _isGated() {
    final isPro = ref.read(isProProvider);
    return !isPro && _completedCount >= _freeAllowance;
  }

  void _resetAndPick() {
    setState(() {
      _strokes.clear();
      _current.clear();
      _revealedCells.clear();
      _done = false;
      _image = null;
      _card = null;
      _paywallGated = _isGated();
    });
    _revealCtrl.value = 1.0;
    if (_paywallGated) return;
    _pickCardAndLoad();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    disposeConfetti();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Card selection & image loading
  // ─────────────────────────────────────────────

  void _pickCardAndLoad() {
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final pool = packs
        .where((p) => !p.id.startsWith('_'))
        .expand((p) => p.cards)
        .where((c) => c.image != null)
        .toList();
    if (pool.isEmpty) return;
    final next = pool[_rng.nextInt(pool.length)];
    // Avoid immediate repeat.
    final chosen = (_card != null && pool.length > 1 && next.id == _card!.id)
        ? pool[(_rng.nextInt(pool.length - 1) + 1) % pool.length]
        : next;
    _card = chosen;
    _loadImage(chosen);
  }

  Future<void> _loadImage(CardModel card) async {
    final gen = ++_loadGen;
    final data =
        await rootBundle.load('assets/images/webp/${card.image}.webp');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final frame = await codec.getNextFrame();
    if (!mounted || gen != _loadGen) return;
    setState(() => _image = frame.image);
  }

  // ─────────────────────────────────────────────
  //  Gesture / grid tracking
  // ─────────────────────────────────────────────

  double _brushRadius(Rect r) =>
      (math.min(r.width, r.height) * 0.085).clamp(24.0, 56.0);

  void _onStart(Offset p) {
    _current
      ..clear()
      ..add(p);
    _markAt(p);
    setState(() {});
    _checkDone();
  }

  void _onMove(Offset p) {
    if (_current.isNotEmpty) {
      final last = _current.last;
      if ((p - last).distance < 3) return; // downsample
    }
    _current.add(p);
    _markAt(p);
    setState(() {});
    _checkDone();
  }

  void _onEnd() {
    if (_current.isNotEmpty) {
      _strokes.add(List.of(_current));
      _current.clear();
      setState(() {});
    }
  }

  void _markAt(Offset p) {
    final r = _imageRect;
    if (r == null || r.isEmpty) return;
    if (!r.inflate(_brushRadius(r)).contains(p)) return;

    final cellW = r.width / _gridCols;
    final cellH = r.height / _gridRows;
    final radius = _brushRadius(r);
    final radCellX = (radius / cellW).ceil();
    final radCellY = (radius / cellH).ceil();
    final cx = ((p.dx - r.left) / cellW).floor();
    final cy = ((p.dy - r.top) / cellH).floor();

    final r2 = radius * radius;
    for (var dy = -radCellY; dy <= radCellY; dy++) {
      for (var dx = -radCellX; dx <= radCellX; dx++) {
        final x = cx + dx;
        final y = cy + dy;
        if (x < 0 || x >= _gridCols || y < 0 || y >= _gridRows) continue;
        final nx = dx * cellW;
        final ny = dy * cellH;
        if (nx * nx + ny * ny <= r2) {
          _revealedCells.add(y * _gridCols + x);
        }
      }
    }
  }

  void _checkDone() {
    if (_done) return;
    final ratio = _revealedCells.length / (_gridCols * _gridRows);
    if (ratio < _completionRatio) return;

    _done = true;
    final card = _card;
    final isEn = ref.read(languageProvider) == 'en';
    HapticFeedback.mediumImpact();
    _revealCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
    _incrementCompletedCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showConfetti();
      if (card != null) {
        // EN packs have no recorded audio → force en-US TTS so the word
        // is spoken in English, not read with a Ukrainian voice.
        AudioService.instance.playWordOnly(
          isEn ? null : card.audioKey,
          card.sound,
          locale: isEn ? 'en-US' : 'uk-UA',
        );
      }
      AnalyticsService.instance.logGameComplete('coloring', 1);
    });
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_isGated()) {
      // Free quota exhausted — prompt paywall instead of loading another drawing.
      runPaywallFlow(context, ref);
      setState(() => _paywallGated = true);
      return;
    }
    setState(() {
      _strokes.clear();
      _current.clear();
      _revealedCells.clear();
      _done = false;
      _image = null;
    });
    _revealCtrl.value = 1.0;
    _pickCardAndLoad();
  }

  // ─────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final card = _card;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s('Розмальовки водою', 'Water coloring')),
      ),
      body: _paywallGated
          ? _PaywallGate(onUnlock: () => runPaywallFlow(context, ref))
          : card == null
          ? Center(
              child: Text(
                s('Відкрий хоча б один пак з картками',
                    'Open at least one pack with images first'),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      s('Проведи пальцем по картинці — проявляться кольори',
                          'Drag your finger — colors appear'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (ctx, box) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: card.colorAccent
                                      .withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedBuilder(
                                animation: _revealCtrl,
                                builder: (_, __) => _ColoringCanvas(
                                  image: _image,
                                  strokes: _strokes,
                                  current: _current,
                                  overlayOpacity: _revealCtrl.value,
                                  onRectChanged: (r) => _imageRect = r,
                                  onStart: _onStart,
                                  onMove: _onMove,
                                  onEnd: _onEnd,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (w, a) => SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.4), end: Offset.zero)
                          .animate(a),
                      child: FadeTransition(opacity: a, child: w),
                    ),
                    child: _done
                        ? _DoneBar(
                            key: ValueKey(card.id),
                            word: card.sound,
                            accent: card.colorAccent,
                            onNext: _next,
                            label: s('Наступна', 'Next'),
                          )
                        : const SizedBox(
                            key: ValueKey('empty'), height: 76),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
//  Canvas widget (painter + gestures)
// ─────────────────────────────────────────────

class _ColoringCanvas extends StatelessWidget {
  final ui.Image? image;
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final double overlayOpacity;
  final ValueChanged<Rect> onRectChanged;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;

  const _ColoringCanvas({
    required this.image,
    required this.strokes,
    required this.current,
    required this.overlayOpacity,
    required this.onRectChanged,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (ctx, box) {
        final rect = _fitContained(
          Offset.zero & Size(box.maxWidth, box.maxHeight),
          Size(image!.width.toDouble(), image!.height.toDouble()),
        );
        // Defer notifying parent until after layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onRectChanged(rect);
        });
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => onStart(d.localPosition),
          onPanUpdate: (d) => onMove(d.localPosition),
          onPanEnd: (_) => onEnd(),
          onPanCancel: onEnd,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ColoringPainter(
              image: image!,
              fittedRect: rect,
              strokes: strokes,
              current: current,
              overlayOpacity: overlayOpacity,
              brushRadius:
                  (math.min(rect.width, rect.height) * 0.085).clamp(24.0, 56.0),
            ),
          ),
        );
      },
    );
  }
}

Rect _fitContained(Rect dst, Size src) {
  if (src.width <= 0 || src.height <= 0) return dst;
  final srcAspect = src.width / src.height;
  final dstAspect = dst.width / dst.height;
  if (srcAspect > dstAspect) {
    final h = dst.width / srcAspect;
    return Rect.fromLTWH(
        dst.left, dst.top + (dst.height - h) / 2, dst.width, h);
  } else {
    final w = dst.height * srcAspect;
    return Rect.fromLTWH(
        dst.left + (dst.width - w) / 2, dst.top, w, dst.height);
  }
}

class _ColoringPainter extends CustomPainter {
  final ui.Image image;
  final Rect fittedRect;
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final double overlayOpacity;
  final double brushRadius;

  _ColoringPainter({
    required this.image,
    required this.fittedRect,
    required this.strokes,
    required this.current,
    required this.overlayOpacity,
    required this.brushRadius,
  });

  // Desaturate + lift toward white so "unrevealed" looks like faded paper.
  static const ColorFilter _desatFilter = ColorFilter.matrix([
    0.45, 0.45, 0.45, 0, 120,
    0.45, 0.45, 0.45, 0, 120,
    0.45, 0.45, 0.45, 0, 120,
    0,    0,    0,    1, 0,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    // Layer 1: full-color image (what gets revealed).
    final basePaint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(image, srcRect, fittedRect, basePaint);

    // Layer 2: faded overlay, with strokes cutting holes via BlendMode.dstOut.
    // The saveLayer paint's alpha fades the WHOLE overlay at completion so
    // the remaining contour bits melt away without the child hunting pixels.
    if (overlayOpacity <= 0.001) return;
    final layerPaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, overlayOpacity);
    canvas.saveLayer(fittedRect, layerPaint);
    final desatPaint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = _desatFilter;
    canvas.drawImageRect(image, srcRect, fittedRect, desatPaint);

    final erase = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = brushRadius * 2;
    final dot = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, erase, dot);
    }
    _drawStroke(canvas, current, erase, dot);

    canvas.restore();
  }

  void _drawStroke(
      Canvas canvas, List<Offset> stroke, Paint line, Paint dot) {
    if (stroke.isEmpty) return;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, brushRadius, dot);
      return;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, line);
    // Cap the endpoints with full circles so a single-point stroke reveals
    // cleanly and rounded caps don't clip on the first/last segment.
    canvas.drawCircle(stroke.first, brushRadius, dot);
    canvas.drawCircle(stroke.last, brushRadius, dot);
  }

  @override
  bool shouldRepaint(_ColoringPainter old) =>
      old.image != image ||
      old.fittedRect != fittedRect ||
      old.strokes.length != strokes.length ||
      old.current.length != current.length ||
      old.overlayOpacity != overlayOpacity;
}

// ─────────────────────────────────────────────
//  Done bar (word + next)
// ─────────────────────────────────────────────

class _DoneBar extends StatelessWidget {
  final String word;
  final Color accent;
  final VoidCallback onNext;
  final String label;

  const _DoneBar({
    super.key,
    required this.word,
    required this.accent,
    required this.onNext,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaywallGate extends ConsumerWidget {
  final VoidCallback onUnlock;
  const _PaywallGate({required this.onUnlock});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎨', style: TextStyle(fontSize: 96)),
            const SizedBox(height: 16),
            Text(
              s('Ще 20+ малюнків чекають!', '20+ more drawings waiting!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              s(
                  'Розблокуй усі картинки одразу — і фарбуй щодня.',
                  'Unlock all pictures — and color every day.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: kAccent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onUnlock,
                icon: const Text('💎', style: TextStyle(fontSize: 18)),
                label: Text(s('Розблокувати', 'Unlock')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

