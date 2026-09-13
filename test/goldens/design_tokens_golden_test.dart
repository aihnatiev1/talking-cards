// Golden tests — README
//
// Regenerate every PNG under test/goldens/images/ with
//
//     flutter test --update-goldens test/goldens
//
// and commit the images next to the tests. Review the diff as you would a
// design change: a golden that moved on purpose is fine, one that moved
// because a tile grew a second shadow is the bug this suite exists for.
//
// Determinism: goldens are rendered and compared on macOS only (Xcode Cloud
// CI is macOS too). Skia antialiases text and curved edges differently on
// Linux, so every golden test here carries `skip: !Platform.isMacOS` and
// simply does not run elsewhere rather than fail on sub-pixel noise. Fonts
// come from test/flutter_test_config.dart (Nunito, also standing in for
// Roboto, plus MaterialIcons); motion is frozen per test with
// `useTestMotion()` so nothing is caught mid-animation.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/utils/design_tokens.dart';

import '../helpers/motion.dart';

/// Pins the design-token contract as pixels (architecture audit §2 F7).
///
/// `design_tokens_test.dart` guards *where* colours may be minted; this
/// guards *what they look like* next to each other — a tint that drifts a
/// few hex digits, or a text style that loses its variation axis and
/// renders Nunito at the default weight, shows up here and nowhere else.
void main() {
  useTestMotion();

  const accents = <String, Color>{
    'brand': DT.brand,
    'teal': DT.teal,
    'soundRed': DT.soundRed,
    'streakOrange': DT.streakOrange,
    'coral': DT.coral,
    'sunBurst': DT.sunBurst,
    'mint': DT.mint,
    'sky': DT.sky,
    'violet': DT.violet,
    'peach': DT.peach,
    'pink': DT.pink,
  };

  const tints = <String, Color>{
    'coralTint': DT.coralTint,
    'sunTint': DT.sunTint,
    'mintTint': DT.mintTint,
    'skyTint': DT.skyTint,
    'violetTint': DT.violetTint,
    'peachTint': DT.peachTint,
    'pinkTint': DT.pinkTint,
  };

  const surfaces = <String, Color>{
    'bgWarm': DT.bgWarm,
    'bgCard': DT.bgCard,
    'surfaceWhite': DT.surfaceWhite,
    'bgDark': DT.bgDark,
    'textPrimary': DT.textPrimary,
    'textSecondary': DT.textSecondary,
    'textMuted': DT.textMuted,
  };

  const semantic = <String, Color>{
    'success': DT.success,
    'warning': DT.warning,
    'error': DT.error,
    'barrier': DT.barrier,
    'barrierSheet': DT.barrierSheet,
  };

  const paletteSeeds = <String, Color>{
    'coral': DT.coral,
    'sky': DT.sky,
    'mint': DT.mint,
    'violet': DT.violet,
  };

  group('DT swatch sheet', () {
    testWidgets('accents, tints, surfaces, semantic and PackPalette samples',
        (tester) async {
      await pumpGolden(
        tester,
        const _SwatchSheet(
          accents: accents,
          tints: tints,
          surfaces: surfaces,
          semantic: semantic,
          paletteSeeds: paletteSeeds,
        ),
        size: const Size(390, 900),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/dt_swatches.png'),
      );
    });
  }, skip: !Platform.isMacOS);

  group('DT type sheet', () {
    testWidgets('display / h1 / h2 / tileTitle / body / caption in Ukrainian',
        (tester) async {
      await pumpGolden(
        tester,
        const _TypeSheet(),
        size: const Size(390, 520),
      );
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('images/dt_type.png'),
      );
    });
  }, skip: !Platform.isMacOS);
}

class _SwatchSheet extends StatelessWidget {
  final Map<String, Color> accents;
  final Map<String, Color> tints;
  final Map<String, Color> surfaces;
  final Map<String, Color> semantic;
  final Map<String, Color> paletteSeeds;

