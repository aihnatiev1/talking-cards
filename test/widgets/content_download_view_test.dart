import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/asset_pack_service.dart';
import 'package:talking_cards/widgets/content_download_view.dart';

/// The waiting screen for a paid pack whose content is still arriving from
/// Play. It has to say what is happening in the parent's language and offer
/// the one action that unblocks each stalled state.
void main() {
  Widget host(ContentPackState state, {bool isEn = false}) => MaterialApp(
    home: Scaffold(
      body: ContentDownloadView(state: state, accent: Colors.blue, isEn: isEn),
    ),
  );

  testWidgets('downloading shows the percentage and no button', (tester) async {
    await tester.pumpWidget(
      host(
        const ContentPackState(
          ContentPackStatus.downloading,
          bytesDownloaded: 45,
          totalBytes: 100,
        ),
      ),
    );
    expect(find.text('Завантажуємо картки… 45%'), findsOneWidget);
    expect(find.byKey(const ValueKey('content-action')), findsNothing);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('content-progress')),
    );
    expect(bar.value, 0.45);
  });

  testWidgets('pending without a size is indeterminate', (tester) async {
    await tester.pumpWidget(
      host(const ContentPackState(ContentPackStatus.pending), isEn: true),
    );
    expect(find.text('Downloading cards…'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('content-progress')),
    );
    expect(bar.value, isNull);
  });

  testWidgets('waiting for Wi-Fi offers mobile data, 72dp tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const ContentPackState(ContentPackStatus.waitingForWifi)),
    );
    expect(find.text('Чекаємо Wi-Fi, щоб завантажити картки'), findsOneWidget);
    expect(find.text('Завантажити через мобільний'), findsOneWidget);
    final size = tester.getSize(find.byKey(const ValueKey('content-action')));
    expect(size.height, greaterThanOrEqualTo(72));
  });

  testWidgets('failure offers a retry', (tester) async {
    await tester.pumpWidget(
      host(const ContentPackState(ContentPackStatus.failed), isEn: true),
    );
    expect(find.text('Could not download the cards'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
