import 'dart:ui';

import '../utils/color_utils.dart';

class CardModel {
  final String id;
  final String sound;
  final String text;
  final String emoji;
  final Color colorBg;
  final Color colorAccent;
  final String? image;
  final String? audioKey;

  const CardModel({
    required this.id,
    required this.sound,
    required this.text,
    required this.emoji,
    required this.colorBg,
    required this.colorAccent,
    this.image,
    this.audioKey,
  });

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  factory CardModel.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String?;
    return CardModel(
      id: json['id'] as String,
      sound: json['sound'] as String,
      text: json['text'] as String,
      emoji: json['emoji'] as String,
      colorBg: colorFromHex(json['colorBg'] as String),
      colorAccent: colorFromHex(json['colorAccent'] as String),
      image: image,
      audioKey: _nonEmpty(json['audio'] as String?) ?? image,
    );
  }
}
