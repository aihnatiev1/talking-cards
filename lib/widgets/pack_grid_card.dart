import 'package:flutter/material.dart';

import '../models/pack_model.dart';

class PackGridCard extends StatelessWidget {
  final PackModel pack;
  final VoidCallback onTap;
  final bool isCompleted;
  final int progress;

  const PackGridCard({
    super.key,
    required this.pack,
    required this.onTap,
    this.isCompleted = false,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final total = pack.cards.length;
    final hasProgress = progress > 0 && !isCompleted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: pack.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: pack.color.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'pack_icon_${pack.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(pack.icon, style: const TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pack.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: pack.color,
              ),
            ),
            const SizedBox(height: 4),
            if (hasProgress) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress / total,
                    minHeight: 4,
                    backgroundColor: pack.color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(pack.color),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$progress/$total',
                style: TextStyle(
                  fontSize: 12,
                  color: pack.color.withValues(alpha: 0.7),
                ),
              ),
            ] else
              Text(
                '$total карток',
                style: TextStyle(
                  fontSize: 12,
                  color: pack.color.withValues(alpha: 0.7),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted)
                  const Text('⭐', style: TextStyle(fontSize: 14)),
                if (pack.isLocked)
                  Icon(Icons.lock_rounded,
                      color: pack.color.withValues(alpha: 0.5), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
