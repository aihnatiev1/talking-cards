import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pack_model.dart';
import '../providers/language_provider.dart';

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
    final isEn = ref.watch(languageProvider) == 'en';
    final cardsLabel = isEn ? 'cards' : 'карток';

    Widget card = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: pack.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20 * scale),
          border: Border.all(
            color: pack.color.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 8 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'pack_icon_${pack.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(pack.icon, style: TextStyle(fontSize: 40 * scale)),
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              pack.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
                color: pack.color,
              ),
            ),
            SizedBox(height: 4 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: hasProgress ? widget.progress / total : 0,
                  minHeight: 6 * scale,
                  backgroundColor: pack.color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(pack.color),
                ),
              ),
            ),
            SizedBox(height: 3 * scale),
            Text(
              hasProgress ? '${widget.progress}/$total' : '$total $cardsLabel',
              style: TextStyle(
                fontSize: 11 * scale,
                color: pack.color.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 2 * scale),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isCompleted)
                  Text('⭐', style: TextStyle(fontSize: 13 * scale)),
                if (pack.isLocked)
                  Icon(Icons.lock_rounded,
                      color: pack.color.withValues(alpha: 0.5), size: 15 * scale),
                if (widget.isSeasonal)
                  Text('✨', style: TextStyle(fontSize: 13 * scale)),
              ],
            ),
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
