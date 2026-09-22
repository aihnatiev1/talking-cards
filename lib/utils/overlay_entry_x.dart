import 'package:flutter/widgets.dart';

extension SafeOverlayRemoval on OverlayEntry {
  /// Removes this entry unless it is already gone.
  ///
  /// `OverlayEntry.remove()` reads `_overlay!`, so a second call — a
  /// dispose racing the timer that was going to remove the same burst, a
  /// route popped while confetti is still in the air — throws a null-check
  /// error out of `overlay.dart:228`. `main.dart` hands `FlutterError`s to
  /// `recordFlutterFatalError`, so that lands in Crashlytics as a fatal
  /// crash for what is only decoration finishing twice. One such event
  /// arrived from an iPhone on 1.3.11, 2026-09-11.
  ///
  /// [mounted] is false both when the entry has been removed and in the
  /// single frame between insertion and its first build. Nothing here
  /// removes an entry it inserted in the same frame — the shortest linger
  /// is a confetti burst — so skipping that window costs nothing.
  void removeIfMounted() {
    if (mounted) remove();
  }
}
