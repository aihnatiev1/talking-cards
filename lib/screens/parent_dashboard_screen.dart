import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/app_review_provider.dart';
import '../providers/daily_stats_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/practice_suggestion_provider.dart';
import '../providers/weak_words_provider.dart';
import '../providers/listen_enabled_provider.dart';
import '../providers/word_evidence_provider.dart';
import '../screens/profile_selector_screen.dart';
import '../services/notification_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/activity_chart.dart';
import '../widgets/card_image.dart';
import '../widgets/settings_action_row.dart';
import '../widgets/word_wall_share.dart';
import 'voice_check_screen.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: GestureDetector(
            onTap: () => showProfileSelector(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.active?.avatarEmoji ?? '👶',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  profile.active?.name ?? s('Малюк', 'Kiddo'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
          centerTitle: false,
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
            isScrollable: MediaQuery.of(context).size.width < kLargeScreen,
            tabAlignment: MediaQuery.of(context).size.width >= kLargeScreen
                ? TabAlignment.fill
                : TabAlignment.start,
            labelStyle: TextStyle(
              fontSize: responsiveFont(context, 13),
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: responsiveFont(context, 13),
            ),
            tabs: [
              Tab(text: s('Огляд', 'Overview')),
              Tab(text: s('Тиждень', 'Week')),
              Tab(text: s('Слова', 'Words')),
              Tab(text: s('Паки', 'Packs')),
              Tab(text: s('Ігри', 'Games')),
              Tab(text: s('Помилки', 'Mistakes')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _WeeklyTab(),
            _WordsTab(),
            _PacksTab(),
            _GamesTab(),
            _WeakWordsTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 1 — Overview
// ─────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final packProgress = ref.watch(packProgressProvider);
    final dailyStats = ref.watch(dailyStatsProvider);
    final evidence = ref.watch(wordEvidenceProvider);
    final suggestion = ref.watch(practiceSuggestionProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    // Three different claims, kept apart on purpose. A view is the app
    // showing a card; a recognition is the child choosing right in a game;
    // a mark is a grown-up saying it came out. Only the last one is about
    // speech, and only a human can make it.
    final seen = packProgress.values.fold(0, (a, b) => a + b);
    final recognized = evidence.recognizedIds.length;
    final marked = evidence.parentMarkedIds.length;
    final activeDays = dailyStats.values.where((v) => v > 0).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle(s('Що показують дані', 'What the data shows')),
        const SizedBox(height: 8),
        _statRow([
          _StatCard(
            icon: AppIcon.stepCards,
            label: s('Переглянули', 'Seen'),
            value: isEn
                ? '$seen ${seen == 1 ? 'card' : 'cards'}'
                : '$seen карток',
            color: DT.brand,
          ),
          _StatCard(
            icon: AppIcon.navGames,
            label: s('Впізнали у грі', 'Recognized in a game'),
            value: isEn
                ? '$recognized ${recognized == 1 ? 'word' : 'words'}'
                : '$recognized слів',
            color: DT.teal,
          ),
        ]),
        const SizedBox(height: 12),
        _statRow([
          _StatCard(
            icon: AppIcon.check,
            label: s('Позначили ви', 'You marked'),
            value: isEn
                ? '$marked ${marked == 1 ? 'word' : 'words'}'
                : '$marked слів',
            color: DT.success,
          ),
          _StatCard(
            icon: AppIcon.calendar,
            label: s('Активних днів', 'Active days'),
            value: '$activeDays',
            color: DT.violet,
          ),
        ]),
        const SizedBox(height: 10),
        _HonestNote(
          text: s(
            'Переглянуте — це побачені картки. Впізнане — правильні '
                'відповіді в іграх. Позначене — ваша оцінка у грі «Повтори '
                'за мною». Застосунок не чує дитину й не оцінює мовлення.',
            'Seen means cards shown. Recognized means correct answers in '
                'games. Marked is your own call in "Repeat after me". The '
                'app does not listen to your child and does not assess speech.',
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(s('Цей тиждень', 'This week')),
        const SizedBox(height: 8),
        _WeeklySummaryCard(
          views: ref.read(dailyStatsProvider.notifier).last7Days().fold(
            0,
            (sum, e) => sum + e.value,
          ),
          recognized: evidence.recognizedSince(7),
          marked: evidence.parentMarkedSince(7),
          streakDays: streak.currentStreak,
          isEn: isEn,
        ),
        const SizedBox(height: 24),
        _sectionTitle(s('Спробуйте разом', 'Try together')),
        const SizedBox(height: 8),
        _PracticeSuggestionCard(
          words: [for (final card in suggestion) card.sound],
          isEn: isEn,
        ),
        const SizedBox(height: 24),
        _sectionTitle(s('Досягнення', 'Achievements')),
        const SizedBox(height: 8),
        if (streak.unlockedRewards.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const AppIconView(AppIcon.stickerAlbum, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    s(
                      'Тут з’являться перші нагороди. Повертайтеся до занять і збирайте досягнення разом!',
                      'Your first rewards will appear here. Keep learning and collect achievements together!',
                    ),
                    style: TextStyle(
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: streak.unlockedRewards
              .map(
                (e) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: DT.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        _sectionTitle(s('Налаштування', 'Settings')),
        const SizedBox(height: 8),
        // Theme lives here (not in the child-reachable about dialog) so a
        // toddler tap can't flip the whole app to dark mode.
        SwitchListTile(
          value: ref.watch(themeModeProvider) == ThemeMode.dark,
          onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          secondary: const Icon(Icons.dark_mode_rounded),
          title: Text(s('Темна тема', 'Dark theme')),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        // Reminder time and frequency — this screen is behind the parental
        // gate, which is where a setting that changes what the phone does
        // at 10:00 belongs.
        const _ReminderSettingsTile(),
        const SizedBox(height: 8),
        // The microphone. Off until this is turned on, and the wording is
        // the promise: the app notices that a turn was taken, it does not
        // judge how a word was said and it keeps nothing.
        SwitchListTile(
          value: ref.watch(listenEnabledProvider),
          onChanged: (v) => ref.read(listenEnabledProvider.notifier).set(v),
          secondary: const Icon(Icons.record_voice_over_rounded),
          title: Text(s('Скажи за мною', 'Say it with me')),
          subtitle: Text(
            s(
              'У грі «Повтори за мною» застосунок сам помічає, що дитина '
                  'сказала слово. Нічого не записується і не оцінюється.',
              'In “Repeat after me” the app notices that your child took a '
                  'turn. Nothing is recorded and nothing is judged.',
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        // Speak & Repeat's thresholds have to be checked in the room they
        // will be used in, not at a desk. The HUD turns the microphone on
        // only while it is open and puts it back afterwards.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mic_rounded),
          title: Text(s('Перевірка мікрофона', 'Microphone check')),
          subtitle: Text(
            s(
              'Подивитись, що чує застосунок. Нічого не записується.',
              'See what the app hears. Nothing is recorded.',
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  VoiceCheckScreen(isEn: ref.read(languageProvider) == 'en'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _RateAppTile(
          label: s('Оцінити додаток', 'Rate the app'),
          onTap: () => ref.read(appReviewControllerProvider).requestReview(),
        ),
      ],
    );
  }

  Widget _statRow(List<Widget> children) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
          ],
        );
      }
      return Row(
        children: children
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

/// When reminders arrive — the grown-up decides, not the app.
///
/// Lives in the parent dashboard, which is only reachable through the
/// parental gate — Material icons and an adult tone are correct here.
///
/// Two settings and nothing else: the hour of day and "every day" vs "a few
/// times a week". There is deliberately no way to ask for *more* reminders.
class _ReminderSettingsTile extends ConsumerStatefulWidget {
  const _ReminderSettingsTile();

  @override
  ConsumerState<_ReminderSettingsTile> createState() =>
      _ReminderSettingsTileState();
}

class _ReminderSettingsTileState extends ConsumerState<_ReminderSettingsTile> {
  int _hour = NotificationService.defaultReminderHour;
  ReminderFrequency _frequency = ReminderFrequency.daily;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hour = await NotificationService.instance.reminderHour;
    final frequency = await NotificationService.instance.frequency;
    if (!mounted) return;
    setState(() {
      _hour = hour;
      _frequency = frequency;
      _loaded = true;
    });
  }

  Future<void> _apply({int? hour, ReminderFrequency? frequency}) async {
    setState(() {
      _hour = hour ?? _hour;
      _frequency = frequency ?? _frequency;
    });
    await NotificationService.instance.setReminderSchedule(
      hour: _hour,
      frequency: _frequency,
      lang: ref.read(languageProvider),
    );
  }

  Future<void> _pickHour() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: 0),
      helpText: AppS(ref.read(languageProvider) == 'en')(
        'Коли надсилати нагадування',
        'When to send reminders',
      ),
    );
    if (picked == null) return;
    await _apply(hour: picked.hour);
  }

  Future<void> _openSheet() async {
    final s = AppS(ref.read(languageProvider) == 'en');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (_, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s('Нагадування', 'Reminders'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s(
                    'Час і частоту обираєте ви. Нагадування — це запрошення, '
                        'а не завдання.',
                    'You choose the time and how often. A reminder is an '
                        'invitation, not a task.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: const ValueKey('reminder_hour_row'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(s('Час', 'Time')),
                  trailing: Text(
                    _formatHour(_hour),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    await _pickHour();
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 4),
                for (final option in ReminderFrequency.values)
                  ListTile(
                    key: ValueKey('reminder_frequency_${option.name}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _frequency == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _frequency == option
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    title: Text(_frequencyLabel(option, s)),
                    onTap: () async {
                      await _apply(frequency: option);
                      setSheetState(() {});
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatHour(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';

  static String _frequencyLabel(ReminderFrequency f, AppS s) => switch (f) {
    ReminderFrequency.daily => s('Щодня', 'Every day'),
    ReminderFrequency.fewTimesAWeek => s(
      'Три рази на тиждень',
      'Three times a week',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = AppS(ref.watch(languageProvider) == 'en');
    if (!_loaded) return const SizedBox.shrink();
    final schedule = _frequency == ReminderFrequency.daily
        ? s('щодня о ${_formatHour(_hour)}', 'every day at ${_formatHour(_hour)}')
        : s(
            'тричі на тиждень о ${_formatHour(_hour)}',
            'three times a week at ${_formatHour(_hour)}',
          );
    return SettingsActionRow(
      key: const ValueKey('reminder_settings_tile'),
      icon: Icons.notifications_none_rounded,
      label: s('Нагадування — $schedule', 'Reminders — $schedule'),
      onTap: _openSheet,
    );
  }
}

/// One quiet paragraph that says what the numbers above are — and what
/// they are not. Parents read "learned" as "my child can say it"; the app
/// has no microphone and must not let that stand.
class _HonestNote extends StatelessWidget {
  final String text;

  const _HonestNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Seven days in three numbers, plus days in a row stated as a fact and
/// never as something at risk.
class _WeeklySummaryCard extends StatelessWidget {
  final int views;
  final int recognized;
  final int marked;
  final int streakDays;
  final bool isEn;

  const _WeeklySummaryCard({
    required this.views,
    required this.recognized,
    required this.marked,
    required this.streakDays,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    final colors = Theme.of(context).colorScheme;
    final lines = <String>[
      s('Переглянуто карток: $views', 'Cards seen: $views'),
      s('Впізнано у грі: $recognized', 'Recognized in a game: $recognized'),
      s('Ви позначили: $marked', 'You marked: $marked'),
      if (streakDays > 0)
        s('Днів поспіль: $streakDays', 'Days in a row: $streakDays'),
    ];
    return Container(
      key: const ValueKey('weekly_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: responsiveFont(context, 13.5),
                  height: 1.35,
                  color: colors.onSurface,
                ),
              ),
            ),
          if (views == 0 && recognized == 0 && marked == 0)
            Text(
              s(
                'Цього тижня занять ще не було.',
                'No sessions this week yet.',
              ),
              style: TextStyle(
                fontSize: responsiveFont(context, 13),
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// One concrete thing to do together today — named words, not advice.
class _PracticeSuggestionCard extends StatelessWidget {
  final List<String> words;
  final bool isEn;

  const _PracticeSuggestionCard({required this.words, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    final colors = Theme.of(context).colorScheme;
    final text = words.isEmpty
        ? s(
            'Пограйте разом у будь-яку гру — і тут з’являться слова, які '
                'варто повторити.',
            'Play any game together and the words worth repeating will '
                'appear here.',
          )
        : s(
            'Спробуйте сьогодні повторити разом: ${words.join(', ')}.',
            'Try repeating these together today: ${words.join(', ')}.',
          );
    return Container(
      key: const ValueKey('practice_suggestion_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DT.brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DT.brand.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: responsiveFont(context, 14),
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  /// The same drawing the child sees on the tabs and the quest map — the
  /// parent zone speaks one visual language with the kid zone (G15).
  final AppIcon icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconView(icon, size: responsiveFont(context, 28)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveFont(context, 18),
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: responsiveFont(context, 12),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Explicit, parent-initiated "Rate the app" action. It is never triggered
/// automatically — a tap opens the OS-native, in-app review sheet (which is
/// rate-limited by the OS and never leaves the app), so it stays child-safe
/// even though the Parent area is not behind a parental gate.
class _RateAppTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RateAppTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DT.brand.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 2 — Weekly chart
// ─────────────────────────────────────────────

class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dailyStatsProvider); // rebuild when stats change
    final chartData = ref.read(dailyStatsProvider.notifier).last7Days();
    final totalWeek = chartData.fold(0, (sum, e) => sum + e.value);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    final weeklyMsg = totalWeek == 0
        ? s('Ще немає активності цього тижня.', 'No activity this week yet.')
        : totalWeek < 20
        ? s(
            'Гарний початок! Продовжуй кожен день 💪',
            'Nice start! Keep going every day 💪',
          )
        : totalWeek < 50
        ? s('Чудовий прогрес! 🌟', 'Great progress! 🌟')
        : s(
            'Неймовірна активність цього тижня! 🏆',
            'Amazing week of activity! 🏆',
          );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn
                ? 'Cards in 7 days: $totalWeek'
                : 'Карток за 7 днів: $totalWeek',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ActivityChart(data: chartData, isEn: isEn),
          const SizedBox(height: 24),
          Text(
            weeklyMsg,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 3 — Word Wall (words with evidence behind them)
// ─────────────────────────────────────────────

class _WordsTab extends ConsumerWidget {
  const _WordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidence = ref.watch(wordEvidenceProvider);
    final packsAsync = ref.watch(packsProvider);
    final profile = ref.watch(profileProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final childName = profile.active?.name ?? s('Малюк', 'Kiddo');

    // Words the child picked correctly in a game, plus words a grown-up
    // marked as "came out". Views are not in here: a card that scrolled
    // past is not a word in the chest.
    final learnedIds = evidence.evidencedIds;

    if (learnedIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📚', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                s(
                  'Тут з’являться слова, які малюк упізнав у грі або які ви '
                      'позначили в «Повтори за мною».',
                  'Words your child recognized in a game — or that you '
                      'marked in "Repeat after me" — will appear here.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return packsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(s('Помилка', 'Error'))),
      data: (packs) {
        // Group learned cards by pack, preserve original card order in pack
        final groups =
            <
              (
                String packId,
                String packTitle,
                String packIcon,
                List<CardModel> cards,
              )
            >[];
        final allLearnedCards = <CardModel>[];
        for (final pack in packs) {
          final cards = pack.cards
              .where((c) => learnedIds.contains(c.id))
              .toList();
          if (cards.isEmpty) continue;
          groups.add((pack.id, pack.title, pack.icon, cards));
          allLearnedCards.addAll(cards);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WordWallHeader(
              childName: childName,
              learnedCount: allLearnedCards.length,
              recognizedCount: evidence.recognizedIds.length,
              markedCount: evidence.parentMarkedIds.length,
              isEn: isEn,
              onShare: () => shareWordWall(
                context: context,
                childName: childName,
                learnedCards: allLearnedCards,
                isEn: isEn,
              ),
            ),
            const SizedBox(height: 20),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(group.$3, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${group.$4.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: group.$4.length,
                itemBuilder: (_, i) => _LearnedTile(card: group.$4[i]),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _WordWallHeader extends StatelessWidget {
  final String childName;
  final int learnedCount;
  final int recognizedCount;
  final int markedCount;
  final bool isEn;
  final VoidCallback onShare;

  const _WordWallHeader({
    required this.childName,
    required this.learnedCount,
    required this.recognizedCount,
    required this.markedCount,
    required this.isEn,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DT.brand, DT.teal],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? "$childName's Word Wall" : 'Стіна слів — $childName',
                  style: TextStyle(
                    fontSize: responsiveFont(context, 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? '$recognizedCount recognized in a game · '
                            '$markedCount marked by you'
                      : '$recognizedCount впізнано у грі · '
                            '$markedCount позначили ви',
                  style: TextStyle(
                    fontSize: responsiveFont(context, 11.5),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$learnedCount',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 36),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        isEn ? (learnedCount == 1 ? 'word' : 'words') : 'слів',
                        style: TextStyle(
                          fontSize: responsiveFont(context, 13),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(isEn ? 'Share' : 'Поділитись'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: DT.brand,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnedTile extends StatelessWidget {
  final CardModel card;

  const _LearnedTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: card.colorBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: card.colorAccent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: CardImage.forCard(
                card,
                fit: BoxFit.cover,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          card.sound,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: responsiveFont(context, 11),
            fontWeight: FontWeight.w700,
            color: card.colorAccent,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 4 — Pack progress
// ─────────────────────────────────────────────

class _PacksTab extends ConsumerWidget {
  const _PacksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(packsProvider);
    final packProgress = ref.watch(packProgressProvider);
    final completedPacks = ref.watch(completedPacksProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return packsAsync.when(
      data: (packs) {
        final regular = packs.where((p) => !p.id.startsWith('_')).toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: regular.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final pack = regular[i];
            final seen = packProgress[pack.id] ?? 0;
            final total = pack.cards.length;
            final ratio = total > 0 ? seen / total : 0.0;
            final isDone = completedPacks.contains(pack.id);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pack.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: pack.color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(pack.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pack.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: pack.color,
                                ),
                              ),
                            ),
                            if (isDone)
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: pack.color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pack.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn
                              ? '$seen / $total ${total == 1 ? 'card' : 'cards'}'
                              : '$seen / $total карток',
                          style: TextStyle(
                            fontSize: 11,
                            color: pack.color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          Center(child: Text(s('Помилка завантаження', 'Loading error'))),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 4 — Games
// ─────────────────────────────────────────────

class _GamesTab extends ConsumerWidget {
  const _GamesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gameStatsProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final played = stats.where((g) => g.plays > 0).toList();

        if (played.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎮', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    s(
                      'Ще не грали в жодну гру.\nЗапустіть будь-яку гру з головного екрану!',
                      'No games played yet.\nTry any game from the home screen!',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        final totalPlays = stats.fold(0, (s, g) => s + g.plays);
        final favorite = stats.reduce((a, b) => a.plays >= b.plays ? a : b);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Summary row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: AppIcon.navGames,
                    label: s('Всього сесій', 'Total sessions'),
                    value: '$totalPlays',
                    color: DT.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: appIconForGame(favorite.id),
                    label: s('Улюблена гра', 'Favorite game'),
                    value: isEn ? favorite.labelEn : favorite.labelUk,
                    color: DT.violet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              s('Всі ігри', 'All games'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...stats.map((g) => _GameStatRow(stat: g, isEn: isEn)),
          ],
        );
      },
    );
  }
}

class _GameStatRow extends StatelessWidget {
  final GameStat stat;
  final bool isEn;
  const _GameStatRow({required this.stat, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final hasPlays = stat.plays > 0;
    final s = AppS(isEn);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasPlays
              ? DT.brand.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasPlays
                ? DT.brand.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            AppIconView(
              appIconForGame(stat.id),
              size: responsiveFont(context, 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEn ? stat.labelEn : stat.labelUk,
                style: TextStyle(
                  fontSize: responsiveFont(context, 14),
                  fontWeight: FontWeight.w600,
                  color: hasPlays ? null : Colors.grey[500],
                ),
              ),
            ),
            if (hasPlays) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stat.plays} ${_playsLabel(stat.plays, isEn)}',
                    style: TextStyle(
                      fontSize: responsiveFont(context, 13),
                      fontWeight: FontWeight.w700,
                      color: DT.brand,
                    ),
                  ),
                  if (stat.bestScore > 0)
                    Text(
                      '${s('рекорд', 'best')}: ${stat.bestScore} ⭐',
                      style: TextStyle(
                        fontSize: responsiveFont(context, 11),
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ] else
              Text(
                s('не грали', 'not played'),
                style: TextStyle(
                  fontSize: responsiveFont(context, 12),
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _playsLabel(int n, bool isEn) {
    if (isEn) return n == 1 ? 'time' : 'times';
    if (n == 1) return 'раз';
    if (n >= 2 && n <= 4) return 'рази';
    return 'разів';
  }
}

// ─────────────────────────────────────────────
//  Tab 5 — Weak words
// ─────────────────────────────────────────────

class _WeakWordsTab extends ConsumerWidget {
  const _WeakWordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mistakes = ref.watch(weakWordsProvider);
    final packsAsync = ref.watch(packsProvider);
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    if (mistakes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                s(
                  'Поки немає помилок!\nПродовжуйте грати у вікторину.',
                  'No mistakes yet!\nKeep playing the quiz.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final weakWordsNotifier = ref.read(weakWordsProvider.notifier);
    final top = weakWordsNotifier.topMistakes();

    return packsAsync.when(
      data: (packs) {
        // Build a cardId → CardModel lookup
        final cardMap = <String, CardModel>{};
        for (final pack in packs) {
          for (final card in pack.cards) {
            cardMap[card.id] = card;
          }
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: top.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final entry = top[i];
            final card = cardMap[entry.key];
            if (card == null) return const SizedBox.shrink();

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: card.colorBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(card.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              title: Text(
                card.sound,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: card.text.isEmpty
                  ? null
                  : Text(
                      card.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entry.value}×',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
