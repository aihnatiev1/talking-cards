import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bloom_state.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import 'profile_provider.dart';

export '../models/bloom_state.dart';

/// Bloom's brain (docs/design/bloom_character.md §5; architecture audit F4
/// calls it `BloomController`). One per app; every `BloomMascot` without a
/// `state:` override renders whatever it says.
final bloomReactionsProvider =
    StateNotifierProvider<BloomReactions, BloomState>((ref) {
  return BloomReactions(
    profileLevel: () => ref.read(profileProvider).active?.level ?? 2,
  );
});

/// Turns events into a [BloomState] — priorities, debounces, idle timers.
///
/// **Bloom does not know about screens.** Hosts send [BloomEvent]s and
/// declare a [BloomScene]; the child's feedback (`FeedbackService`) and the
/// narrator (`AudioService.isSpeaking`) are subscribed here once, so no
/// screen has to wire `listen` or `happy` by hand.
///
/// Pure Dart apart from the two singletons, both injectable, and every
/// clock read goes through [now] so `fake_async` drives the whole thing.
class BloomReactions extends StateNotifier<BloomState> {
  BloomReactions({
    required int Function() profileLevel,
    ValueListenable<bool>? speaking,
    FeedbackService? feedback,
    void Function(BloomSound sound)? playSound,
    bool Function()? praiseMissing,
    DateTime Function()? now,
  })  : _profileLevel = profileLevel,
        _speaking = speaking ?? AudioService.instance.isSpeaking,
        _feedback = feedback ?? FeedbackService.instance,
        _play = playSound ?? _playViaAudioService,
        _praiseMissing =
            praiseMissing ?? (() => AudioService.instance.praiseKnownMissing),
        _now = now ?? DateTime.now,
        super(const BloomState()) {
    _speaking.addListener(_onSpeakingChanged);
    _feedback.addListener(_onFeedback);
    if (_speaking.value) _onSpeakingChanged();
  }

  static void _playViaAudioService(BloomSound s) {
    unawaited(AudioService.instance.playBloom(s.file, volume: s.volume));
  }

  // ── Priorities (§5.3) ─────────────────────────────────────────────────

  /// `sleep` 0 < `idle` 1 < `listen` 2 < `wave` 3 < `curious` = `point` 4
  /// < `blow` 5 < `happy` 6 < `cheer` 7.
  static int priorityOf(BloomEmotion e) => switch (e) {
        BloomEmotion.sleep => 0,
        BloomEmotion.idle => 1,
        BloomEmotion.listen => 2,
        BloomEmotion.wave => 3,
        BloomEmotion.curious => 4,
        BloomEmotion.point => 4,
        BloomEmotion.blow => 5,
        BloomEmotion.happy => 6,
        BloomEmotion.cheer => 7,
      };

  /// Rate limits and thresholds (§5.3 п. 6, 8).
  static const greetingGap = Duration(minutes: 5);
  static const resumeGreetAfter = Duration(minutes: 5);
  static const giggleGap = Duration(milliseconds: 1500);
  static const cardHopGap = Duration(seconds: 3);
  static const secondHintAfter = Duration(seconds: 8);
  static const maxHintsPerTarget = 2;

  /// When the nap is due but Bloom is mid-gesture or a word is playing.
  static const sleepRetry = Duration(seconds: 2);

  /// Idle time before the first hint by profile level (L1 6 / L2 8 / L3+ 10).
  static Duration firstHintAfter(int level) => switch (level) {
        <= 1 => const Duration(seconds: 6),
        2 => const Duration(seconds: 8),
        _ => const Duration(seconds: 10),
      };

  /// Every N-th forward card earns a hop (L1 3 / L2+ 5).
  static int hopEvery(int level) => level <= 1 ? 3 : 5;

  final int Function() _profileLevel;
  final ValueListenable<bool> _speaking;
  final FeedbackService _feedback;
  final void Function(BloomSound) _play;
  final bool Function() _praiseMissing;
  final DateTime Function() _now;

  final LinkedHashMap<Object, BloomScene> _scenes = LinkedHashMap();
  BloomScene get scene => _scenes.isEmpty ? BloomScene.still : _scenes.values.last;

