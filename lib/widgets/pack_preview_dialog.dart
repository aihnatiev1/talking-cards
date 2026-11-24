import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import 'card_image.dart';
import 'pack_cover_hero.dart';
import 'play_components.dart';

class PackPreviewDialog extends StatelessWidget {
  const PackPreviewDialog({
    super.key,
    required this.pack,
    required this.waiting,
    required this.remaining,
    required this.isEn,
    required this.onUnlock,
  });
  final PackModel pack;
  final List<CardModel> waiting;
  final int remaining;
  final bool isEn;
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(DT.sp20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: pack.color.withValues(alpha: 0.12),
                    child: CardImage(
                      name: PackCoverHero.coverOf(pack),
                      fallbackEmoji: pack.icon,
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s('Сподобалось? ${pack.title}', 'Enjoying ${pack.title}?'),
                textAlign: TextAlign.center,
                // On the dialog's white card the pack colour was the
                // headline: mint 2.0:1, sunBurst 1.3:1. The heading is
                // charcoal (11.7:1) and the pack speaks through the icon
                // above it and the button below.
                style: DT.h2,
              ),
              const SizedBox(height: 10),
              Text(
                s(
                  'Ще $remaining карток чекають!',
                  '$remaining more cards waiting!',
                ),
                textAlign: TextAlign.center,
                style: DT.body,
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 8,
                children: [
                  for (final card in waiting)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ColoredBox(
                            color: card.colorBg,
                            child: CardImage.forCard(
                              card,
                              padding: const EdgeInsets.all(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              PlayAction(
                label: s('Розблокувати все', 'Unlock all'),
                icon: AppIcon.lock,
                onPressed: () {
                  Navigator.of(context).pop();
                  onUnlock();
                },
              ),
              const SizedBox(height: 10),
              PlayAction(
                secondary: true,
                icon: AppIcon.navCards,
                label: s('До карток', 'Back to cards'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
