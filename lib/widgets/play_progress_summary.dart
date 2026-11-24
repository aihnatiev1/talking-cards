import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/play_session_provider.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import 'play_components.dart';

/// Only observations from the saved lesson; never an inferred speech score.
class PlayProgressSummary extends ConsumerWidget {
  const PlayProgressSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playSessionProvider).valueOrNull?.current;
    final packs = ref.watch(packsProvider).valueOrNull;
    if (session == null || packs == null || session.step == 0) {
      return const SizedBox.shrink();
    }
    final s = AppS(ref.watch(languageProvider) == 'en');
    final byId = {
      for (final pack in packs)
        for (final card in pack.cards) card.id: card,
    };
    final heard = session.cardIds
        .take(session.step.clamp(0, 3))
        .map((id) => byId[id]?.sound.toLowerCase())
        .whereType<String>()
        .join(', ');
    final recognized = <String>[];
    final helped = <String>[];
    for (var step = 3; step < session.step && step < 6; step++) {
      final word = byId[session.cardIds[step - 3]]?.sound.toLowerCase();
      if (word == null) continue;
      (session.assisted.contains(step) ? helped : recognized).add(word);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: PlayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s('Останнє заняття разом', 'Your latest lesson together'),
              style: DT.h1,
            ),
            const SizedBox(height: 12),
            Text(
              s('Картки заняття: $heard.', 'Lesson cards: $heard.'),
              style: DT.body,
            ),
            if (recognized.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s(
                  'Знайшли без підказки: ${recognized.join(', ')}.',
                  'Found without a hint: ${recognized.join(', ')}.',
                ),
                style: DT.body,
              ),
            ],
            if (helped.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s(
                  'З допомогою: ${helped.join(', ')}.',
                  'With help: ${helped.join(', ')}.',
                ),
                style: DT.body,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              s(
                'Пошукайте цих тваринок разом у книжці.',
                'Look for these animals together in a book.',
              ),
              style: DT.h2,
            ),
            const SizedBox(height: 8),
            Text(
              s(
                'Це спостереження у грі, а не оцінка мовлення.',
                'These are observations in a game, not a speech assessment.',
              ),
              style: DT.caption,
            ),
          ],
        ),
      ),
    );
  }
}
