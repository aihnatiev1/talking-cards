import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ParentalGate {
  /// Shows the parental gate dialog. Returns true if the parent answers correctly.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ParentalGateDialog(),
    );
    return result ?? false;
  }
}

class _ParentalGateDialog extends StatefulWidget {
  const _ParentalGateDialog();

  @override
  State<_ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  final _random = Random();
  late int _a;
  late int _b;
  late int _correctAnswer;
  late List<int> _options;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    _a = _random.nextInt(9) + 2; // 2..10
    _b = _random.nextInt(9) + 2; // 2..10
    _correctAnswer = _a + _b;

    final wrongAnswers = <int>{};
    while (wrongAnswers.length < 3) {
      final wrong = _correctAnswer + _random.nextInt(11) - 5;
      if (wrong != _correctAnswer && wrong > 0) {
        wrongAnswers.add(wrong);
      }
    }

    _options = [_correctAnswer, ...wrongAnswers]..shuffle(_random);
    _showError = false;
  }

  void _onAnswer(int answer) {
    if (answer == _correctAnswer) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _showError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Перевірка для батьків',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Скільки буде $_a + $_b?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _options.map((option) {
                return SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () => _onAnswer(option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '$option',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_showError) ...[
              const SizedBox(height: 16),
              const Text(
                'Попроси маму або тата 😊',
                style: TextStyle(fontSize: 16, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Скасувати',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
