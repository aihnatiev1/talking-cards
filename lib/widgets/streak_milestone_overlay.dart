import 'package:flutter/material.dart';

import '../providers/streak_provider.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import 'bloom_mascot.dart';

/// Full-screen celebration shown the first time a user crosses a streak
/// milestone (3 / 7 / 14 / 30 days). Duolingo-style "you reached it!" pattern,
/// adapted for parent-first reading + kid-first visual.
///
/// Show via [showStreakMilestone] from a stateful widget. The function tags
/// the milestone as celebrated automatically when the user taps "Continue".
Future<void> showStreakMilestone(
  BuildContext context, {
  required Milestone milestone,
  required String childName,
  required bool isEn,
  required VoidCallback onCelebrated,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _MilestoneDialog(
      milestone: milestone,
      childName: childName,
      isEn: isEn,
    ),
  );
  onCelebrated();
}

class _MilestoneDialog extends StatefulWidget {
  final Milestone milestone;
  final String childName;
  final bool isEn;

  const _MilestoneDialog({
    required this.milestone,
    required this.childName,
    required this.isEn,
  });

  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _flame;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _entry, curve: Curves.elasticOut);
    _entry.forward();

    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entry.dispose();
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.isEn;
    final m = widget.milestone;
    final daysLabel = s
        ? (m.days == 1 ? 'day' : 'days')
        : _ukDaysWord(m.days);
    final title = s
        ? '${m.days}-day streak!'
        : 'Серія ${m.days} $daysLabel!';
    final subtitle = widget.childName.isNotEmpty
        ? (s
            ? 'Awesome job, ${widget.childName}!'
            : 'Молодець, ${widget.childName}!')
        : (s ? 'Awesome job!' : 'Молодець!');

    return Center(
      child: ScaleTransition(
        scale: _scale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: DT.shadowLift(kStreakOrange),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing flame badge.
                AnimatedBuilder(
                  animation: _flame,
                  builder: (_, __) {
                    final t = Curves.easeInOut.transform(_flame.value);
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFE082),
                            kStreakOrange.withValues(alpha: 0.85),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kStreakOrange
                                .withValues(alpha: 0.45 + 0.25 * t),
                            blurRadius: 20 + 10 * t,
                            spreadRadius: 2 + 2 * t,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: 1.0 + 0.08 * t,
                          child: const Text(
                            '🔥',
                            style: TextStyle(fontSize: 64),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsiveFont(context, 22),
                    fontWeight: FontWeight.w900,
                    color: kStreakOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsiveFont(context, 16),
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 14),
                // Reward badge + Bloom waving — emotional anchor.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(m.bonusEmoji,
                        style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 12),
                    const BloomMascot(
                      size: 64,
                      emotion: BloomEmotion.waving,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kStreakOrange,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      s ? 'Keep going!' : 'Так тримати!',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 16),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ukDaysWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
      return 'дні';
    }
    return 'днів';
  }
}

/// Tiny re-export so callers can use confetti without importing the mixin
/// separately when they want the milestone overlay's visual chrome.
typedef MilestoneConfettiHost = ConfettiOverlayMixin;
