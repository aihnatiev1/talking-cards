import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bloom_reactions_provider.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import 'bloom_mascot.dart';
import 'card_image.dart';
import 'confetti_burst.dart';
import 'kid_screen.dart';
import 'kid_tap.dart';

/// Which win this is (motion audit 2026-09-13 §4).
///
/// * [round] — T1, end of a game round: Bloom, one confetti burst, cheer.
/// * [pack] — T4, a pack played through: cover, Bloom, confetti rain, cheer.
/// * [milestone] — T3, a streak milestone: parent-facing, bell, no confetti.
///
/// T0 (micro success) stays local to the game tile via
/// `FeedbackService.event(correct)`; T2 (daily reveal) keeps
/// `CardRevealScreen` for now.
enum CelebrationTier { round, pack, milestone }

/// The one way to celebrate. Pushes a [Celebration] over the current screen
/// via [KidRoutes.overlay] and completes when it is popped.
///
/// Buttons pop the overlay themselves (once — a second finger on another
/// pill is ignored) and *then* call their callback, so a caller's `onDone`
/// finds the navigator already back on its own screen. [onShare] is the
/// exception: a share sheet opens on top and the celebration stays.
///
/// Tapping the barrier never dismisses; the system back does, and then no
/// callback runs — same as the dialogs this replaces.
Future<void> celebrate(
  BuildContext context, {
  required CelebrationTier tier,
  required bool isEn,
  String? title,
  String? subtitle,
  String childName = '',
  Color? accent,
  String? packTitle,
  String? packIcon,
  String? packCover,
  String? badge,
  VoidCallback? onAgain,
  VoidCallback? onShare,
  VoidCallback? onDone,
}) {
  return showKidOverlay<void>(
    context,
    Celebration(
      tier: tier,
      isEn: isEn,
      title: title,
      subtitle: subtitle,
      childName: childName,
      accent: accent,
      packTitle: packTitle,
      packIcon: packIcon,
      packCover: packCover,
      badge: badge,
      onAgain: onAgain,
      onShare: onShare,
      onDone: onDone,
    ),
  );
}

/// The celebration card. Usually reached through [celebrate]; built
/// directly only by tests and goldens.
///
/// One master [AnimationController] of [DTMotion.celebrationTotal] drives
/// every beat through named [Interval]s (see [_Beats]) — there is no
/// `Future.delayed` in the choreography. The barrier fade (0 → [DT.barrier]
/// over [DTMotion.overlayEnter]) belongs to the route that pushes this.
///
/// Full motion:
///  * 0 — card scale .85→1 + fade ([DTMotion.enter], `emphasized`);
///    sound + haptic via [FeedbackService] (`roundDone` / `packDone` /
///    `milestone`; the praise in those rows follows at [DTMotion.slow]);
///  * 0 — confetti: burst of 24 ([round]) or rain of 32 ([pack]); none for
///    [milestone];
///  * [DTMotion.celebrationCue] — Bloom M hops ([DTMotion.celebrationBounce])
///    in `cheer` and stays in it; `wave` when Home / Done is tapped;
///  * [DTMotion.celebrationCoverIn] — pack cover scale .8→1 ([pack]);
///  * [DTMotion.celebrate] (600 ms) — pills become tappable; opacity .6→1.
///
/// Reduced motion: the controller runs only to the 600 ms gate, the card
/// fades in over [DTMotion.reducedFade], no confetti, no hops; the sound
/// and the gate stay — the gate is not motion, it is protection from the
/// finger that is still on the glass.
class Celebration extends StatefulWidget {
  final CelebrationTier tier;
  final bool isEn;
  final String? title;
  final String? subtitle;
  final String childName;
  final Color? accent;
  final String? packTitle;
  final String? packIcon;
  final String? packCover;

  /// Milestone reward emoji shown beside Bloom.
  final String? badge;
  final VoidCallback? onAgain;
  final VoidCallback? onShare;
  final VoidCallback? onDone;

  const Celebration({
    super.key,
    required this.tier,
    required this.isEn,
    this.title,
    this.subtitle,
    this.childName = '',
    this.accent,
    this.packTitle,
    this.packIcon,
    this.packCover,
    this.badge,
    this.onAgain,
    this.onShare,
    this.onDone,
  });

