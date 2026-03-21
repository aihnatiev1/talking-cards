import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/constants.dart';
import '../utils/uk_grammar.dart';

/// Captures the share card as image and shares it.
Future<void> shareProgress({
  required BuildContext context,
  required int completedPacks,
  required int totalPacks,
  required int seenCards,
  required int totalCards,
  required int streak,
  required Set<String> badges,
}) async {
  final key = GlobalKey();

  final overlay = OverlayEntry(
    builder: (_) => Positioned(
      left: -1000,
      top: -1000,
      child: RepaintBoundary(
        key: key,
        child: ShareProgressContent(
          completedPacks: completedPacks,
          totalPacks: totalPacks,
          seenCards: seenCards,
          totalCards: totalCards,
          streak: streak,
          badges: badges,
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlay);

  // Wait for layout
  await Future.delayed(const Duration(milliseconds: 100));

  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/progress.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Мій прогрес у Картках-розмовлялках! 🗣️',
    );
  } catch (e) {
    debugPrint('Share error: $e');
  } finally {
    overlay.remove();
  }
}

/// The visual card that gets captured for sharing
class ShareProgressContent extends StatelessWidget {
  final int completedPacks;
  final int totalPacks;
  final int seenCards;
  final int totalCards;
  final int streak;
  final Set<String> badges;

  const ShareProgressContent({
    super.key,
    required this.completedPacks,
    required this.totalPacks,
    required this.seenCards,
    required this.totalCards,
    required this.streak,
    required this.badges,
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
          const Text(
            '🗣️ Картки-розмовлялки',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniStat('⭐', '$completedPacks/$totalPacks', 'розділів'),
              _miniStat('🃏', '$seenCards/$totalCards', 'карток'),
              if (streak > 0) _miniStat('🔥', '$streak', dayWord(streak)),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              badges.join(' '),
              style: const TextStyle(fontSize: 32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
