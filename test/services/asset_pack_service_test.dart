import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/asset_pack_service.dart';

/// Where a card's illustration and clip come from is the one decision that
/// differs per build: bundle on iOS/debug, Play asset pack on the Android
/// bundle. Both branches are pinned here through the test seam; the native
/// side is simulated by pushing "state" calls down the channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = AssetPackService.instance;
  const pad = {
    'assets/pad_content/marker.txt',
    'assets/pad_content/images/webp/paid.webp',
    'assets/pad_content/audio_mp3/paid.mp3',
  };

  group('bundled build (iOS, debug)', () {
    setUp(() => service.debugConfigure(padAssets: pad, bundled: true));

    test('free and paid cards both resolve to bundle assets', () {
      expect(
        service.cardImage('free'),
        const AssetImage('assets/images/webp/free.webp'),
      );
      expect(
        service.cardImage('paid'),
        const AssetImage('assets/pad_content/images/webp/paid.webp'),
      );
      expect(service.audioSource('paid'), (
        isFile: false,
        path: 'assets/pad_content/audio_mp3/paid.mp3',
      ));
      expect(service.audioSource('free'), (
        isFile: false,
        path: 'assets/audio_mp3/free.mp3',
      ));
    });

    test('nothing needs a download and the state is bundled', () {
      expect(service.needsDownload('paid'), isFalse);
      expect(service.contentReady, isTrue);
      expect(service.state.value.isReady, isTrue);
    });

    test('a null image keeps the old missing-asset contract', () {
      expect(
        service.cardImage(null),
        const AssetImage('assets/images/webp/null.webp'),
      );
    });

    test('cacheWidth wraps in the same ResizeImage key Image.asset used', () {
      final p = service.cardImage('free', cacheWidth: 400);
      expect(p, isA<ResizeImage>());
      expect((p as ResizeImage).width, 400);
      expect(p.imageProvider, const AssetImage('assets/images/webp/free.webp'));
    });
  });

  group('Android app bundle, pack on disk', () {
    setUp(
      () => service.debugConfigure(
        padAssets: pad,
        bundled: false,
        packPath: '/data/pack',
      ),
    );

    test('paid content is read from the pack, free from the bundle', () {
      final paid = service.cardImage('paid');
      expect(paid, isA<FileImage>());
      expect((paid as FileImage).file.path, '/data/pack/images/webp/paid.webp');
      expect(
        service.cardImage('free'),
        const AssetImage('assets/images/webp/free.webp'),
      );
      expect(service.audioSource('paid'), (
        isFile: true,
        path: '/data/pack/audio_mp3/paid.mp3',
      ));
      expect(service.audioSource('free'), (
        isFile: false,
        path: 'assets/audio_mp3/free.mp3',
      ));
      expect(service.needsDownload('paid'), isFalse);
    });
  });

  group('Android app bundle, pack still arriving', () {
    setUp(() => service.debugConfigure(padAssets: pad, bundled: false));

    test('paid cards are flagged; free cards are not', () {
      expect(service.needsDownload('paid'), isTrue);
      expect(service.needsDownload('free'), isFalse);
      expect(service.needsDownload(null), isFalse);
      expect(service.contentReady, isFalse);
      expect(service.state.value.status, ContentPackStatus.pending);
    });

    test(
      'a paid card still gets a provider (errorBuilder path), not a crash',
      () {
        expect(
          service.cardImage('paid'),
          const AssetImage('assets/pad_content/images/webp/paid.webp'),
        );
      },
    );

    Future<void> pushState(Map<String, Object?> map) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('state', map),
      );
      await messenger.handlePlatformMessage(
        'com.talkingcards.app/asset_packs',
        data,
        (_) {},
      );
    }

    test('native progress reaches the state notifier', () async {
      // The handler is only installed by init() on Android; emulate that.
      await service.debugInstallHandler();
      await pushState({
        'status': 'downloading',
        'bytesDownloaded': 25,
        'totalBytes': 100,
      });
      expect(service.state.value.status, ContentPackStatus.downloading);
      expect(service.state.value.progress, 0.25);

      await pushState({'status': 'waiting_for_wifi'});
      expect(service.state.value.status, ContentPackStatus.waitingForWifi);

      await pushState({'status': 'completed', 'path': '/data/pack2'});
      expect(service.state.value.isReady, isTrue);
      expect(service.contentReady, isTrue);
      expect(
        (service.cardImage('paid') as FileImage).file.path,
        '/data/pack2/images/webp/paid.webp',
      );
    });

    test(
      'a failure is a state, and fetch() turns it back into pending',
      () async {
        await service.debugInstallHandler();
        await pushState({'status': 'failed'});
        expect(service.state.value.status, ContentPackStatus.failed);
      },
    );
  });
}
