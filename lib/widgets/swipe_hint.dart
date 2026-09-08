import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Swipe hint — a solid pill in the pack colour with animated chevrons and
/// a hand icon. Shows only once ever, then never again.
///
/// The pill used to be frosted white (α 0.12) over a white card and was
/// invisible on screenshots — the one "swipe" cue of the first session lost
/// (design audit 2026-09-08, #21). [accent] is the pack colour so the pill
/// reads on any card while still belonging to the screen.
class SwipeHint extends StatefulWidget {
  /// Pill background; callers pass `pack.color`.
  final Color accent;

  const SwipeHint({super.key, required this.accent});

  @override
  State<SwipeHint> createState() => SwipeHintState();
}

class SwipeHintState extends State<SwipeHint>
    with TickerProviderStateMixin {
  static const _shownKey = 'swipe_hint_shown';

  late final AnimationController _entryCtrl;
  late final AnimationController _loopCtrl;
  late final AnimationController _dismissCtrl;

  bool _visible = false;
  bool _dismissed = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkIfShouldShow();
  }

  Future<void> _checkIfShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;
    if (!mounted) return;

    await prefs.setBool(_shownKey, true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initialized = true;
    setState(() => _visible = true);
    _entryCtrl.forward();
    _loopCtrl.repeat();
  }

  void dismiss() {
    if (_dismissed || !_visible) return;
    _dismissed = true;
    _dismissCtrl.forward().then((_) {
      _loopCtrl.stop();
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    if (_initialized) {
      _entryCtrl.dispose();
      _loopCtrl.dispose();
      _dismissCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_entryCtrl, _dismissCtrl, _loopCtrl]),
          builder: (context, _) => _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final entryValue = Curves.easeOutBack.transform(_entryCtrl.value);
    final dismissValue = Curves.easeIn.transform(_dismissCtrl.value);

    final opacity = entryValue * (1.0 - dismissValue);
    final scale = 0.8 + 0.2 * entryValue;

    if (opacity <= 0) return const SizedBox.shrink();

    final t = _loopCtrl.value;

    // Hand: pause → slide left → pause → reset
    final handProgress = _handCurve(t);
    final handX = 24.0 - 48.0 * handProgress;
    final handOpacity = _fadeEnvelope(t, fadeIn: 0.05, holdEnd: 0.65, fadeOut: 0.80);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              // Near-opaque pack colour: the BackdropFilter blur it replaced
              // cost a saveLayer per frame and still read as white-on-white.
              color: widget.accent.withValues(alpha: 0.9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hand icon that slides left
                Transform.translate(
                  offset: Offset(handX, 0),
                  child: Opacity(
                    opacity: handOpacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationZ(-0.15),
                      child: const Icon(
                        Icons.back_hand_rounded,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Three chevrons with staggered animation
                ..._buildChevrons(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChevrons(double t) {
    return List.generate(3, (i) {
      final delay = i * 0.15;
      final ct = ((t - delay) % 1.0).clamp(0.0, 1.0);
      final chevronOpacity = _chevronFade(ct);
      final slideX = _chevronSlide(ct);

      return Transform.translate(
        offset: Offset(slideX, 0),
        child: Opacity(
          opacity: chevronOpacity,
          child: const Icon(
            Icons.chevron_left_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      );
    });
  }

  // Hand: pause at right, slide left, pause at left
  double _handCurve(double t) {
    if (t < 0.12) return 0.0;
    if (t > 0.62) return 1.0;
    return Curves.easeInOutCubic.transform((t - 0.12) / 0.5);
  }

  // Generic fade envelope
  double _fadeEnvelope(double t, {
    required double fadeIn,
    required double holdEnd,
    required double fadeOut,
  }) {
    if (t < fadeIn) return t / fadeIn;
    if (t < holdEnd) return 1.0;
    if (t < fadeOut) return 1.0 - (t - holdEnd) / (fadeOut - holdEnd);
    return 0.0;
  }

  // Chevron: fade in → hold → fade out
  double _chevronFade(double t) {
    if (t < 0.08) return t / 0.08;
    if (t < 0.45) return 1.0;
    if (t < 0.65) return 1.0 - (t - 0.45) / 0.2;
    return 0.0;
  }

  // Chevron slides slightly left
  double _chevronSlide(double t) {
    if (t < 0.08) return 6.0 * (1.0 - t / 0.08);
    if (t < 0.45) return 0.0;
    return -5.0 * ((t - 0.45) / 0.2).clamp(0.0, 1.0);
  }
}
