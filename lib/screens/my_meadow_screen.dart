import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coloring_album_provider.dart';
import '../providers/filled_sheets_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/ambient_loop.dart';
import '../widgets/card_image.dart';
import '../widgets/colored_sheet_view.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';

/// Everything the child has finished, standing together on the meadow.
///
/// Not a gallery with dates and counts — a place. The reward for
/// finishing a drawing is that it goes and stands with the others, and
/// the meadow fills up over weeks. Tapping one says its word, which is
/// the only thing this screen asks of anybody.
///
/// It gathers from both kinds of finishing: the drawings filled area by
/// area, and the pictures the water revealed.
class MyMeadowScreen extends ConsumerStatefulWidget {
  const MyMeadowScreen({super.key});

  @override
  ConsumerState<MyMeadowScreen> createState() => _MyMeadowScreenState();
}

class _MyMeadowScreenState extends ConsumerState<MyMeadowScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart('my_meadow');
  }

  void _say(String? cardId) {
    if (cardId == null) return;
    final packs = ref.read(packsProvider).valueOrNull ?? const [];
    for (final pack in packs) {
      final card = pack.cards.where((c) => c.id == cardId).firstOrNull;
      if (card != null) {
        AudioService.instance.playWordOnly(card.audioKey, card.sound);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    // What was finished, not what is half-painted on the canvas.
    final fills = ref.watch(finishedSheetsProvider);
    final album = ref.watch(coloringAlbumProvider);

    final residents = <Widget>[
      for (final entry in fills.entries)
        ColoredSheetView(
          key: ValueKey('sheet-${entry.key}'),
          sheetId: entry.key,
          fills: entry.value,
        ),
      for (final entry in album.entries)
        KidTap(
          key: ValueKey('album-${entry.cardId}'),
          onTap: () => _say(entry.cardId),
          sound: null,
          child: CardImage(name: entry.image, fallbackEmoji: '🖼️'),
        ),
    ];

    return KidScreen(
      accent: DT.brand,
      meadow: true,
      title: Text(
        s('Моя галявина', 'My meadow'),
        style: DT.h2.copyWith(fontSize: 19, color: DT.textPrimary),
      ),
      body: residents.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  s(
                    'Тут стануть твої малюнки',
                    'Your drawings will stand here',
                  ),
                  textAlign: TextAlign.center,
                  style: DT.tileTitle.copyWith(color: DT.textSecondary),
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: residents.length,
              itemBuilder: (context, i) => _Resident(
                index: i,
                child: residents[i],
              ),
            ),
    );
  }
}

/// One finished picture on the meadow, breathing on its own beat.
///
/// The offset phase matters: a dozen drawings breathing in unison look
/// mechanical, the same dozen slightly out of step look like a crowd.
class _Resident extends StatelessWidget {
  final int index;
  final Widget child;

  const _Resident({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return AmbientLoop(
      period: DT.motion.drawingBreath + DT.motion.drawingBreathStagger * index,
      builder: (_, t, child) {
        final breath = math.sin(t * math.pi * 2);
        return Transform.scale(
          scaleX: 1 + breath * 0.008,
          scaleY: 1 + breath * 0.014,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DT.surfaceWhite.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      ),
    );
  }
}
