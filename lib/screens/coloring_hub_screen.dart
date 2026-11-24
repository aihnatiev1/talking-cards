import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coloring_album_provider.dart';
import '../providers/coloring_sheets_provider.dart';
import '../providers/filled_sheets_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../widgets/entrance_stagger.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import 'coloring_screen.dart';
import 'fill_coloring_screen.dart';
import 'mirror_draw_screen.dart';
import 'my_meadow_screen.dart';
import 'sticker_scene_screen.dart';

/// One way of drawing.
class _DrawMode {
  final String id;
  final String title;
  final String titleEn;
  final String subtitle;
  final String subtitleEn;
  final Color color;
  final Color tint;
  final String art;
  final Widget Function() open;

  const _DrawMode({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.subtitle,
    required this.subtitleEn,
    required this.color,
    required this.tint,
    required this.art,
    required this.open,
  });
}

/// The drawing shelf: the coloring tab is a choice of *kinds* of drawing
/// now, the way the cards tab is a choice of packs.
///
/// It used to open straight onto the water picture, which made that one
/// idea the whole of "Малюємо" and left nowhere to put a second. Each mode
/// is its own tile, and a child picks by the picture on it — the words are
/// for the grown-up.
class ColoringHubScreen extends ConsumerWidget {
  const ColoringHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    // The filling modes only exist if there are line drawings to fill. A
    // tile that opens an empty screen is worse than no tile, and a build
    // whose contours have not landed yet is a real state.
    final hasSheets =
        (ref.watch(coloringSheetsProvider).valueOrNull ?? const []).isNotEmpty;

    // The meadow only exists once something is standing on it. An empty
    // gallery is a promise the app has not kept yet, and a child cannot
    // read the promise.
    final hasFinished =
        ref.watch(filledSheetsProvider).isNotEmpty ||
        ref.watch(coloringAlbumProvider).entries.isNotEmpty;

    final modes = <_DrawMode>[
      _DrawMode(
        id: 'coloring',
        title: 'Чарівна вода',
        titleEn: 'Magic water',
        subtitle: 'Проведи пальцем — з\'являються кольори',
        subtitleEn: 'Drag your finger — the colours appear',
        color: DT.sky,
        tint: DT.skyTint,
        art: 'water',
        open: () => const ColoringScreen(),
      ),
      if (hasSheets)
        _DrawMode(
          id: 'fill_coloring',
          title: 'Розфарбуй',
          titleEn: 'Colour it in',
          subtitle: 'Обери колір і тисни на частинку',
          subtitleEn: 'Pick a colour, tap a part',
          color: DT.coral,
          tint: DT.coralTint,
          art: 'bucket',
          open: () => const FillColoringScreen(),
        ),
      if (hasSheets)
        _DrawMode(
          id: 'fill_coloring_by_ear',
          title: 'Слухай і фарбуй',
          titleEn: 'Listen and colour',
          subtitle: 'Блум називає колір — знайди його',
          subtitleEn: 'Bloom names a colour — find it',
          color: DT.peach,
          tint: DT.peachTint,
          art: 'ear',
          open: () => const FillColoringScreen(byEar: true),
        ),
      _DrawMode(
        id: 'sticker_scene',
        title: 'Наліпки',
        titleEn: 'Stickers',
        subtitle: 'Постав на галявину — і почуй слово',
        subtitleEn: 'Put them on the meadow and hear the word',
        color: DT.mint,
        tint: DT.mintTint,
        art: 'stickers',
        open: () => const StickerSceneScreen(),
      ),
      if (hasFinished)
        _DrawMode(
          id: 'my_meadow',
          title: 'Моя галявина',
          titleEn: 'My meadow',
          subtitle: 'Усе, що ти вже намалював',
          subtitleEn: 'Everything you have finished',
          color: DT.teal,
          tint: DT.mintTint,
          art: 'trophy',
          open: () => const MyMeadowScreen(),
        ),
      _DrawMode(
        id: 'mirror_draw',
        title: 'Дзеркальце',
        titleEn: 'Mirror',
        subtitle: 'Малюй половинку — вийде ціле',
        subtitleEn: 'Draw one half — get the whole',
        color: DT.violet,
        tint: DT.violetTint,
        art: 'butterfly',
        open: () => const MirrorDrawScreen(),
      ),
    ];

    return KidScreen(
      backdrop: 'assets/images/backdrops/studio_sky.webp',
      accent: DT.brand,
      background: DT.violetTint,
      // Pushed over the home screen (shortcut, My world, quest), where
      // nothing else leads out and `_KidRoute` has no iOS swipe-back.
      showLeading: Navigator.canPop(context),
      title: Text(
        s('Малюємо', 'Let\'s draw'),
        style: DT.h2.copyWith(fontSize: 19, color: DT.textPrimary),
      ),
      body: StaggerScope(
        // Centred and capped: on a tablet a top-aligned grid of six tiles
        // left two thirds of the screen empty, which reads as a page that
        // failed to load rather than a shelf.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: LayoutBuilder(
              builder: (context, box) {
                final cols = MediaQuery.sizeOf(context).width < 600 ? 2 : 3;
                const gap = 14.0;
                final w = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
                // A Wrap, centred: five tiles leave the last one in the
                // middle of its row instead of orphaned on the left.
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < modes.length; i++)
                        SizedBox(
                          width: w,
                          height: w * 1.08,
                          child: StaggeredEntrance(
                            key: ValueKey(modes[i].id),
                            index: i,
                            child: _ModeTile(
                              mode: modes[i],
                              isEn: isEn,
                              position: i,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final _DrawMode mode;
  final bool isEn;
  final int position;

  const _ModeTile({
    required this.mode,
    required this.isEn,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: () {
        // The same event the games shelf uses, with ids that match the
        // `game_start` each screen logs — so "picked it up" and "played
        // it" join per mode. Five ways to draw landed at once; without
        // this we would be guessing which one anybody wants.
        AnalyticsService.instance.logGameTileTap(
          mode.id,
          playable: true,
          section: 'draw',
          position: position,
        );
        Navigator.of(context).push(KidRoutes.content(mode.open()));
      },
      child: Container(
        decoration: BoxDecoration(
          color: mode.tint,
          borderRadius: BorderRadius.circular(DT.rLg + 2),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: mode.color.withValues(alpha: .26),
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: AppArt(mode.art, size: 104))),
            const SizedBox(height: 8),
            Text(
              isEn ? mode.titleEn : mode.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DT.tileTitle.copyWith(color: DT.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isEn ? mode.subtitleEn : mode.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DT.caption.copyWith(fontSize: 13, color: DT.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
