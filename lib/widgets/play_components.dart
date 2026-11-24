import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../utils/design_tokens.dart';
import '../utils/app_icons.dart';
import 'bloom_mascot.dart';
import 'card_image.dart';
import 'kid_tap.dart';
import 'animal_friend_art.dart';

class PlayAction extends StatefulWidget {
  const PlayAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = AppIcon.play,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppIcon icon;
  final bool secondary;
  @override
  State<PlayAction> createState() => _PlayActionState();
}

class _PlayActionState extends State<PlayAction> {
  final _states = WidgetStatesController();
  bool _pressed = false;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    _states.addListener(_changed);
  }

  void _changed() {
    if (_scheduled || _pressed == _states.value.contains(WidgetState.pressed)) {
      return;
    }
    // Material can update disabled/pressed states while rebuilding its child.
    // Schedule the shell update after that build rather than dirtying an ancestor.
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        setState(() => _pressed = _states.value.contains(WidgetState.pressed));
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _states.removeListener(_changed);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callback = widget.onPressed == null
        ? null
        : () {
            KidTap.feedback();
            widget.onPressed?.call();
          };
    final icon = AppIconView(
      widget.icon,
      size: 26,
      color: widget.secondary ? DT.solid(DT.brand) : DT.surfaceWhite,
    );
    final label = Text(widget.label, textAlign: TextAlign.center);
    final button = widget.secondary
        ? OutlinedButton.icon(
            statesController: _states,
            onPressed: callback,
            icon: icon,
            label: label,
          )
        : FilledButton.icon(
            statesController: _states,
            onPressed: callback,
            icon: icon,
            label: label,
          );
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : DT.pressDownMs,
          transform: Matrix4.translationValues(
            0,
            _pressed && !reduce ? 4 : 0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DT.rMd),
            boxShadow: _pressed || widget.onPressed == null
                ? []
                : [
                    BoxShadow(
                      color: widget.secondary
                          ? DT.outline
                          : DT.onTint(DT.brand),
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: button,
        ),
      ),
    );
  }
}

class PlayArt extends StatelessWidget {
  const PlayArt({super.key, required this.card, this.padding = 8});
  final CardModel card;
  final double padding;
  @override
  Widget build(BuildContext context) => CardImage(
    name: card.image,
    fallbackEmoji: '',
    fallback: const AppIconView(AppIcon.pawStep, color: DT.brand, size: 48),
    size: CardArtSize.hero,
    padding: EdgeInsets.all(padding),
  );
}

/// The same small landscape hosts the invitation and the earned animal.
class PlayScene extends StatelessWidget {
  const PlayScene({
    super.key,
    required this.cards,
    this.celebrate = false,
    this.height = 120,
    this.showBloom = true,
  });
  final List<CardModel> cards;
  final bool celebrate;

  /// 120 is the shelf banner; the earned-friend screen asks for a tall stage.
  final double height;

  /// The compact lesson banner has no room for him beside the animal.
  final bool showBloom;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(DT.rLg),
      child: CustomPaint(
        painter: const PlayGardenPainter(),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              if (cards.isNotEmpty)
                Positioned(
                  left: showBloom ? 10 : box.maxWidth * .05,
                  bottom: 0,
                  width: box.maxWidth * (showBloom ? .48 : .9),
                  height: height - 8,
                  child: _ArtSticker(card: cards.first),
                ),
              if (cards.length > 1)
                Positioned(
                  right: 20,
                  bottom: 36,
                  width: 69,
                  height: 69,
                  child: _ArtSticker(card: cards[1]),
                ),
              if (cards.length > 2)
                Positioned(
                  right: 58,
                  bottom: 8,
                  width: 50,
                  height: 50,
                  child: _ArtSticker(card: cards[2]),
                ),
              if (showBloom)
                Positioned(
                  right: 4,
                  bottom: 0,
                  child: BloomMascot(
                    size: height * .6,
                    state: BloomState(
                      emotion: celebrate
                          ? BloomEmotion.cheer
                          : BloomEmotion.wave,
                    ),
                    interactive: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ArtSticker extends StatelessWidget {
  const _ArtSticker({required this.card});
  final CardModel card;
  @override
  Widget build(BuildContext context) =>
      AnimalFriendArt(animal: card.image ?? 'cow');
}

class PlayGardenPainter extends CustomPainter {
  const PlayGardenPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = DT.skyTint);
    canvas.drawCircle(
      Offset(size.width - 30, 30),
      20,
      Paint()..color = DT.sunBurst,
    );
    final hills = Path()
      ..moveTo(0, size.height * .65)
      ..quadraticBezierTo(
        size.width * .4,
        size.height * .35,
        size.width,
        size.height * .7,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hills, Paint()..color = DT.mintTint);
    canvas.drawOval(
      Rect.fromLTWH(-30, size.height - 46, size.width + 60, 95),
      Paint()..color = DT.sceneGrassNear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlayGardenPainter oldDelegate) => false;
}

class PlayPanel extends StatelessWidget {
  const PlayPanel({
    super.key,
    required this.child,
    this.color = DT.surfaceWhite,
    this.padding = const EdgeInsets.all(DT.sp20),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(DT.rXl),
      border: Border.all(color: DT.outline, width: 2),
      boxShadow: const [BoxShadow(color: DT.outline, offset: Offset(0, 4))],
    ),
    child: child,
  );
}
