import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/daily_stats_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../providers/streak_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../services/paywall_flow.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/flash_card.dart';
import '../widgets/share_progress_card.dart';
import '../widgets/speaker_button.dart';
import '../widgets/swipe_hint.dart';

class CardsScreen extends ConsumerStatefulWidget {
  final PackModel pack;

  const CardsScreen({super.key, required this.pack});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  final CardSwiperController _controller = CardSwiperController();
  int _currentIndex = 0;
  Timer? _speakDebounce;
  bool _imagesPrecached = false;
  late final List<CardModel> _cards;
  final GlobalKey<SwipeHintState> _swipeHintKey = GlobalKey();

  // Prevents dispose() from killing audio when navigating to "Play again"
  bool _celebrating = false;

  // Auto-play timer mode
  bool _autoPlayTimer = false;
  Timer? _autoPlayCountdown;
  int _countdownSeconds = 0;
  VoidCallback? _speakingListener;
  VoidCallback? _muteListener;

  @override
  void initState() {
    super.initState();

    final allCards = widget.pack.cards;
    final visibleCards = widget.pack.isLocked
        ? allCards.take(PackModel.freePreviewCount).toList()
        : allCards.toList();
    visibleCards.shuffle(Random());
    _cards = visibleCards;

    // Restart auto-play countdown when mute is toggled
    _muteListener = () {
      if (_autoPlayTimer) _startAutoPlayCountdown();
    };
    AudioService.instance.autoSpeak.addListener(_muteListener!);

    AnalyticsService.instance.logPackOpen(widget.pack.id);
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(packProgressProvider.notifier)
          .updateProgress(widget.pack.id, 0);
      ref.read(reviewProvider.notifier).markSeen(_cards[0].id);
      // Wait for Hero animation + prefs load, then play if not muted
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && AudioService.instance.autoSpeak.value) {
          _speakCurrentCard();
        }
        if (mounted && _autoPlayTimer) {
          _startAutoPlayCountdown();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      for (final card in widget.pack.cards) {
        if (card.image != null) {
          precacheImage(
            AssetImage('assets/images/webp/${card.image}.webp'),
            context,
          );
        }
      }
    }
  }

  /// Load both auto-speak and auto-play-timer in a single prefs call.
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    AudioService.instance.autoSpeak.value =
        prefs.getBool('auto_speak') ?? true;
    if (mounted) {
      setState(() {
        _autoPlayTimer = prefs.getBool('auto_play_timer') ?? false;
      });
    }
  }

  void _toggleAutoPlayTimer() async {
    final newValue = !_autoPlayTimer;
    setState(() => _autoPlayTimer = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_timer', newValue);
    if (newValue) {
      _startAutoPlayCountdown();
    } else {
      _cancelAutoPlayCountdown();
    }
  }

  /// Always waits: isSpeaking true (start) → false (end) → 3s countdown.
  void _startAutoPlayCountdown() {
    _cancelAutoPlayCountdown();
    if (!_autoPlayTimer || _currentIndex >= _cards.length - 1) return;

    final audio = AudioService.instance;
    final card = _cards[_currentIndex];
    final hasSound = audio.hasSound(card.audioKey);
    final isMuted = !audio.autoSpeak.value;

    // No sound or muted — 5s countdown immediately
    if (!hasSound || isMuted) {
      _beginCountdown(5);
      return;
    }

    // Track: saw the sound start, then wait for it to stop.
    // If already speaking when listener added, treat as started.
    bool sawStart = audio.isSpeaking.value;
    _speakingListener = () {
      final speaking = audio.isSpeaking.value;
      if (!sawStart && speaking) {
        sawStart = true;
        return;
      }
      if (sawStart && !speaking) {
        audio.isSpeaking.removeListener(_speakingListener!);
        _speakingListener = null;
        if (mounted && _autoPlayTimer) _beginCountdown(3);
      }
    };
    audio.isSpeaking.addListener(_speakingListener!);
  }

  void _beginCountdown(int seconds) {
    if (!mounted || !_autoPlayTimer) return;
    setState(() => _countdownSeconds = seconds);
    _autoPlayCountdown =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_autoPlayTimer) {
        timer.cancel();
        return;
      }
      setState(() => _countdownSeconds--);
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _controller.swipe(CardSwiperDirection.left);
      }
    });
  }

  void _cancelAutoPlayCountdown() {
    _autoPlayCountdown?.cancel();
    _autoPlayCountdown = null;
    if (_speakingListener != null) {
      AudioService.instance.isSpeaking.removeListener(_speakingListener!);
      _speakingListener = null;
    }
    _countdownSeconds = 0;
  }

  void _speakCurrentCard() {
    final card = _cards[_currentIndex];
    AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    if (_autoPlayTimer) _startAutoPlayCountdown();
  }

  void _speakCardDebounced(int index) {
    _speakDebounce?.cancel();
    _speakDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      final card = _cards[index];
      AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
      // Start countdown AFTER sound has begun (isSpeaking is now true)
      if (_autoPlayTimer) _startAutoPlayCountdown();
    });
  }

  Future<void> _handleUnlock() async {
    final purchased = await runPaywallFlow(context, ref);
    if (purchased && mounted) Navigator.of(context).pop();
  }

  void _shareProgress() {
    final completed = ref.read(completedPacksProvider);
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final progress = ref.read(packProgressProvider);
    final streak = ref.read(streakProvider);
    shareProgress(
      context: context,
      completedPacks: completed.length,
      totalPacks: packs.length,
      seenCards: progress.entries.where((e) => !e.key.startsWith('_')).fold<int>(0, (s, e) => s + e.value),
      totalCards: packs.fold<int>(0, (s, p) => s + p.cards.length),
      streak: streak.currentStreak,
      badges: streak.unlockedRewards,
    );
  }

  void _showCelebration() {
    _celebrating = true;
    AudioService.instance.stop();
    // Don't mark virtual packs (favorites, review) as completed
    if (!widget.pack.id.startsWith('_')) {
      AnalyticsService.instance.logPackComplete(widget.pack.id);
      ref.read(completedPacksProvider.notifier).markCompleted(widget.pack.id);
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => CelebrationOverlay(
          packTitle: widget.pack.title,
          packIcon: widget.pack.icon,
          color: widget.pack.color,
          onShare: _shareProgress,
          onReplay: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => CardsScreen(pack: widget.pack)),
            );
          },
          onDone: () async {
            Navigator.of(context).pop();
            await _maybeShowRatePrompt();
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _maybeShowRatePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('rate_shown') == true) return;
    final completed = ref.read(completedPacksProvider);
    if (completed.isEmpty) return;
    await prefs.setBool('rate_shown', true);
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌟', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Подобається додаток?',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Оцініть нас в магазині — це дуже допомагає!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final review = InAppReview.instance;
                    if (await review.isAvailable()) {
                      review.requestReview();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Оцінити ⭐',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Не зараз',
                    style: TextStyle(color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockDialog() {
    AudioService.instance.stop();
    final allCards = widget.pack.cards;
    final remaining = allCards.length - PackModel.freePreviewCount;
    final previewEmojis = allCards
        .skip(PackModel.freePreviewCount)
        .take(6)
        .map((c) => c.emoji)
        .join(' ');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.pack.icon,
                  style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'Сподобалось? ${widget.pack.title}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.pack.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ще $remaining карток чекають!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 12),
              Text(previewEmojis,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _handleUnlock();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.pack.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Розблокувати все',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Може пізніше',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelAutoPlayCountdown();
    if (_muteListener != null) {
      AudioService.instance.autoSpeak.removeListener(_muteListener!);
    }
    if (!_celebrating) AudioService.instance.stop();
    _speakDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final allCards = widget.pack.cards;
    final progress = (_currentIndex + 1) / cards.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: widget.pack.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'pack_icon_${widget.pack.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(widget.pack.icon,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.pack.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.pack.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _toggleAutoPlayTimer,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _autoPlayTimer
                        ? Icons.timer
                        : Icons.timer_off_outlined,
                    color: _autoPlayTimer
                        ? widget.pack.color
                        : widget.pack.color.withValues(alpha: 0.4),
                    size: 24,
                  ),
                  if (_autoPlayTimer && _countdownSeconds > 0)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: widget.pack.color,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_countdownSeconds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${cards.length}',
                style: TextStyle(
                  color: widget.pack.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor:
                    widget.pack.color.withValues(alpha: 0.15),
                valueColor:
                    AlwaysStoppedAnimation<Color>(widget.pack.color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _speakCurrentCard,
                  child: CardSwiper(
                    controller: _controller,
                    cardsCount: cards.length,
                    numberOfCardsDisplayed:
                        cards.length < 3 ? cards.length : 3,
                    onSwipe: (prevIndex, currentIndex, __) {
                      if (currentIndex != null) {
                        HapticFeedback.lightImpact();
                        _swipeHintKey.currentState?.dismiss();
                        _cancelAutoPlayCountdown();
                        setState(() => _currentIndex = currentIndex);
                        // Don't play sound if this was the last card
                        // (onEnd will fire next)
                        final isLastCard =
                            prevIndex == cards.length - 1;
                        if (!isLastCard) {
                          AnalyticsService.instance.logCardView(
                              cards[currentIndex].id, widget.pack.id);
                          ref
                              .read(packProgressProvider.notifier)
                              .updateProgress(
                                  widget.pack.id, currentIndex);
                          ref
                              .read(dailyStatsProvider.notifier)
                              .recordView();
                          ref
                              .read(reviewProvider.notifier)
                              .markSeen(cards[currentIndex].id);
                          if (AudioService.instance.autoSpeak.value) {
                            _speakCardDebounced(currentIndex);
                          } else if (_autoPlayTimer) {
                            // Muted — start 5s countdown directly
                            _startAutoPlayCountdown();
                          }
                        }
                      }
                      return true;
                    },
                    onEnd: widget.pack.isLocked
                        ? _showUnlockDialog
                        : _showCelebration,
                    cardBuilder: (_, index, __, ___) {
                      return FlashCard(card: cards[index]);
                    },
                  ),
                ),
                Positioned(
                  top: 36,
                  right: 28,
                  child:
                      SpeakerButton(onActivated: _speakCurrentCard),
                ),
                SwipeHint(key: _swipeHintKey),
              ],
            ),
          ),
          if (widget.pack.isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              color: widget.pack.color.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.lock_open_rounded,
                      color: widget.pack.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Превʼю ${cards.length} з ${allCards.length} карток',
                      style: TextStyle(
                        color: widget.pack.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _handleUnlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.pack.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: const Text('Розблокувати',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
