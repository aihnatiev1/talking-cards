import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../l10n/plural_rules.dart';

/// Minimal locale-aware string helper — no packages needed.
///
/// Usage inside any ConsumerWidget / ConsumerStatefulWidget:
///
///   final s = AppS(ref.watch(languageProvider));
///   Text(s('Картки-розмовлялки', 'Talking Cards'))
///
/// Contract:
///   * locale 'uk' → returns the first (Ukrainian) argument, as written;
///   * locale 'en' → returns the second (English) argument, as written;
///   * any other locale → looks the string up in a preloaded translation
///     table (`assets/l10n/ui_<locale>.json`, keyed by the English literal
///     or an explicit [key]), falling back to English when missing.
class AppS {
  final String locale;
  const AppS(this.locale);

  /// Translation tables for locales beyond uk/en, keyed by locale code.
  /// Values are either `String` (plain) or `Map` (plural forms keyed by
  /// CLDR category: one/few/many/other).
  static final Map<String, Map<String, dynamic>> _tables = {};

  /// Direct table access for unit tests (avoids bundling test assets).
  @visibleForTesting
  static Map<String, Map<String, dynamic>> get tablesForTesting => _tables;

  /// Loads `assets/l10n/ui_<locale>.json` into the static table cache.
  /// Silently no-ops when the asset is missing (uk/en never need one).
  static Future<void> preload(String locale) async {
    if (_tables.containsKey(locale)) return;
    try {
      final raw = await rootBundle.loadString('assets/l10n/ui_$locale.json');
      _tables[locale] = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Asset missing or malformed — English fallback will be used.
    }
  }

  /// Returns [uk] for 'uk', [en] for 'en'; for any other locale resolves
  /// the translation table entry under `key ?? en`, falling back to [en].
  String call(String uk, String en, {String? key}) {
    if (locale == 'uk') return uk;
    if (locale == 'en') return en;
    final value = _tables[locale]?[key ?? en];
    return value is String ? value : en;
  }

  /// Parameterised variant of [call]. Templates use `{placeholder}` syntax:
  ///
  ///   s.p('Привіт, {name}!', 'Hello, {name}!', {'name': name})
  ///
  /// For uk/en the passed literals ARE the templates. For other locales the
  /// template is resolved from the table (under `key ?? en`); if the table
  /// value is a Map it is treated as plural forms and the CLDR category for
  /// `args['n'] ?? args['count']` picks the form (falling back to 'other',
  /// then to [en]). Placeholders are then substituted from [args].
  String p(String uk, String en, Map<String, Object> args, {String? key}) {
    String template;
    if (locale == 'uk') {
      template = uk;
    } else if (locale == 'en') {
      template = en;
    } else {
      final value = _tables[locale]?[key ?? en];
      if (value is Map) {
        final raw = args['n'] ?? args['count'];
        final n = raw is num ? raw : num.tryParse('$raw') ?? 0;
        final form = value[pluralCategory(locale, n)] ?? value['other'];
        template = form is String ? form : en;
      } else if (value is String) {
        template = value;
      } else {
        template = en;
      }
    }
    var result = template;
    args.forEach((name, value) {
      result = result.replaceAll('{$name}', '$value');
    });
    return result;
  }
}
