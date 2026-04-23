import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/bonus_cards_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/daily_stats_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/engage_service.dart';
import '../services/tts_service.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../services/paywall_flow.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/flash_card.dart';
import '../widgets/parental_gate.dart';
import '../widgets/share_progress_card.dart';
import '../widgets/speaker_button.dart';
import '../widgets/swipe_hint.dart';
import 'memory_match_screen.dart';

class CardsScreen extends ConsumerStatefulWidget {
  final PackModel pack;

  const CardsScreen({super.key, required this.pack});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _speakDebounce;
  bool _imagesPrecached = false;
  late final List<CardModel> _cards;
  final GlobalKey<SwipeHintState> _swipeHintKey = GlobalKey();

  // Prevents dispose() from killing audio when navigating to "Play again"
  bool _celebrating = false;
  bool _isFlipped = false;

  // Auto-play timer mode
  bool _autoPlayTimer = false;
  Timer? _autoPlayCountdown;
  int _countdownSeconds = 0;
  VoidCallback? _speakingListener;
  VoidCallback? _muteListener;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);

    final allCards = widget.pack.cards;
    final bonus = ref.read(bonusCardsProvider)[widget.pack.id] ?? 0;
    final visibleCards = widget.pack.isLocked
        ? allCards.take(PackModel.freePreviewCount + bonus).toList()
        : allCards.toList();
    // Opposites pack: keep pair order (A→B, A→B...) — do not shuffle
    if (!widget.pack.id.contains('opposites')) {
      visibleCards.shuffle(Random());
    }
    _cards = visibleCards;

    // Restart auto-play countdown when mute is toggled
    _muteListener = () {
      if (_autoPlayTimer) _startAutoPlayCountdown();
    };
    AudioService.instance.autoSpeak.addListener(_muteListener!);

    AnalyticsService.instance.logPackOpen(widget.pack.id);
    EngageService.instance.saveLastPack(widget.pack.id, widget.pack.title);
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
        if (_currentIndex < _cards.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
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
    _speakCard(card);
    if (_autoPlayTimer) _startAutoPlayCountdown();
  }

  void _speakCard(CardModel card) {
    final lang = ref.read(languageProvider);
    // Prefer a recorded mp3 whenever one exists — applies to both UA and
    // EN now that English voice-overs are bundled. Fall back to TTS only
    // when the card has no audio asset.
    if (AudioService.instance.hasSound(card.audioKey)) {
      AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
      return;
    }
    TtsService.instance.speak(
      card.sound,
      locale: lang == 'en' ? 'en-US' : 'uk-UA',
    );
  }

  /// TTS locale for FlashCard: recorded audio → null; otherwise per-language.
  String? _ttsLocaleForCard(CardModel card) {
    if (AudioService.instance.hasSound(card.audioKey)) return null;
    final lang = ref.read(languageProvider);
    return lang == 'en' ? 'en-US' : 'uk-UA';
  }

  void _speakCardDebounced(int index) {
    _speakDebounce?.cancel();
    // Small breather after the swipe settles so the word doesn't start
    // playing while the card is still moving into place.
    _speakDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _speakCard(_cards[index]);
      if (_autoPlayTimer) _startAutoPlayCountdown();
    });
  }

  Future<void> _handleUnlock() async {
    final purchased = await runPaywallFlow(context, ref);
    if (purchased && mounted) Navigator.of(context).pop();
  }

  Future<void> _shareProgress() async {
    // Parent gate — prevents toddlers from triggering the system share sheet
    // (which can expose app data to other apps / contacts).
    final passed = await ParentalGate.show(context);
    if (!passed || !mounted) return;
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
      isEn: ref.read(languageProvider) == 'en',
    );
  }

  /// Waits for sound to finish + 1s (or 3s if no sound), then shows celebration.
  Future<void> _showCelebrationAfterSound() async {
    final audio = AudioService.instance;

    // Wait for debounced speak to kick in (debounce is 100ms)
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (audio.isSpeaking.value) {
      // Sound is playing — wait for it to finish
      final completer = Completer<void>();
      void listener() {
        if (!audio.isSpeaking.value) {
          audio.isSpeaking.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        }
      }
      audio.isSpeaking.addListener(listener);
      // Safety timeout so we don't wait forever
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 10)),
      ]);
      // Extra pause after sound ends
      await Future.delayed(const Duration(seconds: 1));
    } else {
      // No sound playing — wait 3 seconds so user can see the last card
      await Future.delayed(const Duration(seconds: 3));
    }

    if (!mounted) return;
    if (widget.pack.isLocked) {
      _showUnlockDialog();
    } else {
      _showCelebration();
    }
  }

  void _showCelebration() {
    _celebrating = true;
    AudioService.instance.stop();
    // Don't mark virtual packs (favorites, review) as completed
    if (!widget.pack.id.startsWith('_')) {
      AnalyticsService.instance.logPackComplete(widget.pack.id);
      ref.read(completedPacksProvider.notifier).markCompleted(widget.pack.id);
    }
    // Capture the route's own Navigator and overlay context up-front so the
    // celebration buttons never try to pop through a stale ancestor — a bug
    // where finishing a pack left the overlay stuck on the home screen.
    final navigator = Navigator.of(context);
    var overlayDismissed = false;
    void dismissOverlay() {
      if (overlayDismissed) return;
      overlayDismissed = true;
      if (navigator.canPop()) navigator.pop();
    }

    final isEn = ref.read(languageProvider) == 'en';
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => CelebrationOverlay(
          packTitle: widget.pack.title,
          packIcon: widget.pack.icon,
          color: widget.pack.color,
          isEn: isEn,
          onShare: _shareProgress,
          onReplay: () {
            dismissOverlay();
            if (!mounted) return;
            navigator.pushReplacement(
              MaterialPageRoute(
                  builder: (_) => CardsScreen(pack: widget.pack)),
            );
          },
          onDone: () async {
            dismissOverlay();
            await _maybeShowRatePrompt();
            if (mounted && navigator.canPop()) navigator.pop();
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
    final s = AppS(ref.read(languageProvider) == 'en');
    final allCards = widget.pack.cards;
    final bonus = ref.read(bonusCardsProvider)[widget.pack.id] ?? 0;
    final remaining = allCards.length - PackModel.freePreviewCount - bonus;
    final previewEmojis = allCards
        .skip(PackModel.freePreviewCount + bonus)
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
                s('Сподобалось? ${widget.pack.title}', 'Enjoying ${widget.pack.title}?'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.pack.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s('Ще $remaining карток чекають!', '$remaining more cards waiting!'),
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
                  child: Text(s('Розблокувати все', 'Unlock all'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(s('Може пізніше', 'Maybe later'),
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final allCards = widget.pack.cards;
    final progress = (_currentIndex + 1) / cards.length;
    final s = AppS(ref.read(languageProvider) == 'en');

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
            Text(widget.pack.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.pack.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.pack.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.pack.id == '_review')
                    Text(
                      AppS(ref.read(languageProvider) == 'en')(
                          '🔄 Повторення', '🔄 Review'),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.pack.color.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_cards.where((c) => c.audioKey != null).length >= 6)
            IconButton(
              icon: const Text('🧠', style: TextStyle(fontSize: 20)),
              tooltip: 'Грати Memory',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MemoryMatchScreen(
                    pack: widget.pack,
                    cards: _cards,
                  ),
                ));
              },
            ),
          Semantics(
            label: _autoPlayTimer
                ? 'Автогортання увімкнено'
                : 'Автогортання вимкнено',
            button: true,
            child: GestureDetector(
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
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _autoPlayTimer && _countdownSeconds > 0
                    ? '${_currentIndex + 1}/${cards.length}  · $_countdownSeconds'
                    : '${_currentIndex + 1}/${cards.length}',
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
                PageView.builder(
                  controller: _pageController,
                  itemCount: cards.length,
                  onPageChanged: (index) {
                    HapticFeedback.lightImpact();
                    _swipeHintKey.currentState?.dismiss();
                    _cancelAutoPlayCountdown();
                    final prev = _currentIndex;
                    setState(() {
                      _currentIndex = index;
                      _isFlipped = false;
                    });
                    // Track only forward progress
                    if (index > prev) {
                      AnalyticsService.instance.logCardView(
                          cards[index].id, widget.pack.id);
                      ref
                          .read(packProgressProvider.notifier)
                          .updateProgress(widget.pack.id, index);
                      ref
                          .read(dailyStatsProvider.notifier)
                          .recordView();
                      ref
                          .read(dailyQuestProvider.notifier)
                          .recordCardView();
                      ref
                          .read(reviewProvider.notifier)
                          .markSeen(cards[index].id);
                    }
                    if (AudioService.instance.autoSpeak.value) {
                      _speakCardDebounced(index);
                    } else if (_autoPlayTimer) {
                      _startAutoPlayCountdown();
                    }
                    // Last card reached
                    if (index == cards.length - 1) {
                      _showCelebrationAfterSound();
                    }
                  },
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 0;
                        if (_pageController.position.haveDimensions) {
                          value = index - (_pageController.page ?? index.toDouble());
                        }
                        // 3D rotation + scale effect
                        final angle = value * 0.04;
                        final scale = lerpDouble(1, 0.9, value.abs())!;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle)
                            ..scaleByDouble(scale, scale, scale, 1),
                          child: Opacity(
                            opacity: lerpDouble(1, 0.5, value.abs())!.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: FlashCard(
                        card: cards[index],
                        isActive: index == _currentIndex,
                        ttsLocale: _ttsLocaleForCard(cards[index]),
                        onFlipChanged: (flipped) {
                          setState(() => _isFlipped = flipped);
                        },
                      ),
                    );
                  },
                ),
                if (!_isFlipped)
                  Positioned(
                    top: 36,
                    right: 28,
                    child: SpeakerButton(onActivated: _speakCurrentCard),
                  ),
                SwipeHint(key: _swipeHintKey),
                // Auto-play countdown — visible on the card so toddlers see
                // "next card coming". Single tap pauses (toggles auto-play off).
                if (_autoPlayTimer && _countdownSeconds > 0)
                  Positioned(
                    top: 36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _toggleAutoPlayTimer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.pack.color,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: widget.pack.color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pause_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '$_countdownSeconds',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
                      s('Превʼю ${cards.length} з ${allCards.length} карток',
                          'Preview ${cards.length} of ${allCards.length} cards'),
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
                    child: Text(s('Розблокувати', 'Unlock'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

