import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pack_model.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/motion.dart';
import 'card_image.dart';
import 'kid_tap.dart';

/// The picture previews the exact next card, not a cover that may promise
/// a different reward. Titles grow naturally with the selected language.
class RewardPackPicker extends StatefulWidget {
  const RewardPackPicker({
    super.key,
    required this.packs,
    required this.bonusCards,
    required this.isEn,
    required this.onPick,
  });
  final List<PackModel> packs;
  final Map<String, int> bonusCards;
  final bool isEn;
  final ValueChanged<PackModel> onPick;

  @override
  State<RewardPackPicker> createState() => _RewardPackPickerState();
}

class _RewardPackPickerState extends State<RewardPackPicker> {
  String? _selected;

  Future<void> _choose(PackModel pack) async {
    if (_selected != null) return;
    setState(() => _selected = pack.id);
    await Future<void>.delayed(
      MotionPolicy.of(context).dur(DT.motion.successPop),
    );
    if (mounted) widget.onPick(pack);
  }

  @override
  Widget build(BuildContext context) {
    final eligible = widget.packs
        .where(
          (p) =>
              p.effectiveFreePreviewCount + (widget.bonusCards[p.id] ?? 0) <
              p.cards.length,
        )
        .toList();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: DT.rewardPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DT.textSecondary.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              const AppIconView(
                AppIcon.rewardChestOpen,
                size: 64,
                sticker: true,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isEn ? 'Choose your treasure' : 'Обери свій скарб',
                textAlign: TextAlign.center,
                style: DT.h2,
              ),
              const SizedBox(height: 6),
              Text(
                widget.isEn
                    ? 'Which card shall we take home?'
                    : 'Яку картку заберемо до колекції?',
                textAlign: TextAlign.center,
                style: DT.caption.copyWith(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, bounds) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(16) > 23;
                  final columns = largeText || bounds.maxWidth < 320
                      ? 1
                      : bounds.maxWidth >= 620
                      ? 3
                      : 2;
                  final width =
                      (bounds.maxWidth - 16 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 18,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < eligible.length; i++)
                        SizedBox(
                          width: width,
                          child: _option(eligible[i], width, i),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(PackModel pack, double width, int index) {
    final card =
        pack.cards[pack.effectiveFreePreviewCount +
            (widget.bonusCards[pack.id] ?? 0)];
    final selected = _selected == pack.id;
    final ink = DT.onTint(pack.color);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionPolicy.of(
        context,
      ).dur(DT.motion.rewardChoiceEnter(index)),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: _selected == null,
        label: '${pack.title}, ${card.sound}',
        child: KidTap(
          onTap: _selected == null ? () => _choose(pack) : null,
          child: AnimatedContainer(
            key: ValueKey('reward-option-${pack.id}'),
            duration: MotionPolicy.of(context).dur(DT.motion.selectionChange),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? Color.lerp(pack.color, Colors.white, .86)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? ink : pack.color.withValues(alpha: .22),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: pack.color.withValues(alpha: .16),
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    SizedBox(
                      height: math.min(180, width * .85),
                      width: double.infinity,
                      child: AnimatedScale(
                        scale: selected ? 1.045 : 1,
                        duration: MotionPolicy.of(
                          context,
                        ).dur(DT.motion.selectionChange),
                        child: CardImage.forCard(
                          card,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ink,
                          shape: BoxShape.circle,
                        ),
                        child: const AppIconView(
                          AppIcon.check,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pack.title,
                  textAlign: TextAlign.center,
                  style: DT.tileTitle.copyWith(
                    fontSize: 16,
                    height: 1.25,
                    color: DT.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isEn ? '1 new card' : '1 нова картка',
                  textAlign: TextAlign.center,
                  style: DT.caption.copyWith(color: ink),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