  static const int burstPieces = 24;
  static const int rainPieces = 32;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: DT.motion.celebrationTotal,
  );
  late _Beats _beats;
  // Built once from the master; see [_Beats] for the timeline.
  late final Animation<double> _cardFade;
  late final Animation<double> _cardScale;
  late final Animation<double> _confettiAnim;
  late final Animation<double> _mascotAnim;
  late final Animation<double> _coverAnim;
  late final Animation<double> _flameAnim;
  late final Animation<double> _buttonsAnim;
  bool _started = false;
  bool _reduce = false;

  /// Set by the first pill that fires; the overlay pops exactly once.
  bool _closing = false;

  /// "Back to home" was tapped: Bloom waves goodbye while the overlay
  /// fades (bloom_character.md §3.2).
  bool _leaving = false;

  FeedbackEvent get _event => switch (widget.tier) {
    CelebrationTier.round => FeedbackEvent.roundDone,
    CelebrationTier.pack => FeedbackEvent.packDone,
    CelebrationTier.milestone => FeedbackEvent.milestone,
  };

  Color get _accent =>
      widget.accent ??
      switch (widget.tier) {
        CelebrationTier.round => DT.brand,
        CelebrationTier.pack => DT.brand,
        CelebrationTier.milestone => DT.streakOrange,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = MotionPolicy.of(context).reduce;
    // Under reduced motion the clock only has to reach the button gate.
    if (_reduce) _master.duration = DT.motion.celebrate;
    _beats = _Beats(
      total: _master.duration ?? DT.motion.celebrationTotal,
      reduce: _reduce,
    );
    _cardFade = _beats.cardFade(_master);
    _cardScale = _beats.cardScale(_master);
    _confettiAnim = _beats.confetti(
      _master,
      widget.tier == CelebrationTier.pack
          ? DT.motion.confettiRain
          : DT.motion.confettiBurst,
    );
    _mascotAnim = _beats.mascot(_master);
    _coverAnim = _beats.cover(_master);
    _flameAnim = _beats.flame(_master);
    _buttonsAnim = _beats.buttons(_master);
    // Sound never waits for the animation.
    FeedbackService.instance.event(_event, isEn: widget.isEn);
    _master.forward();
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  /// Pop the overlay once, then hand control to the caller.
  void _close(VoidCallback? action) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
    action?.call();
  }

  /// Home / Done: the goodbye wave and `bloom_bye`, then [_close]. The
  /// overlay may be pushed outside the app's `ProviderScope` (tests,
  /// marketing shells) — then only the pose changes.
  void _leave(VoidCallback? action) {
    if (_closing) return;
    setState(() => _leaving = true);
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(bloomReactionsProvider.notifier)
          .sessionEnding(withSound: true);
    } on StateError {
      // No scope: a frozen Bloom still waves.
    }
    _close(action);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn);
    final accent = _accent;
    final confetti = _confetti();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (confetti != null) Positioned.fill(child: confetti),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: DT.sp16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: ScaleTransition(
                      scale: _cardScale,
                      child: _Card(
                        accent: accent,
                        hero: _hero(),
                        title: _title(s),
                        subtitle: _subtitle(s),
                        buttons: _buttons(s, accent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _confetti() {
    if (_reduce) return null;
    return switch (widget.tier) {
      CelebrationTier.round => ConfettiBurst(
        mode: ConfettiMode.burst,
        count: Celebration.burstPieces,
        progress: _confettiAnim,
      ),
      CelebrationTier.pack => ConfettiBurst(
        mode: ConfettiMode.rain,
        count: Celebration.rainPieces,
        progress: _confettiAnim,
      ),
      CelebrationTier.milestone => null,
    };
  }

  Widget _hero() {
    final bounce = _mascotAnim;
    // Bloom M leads the pack and round celebrations in `cheer`; the streak
    // milestone is a parent-facing tier and keeps him small. A frozen
    // state: the overlay is the one Bloom on screen, the host's fades.
    final emotion = _leaving ? BloomEmotion.wave : BloomEmotion.cheer;
    final bloom = _Hopping(
      progress: bounce,
      hops: widget.tier == CelebrationTier.milestone ? 1 : 2,
      child: BloomMascot(
        size: widget.tier == CelebrationTier.milestone
            ? DT.size.mascotSm
            : DT.size.mascotMd,
        state: BloomState.still(
          emotion,
          hops: widget.tier == CelebrationTier.milestone ? 1 : 3,
        ),
        interactive: false,
      ),
    );
    return switch (widget.tier) {
      CelebrationTier.round => bloom,
      CelebrationTier.pack => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bloom,
          const SizedBox(width: DT.sp12),
          ScaleTransition(
            scale: _coverAnim,
            child: SizedBox.square(
              dimension: DT.size.mascotMd,
              child: CardImage(
                name: widget.packCover,
                fallbackEmoji: widget.packIcon ?? '⭐',
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      CelebrationTier.milestone => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FlameBadge(pulse: _flameAnim),
          const SizedBox(height: DT.sp12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.badge != null) ...[
                Text(widget.badge ?? '', style: const TextStyle(fontSize: 36)),
                const SizedBox(width: DT.sp12),
              ],
              bloom,
            ],
          ),
        ],
      ),
    };
  }

  String _title(AppS s) {
    final given = widget.title;
    if (given != null) return given;
    final name = widget.childName.trim();
    return switch (widget.tier) {
      CelebrationTier.round =>
        name.isEmpty
            ? s('Молодець!', 'Great job!')
            : s('Молодець, $name!', 'Great job, $name!'),
      CelebrationTier.pack => s('Молодець!', 'Well done!'),
      CelebrationTier.milestone => s('Так тримати!', 'Keep going!'),
    };
  }

  String? _subtitle(AppS s) {
    final given = widget.subtitle;
    if (given != null) return given;
    final pack = widget.packTitle;
    if (widget.tier == CelebrationTier.pack && pack != null) {
      return s('$pack пройдено!', '$pack complete!');
    }
    return null;
  }

  Widget _buttons(AppS s, Color accent) {
    final pills = switch (widget.tier) {
      CelebrationTier.round => [
        _Pill(
          label: s('Ще раз', 'Play again'),
          accent: accent,
          onTap: () => _close(widget.onAgain),
        ),
        _Pill.outlined(
          label: s('Готово', 'Done'),
          accent: accent,
          onTap: () => _leave(widget.onDone),
        ),
      ],
      CelebrationTier.pack => [
        if (widget.onAgain != null)
          _Pill(
            label: s('Грати знову', 'Play again'),
            accent: accent,
            onTap: () => _close(widget.onAgain),
          ),
        if (widget.onShare != null)
          _Pill(
            label: s('Поділитись', 'Share'),
            accent: DT.teal,
            // Opens a sheet on top; the celebration stays underneath.
            onTap: () => widget.onShare?.call(),
          ),
        _Pill.outlined(
          label: s('На головну', 'Back to home'),
          accent: accent,
          onTap: () => _leave(widget.onDone),
        ),
      ],
      CelebrationTier.milestone => [
        _Pill(
          label: s('Так тримати!', 'Keep going!'),
          accent: accent,
          onTap: () => _close(widget.onDone),
        ),
      ],
    };

    // Gate: nothing is tappable before 600 ms. A toddler's hand is often
    // still on the glass from the last swipe when the card appears.
    return AnimatedBuilder(
      animation: _master,
      builder: (_, child) =>
          IgnorePointer(ignoring: _master.value < _beats.gate, child: child),
      child: FadeTransition(
        opacity: _buttonsAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              if (i > 0) const SizedBox(height: DT.sp8),
              pills[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Named beats of the master controller, as fractions of its total.
///
/// Every number here is a `DT.motion` token divided by the total, so the
/// timeline in docs/motion-audit-2026-09-13.md §4 can be read off the
/// tokens and the widget never spells a millisecond.
class _Beats {
  final Duration total;
  final bool reduce;

  _Beats({required this.total, required this.reduce});

  double _at(Duration d) =>
      (d.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);

  Interval _span(
    Duration start,
    Duration length, {
    Curve curve = Curves.linear,
  }) {
    final a = _at(start);
    final b = max(a, _at(start + length));
    return Interval(a, b, curve: curve);
  }

  /// Fraction at which the pills wake up.
  double get gate => _at(DT.motion.celebrate);

  Animation<double> cardFade(Animation<double> m) => CurvedAnimation(
    parent: m,
    curve: reduce
        ? _span(Duration.zero, DT.motion.reducedFade)
        : _span(Duration.zero, DT.motion.enter),
  );

  Animation<double> cardScale(Animation<double> m) => reduce
      ? const AlwaysStoppedAnimation(1.0)
      : Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(
            parent: m,
            curve: _span(
              Duration.zero,
              DT.motion.enter,
              curve: DT.motion.emphasized,
            ),
          ),
        );

  Animation<double> confetti(Animation<double> m, Duration length) =>
      CurvedAnimation(parent: m, curve: _span(Duration.zero, length));

  /// Bloom's hop(s): 0→1 across the bounce, flat otherwise.
  Animation<double> mascot(Animation<double> m) => reduce
      ? const AlwaysStoppedAnimation(0.0)
      : CurvedAnimation(
          parent: m,
          curve: _span(DT.motion.celebrationCue, DT.motion.celebrationBounce),
        );

  Animation<double> cover(Animation<double> m) => reduce
      ? const AlwaysStoppedAnimation(1.0)
      : Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(
            parent: m,
            curve: _span(
              DT.motion.celebrationCoverIn,
              DT.motion.celebrationCover,
              curve: DT.motion.emphasized,
            ),
          ),
        );

  /// Milestone flame: three soft pulses over the whole run, then warm.
  Animation<double> flame(Animation<double> m) =>
      reduce ? const AlwaysStoppedAnimation(0.0) : m;

  /// Pills: .6 → 1 as the gate opens. Under reduced motion the fade fills
  /// the last [DTMotion.reducedFade] before the gate so it never degenerates
  /// into a zero-length interval.
  Animation<double> buttons(Animation<double> m) {
    final gateAt = DT.motion.celebrate;
    final span = reduce
        ? _span(gateAt - DT.motion.reducedFade, DT.motion.reducedFade)
        : _span(gateAt, DT.motion.base);
    return Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: m, curve: span));
  }
}

/// White card with the tier's accent glow.
class _Card extends StatelessWidget {
  final Color accent;
  final Widget hero;
  final String title;
  final String? subtitle;
  final Widget buttons;

  const _Card({
    required this.accent,
    required this.hero,
    required this.title,
    required this.subtitle,
    required this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DT.sp16),
      padding: const EdgeInsets.all(DT.sp24),
      decoration: BoxDecoration(
        color: DT.surfaceWhite,
        borderRadius: BorderRadius.circular(DT.rXl),
        boxShadow: DT.shadowFloat(accent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          hero,
          const SizedBox(height: DT.sp16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: DT.h1.copyWith(color: accent),
          ),
          if (sub != null) ...[
            const SizedBox(height: DT.sp8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: DT.body.copyWith(fontSize: 16),
            ),
          ],
          const SizedBox(height: DT.sp20),
          buttons,
        ],
      ),
    );
  }
}

/// Lifts [child] in [hops] arcs as [progress] runs 0→1, with a small squash
/// on the way up. Flat at 0 and at 1, so it is safe to leave at rest.
class _Hopping extends StatelessWidget {
  final Animation<double> progress;
  final int hops;
  final Widget child;

  const _Hopping({
    required this.progress,
    required this.hops,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, child) {
        final t = progress.value;
        if (t <= 0 || t >= 1) return child ?? const SizedBox.shrink();
        final arc = sin(pi * hops * t).abs();
        return Transform.translate(
          offset: Offset(0, -14 * arc),
          child: Transform.scale(scale: 1 + 0.08 * arc, child: child),
        );
      },
      child: child,
    );
  }
}

