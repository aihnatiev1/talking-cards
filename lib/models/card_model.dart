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
  final String? soundEn;
  final String? transcription;
  /// When set, the card is rendered as a stylized letter (sound-practice
  /// packs) instead of a webp illustration — the letter itself IS the visual.
  final String? letter;

  const CardModel({
    required this.id,
    required this.sound,
    required this.text,
    required this.emoji,
    required this.colorBg,
    required this.colorAccent,
    this.image,
    this.audioKey,
    this.soundEn,
    this.transcription,
    this.letter,
  });

  /// Image names of negative-mood cards excluded from the colouring book.
  ///
  /// The colouring pool used to be every word card, so the very first
  /// picture a child revealed could be a crying boy (design audit
  /// 2026-09-08, #25). Keyed by [image] because the same illustration is
  /// shared across languages while ids/sounds differ.
  static const Set<String> calmingExcludedImages = {
    'sad',
    'angry',
    'afraid',
    'scared',
    'shy',
    'tired',
    'bored',
    'en_it_hurts',
  };

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
      soundEn: json['soundEn'] as String?,
      transcription: json['transcription'] as String?,
      letter: _nonEmpty(json['letter'] as String?),
    );
  }
}
