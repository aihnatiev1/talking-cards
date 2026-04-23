import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isSeasonal) _shimmer.repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  CardModel? _thumb() {
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
                // Illustration area
                Expanded(
                  flex: 3,
                  child: Container(
                    color: accent.withValues(alpha: 0.10),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: thumb?.image != null
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Image.asset(
                                    'assets/images/webp/${thumb!.image}.webp',
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    pack.icon,
                                    style: const TextStyle(fontSize: 44),
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
                // Title strip — adaptive text so it fits narrow 3-col tiles
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
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
                        ),
                        if (hasProgress) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: total > 0
                                  ? widget.progress / total
                                  : 0,
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
    );

    // Seasonal shimmer — ambient glow around the tile
    if (!widget.isSeasonal) return tile;
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
      child: tile,
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
      child = const Text('⭐', style: TextStyle(fontSize: 14));
      bg = DT.sunBurst;
    } else if (locked) {
      child = Icon(Icons.lock_rounded, size: 15, color: accent);
      bg = DT.surfaceWhite;
    } else {
      child = const Text('✨', style: TextStyle(fontSize: 14));
      bg = DT.sunBurst;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
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
