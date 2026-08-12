/// CLDR plural category selection for the locales the app supports
/// (or plans to). Pure Dart — no Flutter imports.
///
/// Categories follow CLDR:
///   * uk           — one / few / many / other
///   * en / es / pt — one / other
///   * anything else falls back to the en rule (one / other)
String pluralCategory(String locale, num n) {
  switch (locale) {
    case 'uk':
      // Fractions are always 'other' in Ukrainian.
      if (n % 1 != 0) return 'other';
      final i = n.toInt().abs();
      final mod10 = i % 10;
      final mod100 = i % 100;
      if (mod10 == 1 && mod100 != 11) return 'one';
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
        return 'few';
      }
      return 'many';
    case 'en':
    case 'es':
    case 'pt':
    default:
      return n == 1 ? 'one' : 'other';
  }
}
