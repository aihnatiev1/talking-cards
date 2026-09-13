import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/bonus_cards_provider.dart';
import '../providers/content_pack_provider.dart';
import '../providers/app_review_provider.dart';
import '../providers/bloom_reactions_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/daily_stats_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/review_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/asset_pack_service.dart';
import '../services/audio_service.dart';
import '../services/engage_service.dart';
import '../services/feedback_service.dart';
import '../utils/l10n.dart';
import '../services/paywall_flow.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/celebration.dart';
import '../widgets/content_download_view.dart';
import '../widgets/flash_card.dart';
import '../widgets/share_progress_card.dart';
import '../widgets/speaker_button.dart';
import '../widgets/swipe_hint.dart';
import 'memory_match_screen.dart';
import '../utils/image_cache_size.dart';
import '../widgets/kid_screen.dart';
import '../widgets/card_image.dart';
import '../widgets/pack_cover_hero.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/motion.dart';

/// The pack's picture in the header — the landing spot of the Hero that
/// takes off from the home tile. Same picture rule as the tile (cover, else
/// first illustrated card, else the pack emoji), drawn by [CardImage] so a
/// pack still downloading shows its emoji instead of throwing.
class _PackCoverBadge extends StatelessWidget {
  final PackModel pack;

  const _PackCoverBadge({required this.pack});

  static const double _size = 40;
  static final BorderRadius _radius = BorderRadius.circular(10);

  @override
  Widget build(BuildContext context) {
    final tint = pack.color.withValues(alpha: 0.12);
    return PackCoverHero(
      pack: pack,
      borderRadius: _radius,
      // The tile this would fly back to may have scrolled out of view.
      transitionOnUserGestures: false,
      child: SizedBox(
        width: _size,
        height: _size,
        child: ClipRRect(
          borderRadius: _radius,
          child: ColoredBox(
            color: tint,
            child: CardImage(
              name: PackCoverHero.coverOf(pack),
              fallbackEmoji: pack.icon,
              padding: const EdgeInsets.all(3),
            ),
          ),
        ),
      ),
    );
  }
}

class CardsScreen extends ConsumerStatefulWidget {
  final PackModel pack;

  const CardsScreen({super.key, required this.pack});

  /// Where a re-opened pack should start (design audit 2026-09-08, #22).
  ///
  /// [progress] is the stored value from [PackProgressNotifier]: the highest
  /// index reached + 1, or null when the pack was never opened. We resume on
  /// the first card the child has not reached yet, so the "Continue" card on
  /// the home hero actually continues. A fully seen pack, a virtual pack
  /// (favourites/review — ids start with '_') or an empty deck start over.
  static int resumeIndex(int? progress, int length, String packId) {
    if (length <= 0 || packId.startsWith('_')) return 0;
    final next = progress ?? 0;
    if (next <= 0 || next >= length) return 0;
    return next;
  }

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _speakDebounce;
  bool _imagesPrecached = false;
  late final List<CardModel> _cards;

  /// Whether any card on this screen lives in the Play asset pack.
  late final bool _needsContent;
  bool _waitLogged = false;
  final GlobalKey<SwipeHintState> _swipeHintKey = GlobalKey();
  bool _userSwiping = false;

  // Prevents dispose() from killing audio when navigating to "Play again"
  bool _celebrating = false;
  // Set when the user swipes forward on the last card: the end-of-pack wait
  // in [_showCelebrationAfterSound] aborts and the modal shows immediately.
  bool _skipEndWait = false;
  bool _isFlipped = false;

  // Auto-play timer mode
  bool _autoPlayTimer = false;
  Timer? _autoPlayCountdown;
  int _countdownSeconds = 0;
  VoidCallback? _speakingListener;
  VoidCallback? _muteListener;

  /// This screen's stage in Bloom's brain; left in [dispose] so the home
  /// Bloom takes over again (bloom_character.md §5.4).
  final Object _bloomScene = Object();
  BloomReactions get _bloom => ref.read(bloomReactionsProvider.notifier);

