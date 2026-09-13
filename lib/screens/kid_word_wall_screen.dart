import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/srs_provider.dart';
import '../screens/rewards_screen.dart';
import '../services/audio_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/card_image.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

/// Which half of the treasure box is open.
enum TreasureTab { words, stickers }

/// The child's treasure box — the one place in the kid zone that holds
/// what they have collected: the words they know («Слова») and the
/// stickers they earned («Наліпки», ux-gap-audit G14).
///
/// Rewards used to hang off `StatsScreen`, a parent screen with a share
/// button, three charts and 21 progress rows — the child's prizes were
/// two taps deep inside the grown-ups' report. Now the report is behind
/// the parental gate ([StatsScreen.open]) and the prizes are here, one tap
/// from home, behind two big drawn tabs instead of a Material `TabBar` a
/// non-reader cannot use.
///
/// Differences from `_WordsTab` in parent_dashboard:
/// - No "Share" button (that's parent flex)
/// - No grouping by pack — flat grid (kids 1-4 can't read pack names)
/// - Tap on tile = plays audio with subtle pulse, no popup
/// - Empty state invites them to play
class KidWordWallScreen extends ConsumerStatefulWidget {
  const KidWordWallScreen({super.key, this.initialTab = TreasureTab.words});

  /// Which tab opens first — the streak chip lands on [TreasureTab.stickers].
  final TreasureTab initialTab;

  @override
  ConsumerState<KidWordWallScreen> createState() =>
      _KidWordWallScreenState();
}

class _KidWordWallScreenState extends ConsumerState<KidWordWallScreen> {
  static const _learnedThreshold = 2;

  late TreasureTab _tab = widget.initialTab;

  void _select(TreasureTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';

    // No text title: the body's own header greets the child by name and
    // shows the count — that is the "Treasure box" a non-reader gets.
    return KidScreen(
      accent: DT.brand,
      body: Column(
        children: [
          _TreasureTabs(selected: _tab, onSelect: _select, isEn: isEn),
          Expanded(
            child: switch (_tab) {
              TreasureTab.stickers => const RewardsAlbum(),
              TreasureTab.words => _words(context, isEn),
            },
          ),
        ],
      ),
    );
  }

