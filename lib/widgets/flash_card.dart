import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/favorites_provider.dart';
import '../services/audio_service.dart';

class FlashCard extends ConsumerStatefulWidget {
  final CardModel card;

  const FlashCard({super.key, required this.card});

  @override
  ConsumerState<FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends ConsumerState<FlashCard>
    with TickerProviderStateMixin {
  // Press animation
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  // Pulse animation for sound text
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Entrance bounce animation
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceAnim;

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

    AudioService.instance.isSpeaking.addListener(_onSpeakingChanged);
    // Start pulse if already speaking when card is created
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
        onTapUp: (_) => _pressCtrl.reverse(),
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _pressAnim,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
            child: Stack(
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
                // Favorite heart icon (top-left to avoid speaker button overlap)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
