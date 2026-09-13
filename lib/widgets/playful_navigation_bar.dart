import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'kid_tap.dart';

/// A compact toy shelf: stable hit targets, with motion inside each button.
class PlayfulNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isEn;

  const PlayfulNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final labels = isEn
        ? ['Cards', 'Games', 'Coloring']
        : ['Картки', 'Ігри', 'Малюємо'];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14625478),
            blurRadius: 22,
            offset: Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.white, width: 2)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 3;
                  double labelHeight = 0;
                  for (final label in labels) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: label,
                        style: DefaultTextStyle.of(
                          context,
                        ).style.merge(_labelStyle),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(maxWidth: math.max(1, width - 16));
                    labelHeight = math.max(labelHeight, painter.height);
                    painter.dispose();
                  }
                  return Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _TabButton(
                            key: ValueKey('main-tab-$i'),
                            index: i,
                            label: labels[i],
                            selected: selectedIndex == i,
                            height: math.max(76, 56 + labelHeight),
                            onTap: () => onSelected(i),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Tile-title face at shelf size; the family and weight come from DT.
final _labelStyle = DT.tileTitle.copyWith(fontSize: 13, height: 1.15);
const _accents = [Color(0xFF7960D8), Color(0xFFE68A3D), Color(0xFF319F92)];
const _tints = [Color(0xFFF0E9FF), Color(0xFFFFEEDB), Color(0xFFE2F4EC)];
const _inks = [Color(0xFF594391), Color(0xFF91501F), Color(0xFF24695E)];
const _icons = [AppIcon.navCards, AppIcon.navGames, AppIcon.navColoring];

class _TabButton extends StatelessWidget {
  final int index;
  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;
  const _TabButton({
    super.key,
    required this.index,
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = Duration(
      milliseconds: reduceMotionOf(context) ? 0 : 220,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected ? _tints[index] : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _accents[index].withValues(alpha: .19),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ]
              : [],
        ),
        // No Material ripple in the kid zone: the press is the same squeeze
        // and pop as every other child target.
        child: KidTap(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSlide(
                  offset: selected ? const Offset(0, -.035) : Offset.zero,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: selected ? 1.06 : .94,
                    duration: duration,
                    // The shelf keeps its 48×38 slot; the shared 48-space
                    // art (whose live zone is rows 5…43) overflows it by
                    // 5 dp top and bottom into the button's own padding.
                    child: SizedBox(
                      width: 48,
                      height: 38,
                      child: OverflowBox(
                        minHeight: 48,
                        maxHeight: 48,
                        child: AppIconView(_icons[index], size: 48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _labelStyle.copyWith(
                    color: selected ? _inks[index] : const Color(0xFF665E70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