  /// From the shelf, the card is up and to the right.
  static const _cardDirection = Alignment(0.7, -0.8);

  /// What this screen allows Bloom to do right now: hints and the nap are
  /// off while auto-advance turns the pages (a parent set up passive
  /// viewing); `listen` still follows every word.
  void _syncBloomScene() {
    _bloom.sceneEntered(
      _bloomScene,
      _autoPlayTimer
          ? BloomScene.cards.copyWith(hintsEnabled: false, clearSleep: true)
          : BloomScene.cards,
    );
  }

  @override
  void initState() {
    super.initState();
    final allCards = widget.pack.cards;
    final bonus = ref.read(bonusCardsProvider)[widget.pack.id] ?? 0;
    // JSON order is curated (opposites pairs A→B, alphabet А→Я, phrases in
    // difficulty order) and children aged 1–4 want the SAME order 20–30
    // times — the old per-open shuffle broke both (design audit #22).
    _cards = widget.pack.isLocked
        ? allCards.take(widget.pack.effectiveFreePreviewCount + bonus).toList()
        : allCards.toList();

    // Resume where the child left off; the controller and _currentIndex
    // must agree or the first auto-speak/precache would target card 0 while
    // the viewport shows the resumed card.
    final startIndex = CardsScreen.resumeIndex(
      ref.read(packProgressProvider)[widget.pack.id],
      _cards.length,
      widget.pack.id,
    );
    _currentIndex = startIndex;
    _pageController = PageController(
      viewportFraction: 0.92,
      initialPage: startIndex,
    );
    _needsContent = _cards.any(
      (c) => AssetPackService.instance.needsDownload(c.image),
    );
    if (_needsContent) unawaited(AssetPackService.instance.fetch());

    // Restart auto-play countdown when mute is toggled
    _muteListener = () {
      if (_autoPlayTimer) _startAutoPlayCountdown();
    };
    AudioService.instance.autoSpeak.addListener(_muteListener!);

    AnalyticsService.instance.logPackOpen(widget.pack.id);
    EngageService.instance.saveLastPack(widget.pack.id, widget.pack.title);
    _syncBloomScene();
    _bloom.hintTargetChanged(_cardDirection);
    _bloom.packOpened();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // updateProgress only ever raises, so re-recording the resumed index
      // is a no-op for progress and just seeds first-open packs with 1.
      ref
          .read(packProgressProvider.notifier)
          .updateProgress(widget.pack.id, startIndex);
      if (_cards.isNotEmpty) {
        ref.read(reviewProvider.notifier).markSeen(_cards[startIndex].id);
      }
      // Resumed straight onto the final card: mirror onPageChanged so the
      // pack can still be finished without swiping back and forth.
      if (_cards.isNotEmpty && startIndex == _cards.length - 1) {
        _showCelebrationAfterSound();
      }
      // Speak once the route has finished fading in. The pack cover's Hero
      // flight (tile → header) runs on the same route animation, so the
      // first word lands right as the picture settles.
      _afterRouteTransition(() {
        if (mounted && AudioService.instance.autoSpeak.value) {
          _speakCurrentCard();
        }
        if (mounted && _autoPlayTimer) {
          _startAutoPlayCountdown();
        }
      });
    });
  }

  /// Runs [action] when the enclosing route's entrance animation completes
  /// (or right away if there is none / it already finished).
  void _afterRouteTransition(VoidCallback action) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      action();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        if (mounted) action();
      }
    };
    animation.addStatusListener(listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not latched while the pack is still arriving: the first frames of a
    // gated pack must not consume the one precache pass, or the cards get
    // none once the download lands.
    if (!_imagesPrecached && _contentOnDevice) {
      _imagesPrecached = true;
      _precacheAround(_currentIndex);
    }
  }

  /// Precaching the whole pack at once pumped ~100MB of full-res decodes
  /// through the image cache on open; the swiper only ever needs the
  /// immediate neighbours.
  /// True when every image in this pack can actually be read right now.
  /// [build] gates the pack behind [ContentDownloadView] until then, but
  /// [didChangeDependencies] and [onPageChanged] run outside that gate.
  bool get _contentOnDevice =>
      !_needsContent || AssetPackService.instance.contentReady;

  void _precacheAround(int index) {
    for (var i = index - 1; i <= index + 2; i++) {
      if (i < 0 || i >= _cards.length) continue;
      // Only warm what is actually on the device. Precaching an asset
      // still inside an undelivered Play pack throws, and `precacheImage`
      // without `onError` hands that straight to FlutterError.onError —
      // which main.dart files as a FATAL crash. Two of the three fatals of
      // 2026-09-08 came from here, with no screen frame in the stack to
      // say so. `cardArt` answers the question instead of guessing.
      //
      // The cacheWidth must match FlashCard's, or the same picture decodes
      // twice under two different ResizeImage keys.
      final art = AssetPackService.instance.cardArt(
        _cards[i].image,
        cacheWidth: cardCacheWidth(context),
      );
      if (art is! ArtReady) continue;
      precacheImage(
        art.provider,
        context,
        // Play can still evict the pack between the two lines. A warm
        // cache is an optimisation, never a reason to report a crash.
        onError: (_, __) {},
      );
    }
  }

  /// Load both auto-speak and auto-play-timer in a single prefs call.
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // auto_speak is session-only now — no prefs read; see AudioService.
    if (mounted) {
      setState(() {
        _autoPlayTimer = prefs.getBool('auto_play_timer') ?? false;
      });
      _syncBloomScene();
    }
  }

  void _toggleAutoPlayTimer() async {
    final newValue = !_autoPlayTimer;
    setState(() => _autoPlayTimer = newValue);
    _syncBloomScene();
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
    _autoPlayCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    // Only recorded audio — TTS was removed per user feedback ("after my
    // voiceover TTS speaks again"). If a card has no recording, stay silent.
    if (AudioService.instance.hasSound(card.audioKey)) {
      AnalyticsService.instance.logCardListen(card.id);
      AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    }
  }

  /// FlashCard no longer uses TTS at all — always pass null so the card
  /// widget falls through to the recorded-audio branch or silence.
  String? _ttsLocaleForCard(CardModel card) => null;

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
    final purchased = await runPaywallFlow(context, ref, source: 'preview_end');
    if (purchased && mounted) Navigator.of(context).pop();
  }

  /// Parent controls that used to sit in the child's header: autoplay and
  /// the Memory shortcut. Reached by a long-press on the title — a hold is
  /// not a gesture a toddler makes by accident.
  bool get _memoryEligible =>
      widget.pack.id != 'poems' &&
      _cards.where((c) => c.audioKey != null).length >= 6;

  void _showParentTools() {
    HapticFeedback.mediumImpact();
    final s = AppS(ref.read(languageProvider) == 'en');
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  s('Для батьків', 'For parents'),
                  style: DT.h2.copyWith(color: DT.textSecondary),
                ),
              ),
              SwitchListTile(
                value: _autoPlayTimer,
                secondary: Icon(Icons.timer_outlined, color: widget.pack.color),
                title: Text(s('Автогортання', 'Auto-advance')),
                subtitle: Text(
                  s('Картки перегортаються самі', 'Cards turn on their own'),
                ),
                onChanged: (_) {
                  Navigator.of(ctx).pop();
                  _toggleAutoPlayTimer();
                },
              ),
              if (_memoryEligible)
                ListTile(
                  leading: const Text('🧠', style: TextStyle(fontSize: 24)),
                  title: Text(
                    s('Memory з цим розділом', 'Memory with this pack'),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      KidRoutes.game(
                        MemoryMatchScreen(pack: widget.pack, cards: _cards),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareProgress() async {
    // No parental gate — app is rated 4+ (not in Apple Kids Category / Google
    // Families), so store guidelines don't require it. Share button lives
    // deep in the parent-facing results sheet anyway.
    if (!mounted) return;
    final completed = ref.read(completedPacksProvider);
    final packs = ref.read(packsProvider).valueOrNull ?? [];
    final progress = ref.read(packProgressProvider);
    final streak = ref.read(streakProvider);
    shareProgress(
      context: context,
      completedPacks: completed.length,
      totalPacks: packs.length,
      seenCards: progress.entries
          .where((e) => !e.key.startsWith('_'))
          .fold<int>(0, (s, e) => s + e.value),
      totalCards: packs.fold<int>(0, (s, p) => s + p.cards.length),
      streak: streak.currentStreak,
      badges: streak.unlockedRewards,
      isEn: ref.read(languageProvider) == 'en',
    );
  }

  /// Waits briefly for the last-card audio, then reveals the celebration
  /// (or the unlock dialog for locked packs).
  ///
  /// Loop-based watch: the child can either let auto-speak fire (500ms
  /// debounce) OR manually tap to play. We watch `isSpeaking` until:
  /// (a) it's been quiet past the 4s grace window, (b) the 10s cap is hit —
  /// long poems get cut rather than holding the user hostage, or
  /// (c) the user swipes forward on the last card ([_skipEndWait]), which
  /// shows the modal immediately.
  Future<void> _showCelebrationAfterSound() async {
    final audio = AudioService.instance;
    final start = DateTime.now();
    // Verse packs (poems, забавлянки, весела абетка) play long clips — let
    // the last rhyme finish instead of cutting to the modal mid-line. Word
    // packs keep the snappy timings. Swipe-forward still skips instantly.
    final isVerse = PackModel.nonWordPackIds.contains(widget.pack.id);
    final graceEnd = start.add(Duration(seconds: isVerse ? 6 : 4));
    final hardCap = start.add(Duration(seconds: isVerse ? 120 : 10));

    while (mounted && DateTime.now().isBefore(hardCap)) {
      if (_skipEndWait) break;
      final speaking = audio.isSpeaking.value;
      if (!speaking && DateTime.now().isAfter(graceEnd)) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    // Short breather so the voiceover tail doesn't bleed into the modal —
    // skipped entirely when the user explicitly swiped to move on.
    if (!_skipEndWait) {
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted || _celebrating) return;
    if (widget.pack.isLocked) {
      _showUnlockDialog();
    } else {
      _showCelebration();
    }
  }

  void _showCelebration() {
    // The overlay brings its own Bloom M; the one on the shelf fades out
    // so there is one character on screen (bloom_character.md §4.2).
    setState(() => _celebrating = true);
    // Cut the narrator's tail; the tada + praise are the Celebration's
    // (FeedbackEvent.packDone), so nothing is played here.
    AudioService.instance.stop();
    // Don't mark virtual packs (favorites, review) as completed
    var askReview = false;
    if (!widget.pack.id.startsWith('_')) {
      AnalyticsService.instance.logPackComplete(widget.pack.id);
      // First fully-finished pack EVER → the one auto review ask. This is
      // the real peak-delight moment: previews of locked packs never reach
      // celebration (they end in the unlock dialog), so a 5-card preview
      // can't trigger it — only a complete free pack (or any pack for
      // premium). completedPacks being empty makes this fire exactly once.
      askReview = ref.read(completedPacksProvider).isEmpty;
      ref.read(completedPacksProvider.notifier).markCompleted(widget.pack.id);
    }
    // Capture the route's own Navigator up-front so the callbacks never
    // pop through a stale ancestor — a bug where finishing a pack left the
    // overlay stuck on the home screen. The Celebration pops itself exactly
    // once before calling back (its own double-pop guard), so each callback
    // below only has to deal with CardsScreen.
    final navigator = Navigator.of(context);
    final isEn = ref.read(languageProvider) == 'en';
    celebrate(
      context,
      tier: CelebrationTier.pack,
      isEn: isEn,
      packTitle: widget.pack.title,
      packIcon: widget.pack.icon,
      packCover: widget.pack.cover,
      accent: widget.pack.color,
      onShare: _shareProgress,
      onAgain: () {
        if (!mounted) return;
        navigator.pushReplacement(
          KidRoutes.content(CardsScreen(pack: widget.pack)),
        );
      },
      onDone: () {
        if (mounted && navigator.canPop()) navigator.pop();
        // OS-native in-app review sheet, once ever, right after the
        // first-pack celebration — rate-limited by the OS and never
        // leaves the app. Explicit parent path stays in ParentDashboard.
        if (askReview && mounted) {
          ref
              .read(appReviewControllerProvider)
              .maybeRequestAfterWin('first_pack');
        }
      },
    );
  }

  void _showUnlockDialog() {
    AudioService.instance.stop();
    final s = AppS(ref.read(languageProvider) == 'en');
    final allCards = widget.pack.cards;
    final bonus = ref.read(bonusCardsProvider)[widget.pack.id] ?? 0;
    final remaining =
        allCards.length - widget.pack.effectiveFreePreviewCount - bonus;
    final previewEmojis = allCards
        .skip(widget.pack.effectiveFreePreviewCount + bonus)
        .take(6)
        .map((c) => c.emoji)
        .join(' ');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.pack.icon, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                s(
                  'Сподобалось? ${widget.pack.title}',
                  'Enjoying ${widget.pack.title}?',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.pack.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s(
                  'Ще $remaining карток чекають!',
                  '$remaining more cards waiting!',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(previewEmojis, style: const TextStyle(fontSize: 28)),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    s('Розблокувати все', 'Unlock all'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  s('Може пізніше', 'Maybe later'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bloom.sceneLeft(_bloomScene);
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

    // Paid-pack content may still be arriving from Play (fast-follow asset
    // pack). Gating here, not at the tap, covers every way into a pack —
    // grid, hero, quest, deep link — and swaps to the cards the moment the
    // download lands.
    final content = ref.watch(contentPackProvider);
    if (!content.isReady && _needsContent) {
      if (!_waitLogged) {
        _waitLogged = true;
        AnalyticsService.instance.logContentWait(
          widget.pack.id,
          content.status.name,
        );
      }
      ref.listen<ContentPackState>(contentPackProvider, (_, next) {
        if (next.isReady && mounted && AudioService.instance.autoSpeak.value) {
          _speakCurrentCard();
        }
      });
      return KidScreen(
        accent: widget.pack.color,
        body: ContentDownloadView(
          state: content,
          accent: widget.pack.color,
          isEn: s.isEn,
        ),
      );
    }

    // The child's header holds only what a child needs: back, the pack
    // cover (the Hero from the grid tile), the counter, the progress pill.
    // Autoplay and the Memory shortcut live in a parent sheet on a
    // long-press of the cover (audit #18) — a 36dp timer toggle and a
    // third-level game link were the two controls a toddler hit by
    // accident most. The pack name is gone from the header: a two-year-old
    // does not read it and the parent saw it on the tile a second ago.
    return KidScreen(
      accent: widget.pack.color,
      progress: progress,
      // Back: Bloom waves goodbye (no sound — the button pops) while the
      // route slides out.
      leading: KidBackButton(
        accent: widget.pack.color,
        onTap: () {
          _bloom.sessionEnding();
          Navigator.of(context).maybePop();
        },
      ),
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: _showParentTools,
        child: _PackCoverBadge(pack: widget.pack),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
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
      ),
      // Any finger on the screen is activity for Bloom: it resets his idle
      // clock and wakes him. Translucent, so nothing under it changes.
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _bloom.userTouch(),
        child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Swiping forward on the last card = "I'm done" — cut the
                // audio wait and show the celebration/unlock modal now.
                // Android clamps (OverscrollNotification); iOS bounces past
                // maxScrollExtent instead — handle both.
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification)
                      _userSwiping = n.dragDetails != null;
                    if (n is ScrollEndNotification) _userSwiping = false;
                    final pastEnd = n is OverscrollNotification
                        ? n.overscroll > 0
                        : n is ScrollUpdateNotification &&
                              n.metrics.pixels > n.metrics.maxScrollExtent + 24;
                    if (pastEnd &&
                        _currentIndex == cards.length - 1 &&
                        !_celebrating &&
                        !_skipEndWait) {
                      _skipEndWait = true;
                      AudioService.instance.stop();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (index) {
                      FeedbackService.instance.event(FeedbackEvent.swipe);
                      if (_userSwiping) _swipeHintKey.currentState?.dismiss();
                      _cancelAutoPlayCountdown();
                      final prev = _currentIndex;
                      setState(() {
                        _currentIndex = index;
                        _isFlipped = false;
                      });
                      _precacheAround(index);
                      // Track only forward progress
                      if (index > prev) {
                        _bloom.cardAdvanced(index);
                        AnalyticsService.instance.logCardView(
                          cards[index].id,
                          widget.pack.id,
                        );
                        ref
                            .read(packProgressProvider.notifier)
                            .updateProgress(widget.pack.id, index);
                        ref.read(dailyStatsProvider.notifier).recordView();
                        ref.read(dailyQuestProvider.notifier).recordCardView();
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
                        // Bloom cheers on the shelf right away — the child
                        // sees a friend react before the modal arrives. Not
                        // for a locked preview: Bloom takes no part in the
                        // unlock dialog (bloom_character.md §3.2).
                        if (!widget.pack.isLocked) _bloom.packCompleted();
                        _showCelebrationAfterSound();
                      }
                    },
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 0;
                          if (_pageController.position.haveDimensions) {
                            value =
                                index -
                                (_pageController.page ?? index.toDouble());
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
                              opacity: lerpDouble(
                                1,
                                0.5,
                                value.abs(),
                              )!.clamp(0.0, 1.0),
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
                ),
                if (!_isFlipped)
                  Positioned(
                    top: 36,
                    right: 28,
                    child: SpeakerButton(onActivated: _speakCurrentCard),
                  ),
                SwipeHint(key: _swipeHintKey, accent: widget.pack.color),
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
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                              const Icon(
                                Icons.pause_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
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
          _BloomShelf(
            hidden: _celebrating,
            semanticsLabel: s('Блум', 'Bloom'),
          ),
          if (widget.pack.isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: widget.pack.color.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_open_rounded,
                    color: widget.pack.color,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s(
                        'Превʼю ${cards.length} з ${allCards.length} карток',
                        'Preview ${cards.length} of ${allCards.length} cards',
                      ),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      s('Розблокувати', 'Unlock'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }
}

/// The shelf under the `PageView` Bloom S sits on (bloom_character.md
/// §4.2): its own `Column` row, so he can never overlap a card; 64 dp on a
/// phone, 80 on a tablet, 56 when the screen is short. Bloom is flush with
/// the card's left edge and looks up at it. He fades out while the pack
/// celebration — which brings its own Bloom — is up.
class _BloomShelf extends StatelessWidget {
  final bool hidden;
  final String semanticsLabel;

  const _BloomShelf({required this.hidden, required this.semanticsLabel});

  /// Left edge of the drawing from the screen edge.
  static const double _inset = 32;

  @override
  Widget build(BuildContext context) {
    final shelf = DT.size.bloomShelfOf(context);
    final size = DT.size.mascotCompanionOf(context);
    final hit = math.max(size, DT.size.tapMin);
    // The hit zone is centred on the drawing; pull it back so the *drawing*
    // starts at [_inset].
    final left = _inset - (hit - size) / 2;
    return SizedBox(
      height: shelf,
      child: OverflowBox(
        alignment: Alignment.bottomLeft,
        minHeight: 0,
        maxHeight: shelf + BloomMascot.hopClearance,
        child: Padding(
          padding: EdgeInsets.only(left: left),
          child: AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: MotionPolicy.of(context).dur(DT.motion.bloomFade),
            child: IgnorePointer(
              ignoring: hidden,
              child: BloomMascot(size: size, semanticsLabel: semanticsLabel),
            ),
          ),
        ),
      ),
    );
  }
}