  Timer? _oneShotTimer;
  Timer? _listenRelease;
  Timer? _hintTimer;
  Timer? _sleepTimer;
  Timer? _lookTimer;
  BloomEmotion? _oneShot;
  bool _paused = false;
  bool _disposed = false;

  DateTime? _lastGreeting;
  DateTime? _lastGiggle;
  DateTime? _lastCardHop;
  int _forwardCards = 0;
  int _hintsGiven = 0;
  Alignment? _hintTarget;

  /// Test seam: the one-shot currently playing, if any.
  @visibleForTesting
  BloomEmotion? get activeOneShot => _oneShot;

  // ── Public API ────────────────────────────────────────────────────────

  /// Dispatch any event. Hosts may also call the named methods below.
  void handle(BloomEvent e) {
    if (_disposed) return;
    switch (e) {
      case BloomAppEntered(:final firstOfDay):
        appEntered(firstOfDay: firstOfDay);
      case BloomAppResumed(:final away):
        appResumed(away);
      case BloomAppPaused():
        appPaused();
      case BloomSceneEntered(:final key, :final scene):
        sceneEntered(key, scene);
      case BloomSceneLeft(:final key):
        sceneLeft(key);
      case BloomPackOpened():
        packOpened();
      case BloomCardAdvanced(:final index):
        cardAdvanced(index);
      case BloomObjectTapped():
        objectTapped();
      case BloomSuccess(:final tier):
        success(tier);
      case BloomMiss(:final countInRound):
        miss(countInRound);
      case BloomPackCompleted():
        packCompleted();
      case BloomUserTouch(:final position):
        userTouch(position);
      case BloomTapped():
        bloomTapped();
      case BloomHintTargetChanged(:final target):
        hintTargetChanged(target);
      case BloomSessionEnding(:final withSound):
        sessionEnding(withSound: withSound);
    }
  }

  void appEntered({bool firstOfDay = false}) {
    final t = _now();
    final last = _lastGreeting;
    if (last != null && t.difference(last) < greetingGap) return;
    _lastGreeting = t;
    _startOneShot(BloomEmotion.wave, DT.motion.bloomWave, sound: BloomSound.hi);
  }

  void appResumed(Duration away) {
    _paused = false;
    _armIdleTimers();
    if (away < resumeGreetAfter) return;
    _lastGreeting = _now();
    _startOneShot(BloomEmotion.wave, DT.motion.bloomWave, sound: BloomSound.hi);
  }

  void appPaused() {
    _paused = true;
    _hintTimer?.cancel();
    _sleepTimer?.cancel();
  }

  /// Mount or update a host. The most recently entered scene is the stage;
  /// when it leaves, the one under it takes over (cards over home).
  void sceneEntered(Object key, BloomScene scene) {
    final isNew = !_scenes.containsKey(key);
    final wasActive = _scenes.isNotEmpty && _scenes.keys.last == key;
    _scenes.remove(key);
    _scenes[key] = scene;
    final fresh = isNew || !wasActive;
    if (fresh) {
      _hintsGiven = 0;
      _hintTarget = null;
      _cancelOneShot();
      _wake(silent: true);
    }
    _setState(state.copyWith(
      ambient: scene.ambient,
      emotion: fresh ? _levelEmotion : null,
      clearHint: fresh,
      clearLookAt: fresh,
    ));
    _armIdleTimers();
  }

  void sceneLeft(Object key) {
    if (_scenes.remove(key) == null) return;
    _hintsGiven = 0;
    _hintTarget = null;
    _cancelOneShot();
    _wake(silent: true);
    _setState(state.copyWith(
      emotion: _levelEmotion,
      ambient: scene.ambient,
      clearHint: true,
    ));
    _armIdleTimers();
  }

  void packOpened() {
    _forwardCards = 0;
    _hintsGiven = 0;
    _startOneShot(
      BloomEmotion.curious,
      DT.motion.bloomCurious,
      lookAt: _hintTarget ?? _defaultCardLook,
    );
    _armIdleTimers();
  }

  /// Pupils glance towards where the card came from, then back.
  static const _defaultCardLook = Alignment(0.7, -0.8);
  static const _cameFromRight = Alignment(1, -0.2);

