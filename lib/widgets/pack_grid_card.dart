import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../utils/design_tokens.dart';

class PackGridCard extends ConsumerStatefulWidget {
  final PackModel pack;
  final VoidCallback onTap;
  final bool isCompleted;
  final int progress;
  final bool isSeasonal;

  const PackGridCard({
    super.key,
    required this.pack,
    required this.onTap,
    this.isCompleted = false,
    this.progress = 0,
    this.isSeasonal = false,
  });

  @override
  ConsumerState<PackGridCard> createState() => _PackGridCardState();
}

class _PackGridCardState extends ConsumerState<PackGridCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _wobble;
  late final Animation<double> _wobbleRotation;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isSeasonal) _shimmer.repeat(reverse: true);
    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _wobbleRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0.0), weight: 1),
    ]).animate(_wobble);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _wobble.dispose();
    super.dispose();
  }

  void _triggerWobble() {
    HapticFeedback.mediumImpact();
    _wobble
      ..reset()
      ..forward();
  }

  CardModel? _thumb() {
    // Virtual packs (favorites / review / seasonal aliases prefixed with _)
    // own a semantic emoji (❤️ / 🔄) — never replace it with a random card
    // image, otherwise the "Favorites" tile picks whatever the first liked
    // card happens to be.
    if (widget.pack.id.startsWith('_')) return null;
    // Prefer the first card with a real webp illustration — a readable preview
    // for a non-reader. Falls back to the pack emoji when nothing fits.
    for (final c in widget.pack.cards) {
      if (c.image != null) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final total = pack.cards.length;
    final hasProgress = widget.progress > 0 && !widget.isCompleted;
    final thumb = _thumb();
    final accent = pack.color;

    Widget tile = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: _triggerWobble,
      child: AnimatedScale(
        scale: _pressed ? DT.pressScale : 1.0,
        duration: DT.pressMs,
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: DT.surfaceWhite,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(
              color: accent.withValues(alpha: 0.28),
              width: 2,
            ),
            boxShadow: DT.shadowSoft(accent),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DT.rLg - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Illustration area — takes most of the tile so the webp
                // actually reads at a glance. No inner padding: let the image
                // hug the corners of the tinted pane.
                Expanded(
                  flex: 5,
                  child: Container(
                    color: accent.withValues(alpha: 0.10),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: pack.cover != null
                              ? Image.asset(
                                  'assets/images/webp/${pack.cover}.webp',
                                  fit: BoxFit.contain,
                                )
                              : thumb?.image != null
                                  ? Image.asset(
                                      'assets/images/webp/${thumb!.image}.webp',
                                      fit: BoxFit.contain,
                                    )
                                  : Center(
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text(
                                          pack.icon,
                                          style:
                                              const TextStyle(fontSize: 52),
                                        ),
                                      ),
                                    ),
                        ),
                        // Status badge (top-right)
                        if (widget.isCompleted ||
                            pack.isLocked ||
                            widget.isSeasonal)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: _StatusBadge(
                              completed: widget.isCompleted,
                              locked: pack.isLocked,
                              seasonal: widget.isSeasonal,
                              accent: accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Title strip — compact, anchored at bottom so the image
                // dominates the tile.
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pack.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          height: 1.1,
                        ),
                      ),
                      if (hasProgress) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value:
                                total > 0 ? widget.progress / total : 0,
                            minHeight: 3,
                            backgroundColor: accent.withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Long-press wobble: spring-style rotation around tile center.
    Widget wrapped = AnimatedBuilder(
      animation: _wobbleRotation,
      builder: (_, child) => Transform.rotate(
        angle: _wobbleRotation.value,
        alignment: Alignment.center,
        child: child,
      ),
      child: tile,
    );

    // Seasonal shimmer — ambient glow around the tile
    if (!widget.isSeasonal) return wrapped;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DT.rLg + 4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25 + _shimmer.value * 0.35),
              blurRadius: 14 + _shimmer.value * 10,
              spreadRadius: _shimmer.value * 2,
            ),
          ],
        ),
        child: child,
      ),
      child: wrapped,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool completed;
  final bool locked;
  final bool seasonal;
  final Color accent;

  const _StatusBadge({
    required this.completed,
    required this.locked,
    required this.seasonal,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    Color bg;
    if (completed) {
      child = const Icon(
        Icons.check_rounded,
        size: 18,
        color: Colors.white,
      );
      bg = const Color(0xFF22C55E); // clean kid-friendly green
    } else if (locked) {
      child = Icon(Icons.lock_rounded, size: 15, color: accent);
      bg = DT.surfaceWhite;
    } else {
      child = const Text('✨', style: TextStyle(fontSize: 14));
      bg = DT.sunBurst;
    }
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: completed
            ? Border.all(color: Colors.white, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
