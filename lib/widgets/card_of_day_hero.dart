import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';

/// "Card of the Day" hero tile shown on the home screen.
///
/// Illustration-first, mirroring [ContinueHero]: the card art fills the tile
/// edge-to-edge with the word overlaid on a bottom scrim — designed to be the
/// first thing a toddler wants to tap when the app opens.
class CardOfDayHero extends StatefulWidget {
  final CardModel card;
  final VoidCallback onTap;
  final String lang;

  const CardOfDayHero({
    super.key,
    required this.card,
    required this.onTap,
    this.lang = 'uk',
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
            height: 132,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Edge-to-edge illustration on a soft tinted pane.
                  Container(
                    color: accent.withValues(alpha: 0.16),
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: hasImage
                        ? Image.asset(
                            'assets/images/webp/${widget.card.image}.webp',
                            fit: BoxFit.contain,
                          )
                        : Center(
                            child: Text(widget.card.emoji,
                                style: const TextStyle(fontSize: 64)),
                          ),
                  ),
                  // Bottom scrim keeps the overlaid word readable on any art.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Context badge (parent-facing) — top-left over the art.
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DT.surfaceWhite.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppS(widget.lang)(
                            '🔊 Картка дня', '🔊 Card of the day'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  // Word on the scrim, audio affordance to the right.
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            widget.card.sound,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.volume_up_rounded,
                            color: accent,
                            size: 22,
                          ),
                        ),
                      ],
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
