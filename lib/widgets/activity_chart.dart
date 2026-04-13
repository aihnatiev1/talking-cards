import 'package:flutter/material.dart';

class ActivityChart extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final bool isEn;

  const ActivityChart({super.key, required this.data, this.isEn = false});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((e) => e.value).fold(1, (a, b) => a > b ? a : b);
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = colorScheme.primary;
    final labelColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((entry) {
          final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;
          final weekday = _weekday(entry.key);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (entry.value > 0)
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: barColor,
                      ),
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: 80 * ratio + 4,
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekday,
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _weekday(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      const uk = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];
      const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return (isEn ? en : uk)[date.weekday - 1];
    } catch (_) {
      return '';
    }
  }
}
