import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animated swipe hint — a hand icon that slides left across the card,
/// intuitive for children 0-4 who can't read.
/// Shows only once ever, then never again.
class SwipeHint extends StatefulWidget {
  const SwipeHint({super.key});

  @override
  State<SwipeHint> createState() => SwipeHintState();
}

class SwipeHintState extends State<SwipeHint>
    with TickerProviderStateMixin {
  static const _shownKey = 'swipe_hint_shown';

  AnimationController? _slideCtrl;
  Animation<Offset>? _slideAnim;
  Animation<double>? _fadeAnim;
  bool _dismissed = true; // start hidden until we check prefs

  @override
  void initState() {
    super.initState();
    _checkIfShouldShow();
  }

  Future<void> _checkIfShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return; // already shown once
    if (!mounted) return;

    // Mark as shown permanently
    await prefs.setBool(_shownKey, true);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: const Offset(-0.5, 0),
    ).animate(CurvedAnimation(
      parent: _slideCtrl!,
      curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
    ));

    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 15),
    ]).animate(_slideCtrl!);

    setState(() => _dismissed = false);
    _slideCtrl!.repeat();
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _slideCtrl?.stop();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _slideCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _slideAnim == null || _fadeAnim == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SlideTransition(
          position: _slideAnim!,
          child: FadeTransition(
            opacity: _fadeAnim!,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('👆', style: TextStyle(fontSize: 48)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
