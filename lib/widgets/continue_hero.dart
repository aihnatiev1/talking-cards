import 'package:flutter/material.dart';

import '../models/pack_model.dart';
import '../utils/design_tokens.dart';

/// "Continue where you left off" hero tile. Visually mirrors [CardOfDayHero]
/// so the home row stays consistent when it swaps in.
class ContinueHero extends StatefulWidget {
  final PackModel pack;
  final int progress;
  final bool isEn;
  final VoidCallback onTap;

  const ContinueHero({
    super.key,
    required this.pack,
    required this.progress,
    required this.isEn,
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
                  SizedBox(
                    width:
                        MediaQuery.of(context).size.width < 360 ? 76 : 92,
                    height: 108,
                    child: Container(
                      color: accent.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: thumb != null
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/webp/$thumb.webp',
                                height: 88,
                                fit: BoxFit.contain,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.contain,
                              child: Text(widget.pack.icon,
                                  style: const TextStyle(fontSize: 48)),
                            ),
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
                              widget.isEn ? '▶ Continue' : '▶ Продовжити',
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
                              widget.pack.title,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (showProgress) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                minHeight: 3,
                                backgroundColor:
                                    accent.withValues(alpha: 0.15),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ],
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