  void cardAdvanced(int index) {
    _activity();
    _forwardCards++;
    _hintsGiven = 0;
    _glance(_cameFromRight);
    final every = hopEvery(_profileLevel());
    if (_forwardCards % every != 0) return;
    final t = _now();
    final last = _lastCardHop;
    if (last != null && t.difference(last) < cardHopGap) return;
    _lastCardHop = t;
    // Silent on purpose: the pause between words belongs to the word.
    _startOneShot(BloomEmotion.happy, DT.motion.celebrate);
  }

  void objectTapped() => _activity();

  void success(BloomSuccessTier tier) {
    _activity();
    switch (tier) {
      case BloomSuccessTier.micro:
        _startOneShot(BloomEmotion.happy, DT.motion.celebrate);
      case BloomSuccessTier.round:
        _cheer(hops: 3);
    }
  }

  void miss(int countInRound) {
    _activity();
    if (countInRound <= 1) {
      _startOneShot(BloomEmotion.curious, DT.motion.bloomCurious);
      return;
    }
    final target = _hintTarget;
    if (target == null) return;
    _startOneShot(
      BloomEmotion.point,
      DT.motion.bloomPoint,
      hintDirection: target,
      lookAt: target,
    );
  }

  void packCompleted() {
    _activity();
    _cheer(hops: 3);
  }

  void userTouch([Offset? position]) => _activity();

  void bloomTapped() {
    _activity();
    // The hop always; the giggle at most once per 1.5 s, never over a word.
    final t = _now();
    final last = _lastGiggle;
    BloomSound? sound;
    if (last == null || t.difference(last) >= giggleGap) {
      _lastGiggle = t;
      sound = BloomSound.giggle;
    }
    _startOneShot(BloomEmotion.happy, DT.motion.celebrate, sound: sound);
    if (sound == null) return;
    // The hop may have been swallowed by the debounce (§5.3 п. 2) — the
    // giggle is still owed; play it here when the one-shot did not.
    if (_oneShot != BloomEmotion.happy) _playSound(sound);
  }

  void hintTargetChanged(Alignment? target) {
    _hintTarget = target;
    if (target != null && state.emotion == BloomEmotion.idle) {
      _setState(state.copyWith(lookAt: target));
    }
  }

  void sessionEnding({bool withSound = false}) {
    _startOneShot(
      BloomEmotion.wave,
      DT.motion.bloomWave,
      sound: withSound ? BloomSound.bye : null,
    );
  }

  // ── Feedback + narrator subscriptions ─────────────────────────────────

  void _onFeedback(FeedbackEvent e) {
    if (_disposed) return;
    switch (e) {
      case FeedbackEvent.tap:
      case FeedbackEvent.select:
      case FeedbackEvent.swipe:
        _activity();
      case FeedbackEvent.correct:
        success(BloomSuccessTier.micro);
      case FeedbackEvent.wrong:
        miss(1);
      case FeedbackEvent.roundDone:
      case FeedbackEvent.gameDone:
      case FeedbackEvent.packDone:
        success(BloomSuccessTier.round);
      case FeedbackEvent.reveal:
        _startOneShot(BloomEmotion.curious, DT.motion.bloomCurious);
      case FeedbackEvent.milestone:
      case FeedbackEvent.lockedHint:
        // A parent-facing bell / a locked tile: Bloom takes no part.
        break;
    }
  }

  void _onSpeakingChanged() {
    if (_disposed) return;
    if (_speaking.value) {
      _listenRelease?.cancel();
      _listenRelease = null;
      if (state.level == BloomLevel.sleep) _wake(silent: true);
      _setLevel(BloomLevel.listen);
      _hintTimer?.cancel();
      _sleepTimer?.cancel();
      return;
    }
    // Hysteresis: a phrase has tiny silences inside it.
    _listenRelease?.cancel();
    _listenRelease = Timer(DT.motion.bloomListenRelease, () {
      _listenRelease = null;
      if (_disposed || _speaking.value) return;
      if (state.level == BloomLevel.listen) _setLevel(BloomLevel.idle);
      _armIdleTimers();
    });
  }

  // ── Levels and one-shots ──────────────────────────────────────────────

