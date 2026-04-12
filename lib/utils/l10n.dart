/// Minimal bilingual string helper — no packages needed.
///
/// Usage inside any ConsumerWidget / ConsumerStatefulWidget:
///
///   final s = AppS(ref.watch(languageProvider) == 'en');
///   Text(s('Картки-розмовлялки', 'Talking Cards'))
///
class AppS {
  final bool _en;
  const AppS(bool isEn) : _en = isEn;

  /// Returns [en] when the app is in English mode, [uk] otherwise.
  String call(String uk, String en) => _en ? en : uk;

  bool get isEn => _en;
}
