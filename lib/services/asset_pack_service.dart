import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where the paid-pack illustrations and voice clips are right now.
enum ContentPackStatus {
  /// pad_content is inside this build (iOS, debug, plain APK) — nothing to
  /// download, every asset resolves through the Flutter bundle.
  bundled,

  /// The Play asset pack is on disk and every card resolves to a file.
  ready,

  /// Play has not started the download yet (fast-follow queues it right
  /// after install; a fetch() was also requested).
  pending,
  downloading,

  /// Play is holding the download for Wi-Fi; a tap on a paid pack asks the
  /// user to allow cellular.
  waitingForWifi,
  failed,
}

@immutable
class ContentPackState {
  final ContentPackStatus status;
  final int bytesDownloaded;
  final int totalBytes;

  const ContentPackState(
    this.status, {
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
  });

  static const bundled = ContentPackState(ContentPackStatus.bundled);
  static const ready = ContentPackState(ContentPackStatus.ready);

  bool get isReady =>
      status == ContentPackStatus.bundled || status == ContentPackStatus.ready;

  /// 0..1 while downloading, null when the size is not known yet.
  double? get progress =>
      totalBytes > 0 ? (bytesDownloaded / totalBytes).clamp(0.0, 1.0) : null;

  @override
  bool operator ==(Object other) =>
      other is ContentPackState &&
      other.status == status &&
      other.bytesDownloaded == bytesDownloaded &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(status, bytesDownloaded, totalBytes);
}

/// Resolves card illustrations and voice clips to wherever they live.
///
/// The Android app bundle ships only what a first session can touch (free
/// packs, previews, covers, praise) in the base module; the rest of the
/// catalogue — ~90 MB of paid-pack webp/mp3 — travels as the `content_pack`
/// Play asset pack (fast-follow: Play downloads it right after install, in
/// the background). tools/pad_split.py decides which file goes where and
/// moves paid content under assets/pad_content/, so the *asset path* of an
/// illustration already says which module it belongs to.
///
/// Every UI site asks this service instead of hard-coding
/// `assets/images/webp/…`: it returns an [AssetImage] for bundled content
/// and a [FileImage] into the asset pack otherwise. On iOS and in debug
/// builds pad_content is still in the bundle, so the service is a plain
/// path lookup there and nothing is ever downloaded.
class AssetPackService {
  AssetPackService._();
  static final AssetPackService instance = AssetPackService._();

  static const packName = 'content_pack';
  static const _channel = MethodChannel('com.talkingcards.app/asset_packs');
  static const _padPrefix = 'assets/pad_content/';
  static const _markerAsset = '${_padPrefix}marker.txt';

  final ValueNotifier<ContentPackState> state = ValueNotifier(
    ContentPackState.bundled,
  );

  /// Asset paths (as declared in pubspec) that live under pad_content.
  Set<String> _padAssets = const {};
  bool _bundled = true;
  String? _packPath;
  bool _initialized = false;

  /// True when every card can be drawn and spoken right now.
  bool get contentReady => _bundled || _packPath != null;

