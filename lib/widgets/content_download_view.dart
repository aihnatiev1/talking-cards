import 'package:flutter/material.dart';

import '../services/asset_pack_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';

/// What a paid pack shows while its illustrations and voice clips are still
/// arriving from Play (fast-follow asset pack), instead of blank tiles and
/// silence. Big, calm, one thing happening — a toddler sees a cloud and a
/// bar filling up; the sentence underneath is for the parent.
///
/// The two buttons exist for the two ways the download stalls: Play holding
/// it for Wi-Fi (ask to allow cellular) and a failure (try again). Both are
/// ≥72dp, like every other target in the app.
class ContentDownloadView extends StatelessWidget {
  final ContentPackState state;
  final Color accent;
  final bool isEn;

  const ContentDownloadView({
    super.key,
    required this.state,
    required this.accent,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppS(isEn);
    final progress = state.progress;
    final percent = progress == null ? '' : ' ${(progress * 100).round()}%';

    final (
      String line,
      String? action,
      VoidCallback? onAction,
    ) = switch (state.status) {
      ContentPackStatus.waitingForWifi => (
        s(
          'Чекаємо Wi-Fi, щоб завантажити картки',
          'Waiting for Wi-Fi to download the cards',
        ),
        s('Завантажити через мобільний', 'Download over mobile data'),
        AssetPackService.instance.confirmCellular,
      ),
      ContentPackStatus.failed => (
        s('Не вдалося завантажити картки', 'Could not download the cards'),
        s('Спробувати ще раз', 'Try again'),
        AssetPackService.instance.fetch,
      ),
      _ => (
        s('Завантажуємо картки…$percent', 'Downloading cards…$percent'),
        null,
        null,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DT.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('☁️', style: TextStyle(fontSize: 96)),
            const SizedBox(height: DT.sp24),
            ClipRRect(
              borderRadius: BorderRadius.circular(DT.rSm),
              child: LinearProgressIndicator(
                key: const ValueKey('content-progress'),
                value: state.status == ContentPackStatus.failed ? 0 : progress,
                minHeight: 14,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: DT.sp20),
            Text(
              line,
              textAlign: TextAlign.center,
              style: DT.body.copyWith(color: DT.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: DT.sp24),
              SizedBox(
                width: double.infinity,
                height: 72,
                child: FilledButton(
                  key: const ValueKey('content-action'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DT.rLg),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    action,
                    style: DT.h2.copyWith(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
