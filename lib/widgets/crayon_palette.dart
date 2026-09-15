import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import 'kid_tap.dart';

/// One crayon: a colour that also has a name.
///
/// The name is not decoration. Colouring in this app is on the way to
/// «зафарбуй гриву жовтим» — a listening exercise — and that mode needs
/// the same ten colours to be the ones a child has already been choosing
/// by sight. So the palette is defined once, with words attached, and
/// every drawing mode draws from it.
class Crayon {
  final String id;
  final Color color;
  final String name;
  final String nameEn;

  /// The audio key of the colour word, in the `colors` pack.
  ///
  /// Spelled out rather than derived from [id]: the takes were recorded
  /// for cards, not for crayons, and two of them disagree (violet is
  /// filed as `purple`, grey as `gray`). Guessing cost the listening mode
  /// a silent question before this field existed.
  final String audio;

  const Crayon({
    required this.id,
    required this.color,
    required this.name,
    required this.nameEn,
    required this.audio,
  });

  String localizedName(bool isEn) => isEn ? nameEn : name;
}

/// The ten crayons, with their words. The colours themselves live in
/// [DT] like every other colour in the app; what is here is the pairing of
/// each one with the name a child will be asked to match it to.
const List<Crayon> kCrayons = [
  Crayon(
    id: 'red',
    color: DT.crayonRed,
    name: 'червоний',
    nameEn: 'red',
    audio: 'red',
  ),
  Crayon(
    id: 'orange',
    color: DT.crayonOrange,
    name: 'помаранчевий',
    nameEn: 'orange',
    audio: 'orange',
  ),
  Crayon(
    id: 'yellow',
    color: DT.crayonYellow,
    name: 'жовтий',
    nameEn: 'yellow',
    audio: 'yellow',
  ),
  Crayon(
    id: 'green',
    color: DT.crayonGreen,
    name: 'зелений',
    nameEn: 'green',
    audio: 'green',
  ),
  Crayon(
    id: 'blue',
    color: DT.crayonBlue,
    name: 'синій',
    nameEn: 'blue',
    audio: 'blue',
  ),
  Crayon(
    id: 'violet',
    color: DT.crayonViolet,
    name: 'фіолетовий',
    nameEn: 'purple',
    audio: 'purple',
  ),
  Crayon(
    id: 'pink',
    color: DT.crayonPink,
    name: 'рожевий',
    nameEn: 'pink',
    audio: 'pink',
  ),
  Crayon(
    id: 'brown',
    color: DT.crayonBrown,
    name: 'коричневий',
    nameEn: 'brown',
    audio: 'brown',
  ),
  Crayon(
    id: 'grey',
    color: DT.crayonGrey,
    name: 'сірий',
    nameEn: 'grey',
    audio: 'gray',
  ),
  Crayon(
    id: 'black',
    color: DT.crayonBlack,
    name: 'чорний',
    nameEn: 'black',
    audio: 'black',
  ),
];

/// The row of crayons along the bottom of a drawing screen.
///
/// Rounded squares rather than circles: at this size a circle of colour
/// reads as a button to press *into* something, and these are things you
/// pick up. The chosen one grows and lifts — a child who cannot read a
/// selection ring can see which crayon is in their hand.
class CrayonPalette extends StatelessWidget {
  final String selectedId;
  final ValueChanged<Crayon> onSelected;
  final bool isEn;

  /// Glow on one crayon, for the listening mode after a couple of misses.
  /// A hint, in the app's one hint colour — never a correction, and never
  /// the thing that answers for the child.
  final String? hintId;

  const CrayonPalette({
    super.key,
    required this.selectedId,
    required this.onSelected,
    required this.isEn,
    this.hintId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        physics: const BouncingScrollPhysics(),
        itemCount: kCrayons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final crayon = kCrayons[i];
          final selected = crayon.id == selectedId;
          final hinted = crayon.id == hintId;
          return Semantics(
            selected: selected,
            button: true,
            label: crayon.localizedName(isEn),
            excludeSemantics: true,
            child: KidTap(
              onTap: () => onSelected(crayon),
              child: AnimatedContainer(
                duration: DT.pressMs,
                curve: Curves.easeOutCubic,
                // 72 dp of target either way; the unselected chip is the
                // same box with a smaller painted face, so nothing moves
                // sideways when the choice changes.
                width: 72,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: DT.pressMs,
                  curve: Curves.easeOutCubic,
                  width: selected ? 64 : 52,
                  height: selected ? 64 : 52,
                  decoration: BoxDecoration(
                    color: crayon.color,
                    borderRadius: BorderRadius.circular(selected ? 20 : 16),
                    border: Border.all(
                      color: hinted ? DT.hint : Colors.white,
                      width: selected || hinted ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hinted
                            ? DT.hint
                            : crayon.color.withValues(
                                alpha: selected ? .45 : .25,
                              ),
                        offset: hinted
                            ? Offset.zero
                            : Offset(0, selected ? 5 : 3),
                        blurRadius: hinted ? 16 : (selected ? 10 : 6),
                        spreadRadius: hinted ? 2 : 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
