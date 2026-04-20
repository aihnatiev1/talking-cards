import 'package:flutter/material.dart';

import '../models/card_model.dart';
import 'app_card_shell.dart';

/// Pulsing "Card of the Day" hero tile shown on the home screen.
class CardOfDayHero extends StatefulWidget {
  final CardModel card;
  final VoidCallback onTap;
  final bool isEn;

  const CardOfDayHero({
    super.key,
    required this.card,
    required this.onTap,
    this.isEn = false,
  });

  @override
  State<CardOfDayHero> createState() => _CardOfDayHeroState();
}

class _CardOfDayHeroState extends State<CardOfDayHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.card.colorAccent;
    return ScaleTransition(
      scale: _scale,
      child: AppCardShell(
        color: accent,
        onTap: widget.onTap,
        constraints: const BoxConstraints(minHeight: 90),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.isEn ? '🔊 Card of the day' : '🔊 Картка дня',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.card.sound,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.card.emoji, style: const TextStyle(fontSize: 36)),
          ],
        ),
      ),
    );
  }
}
