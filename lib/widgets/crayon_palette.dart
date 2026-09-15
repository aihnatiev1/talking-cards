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

  const Crayon({
    required this.id,
    required this.color,
    required this.name,
    required this.nameEn,
  });

  String localizedName(bool isEn) => isEn ? nameEn : name;
}

/// The ten crayons, with their words. The colours themselves live in
/// [DT] like every other colour in the app; what is here is the pairing of
/// each one with the name a child will be asked to match it to.
const List<Crayon> kCrayons = [
  Crayon(id: 'red', color: DT.crayonRed, name: 'червоний', nameEn: 'red'),
  Crayon(id: 'orange', color: DT.crayonOrange, name: 'помаранчевий', nameEn: 'orange'),
  Crayon(id: 'yellow', color: DT.crayonYellow, name: 'жовтий', nameEn: 'yellow'),
  Crayon(id: 'green', color: DT.crayonGreen, name: 'зелений', nameEn: 'green'),
  Crayon(id: 'blue', color: DT.crayonBlue, name: 'синій', nameEn: 'blue'),
  Crayon(id: 'violet', color: DT.crayonViolet, name: 'фіолетовий', nameEn: 'purple'),
  Crayon(id: 'pink', color: DT.crayonPink, name: 'рожевий', nameEn: 'pink'),
  Crayon(id: 'brown', color: DT.crayonBrown, name: 'коричневий', nameEn: 'brown'),
  Crayon(id: 'grey', color: DT.crayonGrey, name: 'сірий', nameEn: 'grey'),
  Crayon(id: 'black', color: DT.crayonBlack, name: 'чорний', nameEn: 'black'),
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

  const CrayonPalette({
    super.key,
    required this.selectedId,
    required this.onSelected,
    required this.isEn,
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
                      color: Colors.white,
                      width: selected ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: crayon.color.withValues(alpha: selected ? .45 : .25),
                        offset: Offset(0, selected ? 5 : 3),
                        blurRadius: selected ? 10 : 6,
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
