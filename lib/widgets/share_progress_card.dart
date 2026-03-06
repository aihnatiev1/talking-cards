import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/constants.dart';
import '../utils/uk_grammar.dart';

/// Builds the share widget on-demand, captures it, and shares as image.
/// No need for a persistent RepaintBoundary in the tree.
Future<void> shareProgress({
  required BuildContext context,
  required int completedPacks,
  required int totalPacks,
  required int seenCards,
  required int totalCards,
  required int streak,
  required Set<String> badges,
}) async {
  // Create an offscreen render pipeline
  final widget = ShareProgressContent(
    completedPacks: completedPacks,
    totalPacks: totalPacks,
    seenCards: seenCards,
    totalCards: totalCards,
    streak: streak,
    badges: badges,
  );

  // Use a RenderRepaintBoundary to capture without needing it in the tree
  final repaintBoundary = RenderRepaintBoundary();
  final view = View.of(context);
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(child: repaintBoundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(const Size(340, 250)),
      devicePixelRatio: view.devicePixelRatio,
    ),
  );

  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();

  final buildOwner = BuildOwner(focusManager: FocusManager());
  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaintBoundary,
    child: MediaQuery(
      data: MediaQueryData(devicePixelRatio: view.devicePixelRatio),
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

  try {
    final image = await repaintBoundary.toImage(pixelRatio: 3.0);
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
