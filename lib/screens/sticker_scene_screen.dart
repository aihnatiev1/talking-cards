import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../screens/coloring_screen.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/feedback_service.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';
import '../widgets/card_image.dart';
import '../widgets/kid_screen.dart';
import '../widgets/kid_tap.dart';
import '../widgets/meadow_scene.dart';

class _Sticker {
  final CardModel card;
  final Offset position;
  final double scale;
  final double angle;

  const _Sticker({
    required this.card,
    required this.position,
    required this.scale,
    required this.angle,
  });
}

/// A meadow and a tray of things to put on it.
///
/// The drawing mode for the age where filling an area is still too much:
/// at eighteen months a child cannot stay inside a shape, but they can
/// absolutely tap a cat and then tap the grass. Every sticker says its own
/// word as it lands, which is the whole reason this is in a speech app and
/// not just a toy — the scene is an excuse to hear forty words said one at
/// a time, by the child's own hand.
///
/// Nothing can be wrong here: there is no right place for a cat, stickers
/// never overlap-fail, and there is no finish.
class StickerSceneScreen extends ConsumerStatefulWidget {
  const StickerSceneScreen({super.key});

  @override
  ConsumerState<StickerSceneScreen> createState() => _StickerSceneScreenState();
}

class _StickerSceneScreenState extends ConsumerState<StickerSceneScreen> {
  final List<_Sticker> _placed = [];
  final _rng = math.Random();
  CardModel? _held;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logGameStart('sticker_scene');
  }

  void _pick(CardModel card) {
    setState(() => _held = card);
    AudioService.instance.playWordOnly(card.audioKey, card.sound);
  }

  void _place(Offset at) {
    final card = _held;
    if (card == null) return;
    FeedbackService.instance.event(FeedbackEvent.tap, haptic: false);
    AudioService.instance.playWordOnly(card.audioKey, card.sound);
    setState(() {
      _placed.add(_Sticker(
        card: card,
        position: at,
        // A little variety so a meadow of cats does not look like a grid.
        scale: 0.85 + _rng.nextDouble() * 0.4,
        angle: (_rng.nextDouble() - 0.5) * 0.35,
      ));
    });
  }

  void _undo() {
    if (_placed.isEmpty) return;
    FeedbackService.instance.event(FeedbackEvent.tap);
    setState(() => _placed.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final packs = ref.watch(packsProvider).valueOrNull ?? const [];
    // The same pool the water mode draws from: real word cards with a
    // picture, nothing sad, nothing still inside an undelivered pack.
    final pool = ColoringScreen.coloringPool(packs).take(40).toList();
    // Something is always in hand. An empty hand means the first tap on
    // the meadow does nothing, and a child reads that as a screen that
    // does not work — not as "pick a sticker first".
    if (_held == null && pool.isNotEmpty) _held = pool.first;

    return KidScreen.game(
      accent: DT.brand,
      meadow: true,
      trailing: IconButton(
        tooltip: s('Прибрати одну', 'Take one off'),
        onPressed: _undo,
        icon: Icon(
          Icons.undo_rounded,
          size: 28,
          color: _placed.isEmpty ? DT.textMuted : DT.brand,
        ),
      ),
      body: pool.isEmpty
          ? Center(
              child: Text(
                s('Відкрий хоча б один пак з картками',
                    'Open at least one pack with images first'),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _place(d.localPosition),
                    child: Stack(
                      children: [
                        const Positioned.fill(child: MeadowScene()),
                        for (var i = 0; i < _placed.length; i++)
                          _PlacedSticker(
                            key: ValueKey('sticker-$i'),
                            sticker: _placed[i],
                          ),
                      ],
                    ),
                  ),
                ),
                _StickerTray(
                  cards: pool,
                  heldId: _held?.id,
                  onPick: _pick,
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

/// One sticker on the meadow. It arrives with a pop — a thing that lands
/// is more convincing than a thing that is suddenly there.
class _PlacedSticker extends StatefulWidget {
  final _Sticker sticker;
  const _PlacedSticker({super.key, required this.sticker});

  @override
  State<_PlacedSticker> createState() => _PlacedStickerState();
}

class _PlacedStickerState extends State<_PlacedSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: DT.motion.successPop,
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Three times the first size. A sticker a child places is the thing
    // they made, not a decoration on a scene — at 96 dp the meadow looked
    // like a page of tiny icons, and a two-year-old could not tell what
    // they had put down.
    const side = 288.0;
    final sticker = widget.sticker;
    return Positioned(
      left: sticker.position.dx - side / 2,
      top: sticker.position.dy - side / 2,
      width: side,
      height: side,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _in,
          builder: (_, child) => Transform.scale(
            scale: sticker.scale * Curves.easeOutBack.transform(_in.value),
            child: Transform.rotate(angle: sticker.angle, child: child),
          ),
          child: CardImage.forCard(sticker.card),
        ),
      ),
    );
  }
}

class _StickerTray extends StatelessWidget {
  final List<CardModel> cards;
  final String? heldId;
  final ValueChanged<CardModel> onPick;

  const _StickerTray({
    required this.cards,
    required this.heldId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final card = cards[i];
          final held = card.id == heldId;
          return KidTap(
            onTap: () => onPick(card),
            sound: null,
            child: AnimatedContainer(
              duration: DT.pressMs,
              curve: Curves.easeOutCubic,
              width: 104,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: held ? DT.surfaceWhite : DT.surfaceWhite.withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: held ? DT.brand : Colors.white,
                  width: held ? 3 : 2,
                ),
              ),
              child: CardImage.forCard(card),
            ),
          );
        },
      ),
    );
  }
}
