import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../providers/srs_provider.dart';
import '../utils/design_tokens.dart';
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

    const color = DT.sky;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: GestureDetector(
        onTap: () => onTap(dueCards),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: DT.shadowSoft(color),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: DT.surfaceWhite,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🔁', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s('Повторити сьогодні', 'Review today'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s('${dueCards.length} карток чекають',
                          '${dueCards.length} cards waiting'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Text(
                      'GO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: Colors.white),
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
