import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'kid_tap.dart';

/// Picture first, readable label second. Large text widens the choices and
/// allows horizontal scrolling instead of silently shrinking the font.
class ActivityCategories extends StatelessWidget {
  const ActivityCategories({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  static const labelStyle = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static Size _labelSize(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.merge(labelStyle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  static double heightFor(BuildContext context, List<String> labels) =>
      72 +
      labels.fold<double>(
        0,
        (height, label) => math.max(height, _labelSize(context, label).height),
      );

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: heightFor(context, labels),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final widest = labels.fold<double>(
            0,
            (w, label) => math.max(w, _labelSize(context, label).width),
          );
          final width = math.max(
            widest + 24,
            (bounds.maxWidth - 32 - (labels.length - 1) * 8) / labels.length,
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  SizedBox(
                    width: width,
                    child: Semantics(
                      button: true,
                      selected: selected == labels[i],
                      child: KidTap(
                        onTap: () => onSelected(labels[i]),
                        child: AnimatedContainer(
                          key: ValueKey('activity-category-${labels[i]}'),
                          duration: MotionPolicy.of(
                            context,
                          ).dur(DT.motion.selectionChange),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected == labels[i]
                                ? (dark
                                      ? Colors.white.withValues(alpha: .14)
                                      : DT.brand.withValues(alpha: .10))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              width: 2,
                              color: selected == labels[i]
                                  ? (dark
                                        ? Colors.white70
                                        : DT.brand.withValues(alpha: .35))
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIconView(_icon(labels[i]), size: 28),
                              const SizedBox(height: 8),
                              Text(
                                labels[i],
                                maxLines: 1,
                                style: labelStyle.copyWith(
                                  color: dark
                                      ? Colors.white
                                      : selected == labels[i]
                                      ? DT.brandInk
                                      : DT.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  AppIcon _icon(String label) => switch (label) {
    'Мовлення' || 'Speaking' => AppIcon.catSpeech,
    'Звуки' || 'Sounds' => AppIcon.catSounds,
    _ => AppIcon.catWorld,
  };
}
