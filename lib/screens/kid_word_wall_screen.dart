import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/srs_provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/bloom_mascot.dart';

/// Kid-facing version of the Word Wall — lives outside Parent Dashboard so
/// the child can browse their own collection without a parental gate.
///
/// Differences from `_WordsTab` in parent_dashboard:
/// - No "Share" button (that's parent flex)
/// - No grouping by pack — flat grid (kids 1-4 can't read pack names)
/// - Tap on tile = plays audio with subtle pulse, no popup
/// - Empty state invites them to play
class KidWordWallScreen extends ConsumerStatefulWidget {
  const KidWordWallScreen({super.key});

  @override
  ConsumerState<KidWordWallScreen> createState() =>
      _KidWordWallScreenState();
}

class _KidWordWallScreenState extends ConsumerState<KidWordWallScreen> {
  static const _learnedThreshold = 2;

  @override
  Widget build(BuildContext context) {
    final srs = ref.watch(srsProvider);
    final packsAsync = ref.watch(packsProvider);
    final profile = ref.watch(profileProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final childName = profile.active?.name ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          s('Скарбничка', 'Treasure box'),
          style: TextStyle(
            fontSize: responsiveFont(context, 18),
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: packsAsync.when(
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
      ),
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
          colors: [kAccent, kTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const BloomMascot(size: 64, emotion: BloomEmotion.waving),
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
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    AudioService.instance.playWordOnly(
      widget.card.audioKey,
      widget.card.sound,
    );
    _pulse
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return GestureDetector(
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
                        child: card.image != null
                            ? Image.asset(
                                'assets/images/webp/${card.image}.webp',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    card.emoji,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  card.emoji,
                                  style: const TextStyle(fontSize: 36),
                                ),
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
