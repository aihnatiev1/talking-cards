import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import '../widgets/confetti_burst.dart';

// ─────────────────────────────────────────────
//  Exercise data
// ─────────────────────────────────────────────

class _Exercise {
  final String name;
  final String nameEn;
  final String emoji;
  final String description;
  final String descriptionEn;
  final List<String> steps;
  final List<String> stepsEn;
  final int seconds;
  final List<String> sounds; // target sounds this exercise helps

  const _Exercise({
    required this.name,
    required this.nameEn,
    required this.emoji,
    required this.description,
    required this.descriptionEn,
    required this.steps,
    required this.stepsEn,
    required this.seconds,
    required this.sounds,
  });
}

const _exercises = [
  _Exercise(
    name: 'Лопатка',
    nameEn: 'Spatula',
    emoji: '👅',
    description: 'Широкий розслаблений язик на нижній губі',
    descriptionEn: 'Wide relaxed tongue on the lower lip',
    steps: ['Відкрий рота', 'Поклади широкий язик на нижню губу', 'Не напружуй язик', 'Тримай!'],
    stepsEn: ['Open your mouth', 'Place wide tongue on lower lip', 'Keep tongue relaxed', 'Hold!'],
    seconds: 8,
    sounds: ['Ш', 'Ж', 'Ч', 'С', 'З'],
  ),
  _Exercise(
    name: 'Голочка',
    nameEn: 'Needle',
    emoji: '🪡',
    description: 'Вузький гострий язик витягнути вперед',
    descriptionEn: 'Narrow sharp tongue stretched forward',
    steps: ['Відкрий рота', 'Витягни вузький язик', 'Зроби гострий кінчик', 'Тримай!'],
    stepsEn: ['Open your mouth', 'Stretch tongue narrow', 'Make a sharp tip', 'Hold!'],
    seconds: 6,
    sounds: ['Р', 'Л'],
  ),
  _Exercise(
    name: 'Годинник',
    nameEn: 'Clock',
    emoji: '🕐',
    description: 'Кінчик язика рухається ліворуч-праворуч',
    descriptionEn: 'Tongue tip moves left and right',
    steps: ['Відкрий рота', 'Кінчик язика — вправо', 'Потім — вліво', 'Повторюй рівномірно!'],
    stepsEn: ['Open your mouth', 'Tip of tongue — right', 'Then — left', 'Repeat evenly!'],
    seconds: 10,
    sounds: ['Р', 'Л', 'С', 'З'],
  ),
  _Exercise(
    name: 'Гойдалка',
    nameEn: 'Swing',
    emoji: '🎠',
    description: 'Кінчик язика рухається вгору-вниз',
    descriptionEn: 'Tongue tip moves up and down',
    steps: ['Відкрий рота', 'Підніми кінчик язика вгору', 'Опусти вниз', 'Гойдайся!'],
    stepsEn: ['Open your mouth', 'Lift tongue tip up', 'Lower it down', 'Keep swinging!'],
    seconds: 10,
    sounds: ['Р', 'Л'],
  ),
  _Exercise(
    name: 'Грибок',
    nameEn: 'Mushroom',
    emoji: '🍄',
    description: 'Язик прилипає до піднебіння',
    descriptionEn: 'Tongue sticks to the palate',
    steps: ['Відкрий рота широко', 'Притисни язик до піднебіння', 'Утримуй, не опускай', 'Тримай!'],
    stepsEn: ['Open mouth wide', 'Press tongue to palate', 'Hold without dropping', 'Hold!'],
    seconds: 8,
    sounds: ['Р'],
  ),
  _Exercise(
    name: 'Конячка',
    nameEn: 'Horse',
    emoji: '🐴',
    description: 'Клацати язиком, як цокіт копит',
    descriptionEn: 'Click tongue like horse hooves',
    steps: ['Притисни язик до піднебіння', 'Різко відірви — клац!', 'Повторюй швидко', 'Цок-цок-цок!'],
    stepsEn: ['Press tongue to palate', 'Pull it away sharply — click!', 'Repeat quickly', 'Clop-clop-clop!'],
    seconds: 8,
    sounds: ['Р'],
  ),
  _Exercise(
    name: 'Маляр',
    nameEn: 'Painter',
    emoji: '🎨',
    description: 'Язик «малює» по піднебінню вперед-назад',
    descriptionEn: 'Tongue "paints" the palate back and forth',
    steps: ['Відкрий рота', 'Кінчиком язика торкнись верхніх зубів', 'Веди язик по піднебінню назад', 'Поверни назад!'],
    stepsEn: ['Open mouth', 'Touch upper teeth with tongue tip', 'Slide tongue back along palate', 'Return forward!'],
    seconds: 10,
    sounds: ['Р', 'Ш', 'Ж'],
  ),
  _Exercise(
    name: 'Смачне варення',
    nameEn: 'Yummy Jam',
    emoji: '🍓',
    description: 'Облизуємо верхню губу широким язиком',
    descriptionEn: 'Lick the upper lip with a wide tongue',
    steps: ['Відкрий рота', 'Широким язиком облизуй верхню губу', 'Знизу вгору', 'Повторюй!'],
    stepsEn: ['Open mouth', 'Lick upper lip with wide tongue', 'Bottom to top', 'Repeat!'],
    seconds: 8,
    sounds: ['Ш', 'Ж', 'Ч'],
  ),
  _Exercise(
    name: 'Трубочка',
    nameEn: 'Tube',
    emoji: '🌀',
    description: 'Витягнути губи трубочкою вперед',
    descriptionEn: 'Stretch lips into a tube forward',
    steps: ['Стисни зуби', 'Витягни губи трубочкою', 'Тримай губи напружено', 'Тримай!'],
    stepsEn: ['Close teeth', 'Stretch lips into a tube', 'Keep lips tense', 'Hold!'],
    seconds: 6,
    sounds: ['С', 'З', 'Ц'],
  ),
  _Exercise(
    name: 'Посмішка',
    nameEn: 'Smile',
    emoji: '😁',
    description: 'Широка посмішка — зуби видно',
    descriptionEn: 'Wide smile — teeth visible',
    steps: ['Стисни зуби', 'Розтягни губи в широку посмішку', 'Зуби мають бути видно', 'Тримай!'],
    stepsEn: ['Close teeth', 'Stretch lips wide into a smile', 'Teeth should be visible', 'Hold!'],
    seconds: 6,
    sounds: ['С', 'З', 'Ц', 'Л'],
  ),
  _Exercise(
    name: 'Кулька',
    nameEn: 'Ball',
    emoji: '🎈',
    description: 'Надути щоки, потім здути',
    descriptionEn: 'Puff cheeks, then deflate',
    steps: ['Стисни губи', 'Надуй обидві щоки', 'Потримай 3 секунди', 'Здуй — пух!'],
    stepsEn: ['Close lips', 'Puff both cheeks', 'Hold for 3 seconds', 'Deflate — poof!'],
    seconds: 6,
    sounds: ['Б', 'П'],
  ),
  _Exercise(
    name: 'Чашечка',
    nameEn: 'Cup',
    emoji: '🫖',
    description: 'Язик у формі чашечки всередині рота',
    descriptionEn: 'Tongue shaped like a cup inside the mouth',
    steps: ['Відкрий рота широко', 'Підніми краї язика вгору', 'Зроби «чашечку»', 'Тримай форму!'],
    stepsEn: ['Open mouth wide', 'Raise edges of tongue up', 'Make a "cup" shape', 'Hold the shape!'],
    seconds: 8,
    sounds: ['Ш', 'Ж', 'Ч', 'Р'],
  ),
];

