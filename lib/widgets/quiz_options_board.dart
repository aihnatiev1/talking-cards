import 'package:flutter/material.dart';

import '../models/card_model.dart';

/// Uses the available play area, with stacked choices on tall phones.
class QuizOptionsBoard extends StatelessWidget {
  const QuizOptionsBoard({
    super.key,
    required this.options,
    required this.tileBuilder,
  });

  final List<CardModel> options;
  final Widget Function(int index, CardModel card) tileBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      const gap = 16.0;
      final tallPair =
          options.length == 2 && bounds.maxHeight > bounds.maxWidth * 1.15;
      final columns = tallPair
          ? 1
          : bounds.maxWidth > bounds.maxHeight * 2.4
          ? options.length
          : 2;
      final rows = (options.length / columns).ceil();
      // Short windows scroll instead of squeezing the illustration away.
      final minTileHeight = MediaQuery.textScalerOf(context).scale(24) + 120;
      final height = (bounds.maxHeight - gap * (rows - 1)) / rows;
      final tileHeight = height.clamp(minTileHeight, double.infinity);
      return SingleChildScrollView(
        child: Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              SizedBox(
                height: tileHeight,
                child: Row(
                  children: [
                    for (
                      var col = 0;
                      col < columns && row * columns + col < options.length;
                      col++
                    ) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(
                        child: row * columns + col < options.length
                            ? tileBuilder(
                                row * columns + col,
                                options[row * columns + col],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
