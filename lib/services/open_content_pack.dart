import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pack_model.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/last_pack_provider.dart';
import '../providers/packs_provider.dart';
import '../screens/cards_screen.dart';
import '../utils/kid_routes.dart';
import 'analytics_service.dart';
import 'feedback_service.dart';
import 'paywall_flow.dart';
import 'remote_config_service.dart';

Future<void> openContentPack(
  BuildContext context,
  WidgetRef ref,
  PackModel pack, {
  String source = 'other',
  int? position,
}) async {
  if (pack.id == '_review' || !pack.id.startsWith('_')) {
    ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.reviewOldCard);
  }
  // Locked packs. Default: open the free preview — the cards themselves
  // are the demo, and the end-of-preview dialog asks for the purchase
  // once the child has wanted more (audit #15). Remote Config
  // `locked_pack_tap = paywall` restores the offer-first flow for an A/B.
  if (pack.isLocked && RemoteConfigService.instance.lockedPackTapOpensPreview) {
    ref.read(lastOpenedPackProvider.notifier).record(pack.id);
    Navigator.of(context).push(
      KidRoutes.content(
        CardsScreen(pack: pack, source: source, position: position),
      ),
    );
    return;
  }
  if (pack.isLocked) {
    // The tile itself is silent (its sound is `pack_open` on entering the
    // cards); a tap that goes to the paywall instead still gets a tock.
    FeedbackService.instance.event(FeedbackEvent.tap, haptic: false);
    final purchased = await runPaywallFlow(context, ref, source: 'locked_tile');
    if (!context.mounted) return;
    if (purchased) {
      // After purchase, packsProvider rebuilds with isLocked=false.
      // Pull the unlocked version before navigating.
      final unlocked =
          ref
              .read(packsProvider)
              .valueOrNull
              ?.firstWhere((p) => p.id == pack.id, orElse: () => pack) ??
          pack;
      ref.read(lastOpenedPackProvider.notifier).record(unlocked.id);
      Navigator.of(context).push(
        KidRoutes.content(
          CardsScreen(pack: unlocked, source: source, position: position),
        ),
      );
      return;
    }
  }
  ref.read(lastOpenedPackProvider.notifier).record(pack.id);
  AnalyticsService.instance.logFirstAction('library_pack');
  Navigator.of(context).push(
    KidRoutes.content(
      CardsScreen(pack: pack, source: source, position: position),
    ),
  );
}
