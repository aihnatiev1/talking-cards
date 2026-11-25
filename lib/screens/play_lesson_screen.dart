import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../models/play_session.dart';
import '../models/play_topic.dart';
import '../providers/home_tab_provider.dart';
import '../providers/language_provider.dart';
import '../providers/play_session_provider.dart';
import '../providers/profile_provider.dart';
import '../services/audio_service.dart';
import '../utils/design_tokens.dart';
import '../utils/app_icons.dart';
import '../utils/l10n.dart';
import '../widgets/bloom_mascot.dart';
import '../widgets/kid_tap.dart';
import '../widgets/kid_stage.dart';
import '../widgets/meadow_scene.dart';
import '../widgets/play_components.dart';
import '../widgets/cue_pill.dart';
import '../widgets/card_image.dart';
import '../widgets/kid_screen.dart';

/// The three pictures of a find question: the two others in their usual
/// order, the target walking left → middle → right with the step.
@visibleForTesting
List<T> threeOptions<T>(List<T> cards, int step) {
  final target = cards[step - 3];
  return [cards[(step - 2) % 3], cards[(step - 1) % 3]]
    ..insert(step % 3, target);
}

class PlayLessonScreen extends ConsumerStatefulWidget {
  const PlayLessonScreen({super.key, required this.topic, required this.cards});
  final PlayTopic topic;
  final List<CardModel> cards;
  @override
  ConsumerState<PlayLessonScreen> createState() => _PlayLessonScreenState();
}

