import 'dart:convert';

class ProfileModel {
  final String id;
  final String name;
  final String avatarEmoji;
  final DateTime createdAt;
  /// Learning language: 'uk' (Ukrainian) or 'en' (English). Defaults to 'uk'.
  final String language;

  /// Age/difficulty level: 1 (1-2y), 2 (2-3y), 3 (3-4y), 4 (4-5y). Defaults to 2.
  final int level;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.createdAt,
    this.language = 'uk',
    this.level = 2,
  });

  String get flagEmoji => language == 'en' ? '🇬🇧' : '🇺🇦';

  ProfileModel copyWith({String? name, String? avatarEmoji, String? language, int? level}) =>
      ProfileModel(
        id: id,
        name: name ?? this.name,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        createdAt: createdAt,
        language: language ?? this.language,
        level: level ?? this.level,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatarEmoji,
        'createdAt': createdAt.toIso8601String(),
        'lang': language,
        'level': level,
      };

  factory ProfileModel.fromJson(Map<String, dynamic> j) => ProfileModel(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarEmoji: j['avatar'] as String,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        language: j['lang'] as String? ?? 'uk',
        level: (j['level'] as int?) ?? 2,
      );

  static ProfileModel fromJsonString(String s) =>
      ProfileModel.fromJson(json.decode(s) as Map<String, dynamic>);

  String toJsonString() => json.encode(toJson());
}

/// Emoji options shown in the avatar picker (kid-friendly).
const kAvatarEmojis = [
  '👶', '👧', '👦', '🧒', '👩', '🧑',
  '🐱', '🐶', '🐻', '🐸', '🦊', '🐼',
  '🌟', '🎀', '🦄', '🌈', '🎈', '🍭',
  '🚀', '🌸',
];
