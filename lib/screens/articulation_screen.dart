import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/articulation_art.dart';
import '../widgets/kid_screen.dart';

/// Articulation gymnastics — the one screen in the app addressed to the
/// grown-up, not to the child.
///
/// A one-to-four-year-old cannot do tongue exercises from a screen: they
/// copy a face. So this is a reference sheet a parent or a speech
/// therapist reads *aloud* while sitting with the child at a mirror, and
/// it is written in the parent zone's voice — Roboto, plain instructions,
/// no confetti, no reward dots, no mascot, no "Next ▶". The games tab files
/// it under «Для батьків — мовленнєва терапія»; this screen now matches
/// that promise instead of dressing up as a game.
///
/// It keeps `KidScreen` as its shell — the screen is reached from the kid
/// tab, so the 72 dp back control has to sit where it sits everywhere else
/// (`test/architecture/kid_screen_test.dart`) — but nothing else about it
/// is kid-zone: no progress pill, no tint, no play framing.

// ─────────────────────────────────────────────
//  Parent-zone type. Roboto explicitly: `DT.body` / `DT.caption` are
//  Nunito, which is the child's face, and the theme's body slots are
//  Nunito too (`buildAppTheme`). Instructions a grown-up reads paragraph
//  by paragraph want the system face.
// ─────────────────────────────────────────────

const _face = 'Roboto';

const _titleStyle = TextStyle(
  fontFamily: _face,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: DT.textPrimary,
  height: 1.2,
);

const _leadStyle = TextStyle(
  fontFamily: _face,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  color: DT.textSecondary,
  height: 1.45,
);

const _tileNameStyle = TextStyle(
  fontFamily: _face,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: DT.textPrimary,
  height: 1.2,
);

const _labelStyle = TextStyle(
  fontFamily: _face,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: DT.textMuted,
  height: 1.2,
  letterSpacing: 0.6,
);

const _bodyStyle = TextStyle(
  fontFamily: _face,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: DT.textPrimary,
  height: 1.45,
);

