import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pack_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final total = pack.cards.length;
    final hasProgress = widget.progress > 0 && !widget.isCompleted;
    final sw = MediaQuery.of(context).size.width;
    final scale = (sw / 375).clamp(0.85, 1.3);

    Widget card = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: pack.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pack.color.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pack.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                pack.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: pack.color,
                  height: 1.2,
                ),
              ),
            ),
            if (hasProgress) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: widget.progress / total,
                    minHeight: 4,
                    backgroundColor: pack.color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(pack.color),
                  ),
                ),
              ),
            ],
            if (widget.isCompleted || pack.isLocked || widget.isSeasonal) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isCompleted) const Text('⭐', style: TextStyle(fontSize: 12)),
                  if (pack.isLocked)
                    Icon(Icons.lock_rounded,
                        color: pack.color.withValues(alpha: 0.5), size: 13),
                  if (widget.isSeasonal) const Text('✨', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    // Shimmer glow border for seasonal packs
    if (!widget.isSeasonal) return card;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: [
            BoxShadow(
              color: pack.color
                  .withValues(alpha: 0.3 + _shimmer.value * 0.35),
              blurRadius: 10 + _shimmer.value * 8,
              spreadRadius: _shimmer.value * 2,
            ),
          ],
        ),
        child: child,
      ),
      child: card,
    );
  }
}
