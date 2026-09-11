import 'dart:io';

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
        service.cardArt('free'),
        const ArtReady(AssetImage('assets/images/webp/free.webp')),
      );
      expect(
        service.cardArt('paid'),
        const ArtReady(AssetImage('assets/pad_content/images/webp/paid.webp')),
      );
      expect(
        service.cardVoice('paid'),
        const VoiceReady(
          isFile: false,
          path: 'assets/pad_content/audio_mp3/paid.mp3',
        ),
      );
      expect(
        service.cardVoice('free'),
        const VoiceReady(isFile: false, path: 'assets/audio_mp3/free.mp3'),
      );
    });

    test('nothing needs a download and the state is bundled', () {
      expect(service.needsDownload('paid'), isFalse);
      expect(service.contentReady, isTrue);
      expect(service.state.value.isReady, isTrue);
    });

    test('a card with no image is Missing, not a "null.webp" lookup', () {
      // The old contract built AssetImage('assets/images/webp/null.webp')
      // — a provider manufactured to fail — and left every call site to
      // catch it. There is nothing to catch now.
      expect(service.cardArt(null), ArtMissing.noName);
    });

    test('cacheWidth wraps in the same ResizeImage key Image.asset used', () {
      final art = service.cardArt('free', cacheWidth: 400) as ArtReady;
      expect(art.provider, isA<ResizeImage>());
      final resized = art.provider as ResizeImage;
      expect(resized.width, 400);
      expect(resized.imageProvider,
          const AssetImage('assets/images/webp/free.webp'));
    });
  });

  group('resolution table', () {
    const all = {
      'assets/images/webp/free.webp',
      'assets/pad_content/marker.txt',
      'assets/pad_content/images/webp/paid.webp',
      'assets/pad_content/audio_mp3/paid.mp3',
    };

    test('bundled build: paid and free alike are ready from the bundle', () {
      service.debugConfigure(padAssets: pad, bundled: true, allAssets: all);
      expect(
        service.cardArt('free'),
        const ArtReady(AssetImage('assets/images/webp/free.webp')),
      );
      expect(
        service.cardArt('paid'),
        const ArtReady(AssetImage('assets/pad_content/images/webp/paid.webp')),
      );
    });

    test('pack on disk: paid is ready as a file, free stays a bundle asset',
        () {
      service.debugConfigure(
        padAssets: pad,
        bundled: false,
        packPath: '/data/pack',
        allAssets: all,
      );
      expect(
        service.cardArt('paid'),
        ArtReady(FileImage(File('/data/pack/images/webp/paid.webp'))),
      );
      expect(
        service.cardArt('free'),
        const ArtReady(AssetImage('assets/images/webp/free.webp')),
      );
    });

    test('pack not on disk: paid is pending, free is unaffected', () {
      service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);
      expect(service.cardArt('paid'), isA<ArtPending>());
      expect(
        service.cardArt('free'),
        const ArtReady(AssetImage('assets/images/webp/free.webp')),
      );
    });

    test('an asset no build has is Missing, not a runtime throw', () {
      // A typo in the card JSON, or a bad tools/pad_split.py run. Before
      // the manifest check this only surfaced as a failed decode.
      service.debugConfigure(padAssets: pad, bundled: true, allAssets: all);
      expect(service.cardArt('kartoplya'), ArtMissing.notInBuild);
    });

    test('a card with no image is Missing without touching the bundle', () {
      service.debugConfigure(padAssets: pad, bundled: true, allAssets: all);
      expect(service.cardArt(null), ArtMissing.noName);
    });

    test('an unreadable manifest stays permissive rather than blanking all',
        () {
      // allAssets: null is "cannot prove absence" — the resolver must not
      // decide the whole catalogue is missing because a manifest read failed.
      service.debugConfigure(padAssets: pad, bundled: true);
      expect(service.cardArt('anything'), isA<ArtReady>());
    });

    test('cacheWidth still wraps in the ResizeImage key precache shares', () {
      service.debugConfigure(padAssets: pad, bundled: true, allAssets: all);
      final art = service.cardArt('free', cacheWidth: 400) as ArtReady;
      expect(art.provider, isA<ResizeImage>());
      expect((art.provider as ResizeImage).width, 400);
    });

    test('bytes: a pending pack yields a value, never a throw', () async {
      service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);
      final bytes = await service.cardBytes('paid');
      expect(bytes, isA<BytesUnavailable>());
      expect((bytes as BytesUnavailable).reason, isA<ArtPending>());
    });

    test('bytes: a pack evicted after the check yields a value too', () async {
      // packPath points somewhere real-looking with nothing in it — the
      // TOCTOU window between Play saying "downloaded" and the read.
      service.debugConfigure(
        padAssets: pad,
        bundled: false,
        packPath: '/nonexistent/pack',
        allAssets: all,
      );
      final bytes = await service.cardBytes('paid');
      expect(bytes, isA<BytesUnavailable>());
    });

    test('voice mirrors art: ready, pending, missing', () {
      service.debugConfigure(
        padAssets: pad,
        bundled: false,
        packPath: '/data/pack',
        allAssets: all,
      );
      expect(
        service.cardVoice('paid'),
        const VoiceReady(isFile: true, path: '/data/pack/audio_mp3/paid.mp3'),
      );

      service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);
      expect(service.cardVoice('paid'), isA<VoicePending>());
      expect(service.cardVoice('nothing_like_this'), VoiceMissing.notInBuild);
    });

    test('the pack landing mid-session flips pending to ready', () {
      service.debugConfigure(padAssets: pad, bundled: false, allAssets: all);
      expect(service.cardArt('paid'), isA<ArtPending>());

      service.debugConfigure(
        padAssets: pad,
        bundled: false,
        packPath: '/data/pack',
        allAssets: all,
      );
      expect(service.cardArt('paid'), isA<ArtReady>());
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
      final paid = service.cardArt('paid') as ArtReady;
      expect(paid.provider, isA<FileImage>());
      expect((paid.provider as FileImage).file.path,
          '/data/pack/images/webp/paid.webp');
      expect(
        service.cardArt('free'),
        const ArtReady(AssetImage('assets/images/webp/free.webp')),
      );
      expect(
        service.cardVoice('paid'),
        const VoiceReady(isFile: true, path: '/data/pack/audio_mp3/paid.mp3'),
      );
      expect(
        service.cardVoice('free'),
        const VoiceReady(isFile: false, path: 'assets/audio_mp3/free.mp3'),
      );
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

    test('a paid card resolves to ArtPending, not a doomed provider', () {
      // This assertion used to be the opposite, and it was wrong: handing
      // back AssetImage('assets/pad_content/…') for content that is not on
      // the device is exactly what produced the fatal crashes of
      // 2026-09-08. The provider cannot load, and the service knows it.
      expect(service.cardArt('paid'), ArtPending(service.state.value));
    });

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
      final art = service.cardArt('paid') as ArtReady;
      expect(
        (art.provider as FileImage).file.path,
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
