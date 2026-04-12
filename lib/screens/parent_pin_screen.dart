import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/parent_auth_provider.dart';
import '../utils/constants.dart';
import 'parent_dashboard_screen.dart';

enum _PinMode { enter, setup, confirm }

/// PIN entry or setup screen for the parent area.
///
/// - [isSetup] = true → first-time PIN creation (enter + confirm)
/// - [isSetup] = false → enter existing PIN
class ParentPinScreen extends ConsumerStatefulWidget {
  final bool isSetup;

  const ParentPinScreen({super.key, required this.isSetup});

  @override
  ConsumerState<ParentPinScreen> createState() => _ParentPinScreenState();
}

class _ParentPinScreenState extends ConsumerState<ParentPinScreen>
    with SingleTickerProviderStateMixin {
  _PinMode _mode = _PinMode.enter;
  String _pin = '';
  String _firstPin = ''; // stored during confirm step
  String? _errorText;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _mode = widget.isSetup ? _PinMode.setup : _PinMode.enter;
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  // ── PIN input ────────────────────────────────

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _errorText = null;
    });
    HapticFeedback.selectionClick();
    if (_pin.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onComplete() async {
    switch (_mode) {
      case _PinMode.enter:
        final ok = await ref.read(parentAuthProvider.notifier).verify(_pin);
        if (!mounted) return;
        if (ok) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => const ParentDashboardScreen()),
          );
        } else {
          _showError('Невірний PIN');
        }

      case _PinMode.setup:
        _firstPin = _pin;
        setState(() {
          _pin = '';
          _mode = _PinMode.confirm;
        });

      case _PinMode.confirm:
        if (_pin == _firstPin) {
          await ref.read(parentAuthProvider.notifier).setPin(_pin);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => const ParentDashboardScreen()),
          );
        } else {
          _firstPin = '';
          setState(() => _mode = _PinMode.setup);
          _showError('PIN не збігається. Спробуйте ще раз.');
        }
    }
  }

  void _showError(String msg) {
    HapticFeedback.mediumImpact();
    setState(() {
      _pin = '';
      _errorText = msg;
    });
    _shake.forward(from: 0);
  }

  Future<void> _resetPin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Скинути PIN?'),
        content: const Text(
            'Доступ до батьківської зони буде тимчасово заблокований.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Скасувати')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Скинути',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(parentAuthProvider.notifier).resetPin();
      if (mounted) {
        setState(() {
          _pin = '';
          _firstPin = '';
          _mode = _PinMode.setup;
          _errorText = null;
        });
      }
    }
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _PinMode.enter => 'Введіть PIN',
      _PinMode.setup => 'Встановіть PIN',
      _PinMode.confirm => 'Підтвердіть PIN',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('👨‍👩‍👧 Режим батьків',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            // PIN dots
            AnimatedBuilder(
              animation: _shake,
              builder: (_, child) {
                final offset =
                    _shake.value < 0.5 ? _shake.value * 16 : (1 - _shake.value) * 16;
                return Transform.translate(
                  offset: Offset(offset * ((_shake.value * 10).toInt().isEven ? 1 : -1), 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? kAccent : Colors.white24,
                      border: Border.all(
                        color: filled ? kAccent : Colors.white38,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorText != null)
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            const Spacer(),
            // Number pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  _row(['1', '2', '3']),
                  const SizedBox(height: 12),
                  _row(['4', '5', '6']),
                  const SizedBox(height: 12),
                  _row(['7', '8', '9']),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Forgot PIN (only in enter mode)
                      if (_mode == _PinMode.enter)
                        TextButton(
                          onPressed: _resetPin,
                          child: const Text('Забули?',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13)),
                        )
                      else
                        const SizedBox(width: 72),
                      _numButton('0'),
                      _deleteButton(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map(_numButton).toList(),
      );

  Widget _numButton(String digit) => GestureDetector(
        onTap: () => _onDigit(digit),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 1),
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );

  Widget _deleteButton() => GestureDetector(
        onTap: _onDelete,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: const Center(
            child: Icon(Icons.backspace_outlined,
                color: Colors.white54, size: 24),
          ),
        ),
      );
}
