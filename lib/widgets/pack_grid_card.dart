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
    final sw = MediaQuery.of(context).size.width;
    final scale = (sw / 375).clamp(0.85, 1.3);

    return GestureDetector(
      onTap: onTap,
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
                  value: hasProgress ? progress / total : 0,
                  minHeight: 6 * scale,
                  backgroundColor: pack.color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(pack.color),
                ),
              ),
            ),
            SizedBox(height: 3 * scale),
            Text(
              hasProgress ? '$progress/$total' : '$total карток',
              style: TextStyle(
                fontSize: 11 * scale,
                color: pack.color.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 2 * scale),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted)
                  Text('⭐', style: TextStyle(fontSize: 13 * scale)),
                if (pack.isLocked)
                  Icon(Icons.lock_rounded,
                      color: pack.color.withValues(alpha: 0.5), size: 15 * scale),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
