import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// The vertical layout every "one thing happened" kid screen shares:
/// a short heading at the top, a **stage that takes all the height that is
/// left**, and the actions pinned at the bottom, in the thumb zone.
///
/// Reward, completion and empty screens used to be a top-aligned scroll
/// column with fixed-height art, so on a tall phone the content hung from
/// the top and the lower half was blank. The stage builder gets the height
/// it really has and sizes its art from that; if it still doesn't fit
/// (small phone, big text) it scales down instead of overflowing.
class KidStage extends StatelessWidget {
  const KidStage({
    super.key,
    required this.stage,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 440,
  });

  /// Builds the middle (keep the Column `mainAxisSize.min`). `height` is the room the stage area has; `width` is the
  /// column width after [maxWidth].
  final Widget Function(BuildContext context, double width, double height)
  stage;

  final Widget? title;
  final Widget? subtitle;

  /// Pinned under the stage, full width, in order.
  final List<Widget> actions;

  final double maxWidth;

  /// Below this the stage can't be both generous and fit with its heading
  /// and actions (landscape phone, split screen): fall back to a scrolling
  /// column with a fixed-height stage rather than a squeezed one.
  static const double _compactHeight = 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outer) {
        final compact = outer.maxHeight < _compactHeight;
        final head = <Widget>[
          if (title != null) title!,
          if (subtitle != null) ...[const SizedBox(height: DT.sp8), subtitle!],
          const SizedBox(height: DT.sp16),
        ];
        final foot = <Widget>[
          for (final a in actions) ...[const SizedBox(height: DT.sp8), a],
        ];
        Widget stageBox(double w, double h) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: w, child: stage(context, w, h)),
          ),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, DT.sp24),
              child: compact
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...head,
                          SizedBox(
                            height: 340,
                            child: stageBox(
                              (outer.maxWidth - 48).clamp(0.0, maxWidth - 48),
                              340,
                            ),
                          ),
                          ...foot,
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...head,
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) =>
                                stageBox(box.maxWidth, box.maxHeight),
                          ),
                        ),
                        ...foot,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