  BloomEmotion get _levelEmotion => switch (state.level) {
        BloomLevel.sleep => BloomEmotion.sleep,
        BloomLevel.idle => BloomEmotion.idle,
        BloomLevel.listen => BloomEmotion.listen,
      };

  void _setLevel(BloomLevel level) {
    final showLevel = _oneShot == null;
    _setState(state.copyWith(
      level: level,
      emotion: showLevel ? _emotionFor(level) : null,
      lookAt: level == BloomLevel.listen
          ? (_hintTarget ?? _defaultCardLook)
          : null,
    ));
  }

  static BloomEmotion _emotionFor(BloomLevel level) => switch (level) {
        BloomLevel.sleep => BloomEmotion.sleep,
        BloomLevel.idle => BloomEmotion.idle,
        BloomLevel.listen => BloomEmotion.listen,
      };

  /// Start a one-shot if it outranks the current one (§5.3 п. 2). Equal or
  /// lower is dropped — which is also the `happy` debounce: a hop already
  /// in the air keeps flying. Sleep never blocks: any one-shot wakes.
  void _startOneShot(
    BloomEmotion emotion,
    Duration length, {
    int hops = 1,
    Alignment? lookAt,
    Alignment? hintDirection,
    bool swipe = false,
    BloomSound? sound,
  }) {
    final current = _oneShot;
    if (current != null && priorityOf(emotion) <= priorityOf(current)) {
      return;
    }
    if (state.level == BloomLevel.sleep) _wake(silent: true);
    _oneShotTimer?.cancel();
    _oneShot = emotion;
    _setState(state.copyWith(
      emotion: emotion,
      hops: hops,
      lookAt: lookAt ?? state.lookAt,
      hintDirection: hintDirection,
      clearHint: hintDirection == null,
      swipeGesture: swipe,
      serial: state.serial + 1,
    ));
    if (sound != null) _playSound(sound);
    _oneShotTimer = Timer(length, () => _endOneShot(emotion));
  }

  void _endOneShot(BloomEmotion ended) {
    if (_disposed || _oneShot != ended) return;
    _oneShot = null;
    _oneShotTimer = null;
    if (ended == BloomEmotion.cheer) {
      // Idle with the happy face a while longer, no hop.
      _oneShot = BloomEmotion.happy;
      _setState(state.copyWith(
        emotion: BloomEmotion.happy,
        hops: 0,
        clearHint: true,
        swipeGesture: false,
      ));
      _oneShotTimer = Timer(
        DT.motion.bloomAfterglow,
        () => _endOneShot(BloomEmotion.happy),
      );
      return;
    }
    _setState(state.copyWith(
      emotion: _levelEmotion,
      hops: 1,
      clearHint: true,
      swipeGesture: false,
      lookAt: state.level == BloomLevel.listen
          ? (_hintTarget ?? _defaultCardLook)
          : _hintTarget,
      clearLookAt: state.level != BloomLevel.listen && _hintTarget == null,
    ));
  }

  void _cancelOneShot() {
    _oneShotTimer?.cancel();
    _oneShotTimer = null;
    _oneShot = null;
  }

  void _cheer({required int hops}) {
    // The narrator's praise is the cheer's voice; Bloom's own `yay` stands
    // in only when praise is known to be missing (§6).
    final sound = _praiseMissing() ? BloomSound.yay : null;
    _startOneShot(
      BloomEmotion.cheer,
      hops >= 3 ? DT.motion.bloomCheerBig : DT.motion.bloomCheer,
      hops: hops,
      sound: sound,
    );
  }

  /// A quick look towards [where], back to the target after a nod's time.
  void _glance(Alignment where) {
    _lookTimer?.cancel();
    _setState(state.copyWith(lookAt: where));
    _lookTimer = Timer(DT.motion.bloomNod, () {
      _lookTimer = null;
      if (_disposed) return;
      final back = _hintTarget ??
          (state.level == BloomLevel.listen ? _defaultCardLook : null);
      _setState(state.copyWith(lookAt: back, clearLookAt: back == null));
    });
  }

  // ── Idle: hints and sleep (§5.3 п. 3, 4, 8) ──────────────────────────

