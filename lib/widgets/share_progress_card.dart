import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/constants.dart';
import '../utils/uk_grammar.dart';

const _appStoreUrl = 'https://apps.apple.com/app/id6760210043';
const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.talkingcards.app';
const _storeUrl = '$_appStoreUrl\n$_playStoreUrl';

/// Captures the share card as image and shares it.
Future<void> shareProgress({
  required BuildContext context,
  required int completedPacks,
  required int totalPacks,
  required int seenCards,
  required int totalCards,
  required int streak,
  required Set<String> badges,
  bool isEn = false,
}) async {
  // Get position for iPad popover
  Rect? sharePositionOrigin;
  try {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      sharePositionOrigin = ro.localToGlobal(Offset.zero) & ro.size;
    }
  } catch (_) {}

  try {
    // Build the widget off-screen using a pipeline render
    final widget = ShareProgressContent(
      completedPacks: completedPacks,
      totalPacks: totalPacks,
      seenCards: seenCards,
      totalCards: totalCards,
      streak: streak,
      badges: badges,
    );

    final image = await _renderWidgetToImage(widget, 340, context);
    if (image == null) {
      // Fallback: text-only share
      await Share.share(
        isEn
          ? 'My child is learning words with Talking Cards! 🗣️\n'
            '⭐ Packs: $completedPacks/$totalPacks\n'
            '🃏 Cards: $seenCards/$totalCards'
            '${streak > 0 ? '\n🔥 Streak: $streak days' : ''}'
            '\n\nDownload free:\n$_storeUrl'
          : 'Мій малюк вивчає слова з Картками-розмовлялками! 🗣️\n'
            '⭐ Розділів: $completedPacks/$totalPacks\n'
            '🃏 Карток: $seenCards/$totalCards'
            '${streak > 0 ? '\n🔥 Серія: $streak ${dayWord(streak)}' : ''}'
            '\n\nСкачай безкоштовно:\n$_storeUrl',
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/progress.png');
    await file.writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: isEn
          ? 'My child is learning words with Talking Cards! 🗣️\nDownload free: $_storeUrl'
          : 'Мій малюк вивчає слова з Картками-розмовлялками! 🗣️\nСкачай безкоштовно: $_storeUrl',
      sharePositionOrigin: sharePositionOrigin,
    );
  } catch (e, st) {
    debugPrint('Share error: $e\n$st');
    // Last resort: text share
    try {
      await Share.share(
        'Мій малюк вивчає слова з Картками-розмовлялками! 🗣️\n'
        'Скачай безкоштовно: $_storeUrl',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (_) {}
  }
}

/// Renders a widget to a PNG image bytes using an offscreen pipeline.
Future<List<int>?> _renderWidgetToImage(
  Widget widget,
  double width,
  BuildContext context,
) async {
  try {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Create a render pipeline
    final repaintBoundary = RenderRepaintBoundary();
    final view = View.of(context);
    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints(maxWidth: width, maxHeight: 600),
        devicePixelRatio: pixelRatio,
      ),
    );

    final pipelineOwner = PipelineOwner();
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter(
      container: repaintBoundary,
      child: MediaQuery(
        data: MediaQuery.of(context),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    // Clean up
    buildOwner.finalizeTree();

    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  } catch (e) {
    debugPrint('_renderWidgetToImage error: $e');
    return null;
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
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.white.withValues(alpha: 0.2),
              child: const Text(
                '📲 Скачай безкоштовно в App Store',
                textAlign: TextAlign.center,
                style: TextStyle(
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
