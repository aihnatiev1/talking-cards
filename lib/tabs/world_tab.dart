import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';
import '../screens/coloring_hub_screen.dart';
import '../screens/farm_screen.dart';
import '../screens/kid_word_wall_screen.dart';
import '../services/audio_service.dart';
import '../utils/design_tokens.dart';
import '../utils/app_icons.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../widgets/cue_pill.dart';
import '../widgets/kid_tap.dart';

class WorldTab extends ConsumerWidget {
  const WorldTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              // On a frosted plate: the title and its line used to lie
              // straight on the painted clouds, and the line could not be
              // read.
              // Full width and the same inset as the card below it.
              CuePill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s('Мій світ', 'My world'), style: DT.h1),
                      const SizedBox(height: 2),
                      Text(
                        s(
                          'Тут живуть твої маленькі відкриття.',
                          'A home for your little discoveries.',
                        ),
                        style: DT.body.copyWith(color: DT.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // «Ферма»: the toy farm board, every animal in its place.
              _FarmDoor(
                title: s('Ферма', 'The farm'),
                hint: s(
                  'Тваринки говорять — послухай і вгадай',
                  'The animals talk — listen and guess',
                ),
                onTap: () {
                  AudioService.instance.stop();
                  Navigator.of(
                    context,
                  ).push(KidRoutes.game(const FarmScreen()));
                },
              ),
              const SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _WorldDoor(
                        art: 'palette',
                        color: DT.peachTint,
                        title: s('Малювати', 'Draw'),
                        hint: s('Розфарбуй і прикрась', 'Colour and decorate'),
                        onTap: () {
                          AudioService.instance.stop();
                          Navigator.of(
                            context,
                          ).push(KidRoutes.content(const ColoringHubScreen()));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WorldDoor(
                        art: 'chest',
                        color: DT.mintTint,
                        title: s('Мої скарби', 'My treasures'),
                        hint: s(
                          'Слова й гості ферми, які ти зібрав',
                          'Words and farm guests you collected',
                        ),
                        onTap: () {
                          AudioService.instance.stop();
                          Navigator.of(
                            context,
                          ).push(KidRoutes.content(const KidWordWallScreen()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The farm's door: wide, the painted animals talking, its name and line.
class _FarmDoor extends StatelessWidget {
  const _FarmDoor({
    required this.title,
    required this.hint,
    required this.onTap,
  });
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KidTap(
    key: const ValueKey('world-farm'),
    onTap: onTap,
    child: Container(
      height: 190,
      decoration: BoxDecoration(
        color: DT.farmSky,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.outline, width: 2),
        boxShadow: const [BoxShadow(color: DT.outline, offset: Offset(0, 4))],
        image: const DecorationImage(
          image: AssetImage('assets/images/backdrops/farm_scene.webp'),
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            bottom: 8,
            child: Image.asset(
              'assets/images/games/who.webp',
              height: 130,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            right: 150,
            child: CuePill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DT.tileTitle),
                    const SizedBox(height: 2),
                    Text(hint, style: DT.caption, maxLines: 2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A big picture door: the painted icon, its name, one line of what's behind.
class _WorldDoor extends StatelessWidget {
  const _WorldDoor({
    required this.art,
    required this.color,
    required this.title,
    required this.hint,
    required this.onTap,
  });
  final String art;
  final Color color;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KidTap(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.all(DT.sp12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.outline, width: 2),
        boxShadow: const [BoxShadow(color: DT.outline, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppArt(art, size: 84),
          const SizedBox(height: 8),
          Text(title, style: DT.tileTitle, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(hint, style: DT.caption, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
