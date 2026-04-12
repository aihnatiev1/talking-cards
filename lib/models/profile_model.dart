import 'dart:convert';

class ProfileModel {
  final String id;
  final String name;
  final String avatarEmoji;
  final DateTime createdAt;
  /// Learning language: 'uk' (Ukrainian) or 'en' (English). Defaults to 'uk'.
  final String language;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.createdAt,
    this.language = 'uk',
  });

  String get flagEmoji => language == 'en' ? '🇬🇧' : '🇺🇦';

  ProfileModel copyWith({String? name, String? avatarEmoji, String? language}) =>
      ProfileModel(
        id: id,
        name: name ?? this.name,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        createdAt: createdAt,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatarEmoji,
        'createdAt': createdAt.toIso8601String(),
        'lang': language,
      };

  factory ProfileModel.fromJson(Map<String, dynamic> j) => ProfileModel(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarEmoji: j['avatar'] as String,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        language: j['lang'] as String? ?? 'uk',
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
