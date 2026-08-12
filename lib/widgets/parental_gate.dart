import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/l10n.dart';

/// Simple parental gate: an addition question written in WORDS (so a
/// pre-reading child can't parse it) answered on a numeric keypad.
/// Returns true when the adult solves it; false on dismiss or 3 misses.
///
/// Kept deliberately friction-light (no PIN to forget) — the goal is to
/// stop random toddler taps from reaching the parent area, per Apple's
/// parental-gate guidance for kids-oriented apps.
Future<bool> showParentalGate(BuildContext context, {required bool isEn}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentalGateDialog(isEn: isEn),
  );
  return ok ?? false;
}

const _ukWords = [
  '', 'один', 'два', 'три', 'чотири', 'п’ять', 'шість', 'сім',
  'вісім', 'дев’ять'
];
const _enWords = [
  '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'
];

class _ParentalGateDialog extends StatefulWidget {
  final bool isEn;
  const _ParentalGateDialog({required this.isEn});

  @override
  State<_ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  final _rng = Random();
  late int _a;
  late int _b;
  String _entered = '';
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 3 + _rng.nextInt(7); // 3..9
    _b = 3 + _rng.nextInt(7);
    _entered = '';
  }

  String get _question {
    final words = widget.isEn ? _enWords : _ukWords;
    return widget.isEn
        ? '${words[_a]} plus ${words[_b]}?'
        : '${words[_a]} плюс ${words[_b]}?';
  }

  void _tapDigit(int d) {
    HapticFeedback.lightImpact();
    setState(() => _entered += '$d');
    final answer = (_a + _b).toString();
    if (_entered.length < answer.length) return;
    if (_entered == answer) {
      Navigator.of(context).pop(true);
      return;
    }
    _misses++;
    if (_misses >= 3) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(_newQuestion);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppS(widget.isEn ? 'en' : 'uk');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s('Для батьків', 'For parents'),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _entered.isEmpty ? ' ' : _entered,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: kAccent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            for (final row in const [
              [1, 2, 3],
              [4, 5, 6],
              [7, 8, 9],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in row) _key(d),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_key(0)],
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                s('Скасувати', 'Cancel'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _key(int d) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 64,
        height: 56,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: kAccent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _tapDigit(d),
          child: Text(
            '$d',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kAccent,
            ),
          ),
        ),
      ),
    );
  }
}
