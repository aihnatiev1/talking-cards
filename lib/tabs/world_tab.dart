import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/play_topic.dart';
import '../providers/home_tab_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/play_session_provider.dart';
import '../screens/coloring_hub_screen.dart';
import '../screens/kid_word_wall_screen.dart';
import '../services/audio_service.dart';
import '../utils/design_tokens.dart';
import '../utils/app_icons.dart';
import '../utils/kid_routes.dart';
import '../utils/l10n.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/kid_tap.dart';
import '../widgets/play_components.dart';
import '../widgets/animal_friend_art.dart';

class WorldTab extends ConsumerWidget {
  const WorldTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    final journal = ref.watch(playSessionProvider);
    final packs = ref.watch(packsProvider);
    final rewards = journal.valueOrNull?.rewards ?? const <String>{};
    final animals = [
      for (final topic in PlayTopic.all)
        if (rewards.contains(topic.id) &&
            topic.cards(packs.valueOrNull ?? []).isNotEmpty)
          topic.cards(packs.valueOrNull ?? []).first,
    ];
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
              Text(s('Мій світ', 'My world'), style: DT.display),
              const SizedBox(height: 8),
              Text(
                s(
                  'Тут живуть твої маленькі відкриття.',
                  'A home for your little discoveries.',
                ),
                style: DT.body,
              ),
              const SizedBox(height: 24),
              if (journal.isLoading || packs.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (journal.hasError || packs.hasError)
                PlayAction(
                  label: s('Спробувати ще', 'Try again'),
                  onPressed: () {
                    ref.invalidate(playSessionProvider);
                    ref.invalidate(packsProvider);
                  },
                )
              else if (animals.isEmpty)
                PlayPanel(
                  color: DT.mintTint,
                  child: Column(
                    children: [
                      const BloomMascot(
                        size: 140,
                        state: BloomState(emotion: BloomEmotion.wave),
                        interactive: false,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s(
                          'Запросимо першого друга?',
                          'Shall we invite a friend?',
                        ),
                        style: DT.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s(
                          'Пограй із тваринками — одна з них оселиться тут.',
                          'Play with the animals. One will join you here.',
                        ),
                        style: DT.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      PlayAction(
                        label: s('Грати', 'Play'),
                        onPressed: () =>
                            ref.read(homeDestinationProvider.notifier).state =
                                HomeDestination.play,
                      ),
                    ],
                  ),
                )
              else
                PlayPanel(
                  color: DT.mintTint,
                  child: Column(
                    children: [
                      const BloomMascot(
                        size: 88,
                        state: BloomState(emotion: BloomEmotion.happy),
                        interactive: false,
                      ),
                      Text(
                        s(
                          'Торкнись друга й послухай',
                          'Tap a friend and listen',
                        ),
                        style: DT.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DT.rLg),
                        child: SizedBox(
                          width: double.infinity,
                          child: CustomPaint(
                            painter: const PlayGardenPainter(),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 16,
                                children: [
                                  for (final card in animals)
                                    SizedBox(
                                      width: 160,
                                      child: Semantics(
                                        button: true,
                                        label: card.sound,
                                        child: KidTap(
                                          sound: null,
                                          onTap: () => AudioService.instance
                                              .playWordOnly(
                                                card.audioKey,
                                                card.sound,
                                              ),
                                          child: Column(
                                            children: [
                                              Container(
                                                height: 160,
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        DT.rLg,
                                                      ),
                                                ),
                                                child: AnimalFriendArt(
                                                  animal: card.image ?? 'cow',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                card.sound,
                                                style: DT.tileTitle,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                          'Слова й наліпки, які ти зібрав',
                          'Words and stickers you collected',
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
