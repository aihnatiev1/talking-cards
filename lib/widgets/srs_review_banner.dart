import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../providers/srs_provider.dart';
import '../utils/l10n.dart';

/// Banner prompting the user to do today's SRS review.
/// Returns `SizedBox.shrink()` when there are no due cards.
class SrsReviewBanner extends ConsumerWidget {
  final List<CardModel> allCards;
  final void Function(List<CardModel>) onTap;

  const SrsReviewBanner({
    super.key,
    required this.allCards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srs = ref.watch(srsProvider);
    if (srs.dueCount == 0) return const SizedBox.shrink();
    final s = AppS(ref.watch(languageProvider) == 'en');

    final dueCards = allCards
        .where((c) => srs.dueIds.contains(c.id) && c.audioKey != null)
        .toList();
    if (dueCards.isEmpty) return const SizedBox.shrink();

    const color = Color(0xFF00BCD4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: () => onTap(dueCards),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            children: [
              const Text('🔁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s('Повторити сьогодні', 'Review today'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      s('${dueCards.length} карток чекають',
                          '${dueCards.length} cards waiting'),
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
