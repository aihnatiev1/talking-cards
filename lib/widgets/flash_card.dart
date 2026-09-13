import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/favorites_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import 'ambient_loop.dart';
import 'card_image.dart';
import 'kid_tap.dart';
import '../utils/design_tokens.dart';

class FlashCard extends ConsumerStatefulWidget {
  final CardModel card;
  final ValueChanged<bool>? onFlipChanged;
  /// When non-null, card taps use TTS instead of recorded audio.
  final String? ttsLocale;
  /// Only the active (current) card should pulse its word during audio.
  final bool isActive;
  /// Whether the «English ↻» chip is drawn on the front face. `CardsScreen`
  /// turns it off (G9: no text buttons in the kid zone) and flips the card
  /// from the parent tools sheet through [FlashCardState.toggleFlip].
  final bool showEnglishChip;

  const FlashCard({
    super.key,
    required this.card,
    this.onFlipChanged,
    this.ttsLocale,
    this.isActive = true,
    this.showEnglishChip = true,
  });

  @override
  ConsumerState<FlashCard> createState() => FlashCardState();
}

class FlashCardState extends ConsumerState<FlashCard>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceAnim;

  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _showBack = false;

  bool get _hasEnglish =>
      widget.card.soundEn != null && widget.card.soundEn!.isNotEmpty;

  /// True when the card has an English side to flip to.
  bool get hasEnglish => _hasEnglish;

  /// Flip between the word and its English side. Public so the parent tools
  /// sheet in `CardsScreen` can do what the on-card chip used to.
  void toggleFlip() => _toggleFlip();

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entranceAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut),
    );
    _entranceCtrl.forward();

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
    _flipCtrl.addListener(() {
      final isBack = _flipAnim.value >= 0.5;
      if (isBack != _showBack) {
        setState(() => _showBack = isBack);
        widget.onFlipChanged?.call(isBack);
      }
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (!_hasEnglish) return;
    if (_flipCtrl.isAnimating) return;
    HapticFeedback.mediumImpact();
    if (_flipCtrl.isCompleted) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFav = ref.watch(
      favoritesProvider.select((favs) => favs.contains(widget.card.id)),
    );
    final theme = Theme.of(context);
    final cardBg = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;

    return ScaleTransition(
      scale: _entranceAnim,
      child: KidTap(
        // The word is this tap's sound; a pop underneath it would be noise.
        sound: KidSound.none,
        // Only the card face, not its margin (as the old detector did).
        behavior: HitTestBehavior.deferToChild,
        onTap: () {
          // Tap = hear the word, always — a toddler taps the picture
          // expecting sound, not a flip to English text. Flipping to the
          // EN side moved to the 🇬🇧 chip; tapping the back flips home.
          if (_showBack) {
            _toggleFlip();
          } else {
            AnalyticsService.instance.logCardListen(widget.card.id);
            AudioService.instance.speakCard(
              widget.card.audioKey,
              widget.card.sound,
              widget.card.text,
            );
          }
        },
        // Favourite = long-press on the card itself. The 56dp heart in the
        // corner collected accidental taps and silent favourites (audit
        // #20); a hold is a deliberate parent gesture, and the badge that
        // appears says what happened.
        onLongPress: () {
          HapticFeedback.mediumImpact();
          KidTap.feedback();
          ref.read(favoritesProvider.notifier).toggle(widget.card.id);
        },
        child: AnimatedBuilder(
          animation: _flipAnim,
          builder: (context, child) {
            final angle = _flipAnim.value * pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildBack(cardBg, theme),
                      )
                    : _buildFront(cardBg, theme, isFav),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(Color cardBg, ThemeData theme, bool isFav) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Tablets in landscape (allowed from 1.3.12, audit #29): the
            // picture sits left and the word right, instead of a squat
            // picture over a strip of text.
            final wide = constraints.maxWidth > constraints.maxHeight * 1.15;
            final art = _artPane();
            final word = _wordPane(cardBg, theme);
            return wide
                ? Row(children: [
                    Expanded(flex: 58, child: art),
                    Expanded(flex: 42, child: word),
                  ])
                : Column(children: [
                    Expanded(flex: 68, child: art),
                    Expanded(flex: 32, child: word),
                  ]);
          },
        ),
        if (isFav)
          Positioned(
            top: 10,
            left: 10,
            child: IgnorePointer(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.red, size: 22),
              ),
            ),
          ),
        if (_hasEnglish && widget.showEnglishChip)
          Positioned(
            bottom: 6,
            right: 6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleFlip,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('🇬🇧 English ↻', style: DT.caption),
              ),
            ),
          ),
      ],
    );
  }

  Widget _artPane() {
    return Container(
                width: double.infinity,
                height: double.infinity,
                color: widget.card.colorBg,
                child: widget.card.letter != null
                    ? _LetterArt(
                        letter: widget.card.letter!,
                        accent: widget.card.colorAccent,
                      )
                    // Picture or emoji is CardImage's call now: it also
                    // knows when the illustration is still downloading,
                    // which this branch could not tell from "no image".
                    : CardImage.forCard(
                        widget.card,
                        size: CardArtSize.hero,
                      ),
    );
  }

  Widget _wordPane(Color cardBg, ThemeData theme) {
    return ClipRect(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: cardBg,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The word pulses (1.0 → 1.15, 1600 ms) only on the active
              // card and only while its clip plays. Under reduced motion it
              // rests at 1.0 — the speaker button's glow still shows that
              // audio is running.
              ValueListenableBuilder<bool>(
                valueListenable: AudioService.instance.isSpeaking,
                builder: (_, speaking, word) => AmbientLoop(
                  period: const Duration(milliseconds: 1600),
                  enabled: widget.isActive && speaking,
                  builder: (_, t, child) => Transform.scale(
                    scale: 1.0 + 0.15 * t,
                    child: child,
                  ),
                  child: word,
                ),
                child: Text(
                  widget.card.sound,
                  textAlign: TextAlign.center,
                  style: DT.word.copyWith(
                    // Letter cards («Аа») carry 2-3 chars — let them fill
                    // the space instead of floating small in a bare block.
                    fontSize: widget.card.sound.length <= 3 ? 72 : 32,
                    // The pack's own accent, darkened for text, instead of
                    // one red for every pack (audit #19).
                    color: DT.onTint(widget.card.colorAccent),
                  ),
                ),
              ),
              if (widget.card.text.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  widget.card.text,
                  textAlign: TextAlign.center,
                  style: DT.body.copyWith(
                    fontSize: 16,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[300]
                        : DT.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBack(Color cardBg, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          flex: 50,
          child: Container(
            width: double.infinity,
            color: widget.card.colorBg,
            child: CardImage.forCard(
              widget.card,
              size: CardArtSize.hero,
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),
        Expanded(
          flex: 50,
          child: Container(
            width: double.infinity,
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: DT.sky.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('🇬🇧  English',
                        style: DT.caption.copyWith(
                            fontSize: 13, color: DT.onTint(DT.sky))),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.card.soundEn ?? '',
                    textAlign: TextAlign.center,
                    style: DT.word.copyWith(
                      fontSize: 38,
                      color: DT.onTint(widget.card.colorAccent),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.card.transcription ?? '',
                    textAlign: TextAlign.center,
                    style: DT.body.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[400]
                          : DT.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('↺ натисніть щоб повернути', style: DT.caption),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Sound-pack letter tile — the target phoneme IS the visual. Used instead
//  of a webp for cards like sound_r/sound_sh/sound_ts, where the child is
//  learning to produce the sound rather than associate it with an object.
// ─────────────────────────────────────────────

class _LetterArt extends StatelessWidget {
  final String letter;
  final Color accent;

  const _LetterArt({required this.letter, required this.accent});

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(accent, Colors.black, 0.20)!;
    return Container(
      margin: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.85), deep],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              letter,
              style: DT.word.copyWith(
                fontSize: 220,
                color: Colors.white,
                height: 1.0,
                letterSpacing: -4,
                shadows: const [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
