import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/bloom_mascot.dart';

import '../helpers/motion.dart';

/// Bloom's nine emotions as pixels (docs/design/bloom_character.md §5.6,
/// architecture audit F7): every pose at S (56, the companion) and M (96,
/// the celebration lead) on the warm page, plus the wand prop and the
/// silhouette. A stroke that thins, an ear that loses its bend, a mouth
/// that lands a pixel off — one PNG diff instead of a hunt across screens.
void main() {
  useTestMotion();

  group('BloomMascot emotion sheet', () {
    testWidgets('nine emotions at S and M, wand, silhouette', (tester) async {
      await pumpGolden(
        tester,
        const _EmotionSheet(),
        size: const Size(390, 780),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/bloom_emotions.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}

class _EmotionSheet extends StatelessWidget {
  const _EmotionSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.sp12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('S 56 — companion', style: DT.caption),
          const SizedBox(height: DT.sp4),
          Wrap(
            spacing: DT.sp4,
            runSpacing: DT.sp4,
            children: [
              for (final e in BloomEmotion.values)
                _Cell(
                  key: ValueKey('s-${e.name}'),
                  label: e.name,
                  size: DT.size.mascotCompanion,
                  child: BloomMascot(
                    size: DT.size.mascotCompanion,
                    state: BloomState.still(e, lookAt: const Alignment(0.7, -0.8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DT.sp12),
          const Text('M 96 — celebration', style: DT.caption),
          const SizedBox(height: DT.sp4),
          Wrap(
            spacing: DT.sp4,
            runSpacing: DT.sp4,
            children: [
              for (final e in BloomEmotion.values)
                _Cell(
                  key: ValueKey('m-${e.name}'),
                  label: e.name,
                  size: DT.size.mascotMd,
                  child: BloomMascot(
                    size: DT.size.mascotMd,
                    state: BloomState.still(e),
                  ),
                ),
              _Cell(
                key: const ValueKey('m-idle-wand'),
                label: 'idle+wand',
                size: DT.size.mascotMd,
                child: BloomMascot(
                  size: DT.size.mascotMd,
                  state: const BloomState.still(
                    BloomEmotion.idle,
                    prop: BloomProp.wand,
                  ),
                ),
              ),
              _Cell(
                key: const ValueKey('m-facing-right'),
                label: 'facing right',
                size: DT.size.mascotMd,
                child: BloomMascot(
                  size: DT.size.mascotMd,
                  facing: BloomFacing.right,
                  state: const BloomState.still(BloomEmotion.idle),
                ),
              ),
              _Cell(
                key: const ValueKey('silhouette'),
                label: 'silhouette',
                size: DT.size.mascotMd,
                child: const CustomPaint(
                  size: Size.square(40),
                  painter: BloomSilhouettePainter(color: DT.brand),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final double size;
  final Widget child;

  const _Cell({
    super.key,
    required this.label,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size < 72 ? 72 : size + DT.sp8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          Text(label, style: DT.caption.copyWith(fontSize: 8)),
        ],
      ),
    );
  }
}
