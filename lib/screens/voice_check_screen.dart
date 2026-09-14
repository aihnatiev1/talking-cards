import 'package:flutter/material.dart';

import '../services/listen_service.dart';
import '../services/voice_gate.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';

/// Parent-side tuning HUD for the listening gate.
///
/// Speak & Repeat rests on three numbers — the room floor, how far above
/// it counts as a voice, and how long that must last — and none of them
/// can be chosen at a desk. This screen shows a live turn as it happens:
/// the raw sample, the floor the gate settled on, the line it has to
/// cross, and the verdict. Run it in the kitchen with the TV on and in a
/// bedroom at night, with the child's own voice, and the thresholds stop
/// being guesses.
///
/// It lives behind the parental gate and turns the microphone on only for
/// as long as it is open: nothing here changes the profile's setting.
class VoiceCheckScreen extends StatefulWidget {
  final bool isEn;
  const VoiceCheckScreen({super.key, required this.isEn});

  @override
  State<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends State<VoiceCheckScreen> {
  final _listen = ListenService.instance;

  /// What the microphone toggle was before this screen borrowed it. Read
  /// eagerly in [initState]: a lazy `late final` would not be evaluated
  /// until dispose, by which point it would be reading the value this
  /// screen itself set.
  late bool _enabledBefore;

  VoiceOutcome? _last;
  int _spoke = 0;
  int _quiet = 0;
  bool _busy = false;
  String? _blocked;

  @override
  void initState() {
    super.initState();
    _enabledBefore = _listen.enabled.value;
    _listen.enabled.value = true;
  }

  @override
  void dispose() {
    _listen.cancel();
    _listen.enabled.value = _enabledBefore;
    super.dispose();
  }

  Future<void> _run() async {
    final s = AppS(widget.isEn);
    if (_busy) return;
    setState(() {
      _busy = true;
      _blocked = null;
      _last = null;
    });
    if (!await _listen.hasPermission()) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _blocked = s(
          'Немає дозволу на мікрофон — дай його в Налаштуваннях iOS.',
          'No microphone permission — grant it in iOS Settings.',
        );
      });
      return;
    }
    final outcome = await _listen.listenOnce();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = outcome;
      if (outcome == VoiceOutcome.spoke) {
        _spoke++;
      } else {
        _quiet++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn);
    return Scaffold(
      appBar: AppBar(
        title: Text(s('Перевірка мікрофона', 'Microphone check')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            s(
              'Натисни «Слухати» і скажи слово так, як його каже дитина. '
                  'Екран показує, що чує застосунок: рівень звуку, рівень '
                  'кімнати і межу, яку треба перетнути.',
              'Press “Listen” and say a word the way your child says it. '
                  'The screen shows what the app hears: the level, the '
                  'room’s own level and the line a voice has to cross.',
            ),
            style: DT.caption.copyWith(fontSize: 13, color: DT.textSecondary),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<({double db, double? floorDb})?>(
            valueListenable: _listen.sample,
            builder: (_, sample, __) => _Meter(
              isEn: widget.isEn,
              db: sample?.db,
              floorDb: sample?.floorDb,
              listening: _busy,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _busy ? null : _run,
              icon: const Icon(Icons.mic_rounded),
              label: Text(
                _busy ? s('Слухаю…', 'Listening…') : s('Слухати', 'Listen'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 56),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_blocked != null)
            Text(
              _blocked!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DT.error),
            ),
          if (_last != null) ...[
            Center(
              child: Text(
                _last == VoiceOutcome.spoke
                    ? s('Почув голос', 'Heard a voice')
                    : s('Тиша', 'Quiet'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _last == VoiceOutcome.spoke
                      ? DT.success
                      : DT.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // The numbers the verdict was made from, kept on screen: a
            // verdict alone says nothing about which threshold to move.
            ValueListenableBuilder<
              ({double? floorDb, double peakDb, int ms, VoiceOutcome outcome})?
            >(
              valueListenable: _listen.lastTurn,
              builder: (_, turn, __) => turn == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _row(
                          s('Кімната', 'Room'),
                          turn.floorDb == null
                              ? s('не зміряна', 'not measured')
                              : '${turn.floorDb!.toStringAsFixed(1)} dB',
                        ),
                        _row(
                          s('Найгучніше', 'Loudest'),
                          '${turn.peakDb.toStringAsFixed(1)} dB',
                        ),
                        _row(
                          s('Тривалість', 'Length'),
                          '${turn.ms} ms',
                        ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          _row(s('Почув голос', 'Heard a voice'), '$_spoke'),
          _row(s('Тиша', 'Quiet'), '$_quiet'),
          const SizedBox(height: 16),
          _row(
            s('Поріг над кімнатою', 'Threshold over the room'),
            '+${VoiceGate.thresholdDb.toStringAsFixed(0)} dB',
          ),
          _row(
            s('Мінімальна тривалість', 'Minimum length'),
            '${VoiceGate.minSpeechMs} ms',
          ),
          _row(s('Вікно', 'Window'), '${VoiceGate.windowMs} ms'),
          _row(
            s('Калібрування', 'Calibration'),
            '${VoiceGate.calibrationMs} ms',
          ),
          const SizedBox(height: 20),
          Text(
            s(
              'Нічого не записується і нікуди не надсилається — застосунок '
                  'читає лише гучність. Мікрофон вимкнеться, щойно закриєш '
                  'цей екран.',
              'Nothing is recorded and nothing is sent — the app reads '
                  'loudness only. The microphone switches off as soon as '
                  'you leave this screen.',
            ),
            style: DT.caption.copyWith(fontSize: 12, color: DT.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DT.caption.copyWith(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// A dB ruler from -60 to 0 with three marks: the room, the line a voice
/// must cross, and where the microphone is right now.
class _Meter extends StatelessWidget {
  final bool isEn;
  final double? db;
  final double? floorDb;
  final bool listening;

  const _Meter({
    required this.isEn,
    required this.db,
    required this.floorDb,
    required this.listening,
  });

  static const _min = -60.0;
  static const _max = 0.0;

  double _fraction(double value) =>
      ((value - _min) / (_max - _min)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    final live = db;
    final floor = floorDb;
    final line = floor == null ? null : floor + VoiceGate.thresholdDb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (_, box) => SizedBox(
            height: 48,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DT.textPrimary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (live != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: box.maxWidth * _fraction(live),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            (line != null && live >= line
                                    ? DT.success
                                    : DT.brand)
                                .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (floor != null)
                  Positioned(
                    left: box.maxWidth * _fraction(floor) - 1,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: const ColoredBox(color: DT.textMuted),
                  ),
                if (line != null)
                  Positioned(
                    left: box.maxWidth * _fraction(line) - 1,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: const ColoredBox(color: DT.hint),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          live == null
              ? (listening
                    ? s('Калібрую кімнату…', 'Calibrating the room…')
                    : s('—', '—'))
              : s(
                  'зараз ${live.toStringAsFixed(1)} dB · кімната '
                      '${floor?.toStringAsFixed(1) ?? '…'} · межа '
                      '${line?.toStringAsFixed(1) ?? '…'}',
                  'now ${live.toStringAsFixed(1)} dB · room '
                      '${floor?.toStringAsFixed(1) ?? '…'} · line '
                      '${line?.toStringAsFixed(1) ?? '…'}',
                ),
          style: DT.caption.copyWith(
            fontSize: 13,
            color: DT.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
