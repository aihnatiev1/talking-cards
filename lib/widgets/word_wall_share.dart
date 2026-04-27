import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/card_model.dart';
import '../utils/constants.dart';
import 'share_progress_card.dart' show renderWidgetToImage;

const _storeUrl = 'https://aihnatiev1.github.io/talking-cards/';

/// Captures the Word Wall card as image and shares it.
/// [learnedCards] is sorted with the most recently-learned first; up to 12 are
/// embedded in the share image.
Future<void> shareWordWall({
  required BuildContext context,
  required String childName,
  required List<CardModel> learnedCards,
  required bool isEn,
}) async {
  Rect? sharePositionOrigin;
  try {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      sharePositionOrigin = ro.localToGlobal(Offset.zero) & ro.size;
    }
  } catch (_) {}

  final count = learnedCards.length;
  final preview = learnedCards.take(12).toList();
  final fallbackText = isEn
      ? '$childName has learned $count words with Talking Cards! 🗣️\nDownload free: $_storeUrl'
      : '$childName вже вивчає слова з Картками-розмовлялками! 🗣️\nВивчено: $count\nСкачай безкоштовно: $_storeUrl';

  try {
    final widget = WordWallShareContent(
      childName: childName,
      learnedCount: count,
      previewCards: preview,
      isEn: isEn,
    );

    final image = await renderWidgetToImage(widget, 340, context);
    if (image == null) {
      await Share.share(fallbackText, sharePositionOrigin: sharePositionOrigin);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/word_wall.png');
    await file.writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: fallbackText,
      sharePositionOrigin: sharePositionOrigin,
    );
  } catch (e, st) {
    debugPrint('shareWordWall error: $e\n$st');
    try {
      await Share.share(fallbackText, sharePositionOrigin: sharePositionOrigin);
    } catch (_) {}
  }
}

/// Visual card captured for sharing — Lingokids/Endless-style word collection
/// flex for the parent's social feed.
class WordWallShareContent extends StatelessWidget {
  final String childName;
  final int learnedCount;
  final List<CardModel> previewCards;
  final bool isEn;

  const WordWallShareContent({
    super.key,
    required this.childName,
    required this.learnedCount,
    required this.previewCards,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccent, kTeal],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEn ? "$childName's Word Wall" : 'Слова, які знає $childName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$learnedCount',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEn
                ? (learnedCount == 1 ? 'word learned' : 'words learned')
                : 'вивчених слів',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (previewCards.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: previewCards
                  .map((c) => _PreviewTile(card: c))
                  .toList(),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.white.withValues(alpha: 0.2),
              child: Text(
                isEn
                    ? '📲 Download free\nApp Store · Google Play'
                    : '📲 Скачай безкоштовно\nApp Store та Google Play',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final CardModel card;

  const _PreviewTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: card.image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/webp/${card.image}.webp',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Text(card.emoji, style: const TextStyle(fontSize: 28)),
                ),
              )
            : Text(card.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}
