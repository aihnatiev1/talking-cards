import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import 'ambient_loop.dart';
import 'kid_tap.dart';

/// The round 72 dp «listen again» button in a game's header: the painted
/// ear on a white disc, breathing while a recording plays.
class ListenButton extends StatelessWidget {
  const ListenButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = DT.brand,
  });

  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: KidTap(
      // It replays a voice — no pop under it.
      sound: null,
      onTap: onTap,
      child: ValueListenableBuilder<bool>(
        valueListenable: AudioService.instance.isSpeaking,
        builder: (_, speaking, disc) => AmbientLoop(
          period: DT.motion.speakerPulse,
          enabled: speaking,
          builder: (_, t, child) =>
              Transform.scale(scale: 1.0 + 0.06 * t, child: child),
          child: disc,
        ),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DT.surfaceWhite,
            border: Border.all(color: accent, width: 3),
            boxShadow: DT.shadowSoft(accent),
          ),
          child: const Center(child: AppArt('listen', size: 54)),
        ),
      ),
    ),
  );
}
