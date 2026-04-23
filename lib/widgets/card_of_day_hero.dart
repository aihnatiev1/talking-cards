import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../utils/design_tokens.dart';

/// "Card of the Day" hero tile shown on the home screen.
///
/// Larger, illustrated, with a subtle pulse — designed to be the first thing a
/// toddler wants to tap when the app opens.
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
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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
    final hasImage = widget.card.image != null;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? DT.pressScale : 1.0,
          duration: DT.pressMs,
          curve: Curves.easeOut,
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              color: DT.surfaceWhite,
              borderRadius: BorderRadius.circular(DT.rLg),
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
                width: 2,
              ),
              boxShadow: DT.shadowSoft(accent),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DT.rLg - 2),
              child: Row(
                children: [
                  // Illustration pane — fixed width so intrinsic sizing is
                  // bounded on both axes and the image never balloons to its
                  // natural resolution.
                  SizedBox(
                    width: 92,
                    height: 108,
                    child: Container(
                      color: accent.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: hasImage
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/webp/${widget.card.image}.webp',
                                height: 88,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Text(widget.card.emoji,
                              style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.isEn ? '🔊 Card of the day' : '🔊 Картка дня',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.card.sound,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