  /// Any child action: resets the idle clock; wakes Bloom if asleep.
  void _activity() {
    if (state.level == BloomLevel.sleep) {
      _wake(silent: false);
    }
    _armIdleTimers();
  }

  void _wake({required bool silent}) {
    if (state.level != BloomLevel.sleep) return;
    _setState(state.copyWith(level: BloomLevel.idle, emotion: BloomEmotion.idle));
    if (!silent) _startOneShot(BloomEmotion.happy, DT.motion.celebrate);
  }

  void _armIdleTimers() {
    _hintTimer?.cancel();
    _sleepTimer?.cancel();
    if (_paused || _disposed) return;
    final sc = scene;
    if (sc.hintsEnabled && _hintsGiven < maxHintsPerTarget) {
      final delay = _hintsGiven == 0
          ? firstHintAfter(_profileLevel())
          : secondHintAfter;
      _hintTimer = Timer(delay, _hint);
    }
    final sleepAfter = sc.sleepAfter;
    if (sleepAfter != null) {
      _sleepTimer = Timer(sleepAfter, _trySleep);
    }
  }

  void _hint() {
    _hintTimer = null;
    if (_disposed || _paused || !scene.hintsEnabled) return;
    if (_speaking.value || _oneShot != null) {
      // Busy — try again after the second-hint gap without spending a hint.
      _hintTimer = Timer(secondHintAfter, _hint);
      return;
    }
    _hintsGiven++;
    final second = _hintsGiven >= 2;
    final swipe = second && scene.swipeHint;
    final direction = swipe
        ? const Alignment(-1, 0)
        : (_hintTarget ?? _defaultCardLook);
    _startOneShot(
      BloomEmotion.point,
      DT.motion.bloomPoint,
      hintDirection: direction,
      lookAt: direction,
      swipe: swipe,
      // Only the first hint speaks, and only when Bloom is the only actor.
      sound: !second && scene.soloActor ? BloomSound.hmm : null,
    );
    if (_hintsGiven < maxHintsPerTarget) {
      _hintTimer = Timer(secondHintAfter, _hint);
    }
  }

  void _trySleep() {
    _sleepTimer = null;
    if (_disposed || _paused) return;
    if (state.level != BloomLevel.idle || _oneShot != null || _speaking.value) {
      // Not a quiet moment; sleep only ever enters from plain idle. Look
      // again shortly — the idle clock itself counts from the last touch.
      if (scene.sleepAfter != null) _sleepTimer = Timer(sleepRetry, _trySleep);
      return;
    }
    _hintTimer?.cancel();
    _setState(state.copyWith(
      level: BloomLevel.sleep,
      emotion: BloomEmotion.sleep,
      clearLookAt: true,
      clearHint: true,
    ));
    _playSound(BloomSound.zzz);
  }

  // ── Sound (§6) ────────────────────────────────────────────────────────

  /// Never over a word: dropped, not delayed.
  void _playSound(BloomSound sound) {
    if (_speaking.value) return;
    _play(sound);
  }

  /// Latest state asked for while a frame was still building; applied at
  /// the end of that frame.
  BloomState? _deferred;

  void _setState(BloomState next) {
    if (_disposed) return;
    // Screens report their events from initState/dispose, i.e. while the
    // widget tree is building. Riverpod refuses a provider write there
    // (a red screen on device — tests run without the check). A mascot
    // is allowed to be one frame late, so park the write until the frame
    // is done rather than teaching every screen about the phase.
    final phase = SchedulerBinding.instance.schedulerPhase;
    final building = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks;
    if (!building) {
      _deferred = null;
      if (next != state) state = next;
      return;
    }
    final schedule = _deferred == null;
    _deferred = next;
    if (schedule) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final pending = _deferred;
        _deferred = null;
        if (_disposed || pending == null || pending == state) return;
        state = pending;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _speaking.removeListener(_onSpeakingChanged);
    _feedback.removeListener(_onFeedback);
    _oneShotTimer?.cancel();
    _listenRelease?.cancel();
    _hintTimer?.cancel();
    _sleepTimer?.cancel();
    _lookTimer?.cancel();
    super.dispose();
  }
}
