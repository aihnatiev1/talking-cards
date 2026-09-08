import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../providers/profile_provider.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/paywall_flow.dart';
import '../services/remote_config_service.dart';
import '../utils/app_startup.dart';
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../widgets/bloom_mascot.dart';
import 'home_screen.dart';
import '../services/asset_pack_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Steps of onboarding. The order differs per language — see [_pagesFor].
enum _OnbStep { setup, age, magic }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  int _page = 0;

  String _selectedLang = 'uk';
  String _selectedAvatar = '👶';
  int _selectedLevel = 2;

  late final List<_OnbStep> _pages;

  /// EN puts the magic moment first and drops the name/avatar page entirely.
  ///
  /// Why: on 1.3.6 only 2 of 6 English installs that opened onboarding ever
  /// reached the magic moment — the keyboard page ate them before they heard
  /// a single card. Age still shapes the content, so it moves *after* the
  /// value; name and avatar stay editable in the profile switcher.
  /// UA keeps the original order — its funnel is healthy.
  static List<_OnbStep> _pagesFor(String lang) => lang == 'en'
      ? const [_OnbStep.magic, _OnbStep.age]
      : const [_OnbStep.setup, _OnbStep.age, _OnbStep.magic];

  @override
  void initState() {
    super.initState();
    // Language is auto-detected from the system locale instead of asking on
    // a dedicated screen — one step less before the magic moment. The
    // profile switcher still lets parents change it later.
    final sysLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    // uk/ru/be device locales → Ukrainian (many UA parents run ru-locale
    // phones); everything else → English (FirstWords Cards markets).
    _selectedLang = const {'uk', 'ru', 'be'}.contains(sysLang) ? 'uk' : 'en';
    _pages = _pagesFor(_selectedLang);
    // Tell `app_ready` that this launch is paying for onboarding, not for
    // a slow start.
    AppStartup.viaOnboarding = true;
    AnalyticsService.instance.logOnboardingLangSelected(_selectedLang);
    AnalyticsService.instance.logOnboardingStart();
  }

  static const _avatars = [
    '👶', '👧', '👦', '🧒',
    '🐱', '🐶', '🐻', '🐸',
    '🦊', '🐼', '🦄', '🌟',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    // Child setup page has a text field — dismiss the keyboard on advance so
    // the next page lays out against full screen height, not the cropped
    // viewport behind the IME.
    FocusScope.of(context).unfocus();
    if (_pages[_page] == _OnbStep.setup && _nameCtrl.text.trim().isNotEmpty) {
      AnalyticsService.instance.logOnboardingNameEntered();
    }
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  // Name is optional — "Далі" is never blocked. An empty field falls back
  // to «Малюк»/"Kid" in _finish; the keyboard was the funnel's biggest drop.
  bool get _canProceed => true;

  Future<void> _finish() async {
    final name = _nameCtrl.text.trim();
    final notifier = ref.read(profileProvider.notifier);

    // Update the default profile with chosen settings
    final profiles = ref.read(profileProvider).profiles;
    final defaultId = profiles.isNotEmpty ? profiles.first.id : 'default';
    final fallbackName = _selectedLang == 'en' ? 'Kid' : 'Малюк';
    await notifier.updateProfile(
        defaultId, name.isEmpty ? fallbackName : name, _selectedAvatar);
    await notifier.setLanguage(defaultId, _selectedLang);
    await notifier.setLevel(defaultId, _selectedLevel);

    // Mark onboarding as completed so we never show it again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    AnalyticsService.instance.logOnboardingComplete();
    await AnalyticsService.instance.setLanguageProperty(_selectedLang);
    await AnalyticsService.instance.setAgeLevelProperty(_selectedLevel);

    if (!mounted) return;

    // Paywall right after onboarding — per-language lever via Remote Config.
    // EN sees the offer here because English installs churn before they ever
    // reach locked content; UA keeps the softer flow, where the first paywall
    // touchpoint is the first locked-content tap.
    if (RemoteConfigService.instance
        .showOnboardingPaywallFor(_selectedLang)) {
      await runPaywallFlow(context, ref, isOnboarding: true);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// The magic moment drives its own CTA: when it is the last step it wraps
  /// up onboarding, otherwise (EN) it hands over to the age picker.
  void _onMagicComplete() {
    if (_page >= _pages.length - 1) {
      _finish();
    } else {
      _next();
    }
  }

  Widget _buildStep(_OnbStep step) {
    switch (step) {
      case _OnbStep.setup:
        return _ChildSetupPage(
          nameCtrl: _nameCtrl,
          selectedAvatar: _selectedAvatar,
          avatars: _avatars,
          onAvatarSelect: (a) => setState(() => _selectedAvatar = a),
          lang: _selectedLang,
        );
      case _OnbStep.age:
        return _AgePage(
          lang: _selectedLang,
          childName: _nameCtrl.text.trim(),
          selectedLevel: _selectedLevel,
          onSelect: (lvl) {
            AnalyticsService.instance.logOnboardingAgeSelected(lvl);
            setState(() => _selectedLevel = lvl);
          },
        );
      case _OnbStep.magic:
        return _MagicMomentPage(
          key: const ValueKey('magic-moment'),
          childName: _nameCtrl.text.trim(),
          level: _selectedLevel,
          lang: _selectedLang,
          onComplete: _onMagicComplete,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideCta = _pages[_page] == _OnbStep.magic;
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots — faded out on the magic moment, which has its
            // own three card dots; two rows of dots read as two progress bars
            // (audit #4). Faded, not removed: dropping this child shifts the
            // PageView's slot in the Column and Flutter rebuilds it from page
            // zero, right as the flow advances.
            AnimatedOpacity(
              opacity: hideCta ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? kAccent
                        : kAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: _pages.map(_buildStep).toList(),
              ),
            ),

            // Next / Start button (hidden on Magic Moment — it drives its own CTA)
            if (!hideCta)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canProceed ? _next : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: Text(
                      _selectedLang == 'en'
                          ? (isLast ? "Let's start →" : 'Next →')
                          : (isLast ? 'Почати →' : 'Далі →'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Page 1 — Child setup (language is auto-detected from system locale)
// ─────────────────────────────────────────────

class _ChildSetupPage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String selectedAvatar;
  final List<String> avatars;
  final ValueChanged<String> onAvatarSelect;
  final String lang;

  const _ChildSetupPage({
    required this.nameCtrl,
    required this.selectedAvatar,
    required this.avatars,
    required this.onAvatarSelect,
    required this.lang,
  });

  bool get _isEn => lang == 'en';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(selectedAvatar,
                  style: const TextStyle(fontSize: 72)),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _isEn ? 'Nice to meet you!' : 'Знайомство',
              style: TextStyle(
                  fontSize: responsiveFont(context, 26),
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameCtrl,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: responsiveFont(context, 18)),
            decoration: InputDecoration(
              labelText: _isEn
                  ? "Child's name (optional)"
                  : 'Як звати дитину? (не обовʼязково)',
              hintText: _isEn ? 'e.g. Emma' : 'Наприклад: Оленка',
              counterText: '',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              prefixIcon: const Icon(Icons.child_care_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isEn ? 'Choose an avatar' : 'Оберіть аватар',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final w = MediaQuery.of(context).size.width;
              final cols = w < kSmallScreen + 80 ? 4 : 6; // 4 cols below ~440dp
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: avatars.map((emoji) {
              final isSelected = emoji == selectedAvatar;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAvatarSelect(emoji);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kAccent.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: kAccent, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
              );
            }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Page 3 — Age picker
// ─────────────────────────────────────────────

class _AgePage extends StatelessWidget {
  final String lang;
  final String childName;
  final int selectedLevel;
  final ValueChanged<int> onSelect;

  const _AgePage({
    required this.lang,
    required this.childName,
    required this.selectedLevel,
    required this.onSelect,
  });

  bool get _isEn => lang == 'en';

  String get _title {
    if (childName.isEmpty) {
      return _isEn ? 'How old is your little one?' : 'Скільки років малюку?';
    }
    return _isEn ? 'How old is $childName?' : 'Скільки років $childName?';
  }

  @override
  Widget build(BuildContext context) {
    final options = _isEn
        ? const [
            (1, '1–2', 'years'),
            (2, '2–3', 'years'),
            (3, '3–4', 'years'),
            (4, '4–5', 'years'),
          ]
        : const [
            (1, '1–2', 'роки'),
            (2, '2–3', 'роки'),
            (3, '3–4', 'роки'),
            (4, '4–5', 'років'),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('🎂', style: TextStyle(fontSize: screenScale(context) * 64)),
          const SizedBox(height: 20),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: responsiveFont(context, 26),
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _isEn
                ? "We'll pick the right cards for their age"
                : 'Підберемо картки відповідно до віку',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: options
                .map((opt) => _AgeCard(
                      level: opt.$1,
                      ageLabel: opt.$2,
                      unit: opt.$3,
                      selected: selectedLevel == opt.$1,
                      onTap: () => onSelect(opt.$1),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AgeCard extends StatelessWidget {
  final int level;
  final String ageLabel;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  const _AgeCard({
    required this.level,
    required this.ageLabel,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? kAccent.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kAccent : Colors.grey.shade300,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ageLabel,
              style: TextStyle(
                fontSize: responsiveFont(context, 36),
                fontWeight: FontWeight.w900,
                color: selected ? kAccent : const Color(0xFF3F3635),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? kAccent.withValues(alpha: 0.8)
                    : Colors.grey[600],
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              const Icon(Icons.check_circle_rounded,
                  color: kAccent, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Page 4 — Magic Moment
// ─────────────────────────────────────────────

class _MagicMomentPage extends ConsumerStatefulWidget {
  final String childName;
  final int level;
  final String lang;
  final VoidCallback onComplete;

  const _MagicMomentPage({
    super.key,
    required this.childName,
    required this.level,
    required this.lang,
    required this.onComplete,
  });

  @override
  ConsumerState<_MagicMomentPage> createState() => _MagicMomentPageState();
}

class _MagicMomentPageState extends ConsumerState<_MagicMomentPage>
    with TickerProviderStateMixin, ConfettiOverlayMixin {
  late final AnimationController _bounceCtrl;
  Timer? _settleTimer;
  List<CardModel> _cards = const [];
  int _currentIndex = 0;
  bool _ready = false;
  bool _celebrating = false;

  bool get _isEn => widget.lang == 'en';

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    // Two bobs to say hello, then hold still: the only thing moving on this
    // screen must be the card the child is meant to tap (audit #1).
    _settleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _bounceCtrl.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStarterCards());
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _bounceCtrl.dispose();
    disposeConfetti();
    super.dispose();
  }

  Future<void> _loadStarterCards() async {
    try {
      // Load cards directly from the asset matching widget.lang — the active
      // profile language isn't persisted until onboarding finishes, so we can
      // not rely on packsProvider here (it would hand back UK cards for an
      // EN-selecting user).
      final assetPath = _isEn
          ? 'assets/data/en_cards.json'
          : 'assets/data/uk_cards.json';
      final raw = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(raw) as List<dynamic>;
      final packs = jsonList
          .map((e) => PackModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final pack = _pickStarterPack(packs);
      if (pack == null || pack.cards.length < 3) {
        widget.onComplete();
        return;
      }
      if (!mounted) return;
      setState(() {
        _cards = pack.cards.take(3).toList();
        _ready = true;
      });
      // The first tap must answer instantly: a cold disk load in front of
      // the very first word is latency the parent reads as "broken".
      AudioService.instance.warm(_cards.map((c) => c.audioKey));
      AnalyticsService.instance.logOnboardingMagicMomentStart();
    } catch (_) {
      if (mounted) widget.onComplete();
    }
  }

  PackModel? _pickStarterPack(List<PackModel> packs) {
    final preferred = _isEn
        ? const ['en_animals', 'en_home']
        : const ['animals', 'rozmovlyalky'];

    bool isEligible(PackModel p) => !p.isLocked && p.cards.length >= 3;

    for (final id in preferred) {
      for (final p in packs) {
        if (p.id == id && isEligible(p)) return p;
      }
    }
    // Fallback — first unlocked pack with ≥3 cards
    for (final p in packs) {
      if (isEligible(p)) return p;
    }
    return null;
  }

  bool _advancing = false;
  Completer<void>? _skip;

  /// Longest the card stays put after a tap. Word + phrase run ~2–3 s; past
  /// this the flip happens with the audio still playing rather than the
  /// screen appearing frozen.
  static const _maxWaitPerCard = Duration(milliseconds: 2500);

  Future<void> _onCardTap() async {
    if (_celebrating || _cards.isEmpty) return;
    if (_advancing) {
      // A second tap while the word is still playing means "next". Taps
      // used to be swallowed here until playback ended — a toddler taps
      // again within a second, and a parent who sees nothing happen for
      // three seconds concludes the app is broken. English installs meet
      // this screen first, and 4 of 11 left it without finishing.
      if (!(_skip?.isCompleted ?? true)) _skip!.complete();
      return;
    }
    _advancing = true;
    _skip = Completer<void>();
    final card = _cards[_currentIndex];
    HapticFeedback.mediumImpact();

    AnalyticsService.instance
        .logOnboardingMagicMomentCardTap(_currentIndex + 1);

    showConfetti();
    final wasLast = _currentIndex >= _cards.length - 1;

    try {
      // Let the word+phrase finish before flipping, but never hold the
      // screen hostage to it: a second tap or the cap moves on.
      await Future.any<void>([
        AudioService.instance.speakCard(card.audioKey, card.sound, card.text),
        _skip!.future,
        Future<void>.delayed(_maxWaitPerCard),
      ]);
      if (!mounted) return;
      if (wasLast) {
        AnalyticsService.instance.logOnboardingMagicMomentComplete();
        // No "You did it" modal: the mascot says it, confetti and a recorded
        // praise clip land it, and the flow moves on by itself. A dialog here
        // was the first of five adult modals between the child's third tap
        // and the first real card (audit #5).
        setState(() => _celebrating = true);
        showConfetti(linger: const Duration(milliseconds: 1800));
        unawaited(
            AudioService.instance.playPraise(isEn: _isEn, always: true));
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        if (mounted) widget.onComplete();
      } else {
        setState(() => _currentIndex += 1);
      }
    } finally {
      // A frozen onboarding is the one outcome this screen may never have.
      _advancing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return _buildContent();
  }

  Widget _buildContent() {
    final card = _cards[_currentIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _BouncingMascot(controller: _bounceCtrl),
          const SizedBox(height: 8),
          _SpeechBubble(
            text: _bubbleText(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _MagicCard(
                  key: ValueKey(card.id),
                  card: card,
                  speaking: AudioService.instance.isSpeaking,
                  onTap: _onCardTap,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProgressDots(total: _cards.length, current: _currentIndex),
          const SizedBox(height: 14),
          Text(
            _isEn
                ? 'Tap the card to hear the word!'
                : 'Натисни на картку, щоб почути слово!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsiveFont(context, 16),
              fontWeight: FontWeight.w600,
              color: DT.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _bubbleText() {
    final name = widget.childName;
    if (_celebrating) {
      if (_isEn) return name.isEmpty ? 'You did it! 🎉' : 'You did it, $name! 🎉';
      return name.isEmpty ? 'Молодець! 🎉' : 'Молодець, $name! 🎉';
    }
    if (_isEn) {
      final greeting = name.isEmpty ? 'Hi, friend!' : 'Hi, $name!';
      return "$greeting I'm Bloom. Tap the card!";
    }
    final greeting = name.isEmpty ? 'Привіт, друже!' : 'Привіт, $name!';
    return '$greeting Я — Зайчик. Натисни на картку!';
  }
}

// ─────────────────────────────────────────────
//  Magic Moment — sub-widgets
// ─────────────────────────────────────────────

class _BouncingMascot extends StatelessWidget {
  final AnimationController controller;
  const _BouncingMascot({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(controller.value);
        final dy = -8.0 * t; // bob up then reverse
        return Transform.translate(
          offset: Offset(0, dy),
          child: const BloomMascot(size: 96, emotion: BloomEmotion.waving),
        );
      },
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: DT.shadowSoft(Colors.black.withValues(alpha: 0.15)),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: responsiveFont(context, 15),
            fontWeight: FontWeight.w700,
            color: DT.textPrimary,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _MagicCard extends StatefulWidget {
  final CardModel card;
  final ValueListenable<bool> speaking;
  final VoidCallback onTap;

  const _MagicCard({
    super.key,
    required this.card,
    required this.speaking,
    required this.onTap,
  });

  @override
  State<_MagicCard> createState() => _MagicCardState();
}

/// The one tappable thing on the screen has to look tappable: a slow
/// breathing pulse invites the tap, a press-scale answers it, and the word
/// pulses while the clip plays so a muted phone still shows "it worked".
/// Before this the mascot moved and the card sat still (audit #1).
class _MagicCardState extends State<_MagicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final wordColor = DT.onTint(card.colorAccent);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fill the space it is given: ~85% of the width, but never so
          // tall that the tap target loses the centre of the screen.
          final byWidth = constraints.maxWidth * 0.85;
          final byHeight = constraints.maxHeight * 0.92 * (280 / 320);
          final w = math.min(byWidth, byHeight).clamp(220.0, 340.0);
          final h = w * (320 / 280);
          return AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              final breath = 1.0 + 0.04 * Curves.easeInOut.transform(_breath.value);
              final scale = _pressed ? DT.pressScale : breath;
              return AnimatedScale(
                scale: scale,
                duration: DT.pressMs,
                curve: Curves.easeOut,
                child: child,
              );
            },
            child: SizedBox(
              width: w,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  color: card.colorBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: card.colorAccent, width: 3),
                  boxShadow: DT.shadowSoft(card.colorAccent),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: card.image != null
                            ? Image(
                                image: AssetPackService.instance
                                    .cardImage(card.image),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(card.emoji,
                                      style: const TextStyle(fontSize: 120)),
                                ),
                              )
                            : Center(
                                child: Text(card.emoji,
                                    style: const TextStyle(fontSize: 120)),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: widget.speaking,
                        builder: (context, speaking, child) => AnimatedScale(
                          scale: speaking ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: child,
                        ),
                        child: Text(
                          card.sound,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: responsiveFont(context, 32),
                            fontWeight: FontWeight.w900,
                            color: wordColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int total;
  final int current;
  const _ProgressDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current;
        final color = done
            ? kAccent.withValues(alpha: 0.6)
            : active
                ? kAccent
                : Colors.grey.withValues(alpha: 0.3);
        return AnimatedContainer(
          key: ValueKey('mm-dot-$i'),
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 14 : 10,
          height: active ? 14 : 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      }),
    );
  }
}
