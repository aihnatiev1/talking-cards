import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

/// Per-locale feature switches. Encoded from what the code did before the
/// registry existed:
///   * syllableGame  — uk-only (uk phonetics based; no en variant shipped)
///   * articulation  — available in both uk and en today
///   * seasonalPacks — UA cultural content, hidden in en
class LocaleCapabilities {
  final bool syllableGame;
  final bool articulation;
  final bool seasonalPacks;

  const LocaleCapabilities({
    required this.syllableGame,
    required this.articulation,
    required this.seasonalPacks,
  });

  factory LocaleCapabilities.fromJson(Map<String, dynamic> json) =>
      LocaleCapabilities(
        syllableGame: json['syllableGame'] as bool? ?? false,
        articulation: json['articulation'] as bool? ?? false,
        seasonalPacks: json['seasonalPacks'] as bool? ?? false,
      );
}

class LocaleInfo {
  final String code;
  final String flag;
  final String nativeName;
  final String appTitle;

  /// Short second line on the onboarding language card (e.g. card count).
  final String onboardingSublabel;
  final LocaleCapabilities capabilities;

  const LocaleInfo({
    required this.code,
    required this.flag,
    required this.nativeName,
    required this.appTitle,
    required this.onboardingSublabel,
    required this.capabilities,
  });

  factory LocaleInfo.fromJson(Map<String, dynamic> json) => LocaleInfo(
        code: json['code'] as String,
        flag: json['flag'] as String? ?? '',
        nativeName: json['nativeName'] as String? ?? '',
        appTitle: json['appTitle'] as String? ?? '',
        onboardingSublabel: json['onboardingSublabel'] as String? ?? '',
        capabilities: LocaleCapabilities.fromJson(
            json['capabilities'] as Map<String, dynamic>? ?? const {}),
      );
}

/// Registry of the locales the app can offer, loaded from
/// `assets/l10n/locales.json` at splash. All getters are synchronous and
/// fall back to hardcoded uk/en entries, so the splash screen (and unit
/// tests) render correctly even before — or without — the asset load.
class LocaleRegistry {
  LocaleRegistry._();
  static final LocaleRegistry instance = LocaleRegistry._();

  /// Hard fallbacks mirroring assets/l10n/locales.json for uk/en.
  static const List<LocaleInfo> _fallbacks = [
    LocaleInfo(
      code: 'uk',
      flag: '🇺🇦',
      nativeName: 'Українська',
      appTitle: 'Картки-розмовлялки',
      onboardingSublabel: '234 картки',
      capabilities: LocaleCapabilities(
        syllableGame: true,
        articulation: true,
        seasonalPacks: true,
      ),
    ),
    LocaleInfo(
      code: 'en',
      flag: '🇬🇧',
      nativeName: 'English',
      appTitle: 'FirstWords Cards',
      onboardingSublabel: '209 cards',
      capabilities: LocaleCapabilities(
        syllableGame: false,
        articulation: true,
        seasonalPacks: false,
      ),
    ),
  ];

  List<LocaleInfo> _locales = _fallbacks;

  /// Locales in manifest order — drives the onboarding language picker.
  List<LocaleInfo> get locales => _locales;

  /// Loads the manifest; keeps the hard fallbacks on any error or when the
  /// asset is an empty list. Safe to call more than once.
  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/l10n/locales.json');
      final parsed = (json.decode(raw) as List<dynamic>)
          .map((e) => LocaleInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      if (parsed.isNotEmpty) _locales = parsed;
    } catch (e) {
      if (kDebugMode) debugPrint('LocaleRegistry: manifest load failed: $e');
    }
  }

  /// Info for [code]; unknown codes fall back to the en entry (matching
  /// AppS's English fallback for untranslated locales).
  LocaleInfo of(String code) {
    for (final locale in _locales) {
      if (locale.code == code) return locale;
    }
    for (final locale in _fallbacks) {
      if (locale.code == code) return locale;
    }
    return _fallbacks.last; // en
  }

  String flag(String code) => of(code).flag;
  String appTitle(String code) => of(code).appTitle;
  LocaleCapabilities capabilities(String code) => of(code).capabilities;
}
