import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../utils/motion.dart';
import '../widgets/card_image.dart';
import '../widgets/kid_stage.dart';
import '../widgets/kid_tap.dart';

/// One short reveal, then a quiet, tappable keepsake. Reward persistence
/// belongs to the caller; replaying this screen never grants another card.
class CardRevealScreen extends ConsumerStatefulWidget {
  final CardModel card;
  final PackModel pack;
  final int newTotal;
  final void Function(BuildContext)? onShare;
  final VoidCallback? onGoToPack;
  final bool skipAnimation;

  const CardRevealScreen({
    super.key,
    required this.card,
    required this.pack,
    required this.newTotal,
    this.onShare,
    this.onGoToPack,
    this.skipAnimation = false,
  });

  @override
  ConsumerState<CardRevealScreen> createState() => _CardRevealScreenState();
}

class _CardRevealScreenState extends ConsumerState<CardRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: DT.motion.rewardReveal,
  )..addListener(_onReveal);
  bool _started = false;
  bool _announced = false;
  bool _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MotionPolicy.of(context).reduce;
    if (_started) {
      if (reduced && _reveal.isAnimating) _reveal.value = 1;
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving) return;
      if (widget.skipAnimation) {
        _announced = true;
        _reveal.value = 1;
      } else if (reduced) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    });
  }

  void _onReveal() {
    if (_reveal.value < .45 || _announced || _leaving) return;
    _announced = true;
    FeedbackService.instance.event(FeedbackEvent.reveal);
    AudioService.instance.playWordOnly(widget.card.audioKey, widget.card.sound);
  }

  void _leave({bool openPack = false}) {
    if (_leaving) return;
    _leaving = true;
    _reveal.stop();
    AudioService.instance.stop();
    Navigator.of(context).pop();
    if (openPack) widget.onGoToPack?.call();
  }

  @override
  void dispose() {
    _reveal.dispose();
    // An explicit exit already stopped our voice before opening the next
    // route. Its delayed disposal must not stop that route’s new audio.
    if (!_leaving) AudioService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    final accent = widget.pack.color;
    final ink = DT.onTint(accent);
    final total = widget.pack.cards.length;
    final unlocked = widget.newTotal.clamp(0, total);
    return Scaffold(
      backgroundColor: DT.rewardPaper,
      body: DecoratedBox(
        // The treasure room: a painted clay sky of confetti and gold.
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backdrops/treasure_sky.webp'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: s('Закрити', 'Close'),
                  constraints: const BoxConstraints(
                    minWidth: 64,
                    minHeight: 64,
                  ),
                  onPressed: _leave,
                  icon: Icon(Icons.close_rounded, color: ink),
                ),
              ),
              Expanded(
                child: KidStage(
                  title: Text(
                    s('Твій новий скарб!', 'Your new treasure!'),
                    textAlign: TextAlign.center,
                    style: DT.h1.copyWith(color: ink, fontSize: 32),
                  ),
                  subtitle: Text(
                    s(
                      'Картка вже у твоїй колекції',
                      'Already in your collection',
                    ),
                    textAlign: TextAlign.center,
                    style: DT.body.copyWith(color: ink),
                  ),
                  stage: (context, width, height) {
                    // The keepsake owns what is left after the pack line
                    // and the progress row, so the card is as big as the
                    // phone allows instead of a fixed 190.
                    final art = (height - 270).clamp(100.0, 420.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _reveal,
                          child: _keepsake(ink, art),
                          builder: (_, child) {
                            final t = _reveal.value;
                            final appear = ((t - .28) / .52).clamp(0.0, 1.0);
                            final eased = Curves.easeOutCubic.transform(appear);
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: appear,
                                  child: Transform.translate(
                                    offset: Offset(0, 32 * (1 - eased)),
                                    child: Transform.scale(
                                      scale: .86 + .14 * eased,
                                      child: child,
                                    ),
                                  ),
                                ),
                                if (t < .55)
                                  IgnorePointer(
                                    child: Opacity(
                                      opacity: (1 - t / .55).clamp(0.0, 1.0),
                                      child: Transform.rotate(
                                        angle: math.sin(t * math.pi * 8) * .06,
                                        child: AppIconView(
                                          t < .28
                                              ? AppIcon.rewardChestClosed
                                              : AppIcon.rewardChestOpen,
                                          size: 132,
                                          sticker: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _RevealSparks(t, accent),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: DT.surfaceWhite.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(DT.rLg),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  widget.pack.title,
                                  textAlign: TextAlign.center,
                                  style: DT.tileTitle.copyWith(color: ink),
                                ),
                                const SizedBox(height: 8),
                                if (total > 0) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: unlocked / total,
                                      minHeight: 8,
                                      color: accent,
                                      backgroundColor: accent.withValues(
                                        alpha: .12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    s(
                                      '$unlocked з $total карток відкрито',
                                      '$unlocked of $total cards unlocked',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: DT.caption,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  actions: [
                    if (widget.onGoToPack != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _leave(openPack: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            minimumSize: const Size(0, 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            s('До моїх карток', 'Explore my cards'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextButton(
                      onPressed: _leave,
                      style: TextButton.styleFrom(
                        foregroundColor: ink,
                        backgroundColor: DT.surfaceWhite.withValues(alpha: .9),
                        minimumSize: const Size(160, 56),
                      ),
                      child: Text(s('На головну', 'Home')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keepsake(Color ink, double art) => KidTap(
    sound: null,
    onTap: () => AudioService.instance.playWordOnly(
      widget.card.audioKey,
      widget.card.sound,
    ),
    child: Semantics(
      button: true,
      label: widget.card.sound,
      child: Container(
        key: const ValueKey('reward-keepsake'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: widget.pack.color.withValues(alpha: .2)),
          boxShadow: [
            BoxShadow(
              color: widget.pack.color.withValues(alpha: .14),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: art, child: CardImage.forCard(widget.card)),
            const SizedBox(height: 12),
            Text(
              widget.card.sound,
              textAlign: TextAlign.center,
              style: DT.h1.copyWith(color: ink, fontSize: 28),
            ),
            if (widget.card.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.card.text,
                textAlign: TextAlign.center,
                style: DT.caption.copyWith(fontSize: 15, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Icon(Icons.volume_up_rounded, color: ink, size: 28),
          ],
        ),
      ),
    ),
  );
}

/// Twelve deterministic sparks expand once and disappear. No timers or
/// full-screen perpetual confetti remain after the keepsake settles.
class _RevealSparks extends CustomPainter {
  const _RevealSparks(this.time, this.color);
  final double time;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = ((time - .25) / .75).clamp(0.0, 1.0);
    if (t == 0 || t == 1) return;
    final centre = Offset(size.width / 2, size.height * .42);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi * 2 / 12;
      final radius =
          size.shortestSide * (.22 + .38 * Curves.easeOut.transform(t));
      final position =
          centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()
        ..color = (i.isEven ? color : DT.rewardSpark).withValues(
          alpha: (1 - t) * .8,
        );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 4, height: 8),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RevealSparks old) =>
      old.time != time || old.color != color;
}
