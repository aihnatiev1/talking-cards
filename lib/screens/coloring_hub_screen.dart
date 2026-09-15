import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coloring_sheets_provider.dart';
import '../providers/language_provider.dart';
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
  final AppIcon badge;
  final Widget Function() open;

  const _DrawMode({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.subtitle,
    required this.subtitleEn,
    required this.color,
    required this.tint,
    required this.badge,
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

    final modes = <_DrawMode>[
      _DrawMode(
        id: 'water',
        title: 'Чарівна вода',
        titleEn: 'Magic water',
        subtitle: 'Проведи пальцем — з\'являються кольори',
        subtitleEn: 'Drag your finger — the colours appear',
        color: DT.sky,
        tint: DT.skyTint,
        badge: AppIcon.navColoring,
        open: () => const ColoringScreen(),
      ),
      if (hasSheets)
        _DrawMode(
          id: 'fill',
          title: 'Розфарбуй',
          titleEn: 'Colour it in',
          subtitle: 'Обери колір і тисни на частинку',
          subtitleEn: 'Pick a colour, tap a part',
          color: DT.coral,
          tint: DT.coralTint,
          badge: AppIcon.gameMatch,
          open: () => const FillColoringScreen(),
        ),
      if (hasSheets)
        _DrawMode(
          id: 'fill_by_ear',
          title: 'Слухай і фарбуй',
          titleEn: 'Listen and colour',
          subtitle: 'Блум називає колір — знайди його',
          subtitleEn: 'Bloom names a colour — find it',
          color: DT.peach,
          tint: DT.peachTint,
          badge: AppIcon.catSpeech,
          open: () => const FillColoringScreen(byEar: true),
        ),
      _DrawMode(
        id: 'stickers',
        title: 'Наліпки',
        titleEn: 'Stickers',
        subtitle: 'Постав на галявину — і почуй слово',
        subtitleEn: 'Put them on the meadow and hear the word',
        color: DT.mint,
        tint: DT.mintTint,
        badge: AppIcon.stickerRainbow,
        open: () => const StickerSceneScreen(),
      ),
      _DrawMode(
        id: 'mirror',
        title: 'Дзеркальце',
        titleEn: 'Mirror',
        subtitle: 'Малюй половинку — вийде ціле',
        subtitleEn: 'Draw one half — get the whole',
        color: DT.violet,
        tint: DT.violetTint,
        badge: AppIcon.stickerButterfly,
        open: () => const MirrorDrawScreen(),
      ),
    ];

    return KidScreen(
      accent: DT.brand,
      background: DT.violetTint,
      // A tab, not a pushed route: the way out is the bar underneath.
      showLeading: false,
      title: Text(
        s('Малюємо', 'Let\'s draw'),
        style: DT.h2.copyWith(fontSize: 19, color: DT.textPrimary),
      ),
      body: StaggerScope(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.92,
          ),
          itemCount: modes.length,
          itemBuilder: (context, i) => StaggeredEntrance(
            key: ValueKey(modes[i].id),
            index: i,
            child: _ModeTile(mode: modes[i], isEn: isEn),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final _DrawMode mode;
  final bool isEn;

  const _ModeTile({required this.mode, required this.isEn});

  @override
  Widget build(BuildContext context) {
    return KidTap(
      onTap: () => Navigator.of(context).push(KidRoutes.content(mode.open())),
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
            Expanded(
              child: Center(
                child: AppIconView(mode.badge, size: 72, sticker: true),
              ),
            ),
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
              style: DT.caption.copyWith(fontSize: 11, color: DT.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
