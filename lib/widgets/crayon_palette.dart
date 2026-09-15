import 'dart:math' as math;

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

  /// The audio key of the colour word, per language: the `colors` pack
  /// for Ukrainian, `en_colors` for English.
  ///
  /// Spelled out rather than derived from [id]: the takes were recorded
  /// for cards, not for crayons, and they disagree in both languages
  /// (violet is filed as `purple`, grey as `gray`, orange as
  /// `en_orange_c`). Guessing cost the listening mode a silent question
  /// once, and an English child being asked for a colour in Ukrainian a
  /// second time.
  final String audio;
  final String audioEn;

  const Crayon({
    required this.id,
    required this.color,
    required this.name,
    required this.nameEn,
    required this.audio,
    required this.audioEn,
  });

  String localizedAudio(bool isEn) => isEn ? audioEn : audio;

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
    audioEn: 'en_red',
  ),
  Crayon(
    id: 'orange',
    color: DT.crayonOrange,
    name: 'помаранчевий',
    nameEn: 'orange',
    audio: 'orange',
    audioEn: 'en_orange_c',
  ),
  Crayon(
    id: 'yellow',
    color: DT.crayonYellow,
    name: 'жовтий',
    nameEn: 'yellow',
    audio: 'yellow',
    audioEn: 'en_yellow',
  ),
  Crayon(
    id: 'green',
    color: DT.crayonGreen,
    name: 'зелений',
    nameEn: 'green',
    audio: 'green',
    audioEn: 'en_green',
  ),
  Crayon(
    id: 'blue',
    color: DT.crayonBlue,
    name: 'синій',
    nameEn: 'blue',
    audio: 'blue',
    audioEn: 'en_blue',
  ),
  Crayon(
    id: 'violet',
    color: DT.crayonViolet,
    name: 'фіолетовий',
    nameEn: 'purple',
    audio: 'purple',
    audioEn: 'en_purple',
  ),
  Crayon(
    id: 'pink',
    color: DT.crayonPink,
    name: 'рожевий',
    nameEn: 'pink',
    audio: 'pink',
    audioEn: 'en_pink',
  ),
  Crayon(
    id: 'brown',
    color: DT.crayonBrown,
    name: 'коричневий',
    nameEn: 'brown',
    audio: 'brown',
    audioEn: 'en_brown',
  ),
  Crayon(
    id: 'grey',
    color: DT.crayonGrey,
    name: 'сірий',
    nameEn: 'grey',
    audio: 'gray',
    audioEn: 'en_gray',
  ),
  Crayon(
    id: 'black',
    color: DT.crayonBlack,
    name: 'чорний',
    nameEn: 'black',
    audio: 'black',
    audioEn: 'en_black',
  ),
];

/// The crayons along the bottom of a drawing screen, in two rows.
///
/// They used to be one scrolling row, and a two-year-old does not
/// discover a scroll — five of the ten simply did not exist for her. Two
/// rows of five fit any phone without scrolling, so the whole box is on
/// the table the way a real one is.
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

  static const _perRow = 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Whatever the phone is, five across with room to breathe; never
        // below a child's minimum target.
        final cell = math.max(
          DT.size.tapMin,
          (box.maxWidth - 32 - (_perRow - 1) * 8) / _perRow,
        );
        final face = math.min(cell - 8, 64.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final crayon in kCrayons)
                _Crayon(
                  crayon: crayon,
                  selected: crayon.id == selectedId,
                  hinted: crayon.id == hintId,
                  isEn: isEn,
                  cell: cell,
                  face: face,
                  onTap: () => onSelected(crayon),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Crayon extends StatelessWidget {
  final Crayon crayon;
  final bool selected;
  final bool hinted;
  final bool isEn;
  final double cell;
  final double face;
  final VoidCallback onTap;

  const _Crayon({
    required this.crayon,
    required this.selected,
    required this.hinted,
    required this.isEn,
    required this.cell,
    required this.face,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: crayon.localizedName(isEn),
      excludeSemantics: true,
      child: KidTap(
        onTap: onTap,
        child: SizedBox(
          width: cell,
          height: cell,
          child: Center(
            child: AnimatedContainer(
              duration: DT.pressMs,
              curve: Curves.easeOutCubic,
              width: selected ? face : face - 10,
              height: selected ? face : face - 10,
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
                        : crayon.color.withValues(alpha: selected ? .45 : .25),
                    offset: hinted ? Offset.zero : Offset(0, selected ? 5 : 3),
                    blurRadius: hinted ? 16 : (selected ? 10 : 6),
                    spreadRadius: hinted ? 2 : 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