  Widget _words(BuildContext context, bool isEn) {
    final srs = ref.watch(srsProvider);
    final packsAsync = ref.watch(packsProvider);
    final profile = ref.watch(profileProvider);
    final s = AppS(isEn);
    final childName = profile.active?.name ?? '';

    return packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            Center(child: Text(s('Помилка', 'Error'))),
        data: (packs) {
          // Flatten learned cards. Order: most recently reviewed first so new
          // additions surface at the top — kid sees "look, fresh ones!".
          final orderedIds = srs.cards.values
              .where((c) => c.repetitions >= _learnedThreshold)
              .toList()
            ..sort(
                (a, b) => b.nextReviewDate.compareTo(a.nextReviewDate));
          final cardLookup = <String, CardModel>{};
          for (final p in packs) {
            for (final c in p.cards) {
              cardLookup[c.id] = c;
            }
          }
          final learned = orderedIds
              .map((s) => cardLookup[s.cardId])
              .whereType<CardModel>()
              .toList();

          if (learned.isEmpty) {
            return _emptyState(context, isEn, s);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  childName: childName,
                  count: learned.length,
                  isEn: isEn,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width >=
                            kLargeScreen
                        ? 5
                        : 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _LearnedTile(card: learned[i]),
                    childCount: learned.length,
                  ),
                ),
              ),
            ],
          );
        },
    );
  }

  Widget _emptyState(BuildContext context, bool isEn, AppS s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BloomMascot(size: 96),
            const SizedBox(height: 20),
            Text(
              s('Скарбничка порожня', 'Treasure box is empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsiveFont(context, 18),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              s(
                'Грай у вікторину — і слова збиратимуться сюди!',
                'Play the quiz and your words will collect here!',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsiveFont(context, 14),
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two doors of the treasure box, as big drawn tabs.
///
/// Not a Material `TabBar`: that is a text strip with a 2 dp underline and
/// a 48 dp target — unusable by a child who cannot read and taps with a
/// whole hand. These are 84 dp cards, each a drawn [AppIcon] with its word
/// under it (the word is for the parent reading over the shoulder; the
/// icon is what the child aims at), selected one filled in the accent.
class _TreasureTabs extends StatelessWidget {
  const _TreasureTabs({
    required this.selected,
    required this.onSelect,
    required this.isEn,
  });

  final TreasureTab selected;
  final ValueChanged<TreasureTab> onSelect;
  final bool isEn;

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DT.sp16, 0, DT.sp16, DT.sp8),
      child: Row(
        children: [
          Expanded(
            child: _TreasureTab(
              key: const ValueKey('treasure_tab_words'),
              icon: AppIcon.navCards,
              label: s('Слова', 'Words'),
              accent: DT.brand,
              selected: selected == TreasureTab.words,
              onTap: () => onSelect(TreasureTab.words),
            ),
          ),
          const SizedBox(width: DT.sp12),
          Expanded(
            child: _TreasureTab(
              key: const ValueKey('treasure_tab_stickers'),
              icon: AppIcon.stickerAlbum,
              label: s('Наліпки', 'Stickers'),
              accent: DT.peach,
              selected: selected == TreasureTab.stickers,
              onTap: () => onSelect(TreasureTab.stickers),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreasureTab extends StatelessWidget {
  const _TreasureTab({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PackPalette.of(accent);
    return KidTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MotionPolicy.of(context).dur(DT.motion.quick),
        curve: DT.motion.standard,
        height: 84,
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.tint,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: palette.border, width: 1.5),
          boxShadow: selected ? DT.shadowSoft(palette.accent) : DT.shadowRest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconView(
              icon,
              size: 40,
              sticker: selected,
              semanticLabel: label,
            ),
            const SizedBox(height: DT.sp4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.tileTitle.copyWith(
                fontSize: responsiveFont(context, 13),
                color: selected ? Colors.white : palette.onTint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String childName;
  final int count;
  final bool isEn;

  const _Header({
    required this.childName,
    required this.count,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final title = childName.isNotEmpty
        ? (isEn ? "$childName's words" : 'Слова $childName')
        : (isEn ? 'My words' : 'Мої слова');
    final word = isEn
        ? (count == 1 ? 'word' : 'words')
        : _ukWord(count);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DT.brand, DT.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const BloomMascot(
            size: 64,
            state: BloomState.still(BloomEmotion.wave),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsiveFont(context, 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 36),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: responsiveFont(context, 13),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ukWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'слово';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
      return 'слова';
    }
    return 'слів';
  }
}

class _LearnedTile extends StatefulWidget {
  final CardModel card;

  const _LearnedTile({required this.card});

  @override
  State<_LearnedTile> createState() => _LearnedTileState();
}

class _LearnedTileState extends State<_LearnedTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: DT.motion.slow,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    AudioService.instance.playWordOnly(
      widget.card.audioKey,
      widget.card.sound,
    );
    if (MotionPolicy.of(context).reduce) return;
    _pulse
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return KidTap(
      // The card's own word is the answer to the tap — a tock on top of it
      // would only race the voice.
      sound: null,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final t = _pulse.value;
          // Quick pop: scale 1 → 1.08 → 1, glow rises and fades.
          final scale = 1.0 + 0.08 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          final glow = 0.6 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                color: card.colorBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: card.colorAccent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: card.colorAccent
                        .withValues(alpha: 0.15 + glow * 0.4),
                    blurRadius: 8 + glow * 12,
                    spreadRadius: glow,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: card.colorBg,
                        child: CardImage.forCard(
                          card,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(4, 4, 4, 6),
                      child: Text(
                        card.sound,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsiveFont(context, 12),
                          fontWeight: FontWeight.w800,
                          color: card.colorAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
