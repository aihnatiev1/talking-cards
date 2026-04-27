import 'dart:convert';

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
import '../utils/confetti_overlay_mixin.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../widgets/bloom_mascot.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  int _page = 0;

  String _selectedLang = 'uk';
  String _selectedAvatar = '👶';
  int _selectedLevel = 2;

  static const _totalPages = 4;
  static const _magicMomentPage = 3;

  @override
  void initState() {
    super.initState();
    // Rebuild when name changes so _canProceed is re-evaluated
    _nameCtrl.addListener(() => setState(() {}));
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
    if (_page == 1 && _nameCtrl.text.trim().isNotEmpty) {
      AnalyticsService.instance.logOnboardingNameEntered();
    }
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  bool get _canProceed {
    if (_page == 1) return _nameCtrl.text.trim().isNotEmpty;
    return true;
  }

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

    // Show paywall right after onboarding — peak intent moment.
    // Whether they convert or dismiss, we then proceed to HomeScreen.
    await runPaywallFlow(context, ref, isOnboarding: true);

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

  @override
  Widget build(BuildContext context) {
    final hideCta = _page == _magicMomentPage;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) => AnimatedContainer(
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

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _LanguagePage(
                    selected: _selectedLang,
                    onSelect: (l) {
                      AnalyticsService.instance.logOnboardingLangSelected(l);
                      setState(() => _selectedLang = l);
                    },
                  ),
                  _ChildSetupPage(
                    nameCtrl: _nameCtrl,
                    selectedAvatar: _selectedAvatar,
                    avatars: _avatars,
                    onAvatarSelect: (a) => setState(() => _selectedAvatar = a),
                    lang: _selectedLang,
                  ),
                  _AgePage(
                    lang: _selectedLang,
                    childName: _nameCtrl.text.trim(),
                    selectedLevel: _selectedLevel,
                    onSelect: (lvl) {
                      AnalyticsService.instance.logOnboardingAgeSelected(lvl);
                      setState(() => _selectedLevel = lvl);
                    },
                  ),
                  _MagicMomentPage(
                    key: const ValueKey('magic-moment'),
                    childName: _nameCtrl.text.trim(),
                    level: _selectedLevel,
                    lang: _selectedLang,
                    onComplete: _finish,
                  ),
                ],
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
                      _selectedLang == 'en' ? 'Next →' : 'Далі →',
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
//  Page 1 — Language
// ─────────────────────────────────────────────

class _LanguagePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _LanguagePage({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('🗣️', style: TextStyle(fontSize: screenScale(context) * 64)),
          const SizedBox(height: 20),
          Text(
            selected == 'en' ? 'Choose card language' : 'Виберіть мову карток',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: responsiveFont(context, 26),
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            selected == 'en'
                ? 'Can be changed per child'
                : 'Можна змінити окремо для кожної дитини',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(child: _LangCard(
                flag: '🇺🇦',
                label: 'Українська',
                sublabel: '234 картки',
                selected: selected == 'uk',
                onTap: () => onSelect('uk'),
              )),
              const SizedBox(width: 16),
              Expanded(child: _LangCard(
                flag: '🇬🇧',
                label: 'English',
                sublabel: '209 cards',
                selected: selected == 'en',
                onTap: () => onSelect('en'),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String flag, label, sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _LangCard({
    required this.flag,
    required this.label,
    required this.sublabel,
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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
          children: [
            Text(flag, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? kAccent : null,
                )),
            const SizedBox(height: 4),
            Text(sublabel,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? kAccent.withValues(alpha: 0.7)
                      : Colors.grey[500],
                )),
            if (selected) ...[
              const SizedBox(height: 8),
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
//  Page 2 — Child setup
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
              labelText: _isEn ? "Child's name" : "Як звати дитину?",
              hintText: _isEn ? "e.g. Emma" : "Наприклад: Оленка",
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStarterCards());
  }

  @override
  void dispose() {
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

  Future<void> _onCardTap() async {
    if (_celebrating || _cards.isEmpty || _advancing) return;
    _advancing = true;
    final card = _cards[_currentIndex];
    HapticFeedback.mediumImpact();

    AnalyticsService.instance
        .logOnboardingMagicMomentCardTap(_currentIndex + 1);

    showConfetti();
    final wasLast = _currentIndex >= _cards.length - 1;

    // Wait for the full word+phrase playback to finish before flipping to
    // the next card so the audio is never cut off mid-word.
    await AudioService.instance.speakCard(card.audioKey, card.sound, card.text);
    if (!mounted) {
      _advancing = false;
      return;
    }

    if (wasLast) {
      AnalyticsService.instance.logOnboardingMagicMomentComplete();
      setState(() => _celebrating = true);
    } else {
      setState(() => _currentIndex += 1);
    }
    _advancing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return Stack(
      children: [
        _buildContent(),
        if (_celebrating) _CelebrationOverlay(
          isEn: _isEn,
          childName: widget.childName,
          onContinue: widget.onComplete,
        ),
      ],
    );
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
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _bubbleText() {
    final name = widget.childName;
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

class _MagicCard extends StatelessWidget {
  final CardModel card;
  final VoidCallback onTap;

  const _MagicCard({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth * 0.85).clamp(220.0, 280.0);
          final h = w * (320 / 280);
          return SizedBox(
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
                          ? Image.asset(
                              'assets/images/webp/${card.image}.webp',
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
                    child: Text(
                      card.sound,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsiveFont(context, 32),
                        fontWeight: FontWeight.w900,
                        color: card.colorAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
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

class _CelebrationOverlay extends ConsumerStatefulWidget {
  final bool isEn;
  final String childName;
  final VoidCallback onContinue;

  const _CelebrationOverlay({
    required this.isEn,
    required this.childName,
    required this.onContinue,
  });

  @override
  ConsumerState<_CelebrationOverlay> createState() =>
      _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<_CelebrationOverlay>
    with ConfettiOverlayMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showConfetti(linger: const Duration(milliseconds: 2200));
    });
  }

  @override
  void dispose() {
    disposeConfetti();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.childName;
    final title = widget.isEn
        ? (name.isEmpty ? 'You did it! 🎉' : 'You did it, $name! 🎉')
        : (name.isEmpty ? 'Молодець! 🎉' : 'Молодець, $name! 🎉');
    final subtitle = widget.isEn
        ? 'You learned 3 new words!'
        : 'Ти вивчив 3 нових слова!';

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: DT.shadowLift(kAccent),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BloomMascot(size: 96, emotion: BloomEmotion.waving),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: responsiveFont(context, 24),
                      fontWeight: FontWeight.w900,
                      color: DT.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: responsiveFont(context, 15),
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onContinue();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.isEn ? 'Continue →' : 'Далі →',
                        style: TextStyle(
                            fontSize: responsiveFont(context, 17),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
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
