import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/favorites_provider.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';

class FlashCard extends ConsumerStatefulWidget {
  final CardModel card;
  final ValueChanged<bool>? onFlipChanged;
  /// When non-null, card taps use TTS instead of recorded audio.
  final String? ttsLocale;

  const FlashCard({
    super.key,
    required this.card,
    this.onFlipChanged,
    this.ttsLocale,
  });

  @override
  ConsumerState<FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends ConsumerState<FlashCard>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceAnim;

  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _showBack = false;

  bool get _hasEnglish =>
      widget.card.soundEn != null && widget.card.soundEn!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

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

    AudioService.instance.isSpeaking.addListener(_onSpeakingChanged);
    if (AudioService.instance.isSpeaking.value) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    AudioService.instance.isSpeaking.removeListener(_onSpeakingChanged);
    _pressCtrl.dispose();
    _pulseCtrl.dispose();
    _entranceCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  void _onSpeakingChanged() {
    if (!mounted) return;
    if (AudioService.instance.isSpeaking.value) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.0;
    }
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
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          if (_hasEnglish) {
            _toggleFlip();
          } else if (widget.ttsLocale != null) {
            TtsService.instance.speak(
                widget.card.sound, locale: widget.ttsLocale!);
          } else {
            AudioService.instance.speakCard(
              widget.card.audioKey,
              widget.card.sound,
              widget.card.text,
            );
          }
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _pressAnim,
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
      ),
    );
  }

  Widget _buildFront(Color cardBg, ThemeData theme, bool isFav) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 68,
              child: Container(
                width: double.infinity,
                color: widget.card.colorBg,
                child: widget.card.image != null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/webp/${widget.card.image}.webp',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Center(
                        child: Text(
                          widget.card.emoji,
                          style: const TextStyle(fontSize: 120),
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 32,
              child: ClipRect(
                child: Container(
                  width: double.infinity,
                  color: cardBg,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Text(
                            widget.card.sound,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD63031),
                              letterSpacing: 1.0,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.card.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[300]
                                : const Color(0xFF4A4A4A),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 10,
          left: 10,
          child: GestureDetector(
            onTap: () => ref
                .read(favoritesProvider.notifier)
                .toggle(widget.card.id),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : Colors.grey[400],
                size: 24,
              ),
            ),
          ),
        ),
        if (_hasEnglish)
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🇬🇧 English',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
      ],
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
            child: widget.card.image != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/webp/${widget.card.image}.webp',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : Center(
                    child: Text(
                      widget.card.emoji,
                      style: const TextStyle(fontSize: 90),
                    ),
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
                      color: const Color(0xFF1A5276).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('🇬🇧  English',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF1A5276))),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.card.soundEn ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: widget.card.colorAccent,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.card.transcription ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[400]
                          : const Color(0xFF5D6D7E),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '↺ натисніть щоб повернути',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
