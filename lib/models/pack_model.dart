import 'dart:ui';

import '../utils/color_utils.dart';
import 'card_model.dart';

class PackModel {
  final String id;
  final String title;
  final String icon;
  final Color color;
  final bool isLocked;
  final bool isFree; // originally free in JSON (not unlocked by purchase)
  final List<CardModel> cards;
  /// Optional dedicated cover image (webp asset name, no extension) used as
  /// the pack's thumbnail on the main grid. Falls back to the first card's
  /// illustration when null. Lets sound-packs display a drawn letter as cover
  /// while keeping real illustrations on the cards inside.
  final String? cover;

  static const int freePreviewCount = 5;

  const PackModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.isLocked,
    required this.isFree,
    required this.cards,
    this.cover,
  });

  factory PackModel.fromJson(Map<String, dynamic> json) {
    final locked = json['isLocked'] as bool? ?? false;
    return PackModel(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String,
      color: colorFromHex(json['color'] as String),
      isLocked: locked,
      isFree: !locked,
      cards: (json['cards'] as List<dynamic>)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      cover: (json['cover'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['cover'] as String?,
    );
  }

  PackModel copyWith({bool? isLocked}) {
    return PackModel(
      id: id,
      title: title,
      icon: icon,
      color: color,
      isLocked: isLocked ?? this.isLocked,
      isFree: isFree, // preserve original status
      cards: cards,
      cover: cover,
    );
  }
}
