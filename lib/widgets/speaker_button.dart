import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_service.dart';
import '../utils/constants.dart';

/// Self-contained speaker toggle button.
/// Uses ValueListenableBuilder — rebuilds only itself, not the parent.
class SpeakerButton extends StatefulWidget {
  /// Called when autoSpeak is toggled on and current card should be spoken.
  final VoidCallback? onActivated;

  const SpeakerButton({super.key, this.onActivated});

  @override
  State<SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<SpeakerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const _onColor = kTeal;
  static const _offColor = kSoundRed;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    AudioService.instance.isSpeaking.addListener(_updatePulse);
    AudioService.instance.autoSpeak.addListener(_updatePulse);
  }

  @override
  void dispose() {
    AudioService.instance.isSpeaking.removeListener(_updatePulse);
    AudioService.instance.autoSpeak.removeListener(_updatePulse);
    _pulseController.dispose();
    super.dispose();
  }

  void _updatePulse() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final speaking = AudioService.instance.isSpeaking.value;
      final autoOn = AudioService.instance.autoSpeak.value;
      if (speaking && autoOn) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioService.instance.autoSpeak,
      builder: (_, autoOn, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: AudioService.instance.isSpeaking,
          builder: (_, speaking, __) {
            return GestureDetector(
              onTap: () async {
                final audio = AudioService.instance;
                final newValue = !audio.autoSpeak.value;
                audio.autoSpeak.value = newValue;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('auto_speak', newValue);
                if (newValue) {
                  widget.onActivated?.call();
                } else {
                  audio.stop();
                }
              },
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: autoOn ? _onColor : _offColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: autoOn
                            ? _onColor.withValues(alpha: 0.4)
                            : _offColor.withValues(alpha: 0.3),
                        blurRadius: speaking && autoOn ? 12 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    autoOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