  /// Splash calls this once; safe to call again (no-op).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _padAssets = manifest
          .listAssets()
          .where((p) => p.startsWith(_padPrefix))
          .toSet();
    } catch (e) {
      if (kDebugMode) debugPrint('AssetPackService: manifest failed: $e');
    }
    if (_padAssets.isEmpty) return; // nothing was ever split off

    // The marker travels with pad_content: loadable → the content is in this
    // build's bundle (iOS, debug, APK) and Play is not involved.
    try {
      await rootBundle.load(_markerAsset);
      _bundled = true;
      return;
    } catch (_) {
      _bundled = false;
    }
    if (!Platform.isAndroid) {
      // Cannot happen on a well-formed build; degrade to bundle paths so
      // errorBuilders show emoji rather than the app blocking on a download.
      _bundled = true;
      return;
    }

    _channel.setMethodCallHandler(_onNativeCall);
    try {
      // Splash gives every init a few seconds; Play's answer is normally
      // instant, and a slow one must not eat that budget.
      final path = await _channel
          .invokeMethod<String?>('location', {'pack': packName})
          .timeout(const Duration(seconds: 2));
      if (path != null) {
        _packPath = path;
        state.value = ContentPackState.ready;
        return;
      }
      state.value = const ContentPackState(ContentPackStatus.pending);
      // fetch() resolves only once Play has accepted the request, which the
      // local-testing fake takes seconds to do — never awaited on startup.
      unawaited(fetch());
    } on MissingPluginException {
      state.value = const ContentPackState(ContentPackStatus.failed);
    } catch (e) {
      if (kDebugMode) debugPrint('AssetPackService: init failed: $e');
      state.value = const ContentPackState(ContentPackStatus.failed);
    }
  }

  /// Asks Play to (re)start the download. Idempotent on the Play side.
  Future<void> fetch() async {
    if (contentReady || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('fetch', {'pack': packName});
      if (state.value.status == ContentPackStatus.failed) {
        state.value = const ContentPackState(ContentPackStatus.pending);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AssetPackService: fetch failed: $e');
    }
  }

  /// Shows Play's own "download over cellular?" dialog when the pack is
  /// waiting for Wi-Fi. Returns without effect otherwise.
  Future<void> confirmCellular() async {
    if (state.value.status != ContentPackStatus.waitingForWifi) return;
    try {
      await _channel.invokeMethod('confirm', {'pack': packName});
    } catch (_) {}
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method != 'state') return null;
    final map = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
    final status = map['status'] as String?;
    final downloaded = (map['bytesDownloaded'] as num?)?.toInt() ?? 0;
    final total = (map['totalBytes'] as num?)?.toInt() ?? 0;
    switch (status) {
      case 'completed':
        final path = map['path'] as String?;
        if (path != null) {
          _packPath = path;
          state.value = ContentPackState.ready;
        }
      case 'downloading':
      case 'transferring':
        state.value = ContentPackState(
          ContentPackStatus.downloading,
          bytesDownloaded: downloaded,
          totalBytes: total,
        );
      case 'pending':
      case 'not_installed':
      case 'unknown':
        state.value = ContentPackState(
          ContentPackStatus.pending,
          bytesDownloaded: downloaded,
          totalBytes: total,
        );
      case 'waiting_for_wifi':
      case 'requires_user_confirmation':
        state.value = ContentPackState(
          ContentPackStatus.waitingForWifi,
          bytesDownloaded: downloaded,
          totalBytes: total,
        );
      case 'failed':
      case 'canceled':
        state.value = const ContentPackState(ContentPackStatus.failed);
    }
    return null;
  }

  // ─── Resolution ────────────────────────────────────────────────────────

  String _imageAsset(String name) {
    final pad = '${_padPrefix}images/webp/$name.webp';
    return _padAssets.contains(pad) ? pad : 'assets/images/webp/$name.webp';
  }

  String _audioAsset(String file) {
    final pad = '${_padPrefix}audio_mp3/$file.mp3';
    return _padAssets.contains(pad) ? pad : 'assets/audio_mp3/$file.mp3';
  }

  /// True when [name] (webp asset name, no extension) has to come from the
  /// asset pack on this build — i.e. it is paid content and not bundled.
  bool needsDownload(String? name) =>
      name != null &&
      !contentReady &&
      _padAssets.contains('${_padPrefix}images/webp/$name.webp');

  /// The file inside the asset pack for a pad_content asset path, or null
  /// when the pack is not on disk (or the asset is bundled).
  String? _packFile(String assetPath) {
    final root = _packPath;
    if (_bundled || root == null || !assetPath.startsWith(_padPrefix)) {
      return null;
    }
    return '$root/${assetPath.substring(_padPrefix.length)}';
  }

  /// Provider for a card illustration. [cacheWidth]/[cacheHeight] behave
  /// like Image.asset's — the same ResizeImage key, so precache and display
  /// share one decode. A null [name] resolves to a missing asset, exactly as
  /// the old `'…/${card.image}.webp'` interpolation did, so call sites keep
  /// relying on their errorBuilder/emoji fallback.
  ImageProvider cardImage(String? name, {int? cacheWidth, int? cacheHeight}) {
    final asset = _imageAsset(name ?? 'null');
    final file = _packFile(asset);
    final ImageProvider base = file != null
        ? FileImage(File(file))
        : AssetImage(asset);
    return ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, base);
  }

  /// Raw bytes of a card illustration (the colouring book decodes its own).
  Future<ByteData> cardImageBytes(String? name) async {
    final asset = _imageAsset(name ?? 'null');
    final file = _packFile(asset);
    if (file != null) {
      final bytes = await File(file).readAsBytes();
      return ByteData.sublistView(bytes);
    }
    return rootBundle.load(asset);
  }

  /// Where AudioService should load [file] (mp3 name, no extension) from:
  /// a filesystem path inside the asset pack, or a bundle asset path.
  ({bool isFile, String path}) audioSource(String file) {
    final asset = _audioAsset(file);
    final packFile = _packFile(asset);
    if (packFile != null) return (isFile: true, path: packFile);
    return (isFile: false, path: asset);
  }

  /// Test seam: install the native→Dart handler init() would on Android.
  @visibleForTesting
  Future<void> debugInstallHandler() async =>
      _channel.setMethodCallHandler(_onNativeCall);

  /// Test seam: pretend the manifest/marker/native side said this.
  @visibleForTesting
  void debugConfigure({
    required Set<String> padAssets,
    required bool bundled,
    String? packPath,
    ContentPackState? state,
  }) {
    _initialized = true;
    _padAssets = padAssets;
    _bundled = bundled;
    _packPath = packPath;
    this.state.value =
        state ??
        (bundled
            ? ContentPackState.bundled
            : packPath != null
            ? ContentPackState.ready
            : const ContentPackState(ContentPackStatus.pending));
  }
}
