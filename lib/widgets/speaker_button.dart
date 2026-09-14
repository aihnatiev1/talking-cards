import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import 'ambient_loop.dart';
import 'kid_tap.dart';

/// Self-contained speaker toggle button.
/// Uses ValueListenableBuilder — rebuilds only itself, not the parent.
class SpeakerButton extends StatelessWidget {
  /// Called when autoSpeak is toggled on and current card should be spoken.
  final VoidCallback? onActivated;

  const SpeakerButton({super.key, this.onActivated});

  static const _onColor = DT.teal;
  static const _offColor = DT.soundRed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioService.instance.autoSpeak,
      builder: (_, autoOn, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: AudioService.instance.isSpeaking,
          builder: (_, speaking, __) {
            return KidTap(
              // Toggling speech is itself the sound of this tap.
              sound: null,
              onTap: () {
                final audio = AudioService.instance;
                final newValue = !audio.autoSpeak.value;
                // Session-only mute — never persisted, so an accidental
                // toddler tap can't silence the app across launches.
                audio.autoSpeak.value = newValue;
                if (newValue) {
                  onActivated?.call();
                } else {
                  // The only action in the app whose answer used to be
                  // silence. A low tock says "heard" (sound_palette §6.14).
                  audio.stop();
                  FeedbackService.instance.play(KidSound.tap, pitch: 0.9);
                }
              },
              // Pulses (1.0 → 1.2, 500 ms) while a clip plays with sound
              // on. Under reduced motion it rests at 1.0 — the wider shadow
              // while speaking (blurRadius 12 vs 6) still shows that audio
              // is playing.
              child: AmbientLoop(
                period: const Duration(milliseconds: 500),
                enabled: speaking && autoOn,
                builder: (_, t, child) => Transform.scale(
                  scale: 1.0 + 0.2 * t,
                  child: child,
                ),
                child: Container(
                  // The one control a child presses on the cards screen, so
                  // it carries the full 72 dp target (CLAUDE.md rule 1 /
                  // ux-gap G12) rather than the old 56.
                  width: DT.size.tapMin,
                  height: DT.size.tapMin,
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
                  // White paper speaker on the saturated disc; the ink
                  // outline keeps it legible on both the teal and the red.
                  child: Center(
                    child: AppIconView(
                      autoOn ? AppIcon.sound : AppIcon.soundOff,
                      // 0.53 of the disc — the ratio the 30/56 button had.
                      size: 38,
                      color: Colors.white,
                    ),
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
