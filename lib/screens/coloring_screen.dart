import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/coloring_album_provider.dart';
import '../providers/content_pack_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../services/paywall_flow.dart';
import '../utils/app_icons.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../services/asset_pack_service.dart';
import '../widgets/card_image.dart';
import '../widgets/content_download_view.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

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

  /// Every illustrated word card that is safe to colour: real packs only,
  /// no verse packs, no negative-mood images (design audit 2026-09-08, #25 —
  /// the first picture a child saw could be a crying boy).
  static List<CardModel> coloringPool(Iterable<PackModel> packs) => packs
      .where((p) =>
          !p.id.startsWith('_') && !PackModel.nonWordPackIds.contains(p.id))
      .expand((p) => p.cards)
      .where((c) {
        final image = c.image;
        return image != null &&
            !CardModel.calmingExcludedImages.contains(image) &&
            // A picture still inside the undelivered Play asset pack cannot
            // be coloured — there are no bytes to decode. Unfiltered, it
            // threw out of a fire-and-forget load and left the canvas on
            // its spinner forever. games_tab filters its pool the same way.
            !AssetPackService.instance.needsDownload(image);
      })
      .toList();

  /// Picks the next picture; never the same card twice in a row when the
  /// pool offers a choice. Draws from `pool.length - 1` slots and skips over
  /// [current] so the exclusion is exact rather than a lucky re-roll.
  static CardModel pickNext(
    List<CardModel> pool,
    CardModel? current,
    math.Random rng,
  ) {
    assert(pool.isNotEmpty);
    final currentIndex =
        current == null ? -1 : pool.indexWhere((c) => c.id == current.id);
    if (currentIndex < 0 || pool.length == 1) {
      return pool[rng.nextInt(pool.length)];
    }
    final slot = rng.nextInt(pool.length - 1);
    return pool[slot >= currentIndex ? slot + 1 : slot];
  }

  @override
  ConsumerState<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends ConsumerState<ColoringScreen>
    with ConfettiOverlayMixin, TickerProviderStateMixin {
  static const int _gridCols = 24;
  static const int _gridRows = 24;
  static const double _completionRatio = 0.85;

  static const _completedCountKey = 'coloring_completed_count';
  // 72dp button + the done bar's vertical margins.
  static const double _bottomBarHeight = 96;
  // 3 free drawings before the paywall gate — one felt exhausted too fast
  // for the value this tab demonstrates.
  static const _freeAllowance = 3;

  final math.Random _rng = math.Random();

  CardModel? _card;
  ui.Image? _image;
  int _loadGen = 0;

  final List<List<Offset>> _strokes = [];
  final List<Offset> _current = [];
  final Set<int> _revealedCells = {};

  Rect? _imageRect;
  bool _done = false;

  /// The ghost finger (п. 24) runs once per profile, on the first picture of
  /// the visit, and any real touch ends it early. This flag is the "already
  /// over" half; the "never again" half lives in [coloringAlbumProvider].
  bool _handHintOver = false;

  /// The first pick of this visit may resume the picture the child left
  /// unfinished; every later pick is a new one.
  bool _mayResume = true;
  int _completedCount = 0;
  bool _paywallGated = false;

  /// The colourable pool is empty, or its bytes cannot be read, because the
  /// Play asset pack has not landed. Renders [ContentDownloadView] — the
  /// one screen in the app that explains a download to a parent.
  bool _contentUnavailable = false;

  /// 1.0 = overlay fully visible (not revealed), 0.0 = fully revealed.
  /// Once the child reaches 85%, we animate this to 0 so the remaining
  /// stubborn contour bits melt away on their own.
  late final AnimationController _revealCtrl = AnimationController(
    vsync: this,
    duration: DT.motion.coloringMelt,
    value: 1.0,
  );

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart('coloring');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AudioService.instance.playInstruction(
        'coloring',
        isEn: ref.read(languageProvider) == 'en',
      );
    });
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
  /// The UNLOCK_ALL dart-define (testing builds) bypasses the gate entirely.
  bool _isGated() {
    if (const bool.fromEnvironment('UNLOCK_ALL')) return false;
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
      _contentUnavailable = false;
      _loadFailures = 0;
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

  Future<void> _pickCardAndLoad() async {
    // The album knows which picture was left half-revealed last time; the
    // canvas waits that one read rather than dealing a stranger over it.
    final album = ref.read(coloringAlbumProvider.notifier);
    await album.ready;
    if (!mounted) return;

    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final pool = ColoringScreen.coloringPool(packs);
    if (pool.isEmpty) {
      // Everything colourable is still in the Play pack: say so with the
      // download screen rather than leaving the canvas spinning.
      if (packs.isNotEmpty && !AssetPackService.instance.contentReady) {
        setState(() => _contentUnavailable = true);
      }
      return;
    }
    final chosen = _resume(pool) ?? ColoringScreen.pickNext(pool, _card, _rng);
    _mayResume = false;
    _card = chosen;
    // Remembered before the first stroke: a child who leaves mid-picture
    // comes back to it, which is what makes it *theirs* rather than a
    // stream of pictures the app hands out (п. 24).
    album.setUnfinished(chosen.id);
    _loadImage(chosen);
  }

  /// The unfinished picture from the last visit, if it is still colourable.
  CardModel? _resume(List<CardModel> pool) {
    if (!_mayResume) return null;
    final id = ref.read(coloringAlbumProvider).unfinishedCardId;
    if (id == null) return null;
    for (final card in pool) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// A read can fail even after the pool filter — Play may evict the pack
  /// in between. Bounded so a wholly unreadable pool cannot loop.
  int _loadFailures = 0;
  static const _maxLoadFailures = 3;

  Future<void> _loadImage(CardModel card) async {
    final gen = ++_loadGen;
    // The colouring book is the one place that needs raw bytes — the
    // painter wants a ui.Image — so it consumes CardBytes directly
    // instead of going through CardImage like every other screen.
    final bytes = await AssetPackService.instance.cardBytes(card.image);
    if (!mounted || gen != _loadGen) return;

    switch (bytes) {
      case BytesUnavailable(:final reason):
        // The pool filter should have kept this card out; getting here
        // means Play evicted the pack in between, or the card names an
        // asset this build does not have. Either way it is a value now —
        // it used to be a throw out of a fire-and-forget future, which
        // Crashlytics filed as fatal while the canvas span forever.
        AnalyticsService.instance.logAssetUnavailable(
          'coloring',
          switch (reason) {
            ArtPending() => 'pending',
            ArtMissing(:final reason) => reason,
            ArtReady() => 'unknown',
          },
        );
        _afterFailedLoad();
      case BytesReady(:final data):
        final ui.Image decoded;
        try {
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          decoded = (await codec.getNextFrame()).image;
        } catch (_) {
          // Bytes present but undecodable: a corrupt file rather than a
          // missing one. Same dead end for the child, so same exit.
          if (!mounted || gen != _loadGen) return;
          AnalyticsService.instance
              .logAssetUnavailable('coloring', 'decode_failed');
          _afterFailedLoad();
          return;
        }
        if (!mounted || gen != _loadGen) return;
        _loadFailures = 0;
        setState(() => _image = decoded);
    }
  }

  /// Try another picture, but not forever: a pool that is wholly
  /// unreadable has to end on the download screen, not on a retry loop.
  void _afterFailedLoad() {
    if (++_loadFailures > _maxLoadFailures) {
      setState(() => _contentUnavailable = true);
      return;
    }
    _pickCardAndLoad();
  }

  // ─────────────────────────────────────────────
  //  Gesture / grid tracking
  // ─────────────────────────────────────────────

  double _brushRadius(Rect r) =>
      (math.min(r.width, r.height) * 0.085).clamp(24.0, 56.0);

  void _onStart(Offset p) {
    _endHandHint();
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

  /// The demonstration is over the moment the child's own finger lands —
  /// forgiving input (CLAUDE.md rule 3): the hint never competes for the
  /// stroke that interrupted it.
  void _endHandHint() {
    if (_handHintOver) return;
    setState(() => _handHintOver = true);
    ref.read(coloringAlbumProvider.notifier).markHandHintSeen();
  }

  void _checkDone() {
    if (_done) return;
    final ratio = _revealedCells.length / (_gridCols * _gridRows);
    if (ratio < _completionRatio) return;

    _done = true;
    final card = _card;
    final isEn = ref.read(languageProvider) == 'en';
    FeedbackService.instance.event(FeedbackEvent.correct);
    _revealCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
    _incrementCompletedCount();
    if (card != null) {
      // Into the album — the result of colouring is a collection, not just
      // the picture currently on screen (п. 24).
      ref.read(coloringAlbumProvider.notifier).record(card);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showConfetti();
      if (card != null) {
        // Recorded mp3 only — there is no TTS fallback in this app (see
        // AudioService.playWordOnly). A card with no clip stays silent,
        // which AudioService now reports as asset_unavailable rather than
        // swallowing.
        AudioService.instance.playWordOnly(
          card.audioKey,
          card.sound,
          locale: isEn ? 'en-US' : 'uk-UA',
        );
      }
      AnalyticsService.instance.logGameComplete('coloring', 1);
    });
  }

  /// "New picture": reachable at any time, not only from the done bar, so a
  /// child can leave a picture they dislike (design audit #25). Haptic +
  /// pop SFX because 1–2-year-olds need audio feedback on every action.
  void _next() {
    FeedbackService.instance.event(FeedbackEvent.tap);
    if (_isGated()) {
      // Free quota exhausted — prompt paywall instead of loading another drawing.
      runPaywallFlow(context, ref, source: 'coloring_gate');
      setState(() => _paywallGated = true);
      return;
    }
    setState(() {
      _strokes.clear();
      _current.clear();
      _revealedCells.clear();
      _done = false;
      _image = null;
      _contentUnavailable = false;
      _loadFailures = 0;
      _mayResume = false;
    });
    _revealCtrl.value = 1.0;
    _pickCardAndLoad();
  }

  /// Opens the album: every picture this child has revealed, biggest first
  /// touch target the sheet can give them. Tapping one brings it back to
  /// the canvas.
  void _openAlbum() {
    FeedbackService.instance.event(FeedbackEvent.tap);
    final packs = ref.read(packsProvider).valueOrNull ?? const <PackModel>[];
    final pool = ColoringScreen.coloringPool(packs);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: DT.barrierSheet,
      builder: (_) => _AlbumSheet(
        pool: pool,
        onPick: (card) {
          Navigator.of(context).pop();
          _openFromAlbum(card);
        },
      ),
    );
  }

  void _openFromAlbum(CardModel card) {
    setState(() {
      _strokes.clear();
      _current.clear();
      _revealedCells.clear();
      _done = false;
      _image = null;
      _contentUnavailable = false;
      _loadFailures = 0;
      _mayResume = false;
      _card = card;
    });
    _revealCtrl.value = 1.0;
    ref.read(coloringAlbumProvider.notifier).setUnfinished(card.id);
    _loadImage(card);
  }

  // ─────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final card = _card;
    final album = ref.watch(coloringAlbumProvider);
    final motion = MotionPolicy.of(context);
    // Once per profile, and never over a picture that is already being
    // revealed: a ghost finger draws one line to show what this screen wants
    // (п. 24). Checked against `reduced` rather than `reduce` on purpose —
    // the OS flag means "do not animate a hand at me", while the *test*
    // override only freezes idle loops, and this hint is the thing under
    // test. Under real reduced motion it simply stays unseen and waits.
    final showHand = album.loaded &&
        !album.handHintSeen &&
        !_handHintOver &&
        !_done &&
        motion.mode != MotionMode.reduced &&
        _image != null &&
        _strokes.isEmpty &&
        _current.isEmpty;

    // No text title: the finger on the picture is the whole instruction.
    return KidScreen.game(
      accent: DT.brand,
      background: DT.violetTint,
      body: _paywallGated
          ? _PaywallGate(
              onUnlock: () =>
                  runPaywallFlow(context, ref, source: 'coloring_gate'))
          : _contentUnavailable
          ? ContentDownloadView(
              state: ref.watch(contentPackProvider),
              accent: DT.brand,
              isEn: isEn,
            )
          : card == null
          ? Center(
              child: Text(
                s('Відкрий хоча б один пак з картками',
                    'Open at least one pack with images first'),
              ),
            )
          : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      s('Проведи пальцем по картинці — проявляться кольори',
                          'Drag your finger — the colors appear'),
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
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AnimatedBuilder(
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
                                  if (showHand)
                                    _GhostFinger(
                                      key: const ValueKey('ghost-finger'),
                                      onDone: _endHandHint,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Both states share one height so the canvas (and the
                  // strokes' local coordinates) never resize mid-drawing.
                  SizedBox(
                    height: _bottomBarHeight,
                    child: AnimatedSwitcher(
                      duration: motion.dur(DT.motion.coloringBarSwap),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (w, a) => SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero)
                            .animate(a),
                        child: FadeTransition(opacity: a, child: w),
                      ),
                      child: _done
                          ? _DoneBar(
                              key: ValueKey(card.id),
                              word: card.sound,
                              accent: card.colorAccent,
                              onNext: _next,
                              label: s('Нова картинка', 'New picture'),
                              album: album.entries.length,
                              onAlbum: _openAlbum,
                              albumLabel: s('Мої картинки', 'My pictures'),
                            )
                          : _IdleBar(
                              key: const ValueKey('idle'),
                              onNext: _next,
                              label: s('Нова картинка', 'New picture'),
                              album: album.entries.length,
                              onAlbum: _openAlbum,
                              albumLabel: s('Мої картинки', 'My pictures'),
                            ),
                    ),
                  ),
                ],
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

  // Desaturate to luma and soften darks so the contour reads as a friendly
  // outline rather than harsh ink. Formula per channel:
  // out = 0.3*R + 0.59*G + 0.11*B + 55 (human-eye weights + lift).
  // Pure black lands at ~55 (medium gray contour); pure white near 255.
  static const ColorFilter _desatFilter = ColorFilter.matrix([
    0.30, 0.59, 0.11, 0, 55,
    0.30, 0.59, 0.11, 0, 55,
    0.30, 0.59, 0.11, 0, 55,
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
//  "New picture" button + bottom bars
// ─────────────────────────────────────────────

/// Permanent 72×72dp round "new picture" button (design audit #25). Lives
/// in the same bottom-right spot before and after completion so the child
/// learns a single control; [_DoneBar] reuses it instead of a text button.
class _NewPictureButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _NewPictureButton({required this.onTap, required this.label});

  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: KidTap(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: DT.violet,
            shape: BoxShape.circle,
            boxShadow: DT.shadowSoft(DT.violet),
          ),
          child: const Center(
            child: Icon(
              Icons.shuffle_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar while the child is still revealing: just the new-picture
/// button, right-aligned to match its place in [_DoneBar].
class _IdleBar extends StatelessWidget {
  final VoidCallback onNext;
  final String label;
  final int album;
  final VoidCallback onAlbum;
  final String albumLabel;

  const _IdleBar({
    super.key,
    required this.onNext,
    required this.label,
    required this.album,
    required this.onAlbum,
    required this.albumLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (album > 0)
            _AlbumButton(count: album, onTap: onAlbum, label: albumLabel),
          const Spacer(),
          _NewPictureButton(onTap: onNext, label: label),
        ],
      ),
    );
  }
}

/// The way into the child's own collection (п. 24). Only appears once there
/// is something in it — an empty shelf is not an invitation, and the kid
/// zone gets no control that does nothing.
class _AlbumButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final String label;

  const _AlbumButton({
    required this.count,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: KidTap(
        onTap: onTap,
        child: SizedBox(
          width: _NewPictureButton.size,
          height: _NewPictureButton.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _NewPictureButton.size,
                height: _NewPictureButton.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DT.violet.withValues(alpha: 0.45),
                    width: 2,
                  ),
                  boxShadow: DT.shadowSoft(DT.violet),
                ),
                child: const Center(
                  child: AppIconView(AppIcon.stickerAlbum, size: 38),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DT.sp8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DT.violet,
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
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

/// The album itself: every picture this child has brought to full colour,
/// newest first. Pictures only — the sheet says what it is by being full of
/// the child's own work (rule 4). Tapping one puts it back on the canvas.
class _AlbumSheet extends ConsumerWidget {
  final List<CardModel> pool;
  final ValueChanged<CardModel> onPick;

  const _AlbumSheet({required this.pool, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(coloringAlbumProvider).entries;
    final byImage = {for (final c in pool) c.image: c};

    return Container(
      decoration: const BoxDecoration(
        color: DT.bgWarm,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      padding: const EdgeInsets.fromLTRB(DT.sp16, DT.sp12, DT.sp16, DT.sp24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: DT.textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(DT.rSm),
            ),
          ),
          const SizedBox(height: DT.sp16),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: DT.sp12,
              crossAxisSpacing: DT.sp12,
              children: [
                for (final entry in entries)
                  _AlbumTile(
                    key: ValueKey(entry.image),
                    image: entry.image,
                    card: byImage[entry.image],
                    onTap: onPick,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final String image;

  /// Null when the picture is no longer in the pool (locked again, or the
  /// language switched away from it): it still shows, it just cannot be
  /// reopened — the collection does not lose entries behind the child's back.
  final CardModel? card;
  final ValueChanged<CardModel> onTap;

  const _AlbumTile({
    super.key,
    required this.image,
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        boxShadow: DT.shadowSoft(DT.violet),
      ),
      padding: const EdgeInsets.all(DT.sp8),
      child: CardImage(
        name: image,
        fallbackEmoji: card?.emoji ?? '🖼️',
        padding: EdgeInsets.zero,
      ),
    );
    final target = card;
    if (target == null) return tile;
    return KidTap(onTap: () => onTap(target), child: tile);
  }
}

// ─────────────────────────────────────────────
//  The ghost finger (п. 24)
// ─────────────────────────────────────────────

/// One wordless demonstration on the first visit: a translucent finger
/// draws a line across the picture and a pale trail follows it. It runs
/// once per profile, it is `IgnorePointer` so it can never steal the
/// child's first stroke, and [onDone] fires whether it finished or was
/// interrupted.
class _GhostFinger extends StatefulWidget {
  final VoidCallback onDone;

  const _GhostFinger({super.key, required this.onDone});

  @override
  State<_GhostFinger> createState() => _GhostFingerState();
}

class _GhostFingerState extends State<_GhostFinger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: DT.motion.coloringHandTrace,
  );

  @override
  void initState() {
    super.initState();
    _ctrl
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _GhostFingerPainter(_ctrl.value),
        ),
      ),
    );
  }
}

class _GhostFingerPainter extends CustomPainter {
  _GhostFingerPainter(this.t);

  /// 0 → 1 through one pass.
  final double t;

  /// Fade in, hold, fade out — as fractions of the pass.
  static const _fadeIn = 0.08;
  static const _fadeOut = 0.85;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = t < _fadeIn
        ? t / _fadeIn
        : t > _fadeOut
            ? (1 - t) / (1 - _fadeOut)
            : 1.0;
    if (opacity <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.66)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.28,
        size.width * 0.64,
        size.height * 0.86,
        size.width * 0.84,
        size.height * 0.40,
      );
    final metric = path.computeMetrics().first;
    final travelled = metric.length * t;
    final trail = metric.extractPath(0, travelled);

    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 30
        ..color = Colors.white.withValues(alpha: 0.42 * opacity),
    );

    final tangent = metric.getTangentForOffset(travelled);
    final at = tangent?.position;
    if (at == null) return;

    // The finger: a pad on the line and a tapered tip leaving it — enough
    // to read as a hand without pretending to be an illustration.
    canvas.drawCircle(
      at,
      18,
      Paint()..color = Colors.white.withValues(alpha: 0.85 * opacity),
    );
    canvas.drawCircle(
      at,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = DT.bloomInk.withValues(alpha: 0.30 * opacity),
    );
    final tip = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx + 6, at.dy - 58, 22, 52),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      tip,
      Paint()..color = Colors.white.withValues(alpha: 0.70 * opacity),
    );
    canvas.drawRRect(
      tip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = DT.bloomInk.withValues(alpha: 0.22 * opacity),
    );
  }

  @override
  bool shouldRepaint(_GhostFingerPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
//  Done bar (word + next)
// ─────────────────────────────────────────────

class _DoneBar extends StatelessWidget {
  final String word;
  final Color accent;
  final VoidCallback onNext;
  final String label;
  final int album;
  final VoidCallback onAlbum;
  final String albumLabel;

  const _DoneBar({
    super.key,
    required this.word,
    required this.accent,
    required this.onNext,
    required this.label,
    required this.album,
    required this.onAlbum,
    required this.albumLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: EdgeInsets.fromLTRB(album > 0 ? 8 : 20, 0, 0, 0),
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
          if (album > 0)
            _AlbumButton(count: album, onTap: onAlbum, label: albumLabel)
          else
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
          _NewPictureButton(onTap: onNext, label: label),
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
    // Real coloring pool size (same filter the picker uses), rounded down to
    // hundreds so the claim stays honest as content grows. "20+" undersold
    // a 400+ library by a factor of 20.
    final packs = ref.watch(packsProvider).valueOrNull ?? const <PackModel>[];
    final poolSize = ColoringScreen.coloringPool(packs).length;
    final hundreds = math.max(1, poolSize ~/ 100) * 100;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎨', style: TextStyle(fontSize: 96)),
            const SizedBox(height: 16),
            Text(
              s('Понад $hundreds картинок чекають!',
                  '$hundreds+ pictures waiting!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              // Honest about what this is: colours appear under a finger.
              // No brush, no palette — do not promise free drawing (п. 24).
              s(
                  'Розблокуй усі картинки — проявляй кольори пальчиком щодня.',
                  'Unlock all pictures — reveal the colors with a finger, '
                      'every day.'),
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
                    color: DT.brand.withValues(alpha: 0.35),
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
                  backgroundColor: DT.brand,
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

