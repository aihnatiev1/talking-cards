import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/app_icons.dart';
import 'package:talking_cards/utils/design_tokens.dart';
import 'package:talking_cards/widgets/app_icon_painters.dart';

import '../helpers/motion.dart';

/// The whole icon language on one sheet (F5, ux-gap-audit §5.1).
///
/// Every [AppIcon] at 48 dp in two rows of context: on the warm page
/// (plain) and on a saturated tile (`sticker: true`, white paper edge).
/// Underneath, the sound-pack letter stickers. A stroke that thickens, a
/// highlight band that moves, a palette drift — all show up here as one
/// PNG diff rather than across twenty screens.
void main() {
  useTestMotion();

  group('AppIcon sheet', () {
    testWidgets('every icon at 48 dp, plain and sticker', (tester) async {
      await pumpGolden(
        tester,
        const _IconSheet(),
        size: const Size(390, 1120),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/app_icons.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}

class _IconSheet extends StatelessWidget {
  const _IconSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.sp12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AppIcon @48, plain', style: DT.caption),
          const SizedBox(height: DT.sp4),
          Wrap(
            spacing: DT.sp8,
            runSpacing: DT.sp8,
            children: [
              for (final icon in AppIcon.values)
                AppIconView(icon, key: ValueKey('plain-${icon.name}'), size: 48),
            ],
          ),
          const SizedBox(height: DT.sp12),
          const Text('sticker: true on a tile', style: DT.caption),
          const SizedBox(height: DT.sp4),
          Container(
            padding: const EdgeInsets.all(DT.sp8),
            decoration: BoxDecoration(
              color: DT.sky,
              borderRadius: BorderRadius.circular(DT.rMd),
            ),
            child: Wrap(
              spacing: DT.sp8,
              runSpacing: DT.sp8,
              children: [
                for (final icon in AppIcon.values)
                  AppIconView(
                    icon,
                    key: ValueKey('sticker-${icon.name}'),
                    size: 48,
                    sticker: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: DT.sp12),
          const Text('LetterStickerIcon', style: DT.caption),
          const SizedBox(height: DT.sp4),
          const Wrap(
            spacing: DT.sp8,
            children: [
              LetterStickerIcon(letter: 'Р', color: DT.coral, size: 56),
              LetterStickerIcon(letter: 'Л', color: DT.violet, size: 56),
              LetterStickerIcon(letter: 'Ш', color: DT.sky, size: 56),
              LetterStickerIcon(letter: 'SH', color: DT.pink, size: 56),
              LetterStickerIcon(letter: 'TH', color: DT.mint, size: 56),
            ],
          ),
          const SizedBox(height: DT.sp12),
          const Text('sound on/off in white @28, check @14', style: DT.caption),
          const SizedBox(height: DT.sp4),
          const Row(
            children: [
              _Disc(
                color: DT.teal,
                child: AppIconView(AppIcon.sound, size: 28, color: Colors.white),
              ),
              SizedBox(width: DT.sp8),
              _Disc(
                color: DT.soundRed,
                child: AppIconView(AppIcon.soundOff, size: 28, color: Colors.white),
              ),
              SizedBox(width: DT.sp8),
              _Disc(
                color: DT.success,
                size: 24,
                child: AppIconView(AppIcon.check, size: 14, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;
  const _Disc({required this.color, required this.child, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}
