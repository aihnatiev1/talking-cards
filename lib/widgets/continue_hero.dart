import 'package:flutter/material.dart';

import '../models/pack_model.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';

/// "Continue where you left off" hero tile. Visually mirrors [CardOfDayHero]
/// so the home row stays consistent when it swaps in.
///
/// Illustration-first: the pack artwork fills the whole card edge-to-edge,
/// with the title and progress overlaid on a bottom scrim — a non-reader
/// recognizes the picture, the parent reads the label.
class ContinueHero extends StatefulWidget {
  final PackModel pack;
  final int progress;
  final String lang;
  final VoidCallback onTap;

  const ContinueHero({
    super.key,
    required this.pack,
    required this.progress,
    required this.lang,
    required this.onTap,
  });

  @override
  State<ContinueHero> createState() => _ContinueHeroState();
}

class _ContinueHeroState extends State<ContinueHero>
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

  String? _thumbImage() {
    if (widget.pack.cover != null) return widget.pack.cover;
    for (final c in widget.pack.cards) {
      if (c.image != null) return c.image;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.pack.color;
    final thumb = _thumbImage();
    final total = widget.pack.cards.length;
    final showProgress = widget.progress > 0 && total > 0;
    final progressValue =
        showProgress ? (widget.progress / total).clamp(0.0, 1.0) : 0.0;

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
                    child: thumb != null
                        ? Image.asset(
                            'assets/images/webp/$thumb.webp',
                            fit: BoxFit.contain,
                          )
                        : Center(
                            child: Text(widget.pack.icon,
                                style: const TextStyle(fontSize: 64)),
                          ),
                  ),
                  // Bottom scrim keeps the overlaid title readable on any art.
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
                        AppS(widget.lang)('▶ Продовжити', '▶ Continue'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  // Title + progress on the scrim, play affordance to the right.
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.pack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (showProgress) ...[
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progressValue,
                                    minHeight: 4,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.35),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                ),
                              ],
                            ],
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
                            Icons.play_arrow_rounded,
                            color: accent,
                            size: 24,
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
