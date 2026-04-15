import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';

// Packs to exclude from sound filtering (non-real-word packs)
const _excludedPacks = {
  'rozmovlyalky', 'phrases', 'opposites',
  'sound_r', 'sound_l', 'sound_sh', 'sound_s',
};

class SoundFilterScreen extends ConsumerStatefulWidget {
  const SoundFilterScreen({super.key});

  @override
  ConsumerState<SoundFilterScreen> createState() => _SoundFilterScreenState();
}

class _SoundFilterScreenState extends ConsumerState<SoundFilterScreen> {
  String? _selectedLetter;

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    final packsAsync = ref.watch(packsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s('За першим звуком', 'By first sound'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (packs) {
          // Collect all cards (exclude non-word packs)
          final allCards = <CardModel>[];
          for (final pack in packs) {
            if (_excludedPacks.contains(pack.id)) continue;
            if (pack.isLocked) continue;
            allCards.addAll(pack.cards);
          }

          // Build letter → cards map (by first letter of sound)
          final Map<String, List<CardModel>> byLetter = {};
          for (final card in allCards) {
            final word = card.sound.trim();
            if (word.isEmpty || card.sound.contains('-')) continue;
            final letter = word[0].toUpperCase();
            byLetter.putIfAbsent(letter, () => []).add(card);
          }

          final letters = byLetter.keys.toList()..sort();

          // Auto-select first letter if none chosen
          if (_selectedLetter == null && letters.isNotEmpty) {
            _selectedLetter = letters.first;
          }

          final filteredCards = _selectedLetter != null
              ? (byLetter[_selectedLetter] ?? [])
              : <CardModel>[];

          return Column(
            children: [
              // Letter chips
              _LetterChipRow(
                letters: letters,
                counts: {for (final l in letters) l: byLetter[l]!.length},
                selected: _selectedLetter,
                onSelect: (l) {
                  setState(() => _selectedLetter = l);
                  AnalyticsService.instance.logSoundFilterOpen(l);
                },
              ),

              // Count label
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Text(
                      _selectedLetter != null
                          ? s(
                              'Слова на «$_selectedLetter» — ${filteredCards.length}',
                              'Words with «$_selectedLetter» — ${filteredCards.length}',
                            )
                          : '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kAccent,
                      ),
                    ),
                  ],
                ),
              ),

              // Cards grid
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: GridView.builder(
                    key: ValueKey(_selectedLetter),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filteredCards.length,
                    itemBuilder: (_, i) =>
                        _SoundCard(card: filteredCards[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Horizontal letter chip row
// ─────────────────────────────────────────────

class _LetterChipRow extends StatelessWidget {
  final List<String> letters;
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _LetterChipRow({
    required this.letters,
    required this.counts,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final letter = letters[i];
          final isSelected = selected == letter;
          final count = counts[letter] ?? 0;

          return GestureDetector(
            onTap: () => onSelect(letter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              decoration: BoxDecoration(
                color: isSelected ? kAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? kAccent
                      : Colors.grey.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    letter,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white70
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Single card chip with audio on tap
// ─────────────────────────────────────────────

class _SoundCard extends ConsumerStatefulWidget {
  final CardModel card;
  const _SoundCard({required this.card});

  @override
  ConsumerState<_SoundCard> createState() => _SoundCardState();
}

class _SoundCardState extends ConsumerState<_SoundCard> {
  bool _playing = false;

  void _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    ref.read(dailyQuestProvider.notifier).recordCardView();
    await AudioService.instance.speakCard(
      widget.card.audioKey,
      widget.card.sound,
      widget.card.text,
    );
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return GestureDetector(
      onTap: _play,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _playing
              ? card.colorAccent.withValues(alpha: 0.15)
              : card.colorBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _playing
                ? card.colorAccent
                : card.colorAccent.withValues(alpha: 0.2),
            width: _playing ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (card.image != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Image.asset(
                    'assets/images/webp/${card.image}.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Text(card.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                card.sound,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: card.colorAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
