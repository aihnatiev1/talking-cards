import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/play_topic.dart';
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
import '../widgets/cue_pill.dart';
import '../models/card_model.dart';
import '../utils/motion.dart';
import '../widgets/kid_tap.dart';
import 'play_tab.dart';
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
          (topic, topic.cards(packs.valueOrNull ?? []).first),
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
                        // Straight into the lesson that brings the first
                        // friend — not back to the home screen to find it.
                        onPressed: () => openNextPlayLesson(context, ref),
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
                      const SizedBox(height: 12),
                      // A deck to leaf through, one friend at a time — a
                      // column of every friend grew longer than the screen
                      // as the lessons were played.
                      _FriendDeck(friends: animals),
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

/// The friends from the lessons as a deck of big cards: swipe or tap the
/// arrows to leaf through, tap a friend to hear it.
class _FriendDeck extends StatefulWidget {
  const _FriendDeck({required this.friends});

  final List<(PlayTopic, CardModel)> friends;

  @override
  State<_FriendDeck> createState() => _FriendDeckState();
}

class _FriendDeckState extends State<_FriendDeck> {
  // The newest friend first: the one the child has just met.
  late final PageController _pages = PageController(
    viewportFraction: .82,
    initialPage: widget.friends.length - 1,
  );
  late int _page = widget.friends.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (page < 0 || page >= widget.friends.length) return;
    _pages.animateToPage(
      page,
      duration: MotionPolicy.of(context).dur(DT.motion.base),
      curve: Curves.easeOutCubic,
    );
  }

  void _hear((PlayTopic, CardModel) friend) {
    final (topic, card) = friend;
    if (topic.withSounds) {
      AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    } else {
      AudioService.instance.playWordOnly(card.audioKey, card.sound);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = widget.friends;
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pages,
            itemCount: friends.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, i) {
              final (topic, card) = friends[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Semantics(
                  button: true,
                  label: card.sound,
                  child: KidTap(
                    key: ValueKey('friend-${topic.id}'),
                    sound: null,
                    onTap: () => _hear(friends[i]),
                    child: Container(
                      decoration: BoxDecoration(
                        color: DT.surfaceWhite,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: DT.shadowSoft(DT.brand),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CustomPaint(
                        painter: const PlayGardenPainter(),
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  4,
                                ),
                                child: AnimalFriendArt(
                                  animal: card.image ?? 'cow',
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                card.sound,
                                style: DT.tileTitle.copyWith(fontSize: 22),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (friends.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DeckArrow(
                key: const ValueKey('friend-prev'),
                left: true,
                enabled: _page > 0,
                onTap: () => _go(_page - 1),
              ),
              const SizedBox(width: 16),
              for (var i = 0; i < friends.length; i++)
                AnimatedContainer(
                  duration: MotionPolicy.of(context).dur(DT.motion.quick),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? DT.brand : DT.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              const SizedBox(width: 16),
              _DeckArrow(
                key: const ValueKey('friend-next'),
                left: false,
                enabled: _page < friends.length - 1,
                onTap: () => _go(_page + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeckArrow extends StatelessWidget {
  const _DeckArrow({
    super.key,
    required this.left,
    required this.enabled,
    required this.onTap,
  });

  final bool left;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KidTap(
    onTap: enabled ? onTap : null,
    child: AnimatedOpacity(
      opacity: enabled ? 1 : .35,
      duration: MotionPolicy.of(context).dur(DT.motion.quick),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: DT.surfaceWhite,
          shape: BoxShape.circle,
          boxShadow: DT.shadowSoft(DT.brand),
        ),
        alignment: Alignment.center,
        child: Transform.flip(
          flipX: left,
          child: const AppArt('play', size: 30),
        ),
      ),
    ),
  );
}
