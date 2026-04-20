import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/packs_provider.dart';
import '../screens/quest_map_screen.dart';
import '../utils/pack_categories.dart';

class QuestTab extends ConsumerWidget {
  const QuestTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packsProvider);
    final packs = packsAsync.valueOrNull ?? [];
    final cotdResult = cardOfTheDay(packs);
    final cotd = cotdResult?.$1;
    final cotdLocked = cotdResult?.$2 ?? false;

    return QuestMapScreen(
      showBackButton: false,
      cardOfDay: cotd,
      cardOfDayLocked: cotdLocked,
      onCardOfDayTap: () {
        // Audio is handled inside QuestMapScreen via _handleStopTap
      },
    );
  }
}
