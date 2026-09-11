import 'package:flutter/widgets.dart';

import '../models/card_model.dart';
import '../services/analytics_service.dart';
import '../services/asset_pack_service.dart';
import '../utils/image_cache_size.dart';

/// How large this illustration will be drawn, and therefore how wide it
/// may decode. A named size instead of a raw int because precache and
/// display have to agree on the [ResizeImage] key — disagree and the same
/// picture decodes twice, at ~2.2 MB a copy.
enum CardArtSize {
  /// Full-screen: the swiper card, the reveal.
  hero,

  /// Grid tile, quiz option, game thumbnail — about half the screen.
  tile,
}

/// The only widget in the app allowed to draw a card illustration.
///
/// Everything else asks for one through here, and gets a picture or a
/// placeholder — never a blank box, never a crash. Three things are
/// centralised because getting any of them wrong at a call site is
/// invisible until it reaches a child:
///
/// * **Absence is handled.** [AssetPackService.cardArt] answers with a
///   sealed [CardArt], and the `switch` below is exhaustive, so a new
///   state cannot be forgotten. Before this, 17 of 24 call sites built an
///   `Image` with no `errorBuilder` over content that may not be on the
///   device yet, and `main.dart` files those throws as fatal crashes.
/// * **The placeholder heals itself.** It listens to
///   [AssetPackService.state], so a tile drawn while the Play pack was
///   still downloading redraws as the real picture the moment it lands. A
///   plain `errorBuilder` stays blank until some unrelated rebuild comes
///   along.
/// * **The failure is measured, not crashed.** Non-fatal analytics, once
///   per asset per session.
///
/// The one legitimate non-user is the colouring book: it needs a
/// `ui.Image` for its painter, so it consumes [AssetPackService.cardBytes]
/// and switches on [CardBytes] itself.
class CardImage extends StatelessWidget {
  /// Asset name, no extension and no directory — as it appears in the card
  /// JSON. Null renders the emoji, which is the intended look for a card
  /// that simply has no illustration.
  final String? name;

  /// Drawn whenever there is no picture. Never empty: [CardModel.emoji] is
  /// non-nullable precisely so there is always something to show.
  final String fallbackEmoji;

  final CardArtSize size;
  final BoxFit fit;

  /// Behind the emoji. Defaults to transparent so tiles keep their own.
  final Color? background;

  /// Inset applied to the picture *and* the placeholder, so swapping one
  /// for the other does not move the artwork. Zero for edge-to-edge tiles.
  final EdgeInsets padding;

  const CardImage({
    super.key,
    required this.name,
    required this.fallbackEmoji,
    this.size = CardArtSize.tile,
    this.fit = BoxFit.contain,
    this.background,
    this.padding = const EdgeInsets.all(12),
  });

  /// The common case: a card knows both its picture and its emoji.
  CardImage.forCard(
    CardModel card, {
    super.key,
    this.size = CardArtSize.tile,
    this.fit = BoxFit.contain,
    this.background,
    this.padding = const EdgeInsets.all(12),
  })  : name = card.image,
        fallbackEmoji = card.emoji;

  /// Reported at most once per asset per session: a grid of twenty tiles
  /// waiting on the same pack is one problem, not twenty events.
  static final Set<String> _reported = {};

  static void _report(String? name, String reason) {
    if (name == null || !_reported.add('$name/$reason')) return;
    AnalyticsService.instance.logAssetUnavailable('image', reason);
  }

  @visibleForTesting
  static void debugResetReported() => _reported.clear();

  @override
  Widget build(BuildContext context) {
    // Listening to the service's notifier rather than to
    // `contentPackProvider` keeps this widget free of Riverpod, and that
    // is not a style preference: the share-image pipeline
    // (`renderWidgetToImage`) builds its tree against its own BuildOwner
    // with no ProviderScope above it. A ConsumerWidget there throws "No
    // ProviderScope found" into FlutterError.onError — which main.dart
    // files as a fatal crash. The one widget whose job is to never do
    // that must work in every tree the app renders.
    return ValueListenableBuilder<ContentPackState>(
      valueListenable: AssetPackService.instance.state,
      builder: (context, _, _) => _art(context),
    );
  }

  Widget _art(BuildContext context) {
    final art = AssetPackService.instance.cardArt(
      name,
      cacheWidth: switch (size) {
        CardArtSize.hero => cardCacheWidth(context),
        CardArtSize.tile => tileCacheWidth(context),
      },
    );

    return switch (art) {
      ArtReady(:final provider) => Padding(
          padding: padding,
          child: Image(
            image: provider,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
          // Last line of defence. Play can evict a pack between the
          // resolve above and the decode, and a bundled file can still be
          // corrupt. Neither is worth a crash report.
            errorBuilder: (context, error, stack) {
              _report(name, 'decode_failed');
              return _Placeholder(
                emoji: fallbackEmoji,
                background: background,
                padding: padding,
              );
            },
          ),
        ),
      // Real content, still on its way. The pulse says "coming", where a
      // spinner would say "broken" to a two-year-old.
      ArtPending() => _pending(),
      ArtMissing(:final reason) => _missing(reason),
    };
  }

  Widget _pending() {
    _report(name, 'pending');
    return _Placeholder(
      emoji: fallbackEmoji,
      background: background,
      padding: padding,
    );
  }

  Widget _missing(String reason) {
    // A card with no illustration is not a fault — the emoji is the design.
    if (reason != ArtMissing.noName.reason) _report(name, reason);
    return _Placeholder(
      emoji: fallbackEmoji,
      background: background,
      padding: padding,
    );
  }
}

/// The emoji stand-in. No text, no broken-image glyph, no English: the
/// audience is one to four years old and does not read.
///
/// Deliberately static, and deliberately identical for "downloading" and
/// "no illustration". The design called for a slow pulse on the pending
/// state; it was dropped for three reasons. A grid of twenty waiting tiles
/// would hold twenty `AnimationController`s on the cheap tablets this app
/// targets (60fps is a hard rule here). An animation that never ends hangs
/// `pumpAndSettle`, so every screen test touching a pending card would
/// have to know about it. And the "coming, not broken" message is already
/// carried where a parent reads it — the `downloading` badge on the pack
/// tile and [ContentDownloadView] at screen level — whereas the child just
/// needs something recognisable in the box.
class _Placeholder extends StatelessWidget {
  final String emoji;
  final Color? background;
  final EdgeInsets padding;

  const _Placeholder({
    required this.emoji,
    this.background,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    // FittedBox scales one glyph to whatever box it lands in, so the same
    // placeholder serves a full-screen card and a grid thumbnail.
    final child = Center(
      child: Padding(
        padding: padding,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(emoji, style: const TextStyle(fontSize: 120)),
        ),
      ),
    );
    final bg = background;
    return bg == null ? child : ColoredBox(color: bg, child: child);
  }
}