/// Streak flame disc. Three pulses over the master run, then rests warm.
class _FlameBadge extends StatelessWidget {
  final Animation<double> pulse;

  const _FlameBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, child) {
        final t = pulse.value;
        final p = t >= 1 ? 0.0 : sin(pi * 3 * t).abs();
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [DT.sunBurst, DT.streakOrange.withValues(alpha: 0.85)],
            ),
            boxShadow: [
              BoxShadow(
                color: DT.streakOrange.withValues(alpha: 0.45 + 0.25 * p),
                blurRadius: 20 + 10 * p,
                spreadRadius: 2 + 2 * p,
              ),
            ],
          ),
          child: Center(
            child: Transform.scale(scale: 1.0 + 0.08 * p, child: child),
          ),
        );
      },
      child: const Text('🔥', style: TextStyle(fontSize: 64)),
    );
  }
}

/// A big pill a toddler can hit: full width, at least [DTSize.tapMin]
/// tall, no Material ripple — `KidTap` owns the squeeze, haptic and pop.
class _Pill extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool filled;

  const _Pill({required this.label, required this.accent, required this.onTap})
    : filled = true;

  const _Pill.outlined({
    required this.label,
    required this.accent,
    required this.onTap,
  }) : filled = false;

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: double.infinity,
          minHeight: DT.size.tapMin,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: DT.sp20,
          vertical: DT.sp12,
        ),
        decoration: BoxDecoration(
          color: filled ? accent : DT.surfaceWhite,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: filled ? null : Border.all(color: accent, width: 2),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: DT.tileTitle.copyWith(
            fontSize: 20,
            color: filled ? DT.surfaceWhite : accent,
          ),
        ),
      ),
    );
  }
}