const _buttonStyle = TextStyle(
  fontFamily: _face,
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

/// The one accent of this screen: the violet the games tab already uses for
/// the grown-ups' section.
const _accent = DT.violet;

// ─────────────────────────────────────────────
//  Exercise data
// ─────────────────────────────────────────────

@visibleForTesting
class Exercise {
  /// Stable key. Also the illustration's file name
  /// (`assets/images/articulation/<id>.webp`) — see [ArticulationArt].
  final String id;
  final String name;
  final String nameEn;
  final String description;
  final String descriptionEn;
  final List<String> steps;
  final List<String> stepsEn;

  /// How long the position is held, in seconds. Shown as an optional timer.
  final int seconds;

  /// The sounds this exercise prepares. The main reason a therapist picks
  /// one exercise over another, so it is set as a headline, not a chip.
  final List<String> sounds;

  const Exercise({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.description,
    required this.descriptionEn,
    required this.steps,
    required this.stepsEn,
    required this.seconds,
    required this.sounds,
  });
}

@visibleForTesting
const articulationExercises = [
  Exercise(
    id: 'spatula',
    name: 'Лопатка',
    nameEn: 'Spatula',
    description: 'Широкий розслаблений язик лежить на нижній губі',
    descriptionEn: 'A wide, relaxed tongue rests on the lower lip',
    steps: [
      'Відкрийте рота, покажіть рух самі',
      'Широкий язик лягає на нижню губу',
      'Язик розслаблений, не тремтить',
      'Утримувати нерухомо',
    ],
    stepsEn: [
      'Open your mouth and show the move yourself',
      'The wide tongue rests on the lower lip',
      'The tongue stays relaxed, not trembling',
      'Hold it still',
    ],
    seconds: 8,
    sounds: ['Ш', 'Ж', 'Ч', 'С', 'З'],
  ),
  Exercise(
    id: 'needle',
    name: 'Голочка',
    nameEn: 'Needle',
    description: 'Вузький гострий язик витягнутий уперед',
    descriptionEn: 'A narrow, pointed tongue stretched forward',
    steps: [
      'Відкрийте рота',
      'Витягніть вузький язик уперед',
      'Кінчик — гострий, губи не допомагають',
      'Утримувати нерухомо',
    ],
    stepsEn: [
      'Open your mouth',
      'Stretch the tongue forward, narrow',
      'The tip stays sharp; the lips do not help',
      'Hold it still',
    ],
    seconds: 6,
    sounds: ['Р', 'Л'],
  ),
  Exercise(
    id: 'clock',
    name: 'Годинник',
    nameEn: 'Clock',
    description: 'Кінчик язика рухається від кутика до кутика',
    descriptionEn: 'The tongue tip moves from corner to corner',
    steps: [
      'Відкрийте рота, підборіддя нерухоме',
      'Кінчик язика — до правого кутика',
      'Потім — до лівого',
      'Ритм рівний, без поспіху',
    ],
    stepsEn: [
      'Open your mouth; the jaw stays still',
      'Tongue tip to the right corner',
      'Then to the left corner',
      'Keep an even, unhurried rhythm',
    ],
    seconds: 10,
    sounds: ['Р', 'Л', 'С', 'З'],
  ),
  Exercise(
    id: 'swing',
    name: 'Гойдалка',
    nameEn: 'Swing',
    description: 'Кінчик язика піднімається вгору й опускається вниз',
    descriptionEn: 'The tongue tip rises and drops',
    steps: [
      'Відкрийте рота, підборіддя нерухоме',
      'Кінчик язика — за верхні зуби',
      'Потім — за нижні',
      'Чергуйте повільно',
    ],
    stepsEn: [
      'Open your mouth; the jaw stays still',
      'Tongue tip behind the upper teeth',
      'Then behind the lower teeth',
      'Alternate slowly',
    ],
    seconds: 10,
    sounds: ['Р', 'Л'],
  ),
  Exercise(
    id: 'mushroom',
    name: 'Грибок',
    nameEn: 'Mushroom',
    description: 'Язик присмоктується до піднебіння, вуздечка натягнута',
    descriptionEn: 'The tongue suctions to the palate, stretching the frenulum',
    steps: [
      'Відкрийте рота широко',
      'Присмокчіть язик до піднебіння',
      'Не відпускайте, рот відкривається ширше',
      'Утримувати, доки не втомиться',
    ],
    stepsEn: [
      'Open your mouth wide',
      'Suction the tongue to the palate',
      'Hold the suction and open wider',
      'Hold until it tires',
    ],
    seconds: 8,
    sounds: ['Р'],
  ),
  Exercise(
    id: 'horse',
    name: 'Конячка',
    nameEn: 'Horse',
    description: 'Клацання язиком — цокіт копит',
    descriptionEn: 'Clicking the tongue like hooves',
    steps: [
      'Присмокчіть язик до піднебіння',
      'Різко відірвіть — клац',
      'Нижня щелепа нерухома',
      'Повторюйте у рівному темпі',
    ],
    stepsEn: [
      'Suction the tongue to the palate',
      'Release it sharply — click',
      'The lower jaw stays still',
      'Repeat at an even tempo',
    ],
    seconds: 8,
    sounds: ['Р'],
  ),
  Exercise(
    id: 'painter',
    name: 'Маляр',
    nameEn: 'Painter',
    description: 'Язик «фарбує» піднебіння вперед-назад',
    descriptionEn: 'The tongue "paints" the palate back and forth',
    steps: [
      'Відкрийте рота',
      'Кінчиком язика торкніться верхніх зубів зсередини',
      'Ведіть язик по піднебінню назад',
      'Поверніться вперед тим самим шляхом',
    ],
    stepsEn: [
      'Open your mouth',
      'Touch the upper teeth from inside with the tip',
      'Slide the tongue back along the palate',
      'Return forward the same way',
    ],
    seconds: 10,
    sounds: ['Р', 'Ш', 'Ж'],
  ),
  Exercise(
    id: 'jam',
    name: 'Смачне варення',
    nameEn: 'Tasty jam',
    description: 'Широкий язик облизує верхню губу згори вниз',
    descriptionEn: 'A wide tongue licks the upper lip downward',
    steps: [
      'Відкрийте рота, губа розслаблена',
      'Широким язиком облизуйте верхню губу',
      'Рух — згори вниз, у рот',
      'Нижня щелепа нерухома',
    ],
    stepsEn: [
      'Open your mouth; the lip stays relaxed',
      'Lick the upper lip with a wide tongue',
      'The move goes top to bottom, into the mouth',
      'The lower jaw stays still',
    ],
    seconds: 8,
    sounds: ['Ш', 'Ж', 'Ч'],
  ),
  Exercise(
    id: 'tube',
    name: 'Трубочка',
    nameEn: 'Tube',
    description: 'Губи витягнуті вперед трубочкою',
    descriptionEn: 'The lips are pushed forward into a tube',
    steps: [
      'Зуби зімкнені',
      'Витягніть губи вперед трубочкою',
      'Губи напружені, кутики зібрані',
      'Утримувати',
    ],
    stepsEn: [
      'Keep the teeth together',
      'Push the lips forward into a tube',
      'The lips stay tense, corners gathered',
      'Hold',
    ],
    seconds: 6,
    sounds: ['С', 'З', 'Ц'],
  ),
  Exercise(
    id: 'smile',
    name: 'Посмішка',
    nameEn: 'Smile',
    description: 'Губи розтягнуті, зуби видно',
    descriptionEn: 'The lips are stretched, teeth showing',
    steps: [
      'Зуби зімкнені',
      'Розтягніть губи в широку посмішку',
      'Верхні й нижні зуби видно',
      'Утримувати, потім чергувати з трубочкою',
    ],
    stepsEn: [
      'Keep the teeth together',
      'Stretch the lips into a wide smile',
      'Upper and lower teeth are visible',
      'Hold, then alternate with the tube',
    ],
    seconds: 6,
    sounds: ['С', 'З', 'Ц', 'Л'],
  ),
  Exercise(
    id: 'balloon',
    name: 'Кулька',
    nameEn: 'Balloon',
    description: 'Надуті щоки, повітря утримується в роті',
    descriptionEn: 'Puffed cheeks holding the air in the mouth',
    steps: [
      'Зімкніть губи',
      'Надуйте обидві щоки',
      'Утримайте повітря, губи не пропускають',
      'Видихніть одним рухом',
    ],
    stepsEn: [
      'Close the lips',
      'Puff both cheeks',
      'Hold the air; the lips keep the seal',
      'Release it in one breath',
    ],
    seconds: 6,
    sounds: ['Б', 'П'],
  ),
  Exercise(
    id: 'cup',
    name: 'Чашечка',
    nameEn: 'Cup',
    description: 'Краї язика підняті, середина — заглиблення',
    descriptionEn: 'The edges of the tongue rise, the middle dips',
    steps: [
      'Відкрийте рота широко',
      'Покладіть широкий язик на нижню губу',
      'Підніміть краї й кінчик — вийде чашечка',
      'Занесіть чашечку в рот, не розливши форму',
    ],
    stepsEn: [
      'Open your mouth wide',
      'Rest the wide tongue on the lower lip',
      'Lift the edges and the tip — a cup',
      'Carry the cup into the mouth without losing the shape',
    ],
    seconds: 8,
    sounds: ['Ш', 'Ж', 'Ч', 'Р'],
  ),
];

// ─────────────────────────────────────────────
//  The sheet — all twelve exercises
// ─────────────────────────────────────────────

class ArticulationScreen extends ConsumerWidget {
  const ArticulationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return KidScreen(
      accent: _accent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DT.sp20, 0, DT.sp20, DT.sp32),
        children: [
          Text(
            s('Артикуляційна гімнастика', 'Articulation exercises'),
            style: _titleStyle,
          ),
          const SizedBox(height: DT.sp8),
          Text(
            s(
              'Вправи для дорослого з дитиною. Сядьте разом перед дзеркалом, '
                  'покажіть рух і попросіть повторити. Достатньо 3–5 хвилин '
                  'на день.',
              'Exercises for a grown-up to do with the child. Sit together at '
                  'a mirror, show the movement, then ask the child to copy '
                  'it. Three to five minutes a day is enough.',
            ),
            style: _leadStyle,
          ),
          const SizedBox(height: DT.sp20),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: DT.sp12,
              crossAxisSpacing: DT.sp12,
              childAspectRatio: 0.78,
            ),
            itemCount: articulationExercises.length,
            itemBuilder: (context, i) {
              final ex = articulationExercises[i];
              return _ExerciseTile(
                key: ValueKey(ex.id),
                exercise: ex,
                isEn: isEn,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArticulationDetailScreen(
                      initialIndex: i,
                      isEn: isEn,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final bool isEn;
  final VoidCallback onTap;

  const _ExerciseTile({
    super.key,
    required this.exercise,
    required this.isEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Material(
      color: DT.surfaceWhite,
      borderRadius: BorderRadius.circular(DT.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DT.rMd),
        child: Container(
          padding: const EdgeInsets.all(DT.sp12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DT.rMd),
            border: Border.all(
              color: DT.textPrimary.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: DT.violetTint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                  child: ArticulationArt(id: exercise.id),
                ),
              ),
              const SizedBox(height: DT.sp8),
              Text(
                isEn ? exercise.nameEn : exercise.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _tileNameStyle,
              ),
              const SizedBox(height: DT.sp4),
              Text(
                '${s('Звуки', 'Sounds')}: ${exercise.sounds.join(' · ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: _face,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DT.brand,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  One exercise, with plain navigation through the set
// ─────────────────────────────────────────────

/// A single exercise, opened from the sheet.
///
/// Navigation is between *exercises*, not through a level: «Попередня» /
/// «Наступна» move within one route and the header says «3 з 12», so a
/// therapist can work down the list without going back to the grid. There
/// is no reward on the way out — finishing is a grown-up closing a
/// reference sheet.
class ArticulationDetailScreen extends StatefulWidget {
  final int initialIndex;
  final bool isEn;

  const ArticulationDetailScreen({
    super.key,
    required this.initialIndex,
    required this.isEn,
  });

  @override
  State<ArticulationDetailScreen> createState() =>
      _ArticulationDetailScreenState();
}

class _ArticulationDetailScreenState extends State<ArticulationDetailScreen>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;

  /// Optional hold timer. Idle by default: the exercise does not need it,
  /// a parent who would otherwise count the eight seconds out loud does.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: Duration(seconds: _exercise.seconds),
  )..addStatusListener((status) {
      // Not disposed here — disposing a controller from inside its own
      // status callback tears down the listener list mid-notification.
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _running = false);
      }
    });

  bool _running = false;

  Exercise get _exercise => articulationExercises[_index];

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _stopTimer() {
    _hold.stop();
    _hold.reset();
    _running = false;
  }

  void _toggleTimer() {
    setState(() {
      if (_running) {
        _stopTimer();
        return;
      }
      _hold.duration = Duration(seconds: _exercise.seconds);
      _hold.forward(from: 0);
      _running = true;
    });
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= articulationExercises.length) return;
    setState(() {
      _stopTimer();
      _index = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn);
    final ex = _exercise;
    final steps = widget.isEn ? ex.stepsEn : ex.steps;

    return KidScreen(
      accent: _accent,
      trailing: SizedBox(
        width: 72,
        child: Center(
          child: Text(
            widget.isEn
                ? '${_index + 1} of ${articulationExercises.length}'
                : '${_index + 1} з ${articulationExercises.length}',
            style: _labelStyle,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DT.sp20, 0, DT.sp20, DT.sp24),
        children: [
          SizedBox(
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DT.violetTint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(DT.rMd),
              ),
              child: ArticulationArt(
                key: ValueKey(ex.id),
                id: ex.id,
                padding: const EdgeInsets.all(DT.sp16),
              ),
            ),
          ),
          const SizedBox(height: DT.sp16),
          Text(widget.isEn ? ex.nameEn : ex.name, style: _titleStyle),
          const SizedBox(height: DT.sp4),
          Text(
            widget.isEn ? ex.descriptionEn : ex.description,
            style: _leadStyle,
          ),
          const SizedBox(height: DT.sp16),
          _SoundsBanner(sounds: ex.sounds, isEn: widget.isEn),
          const SizedBox(height: DT.sp20),
          Text(s('ЯК ВИКОНУВАТИ', 'HOW TO DO IT'), style: _labelStyle),
          const SizedBox(height: DT.sp8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              key: ValueKey('${ex.id}_step_$i'),
              padding: const EdgeInsets.only(bottom: DT.sp12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}.', style: _bodyStyle),
                  ),
                  Expanded(child: Text(steps[i], style: _bodyStyle)),
                ],
              ),
            ),
          const SizedBox(height: DT.sp8),
          _HoldTimer(
            seconds: ex.seconds,
            controller: _hold,
            running: _running,
            onToggle: _toggleTimer,
            isEn: widget.isEn,
          ),
        ],
      ),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(DT.sp20, 0, DT.sp20, DT.sp16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _NavButton(
                    label: s('Попередня', 'Previous'),
                    onPressed: _index > 0 ? () => _go(-1) : null,
                  ),
                ),
                const SizedBox(width: DT.sp12),
                Expanded(
                  child: _NavButton(
                    label: s('Наступна', 'Next'),
                    onPressed: _index < articulationExercises.length - 1
                        ? () => _go(1)
                        : null,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                s('Завершити', 'Finish'),
                style: _buttonStyle.copyWith(color: DT.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The target sounds, set as the headline of the exercise.
///
/// This is the line a speech therapist scans for: «Грибок» means nothing
/// on its own, «Р» decides whether the exercise belongs in today's
/// session. It used to be a row of 11 sp chips.
class _SoundsBanner extends StatelessWidget {
  final List<String> sounds;
  final bool isEn;

  const _SoundsBanner({required this.sounds, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DT.sp16,
        vertical: DT.sp12,
      ),
      decoration: BoxDecoration(
        color: DT.violetTint,
        borderRadius: BorderRadius.circular(DT.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s('ГОТУЄ ЗВУКИ', 'PREPARES THE SOUNDS'),
            style: _labelStyle.copyWith(color: DT.onTint(_accent)),
          ),
          const SizedBox(height: DT.sp8),
          Wrap(
            spacing: DT.sp8,
            runSpacing: DT.sp8,
            children: [
              for (final sound in sounds)
                Container(
                  key: ValueKey('sound_$sound'),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DT.surfaceWhite,
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                  child: Text(
                    sound,
                    style: const TextStyle(
                      fontFamily: _face,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: DT.textPrimary,
                      height: 1.0,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An opt-in countdown for the hold, and nothing more: no reps, no dots,
/// no celebration when it runs out. A grown-up counting seconds out loud
/// is the alternative this replaces.
class _HoldTimer extends StatelessWidget {
  final int seconds;
  final AnimationController controller;
  final bool running;
  final VoidCallback onToggle;
  final bool isEn;

  const _HoldTimer({
    required this.seconds,
    required this.controller,
    required this.running,
    required this.onToggle,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onToggle,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: DT.onTint(_accent),
            side: BorderSide(color: DT.onTint(_accent).withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DT.rMd),
            ),
          ),
          child: Text(
            running
                ? s('Зупинити відлік', 'Stop the count')
                : s('Відлік $seconds с', 'Count $seconds s'),
            style: _buttonStyle,
          ),
        ),
        if (running) ...[
          const SizedBox(height: DT.sp8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(DT.rSm),
              child: LinearProgressIndicator(
                value: 1 - controller.value,
                minHeight: 6,
                backgroundColor: DT.violetTint,
                valueColor: const AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _NavButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: DT.textPrimary,
        side: BorderSide(color: DT.textPrimary.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rMd),
        ),
      ),
      child: Text(label, style: _buttonStyle),
    );
  }
}