  const _SwatchSheet({
    required this.accents,
    required this.tints,
    required this.surfaces,
    required this.semantic,
    required this.paletteSeeds,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.sp16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwatchRow(title: 'accents', colors: accents),
          const SizedBox(height: DT.sp12),
          _SwatchRow(title: 'tints', colors: tints),
          const SizedBox(height: DT.sp12),
          _SwatchRow(title: 'surfaces + text', colors: surfaces),
          const SizedBox(height: DT.sp12),
          _SwatchRow(title: 'semantic', colors: semantic),
          const SizedBox(height: DT.sp16),
          const Text('PackPalette.of(accent)', style: DT.caption),
          const SizedBox(height: DT.sp8),
          for (final entry in paletteSeeds.entries) ...[
            _PaletteSample(name: entry.key, palette: PackPalette.of(entry.value)),
            const SizedBox(height: DT.sp8),
          ],
          const SizedBox(height: DT.sp8),
          const Text('shadows: soft / lift / float', style: DT.caption),
          const SizedBox(height: DT.sp12),
          Row(
            children: [
              _ShadowSample(shadow: DT.shadowSoft(DT.brand)),
              const SizedBox(width: DT.sp24),
              _ShadowSample(shadow: DT.shadowLift(DT.brand)),
              const SizedBox(width: DT.sp24),
              _ShadowSample(shadow: DT.shadowFloat(DT.brand)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final String title;
  final Map<String, Color> colors;
  const _SwatchRow({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DT.caption),
        const SizedBox(height: DT.sp4),
        Wrap(
          spacing: DT.sp8,
          runSpacing: DT.sp8,
          children: [
            for (final entry in colors.entries)
              Column(
                children: [
                  Container(
                    width: 48,
                    height: 36,
                    decoration: BoxDecoration(
                      color: entry.value,
                      borderRadius: BorderRadius.circular(DT.rSm),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 52,
                    child: Text(
                      entry.key,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: DT.caption.copyWith(fontSize: 8),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PaletteSample extends StatelessWidget {
  final String name;
  final PackPalette palette;
  const _PaletteSample({required this.name, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: DT.sp12),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: palette.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DT.sp12),
          Text(
            name,
            style: DT.tileTitle.copyWith(color: palette.onTint),
          ),
        ],
      ),
    );
  }
}

class _ShadowSample extends StatelessWidget {
  final List<BoxShadow> shadow;
  const _ShadowSample({required this.shadow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 48,
      decoration: BoxDecoration(
        color: DT.surfaceWhite,
        borderRadius: BorderRadius.circular(DT.rMd),
        boxShadow: shadow,
      ),
    );
  }
}

class _TypeSheet extends StatelessWidget {
  const _TypeSheet();

  static const sample = 'Картки-розмовлялки';

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DT.sp16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('display 28 / 900', style: DT.caption),
          Text(sample, style: DT.display),
          SizedBox(height: DT.sp16),
          Text('h1 22 / 800', style: DT.caption),
          Text(sample, style: DT.h1),
          SizedBox(height: DT.sp16),
          Text('h2 18 / 800', style: DT.caption),
          Text(sample, style: DT.h2),
          SizedBox(height: DT.sp16),
          Text('tileTitle 17 / 800', style: DT.caption),
          Text(sample, style: DT.tileTitle),
          SizedBox(height: DT.sp16),
          Text('body 14 / 500', style: DT.caption),
          Text(sample, style: DT.body),
          SizedBox(height: DT.sp16),
          Text('caption 12 / 600', style: DT.caption),
          Text(sample, style: DT.caption),
          SizedBox(height: DT.sp16),
          Text('onTint(coral) on coralTint', style: DT.caption),
          _OnTintLine(),
        ],
      ),
    );
  }
}

class _OnTintLine extends StatelessWidget {
  const _OnTintLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DT.sp12,
        vertical: DT.sp8,
      ),
      decoration: BoxDecoration(
        color: DT.coralTint,
        borderRadius: BorderRadius.circular(DT.rSm),
      ),
      child: Text(
        _TypeSheet.sample,
        style: DT.h2.copyWith(color: DT.onTint(DT.coral)),
      ),
    );
  }
}
