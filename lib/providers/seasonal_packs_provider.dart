import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../utils/color_utils.dart';

// ─────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────

/// A [PackModel] extended with seasonal availability dates.
class SeasonalPackModel extends PackModel {
  /// e.g. "12-01" = December 1
  final String activeFrom;

  /// e.g. "01-15" = January 15
  final String activeTo;

  const SeasonalPackModel({
    required super.id,
    required super.title,
    required super.icon,
    required super.color,
    required super.cards,
    required this.activeFrom,
    required this.activeTo,
  }) : super(isLocked: false, isFree: true);

  /// True when [now] falls within the active window.
  /// Handles cross-year ranges (e.g. Dec–Jan).
  bool isActiveOn(DateTime now) {
    final md = now.month * 100 + now.day;
    final fromParts = activeFrom.split('-');
    final toParts = activeTo.split('-');
    final fromMd =
        int.parse(fromParts[0]) * 100 + int.parse(fromParts[1]);
    final toMd = int.parse(toParts[0]) * 100 + int.parse(toParts[1]);

    if (fromMd <= toMd) {
      // Normal range: e.g. 0401 – 0515
      return md >= fromMd && md <= toMd;
    } else {
      // Cross-year range: e.g. 1201 – 0115 (Dec–Jan)
      return md >= fromMd || md <= toMd;
    }
  }

  factory SeasonalPackModel.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>)
        .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
        .toList();
    return SeasonalPackModel(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String,
      color: colorFromHex(json['color'] as String),
      cards: cards,
      activeFrom: json['activeFrom'] as String,
      activeTo: json['activeTo'] as String,
    );
  }
}

// ─────────────────────────────────────────────
//  Provider — all seasonal packs (loaded once)
// ─────────────────────────────────────────────

final _allSeasonalPacksProvider =
    FutureProvider<List<SeasonalPackModel>>((ref) async {
  final jsonString =
      await rootBundle.loadString('assets/data/seasonal_packs.json');
  final list = json.decode(jsonString) as List<dynamic>;
  return list
      .map((e) =>
          SeasonalPackModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────
//  Provider — only packs active today
// ─────────────────────────────────────────────

final activeSeasonalPacksProvider =
    FutureProvider<List<SeasonalPackModel>>((ref) async {
  final all = await ref.watch(_allSeasonalPacksProvider.future);
  final now = DateTime.now();
  return all.where((p) => p.isActiveOn(now)).toList();
});