// ─────────────────────────────────────────────
//  Main screen — grid of exercises
// ─────────────────────────────────────────────

class ArticulationScreen extends ConsumerWidget {
  const ArticulationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);

    return Scaffold(
      backgroundColor: const Color(0xFFF5EEFF),
      appBar: AppBar(
        title: Text(
          s('Артикуляційна гімнастика', 'Articulation Exercises'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              s('Щоденні вправи для язика і губ',
                  'Daily exercises for tongue and lips'),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: _exercises.length,
              itemBuilder: (_, i) {
                final ex = _exercises[i];
                return _ExerciseCard(
                  exercise: ex,
                  isEn: isEn,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ExercisePlayerScreen(
                        exercise: ex,
                        isEn: isEn,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final _Exercise exercise;
  final bool isEn;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.isEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: kAccent.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(exercise.emoji,
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              isEn ? exercise.nameEn : exercise.name,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: exercise.sounds
                  .take(4)
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: kAccent,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Exercise player — timed exercise
// ─────────────────────────────────────────────

class _ExercisePlayerScreen extends StatefulWidget {
  final _Exercise exercise;
  final bool isEn;

  const _ExercisePlayerScreen({
    required this.exercise,
    required this.isEn,
  });

  @override
  State<_ExercisePlayerScreen> createState() => _ExercisePlayerScreenState();
}

class _ExercisePlayerScreenState extends State<_ExercisePlayerScreen>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  bool _done = false;
  int _reps = 0;
  static const _maxReps = 5;

  // Hold timer — shown on the last "Тримай!" step
  late AnimationController _holdCtrl;
  bool _holding = false;

  // Bounce for the big emoji on rep complete — immediate visual reward.
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceScale;

  OverlayEntry? _confettiEntry;

  List<String> get steps =>
      widget.isEn ? widget.exercise.stepsEn : widget.exercise.steps;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.exercise.seconds),
    );
    _holdCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _onRepComplete();
      }
    });

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOutBack));
  }

  void _onRepComplete() {
    HapticFeedback.mediumImpact();
    _bounceCtrl.forward(from: 0);

    final willFinish = _reps + 1 >= _maxReps;
    _burstConfetti(linger: willFinish ? 1800 : 700);

    setState(() {
      _holding = false;
      _reps++;
      if (willFinish) {
        _done = true;
        HapticFeedback.heavyImpact();
      } else {
        _stepIndex = 0;
      }
    });
  }

  void _burstConfetti({required int linger}) {
    if (!mounted) return;
    _confettiEntry?.remove();
    final size = MediaQuery.of(context).size;
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(
          origin: Offset(size.width / 2, size.height / 2.4),
        ),
      ),
    );
    _confettiEntry = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(Duration(milliseconds: linger), () {
      if (_confettiEntry == entry) {
        _confettiEntry?.remove();
        _confettiEntry = null;
      }
    });
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
    _bounceCtrl.dispose();
    _confettiEntry?.remove();
    super.dispose();
  }

  void _nextStep() {
    if (_stepIndex < steps.length - 1) {
      setState(() => _stepIndex++);
      // Auto-start hold timer on last step
      if (_stepIndex == steps.length - 1) {
        _holding = true;
        _holdCtrl.forward(from: 0);
      }
    }
  }

  bool get _isLastStep => _stepIndex == steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn);
    final name = widget.isEn ? widget.exercise.nameEn : widget.exercise.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF5EEFF),
      appBar: AppBar(
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // "For parent" banner
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s('👨‍👧 Батьки читають вголос — дитина повторює рухи',
                      '👨‍👧 Parents read aloud — child mirrors the moves'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Big emoji — bounces on each rep completion for instant reward
              ScaleTransition(
                scale: _bounceScale,
                child: Text(widget.exercise.emoji,
                    style: const TextStyle(fontSize: 128)),
              ),

              const SizedBox(height: 10),

              // Reps counter — dots grow as reps complete
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_maxReps, (i) {
                  final done = i < _reps;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: done ? 22 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: done ? kAccent : kAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Steps list — all visible, current highlighted
              Expanded(
                child: ListView.builder(
                  itemCount: steps.length,
                  itemBuilder: (_, i) {
                    final isCurrent = i == _stepIndex;
                    final isDone = i < _stepIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? kAccent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? kAccent.withValues(alpha: 0.4)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? const Color(0xFF43A047)
                                  : isCurrent
                                      ? kAccent
                                      : Colors.grey[300],
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 16)
                                  : Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: TextStyle(
                                fontSize: isCurrent ? 17 : 14,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isDone
                                    ? Colors.grey[400]
                                    : isCurrent
                                        ? Colors.black87
                                        : Colors.grey[600],
                              ),
                            ),
                          ),
                          // Hold timer on last step
                          if (isCurrent && _isLastStep && _holding)
                            AnimatedBuilder(
                              animation: _holdCtrl,
                              builder: (_, __) => SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  value: _holdCtrl.value,
                                  strokeWidth: 4,
                                  backgroundColor:
                                      kAccent.withValues(alpha: 0.2),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          kAccent),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              if (!_done) ...[
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isLastStep && _holding ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      disabledBackgroundColor:
                          kAccent.withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 3,
                    ),
                    child: Text(
                      _isLastStep
                          ? s('Тримай... ⏳', 'Hold... ⏳')
                          : s('Далі ▶', 'Next ▶'),
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s('Зупинити', 'Stop'),
                      style: TextStyle(color: Colors.grey[500])),
                ),
              ] else ...[
                // Done state
                const SizedBox(height: 20),
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  s('Молодець! Виконано $_maxReps разів!',
                      'Well done! Completed $_maxReps times!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(s('Назад', 'Back')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _done = false;
                            _reps = 0;
                            _stepIndex = 0;
                            _holding = false;
                          });
                          _holdCtrl.reset();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(s('Ще раз 🔄', 'Again 🔄')),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
