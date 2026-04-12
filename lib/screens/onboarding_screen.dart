import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/profile_provider.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
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

  @override
  void initState() {
    super.initState();
    // Rebuild when name changes so _canProceed is re-evaluated
    _nameCtrl.addListener(() => setState(() {}));
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
    if (_page < 2) {
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

    // Mark onboarding as completed so we never show it again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    AnalyticsService.instance.logOnboardingComplete();

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
                children: List.generate(3, (i) => AnimatedContainer(
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
                    onSelect: (l) => setState(() => _selectedLang = l),
                  ),
                  _ChildSetupPage(
                    nameCtrl: _nameCtrl,
                    selectedAvatar: _selectedAvatar,
                    avatars: _avatars,
                    onAvatarSelect: (a) => setState(() => _selectedAvatar = a),
                    lang: _selectedLang,
                  ),
                  _FeaturesPage(lang: _selectedLang),
                ],
              ),
            ),

            // Next / Start button
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
                    _page == 2
                        ? (_selectedLang == 'en' ? "Let's start! 🚀" : 'Почнемо! 🚀')
                        : (_selectedLang == 'en' && _page > 0 ? 'Next →' : 'Далі →'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
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
          const Text('🗣️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          const Text(
            'Яку мову вчимо?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Можна змінити окремо для кожної дитини',
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
            child: Text(selectedAvatar,
                style: const TextStyle(fontSize: 72)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _isEn ? 'Nice to meet you!' : 'Знайомство',
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameCtrl,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 18),
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
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 6,
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Page 3 — Features
// ─────────────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  final String lang;
  const _FeaturesPage({required this.lang});

  @override
  Widget build(BuildContext context) {
    final isEn = lang == 'en';
    final features = isEn
        ? [
            ('🃏', 'Cards with pictures', '209 words to explore'),
            ('🧠', 'Memory & quiz games', 'Fun learning through play'),
            ('📅', 'Daily quests', 'Build a habit together'),
          ]
        : [
            ('🃏', 'Картки зі звуком', '234 яскравих картки'),
            ('🧠', 'Ігри та вікторина', 'Вчимось через гру'),
            ('📅', 'Щоденні завдання', 'Формуємо звичку разом'),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            isEn ? 'All set!' : 'Все готово!',
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            isEn
                ? "Here's what's waiting for you"
                : 'Ось що є в застосунку',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(f.$1, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(f.$3,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
