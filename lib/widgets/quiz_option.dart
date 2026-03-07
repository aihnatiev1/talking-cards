import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../utils/constants.dart';

class QuizOption extends StatefulWidget {
  final CardModel card;
  final bool? isCorrectAnswer;
  final VoidCallback onTap;

  const QuizOption({
    super.key,
    required this.card,
    required this.onTap,
    this.isCorrectAnswer,
  });

  @override
  State<QuizOption> createState() => _QuizOptionState();
}

class _QuizOptionState extends State<QuizOption>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant QuizOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCorrectAnswer == false && oldWidget.isCorrectAnswer != false) {
      _shakeCtrl.forward().then((_) => _shakeCtrl.reset());
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine visual state
    final bool isCorrect = widget.isCorrectAnswer == true;
    final bool isWrong = widget.isCorrectAnswer == false;

    final Color cardColor = widget.card.colorBg;
    Color overlayColor;
    if (isCorrect) {
      overlayColor = kTeal;
    } else if (isWrong) {
      overlayColor = const Color(0xFFFF6B6B);
    } else {
      overlayColor = cardColor;
    }

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final shake = _shakeCtrl.isAnimating
            ? 10.0 *
                (1 - _shakeCtrl.value) *
                ((_shakeCtrl.value * 8).toInt().isEven ? 1 : -1)
            : 0.0;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _pressAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: overlayColor.withValues(alpha: isCorrect || isWrong ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: overlayColor.withValues(alpha: isCorrect || isWrong ? 0.8 : 0.3),
                width: isCorrect || isWrong ? 3 : 2,
              ),
              boxShadow: [
                if (isCorrect)
                  BoxShadow(
                    color: kTeal.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                if (!isCorrect && !isWrong)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: widget.card.image != null
                      ? Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/images/webp/${widget.card.image}.webp',
                            fit: BoxFit.contain,
                          ),
                        )
                      : FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              widget.card.emoji,
                              style: const TextStyle(fontSize: 56),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.card.sound,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isCorrect
                        ? kTeal
                        : isWrong
                            ? const Color(0xFFFF6B6B)
                            : kSoundRed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