class _PlayLessonScreenState extends ConsumerState<PlayLessonScreen>
    with WidgetsBindingObserver {
  late final PlaySessionNotifier _journal;
  bool _contextChanged = false;

  bool get _ownsSession =>
      mounted &&
      !_contextChanged &&
      identical(_journal, ref.read(playSessionProvider.notifier));

  bool _saving = false;
  bool _correct = false;
  bool _touched = false;
  bool _speaking = false;
  bool _background = false;
  int _voice = 0;
  int? _promptedStep;
  Timer? _hintTimer;
  String? _feedback;
  String? _error;

  @override
  void initState() {
    super.initState();
    _journal = ref.read(playSessionProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _voice++;
    _hintTimer?.cancel();
    AudioService.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _hintTimer?.cancel();
      _voice++;
      AudioService.instance.stop();
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _say(CardModel card) async {
    if (!_ownsSession) return;
    _hintTimer?.cancel();
    final generation = ++_voice;
    if (!AudioService.instance.isWordAvailable(card.audioKey)) {
      setState(() {
        _speaking = false;
        _error = ref.read(languageProvider) == 'en'
            ? 'Audio is unavailable. You can keep playing.'
            : 'Звук зараз недоступний. Можна грати далі.';
      });
      return;
    }
    setState(() => _speaking = true);
    final step =
        ref
            .read(playSessionProvider)
            .valueOrNull
            ?.sessions[widget.topic.id]
            ?.step ??
        0;
    try {
      // Meeting an animal-sound card is the whole recording — the name,
      // then the animal's own voice. Asking for it is the name alone.
      if (widget.topic.withSounds && step < 3) {
        await AudioService.instance.speakCard(
          card.audioKey,
          card.sound,
          card.text,
        );
      } else {
        await AudioService.instance.playWordOnly(
          card.audioKey,
          card.sound,
          locale: ref.read(languageProvider) == 'en' ? 'en-US' : 'uk-UA',
        );
      }
    } finally {
      if (_ownsSession && generation == _voice) {
        setState(() => _speaking = false);
        final current = ref
            .read(playSessionProvider)
            .valueOrNull
            ?.sessions[widget.topic.id];
        if (current != null &&
            current.step >= 3 &&
            current.step < 6 &&
            !_correct &&
            !current.hint &&
            !_background) {
          _hintTimer = Timer(DT.motion.lessonHint, () {
            if (mounted && !_correct && !_background) {
              _save(() => _journal.hint(current.topic, current.step));
            }
          });
        }
      }
    }
  }

  Future<void> _save(Future<void> Function() operation) async {
    if (!_ownsSession || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = ref.read(languageProvider) == 'en'
              ? 'Could not save. Try again.'
              : 'Не вдалося зберегти. Спробуй ще раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _next(PlaySession session) async {
    final notifier = _journal;
    _hintTimer?.cancel();
    _voice++;
    AudioService.instance.stop();
    await _save(() => notifier.advance(session.topic, session.step));
    if (mounted && _error == null) {
      setState(() {
        _correct = false;
        _touched = false;
        _feedback = null;
        _speaking = false;
      });
    }
  }

  Future<void> _choose(
    CardModel chosen,
    CardModel target,
    PlaySession session,
  ) async {
    if (!_ownsSession || _saving || _correct || _background) return;
    _hintTimer?.cancel();
    final s = AppS(ref.read(languageProvider) == 'en');
    if (chosen.id == target.id) {
      setState(() {
        _correct = true;
        _feedback = s('Ось він!', 'You found it!');
      });
      await _say(chosen);
    } else {
      setState(
        () => _feedback = s(
          'Це ${chosen.sound.toLowerCase()}. Послухай ще.',
          'That is ${chosen.sound.toLowerCase()}. Listen again.',
        ),
      );
      final notifier = _journal;
      await _save(() => notifier.miss(session.topic, session.step));
      if (mounted && !_background) {
        await _say(chosen);
        if (mounted && !_background && !_correct) {
          await Future<void>.delayed(DT.motion.questionCue);
          if (mounted && !_background && !_correct) await _say(target);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final session = ref
        .watch(playSessionProvider)
        .valueOrNull
        ?.sessions[widget.topic.id];
    if (!_ownsSession && !_contextChanged) {
      _contextChanged = true;
      _hintTimer?.cancel();
      _voice++;
      AudioService.instance.stop();
    }
    final cards = session == null
        ? <CardModel>[]
        : [
            for (final id in session.cardIds)
              ...widget.cards.where((card) => card.id == id),
          ];
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _voice++;
          AudioService.instance.stop();
        }
      },
      child: Scaffold(
        // The games' meadow, not a flat off-white page: the lesson is a
        // place the animals live in, and the empty lower half now has grass
        // and sky in it.
        backgroundColor: DT.sceneSkyTop,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/backdrops/guess_sky.webp',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                errorBuilder: (_, __, ___) => const MeadowScene(),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _contextChanged || session == null || cards.length != 3
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s(
                                'Відкриймо інше заняття',
                                'Let’s open another lesson',
                              ),
                              style: DT.h2,
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text(s('Назад', 'Back')),
                            ),
                          ],
                        )
                      : _body(session, cards, s, isEn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(PlaySession session, List<CardModel> cards, AppS s, bool isEn) {
    final step = session.step;
    final target =
        cards[step < 3
            ? step
            : step < 6
            ? step - 3
            : 0];
    final exploring = step < 3;
    final repeating = step == 6;
    final complete = session.complete;
    if (step >= 3 && step < 6 && _promptedStep != step) {
      _promptedStep = step;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !_background &&
            ModalRoute.of(context)?.isCurrent == true) {
          _say(target);
        }
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              KidCloseButton(
                accent: DT.brand,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: step / 7,
                  minHeight: 12,
                  semanticsLabel: s('Прогрес заняття', 'Lesson progress'),
                ),
              ),
              const SizedBox(width: 12),
              AppIconView(
                complete ? AppIcon.check : AppIcon.pawStep,
                color: DT.brand,
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        // Air under the round close button: the line below used to start
        // right at its edge and the button sat on top of it.
        const SizedBox(height: 10),
        if (complete)
          Expanded(
            child: KidStage(
              title: Text(
                s('Ось і новий друг!', 'Meet your new friend!'),
                style: DT.display,
                textAlign: TextAlign.center,
              ),
              stage: (context, width, height) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayScene(
                    cards: [cards.first],
                    celebrate: true,
                    height: (height - 90).clamp(160.0, 300.0),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    cards.first.sound,
                    style: DT.word,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                PlayAction(
                  label: s('До мого світу', 'My world'),
                  icon: AppIcon.catWorld,
                  onPressed: () {
                    ref.read(homeDestinationProvider.notifier).state =
                        HomeDestination.world;
                    Navigator.of(context).pop();
                  },
                ),
                CuePill(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      s('На головну', 'Home'),
                      style: DT.tileTitle.copyWith(color: DT.brand),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              // Everything fits on one screen: a child does not scroll to
              // find the button. The picture takes whatever height is left.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CuePill(
                    child: Text(
                      repeating
                          ? s('Спробуємо разом?', 'Shall we try together?')
                          : exploring
                          ? s('Торкнись і послухай', 'Tap and listen')
                          : s('Знайди тваринку', 'Find the animal'),
                      style: DT.h1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (exploring || repeating)
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: target.sound,
                        child: KidTap(
                          key: const ValueKey('lesson-card'),
                          sound: null,
                          onTap: () {
                            setState(() => _touched = true);
                            _say(target);
                          },
                          child: PlayPanel(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Column(
                              children: [
                                Expanded(
                                  child: AnimatedScale(
                                    scale: _speaking ? 1.05 : 1,
                                    duration: DT.motion.base,
                                    curve: Curves.easeOutBack,
                                    child: PlayArt(card: target),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          target.sound,
                                          style: DT.word,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    AppArt('listen', size: 40),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    PlayAction(
                      label: target.sound,
                      icon: AppIcon.sound,
                      secondary: true,
                      onPressed: () => _say(target),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          // Stable positions for the whole question; the target alternates.
                          final other = cards[(step - 3 + 1) % cards.length];
                          final level =
                              ref.read(profileProvider).active?.level ?? 2;
                          final helpedBefore = session.assisted.any(
                            (question) => question < step,
                          );
                          final useThree =
                              !helpedBefore &&
                              (level >= 3 || (level >= 2 && step == 5));
                          final options = useThree
                              ? threeOptions(cards, step)
                              : step.isEven
                              ? [other, target]
                              : [target, other];
                          // A board, not a row: three narrow columns left a
                          // small picture at the top of a tall white strip.
                          // Two pictures stand one above the other on a
                          // phone; three are two and one, each picture
                          // filling its tile.
                          // Whole pictures, never cropped: the cards are
                          // drawn 3 : 4, so each tile is 3 : 4 too — two
                          // side by side, a third centred under them — and
                          // as big as the space allows.
                          return _LessonBoard(
                            options: options,
                            tileBuilder: (_, card) => Semantics(
                              button: true,
                              label: card.sound,
                              selected: _correct && card.id == target.id,
                              child: KidTap(
                                sound: null,
                                key: ValueKey('lesson-option-${card.id}'),
                                onTap: _saving || _correct
                                    ? null
                                    : () => _choose(card, target, session),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _correct && card.id == target.id
                                        ? DT.mintTint
                                        : DT.surfaceWhite,
                                    borderRadius: BorderRadius.circular(DT.rLg),
                                    border: Border.all(
                                      color:
                                          card.id == target.id &&
                                              (_correct || session.hint)
                                          ? (_correct ? DT.brand : DT.hint)
                                          : DT.outline,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: DT.outline,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            DT.rMd,
                                          ),
                                          child: CardImage.forCard(
                                            card,
                                            size: CardArtSize.hero,
                                            fit: BoxFit.contain,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      if ((_correct || session.hint) &&
                                          card.id == target.id)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: DT.surfaceWhite,
                                              shape: BoxShape.circle,
                                            ),
                                            child: _correct
                                                ? const AppIconView(
                                                    AppIcon.check,
                                                    color: DT.brand,
                                                  )
                                                : const AppArt(
                                                    'sparkle',
                                                    size: 30,
                                                  ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: DT.body),
                    ),
                  const SizedBox(height: 10),
                  // The bottom row is always there, so nothing jumps and the
                  // button is never below the fold: Bloom on the left, the
                  // next step (or the "show me" help) on the right.
                  SizedBox(
                    height: 96,
                    child: Row(
                      children: [
                        // His picture has wide empty margins, so the slot
                        // is narrower than the canvas and the bunny himself
                        // fills it — at 72 dp he was a speck beside the
                        // button.
                        SizedBox(
                          width: 78,
                          child: OverflowBox(
                            minWidth: 112,
                            maxWidth: 112,
                            minHeight: 112,
                            maxHeight: 112,
                            alignment: Alignment.bottomCenter,
                            child: BloomMascot(
                              size: 112,
                              interactive: false,
                              state: BloomState(
                                emotion: _correct
                                    ? BloomEmotion.happy
                                    : !exploring && !repeating && session.hint
                                    ? BloomEmotion.point
                                    : _speaking
                                    ? BloomEmotion.listen
                                    : BloomEmotion.wave,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: repeating
                              ? PlayAction(
                                  label: s('Завершити', 'Finish'),
                                  icon: AppIcon.check,
                                  onPressed: _saving
                                      ? null
                                      : () => _next(session),
                                )
                              : (exploring && _touched) ||
                                    (!exploring && _correct)
                              ? PlayAction(
                                  label: s('Далі', 'Continue'),
                                  icon: AppIcon.play,
                                  onPressed: _saving || _speaking
                                      ? null
                                      : () => _next(session),
                                )
                              : !exploring
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: CuePill(
                                    child: TextButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _save(
                                              () => _journal.hint(
                                                session.topic,
                                                step,
                                              ),
                                            ),
                                      icon: const AppArt('sparkle', size: 30),
                                      label: Text(
                                        _feedback ??
                                            s('Покажи мені', 'Show me'),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The lesson's answers in portrait tiles of the cards' own 3 : 4 shape:
/// two side by side, a third centred under them, sized to fill the space
/// without cropping a picture.
class _LessonBoard extends StatelessWidget {
  const _LessonBoard({required this.options, required this.tileBuilder});

  final List<CardModel> options;
  final Widget Function(int index, CardModel card) tileBuilder;

  static const _gap = 12.0;
  static const _aspect = 3 / 4;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final rows = (options.length / 2).ceil();
      var width = (box.maxWidth - _gap) / 2;
      var height = width / _aspect;
      final fit = (box.maxHeight - _gap * (rows - 1)) / rows;
      if (height > fit) {
        height = fit;
        width = height * _aspect;
      }
      Widget tile(int i) => SizedBox(
        width: width,
        height: height,
        child: tileBuilder(i, options[i]),
      );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: _gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tile(row * 2),
                  if (row * 2 + 1 < options.length) ...[
                    const SizedBox(width: _gap),
                    tile(row * 2 + 1),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
