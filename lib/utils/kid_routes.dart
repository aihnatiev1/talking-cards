import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'motion.dart';

/// The one transition language of the app (motion audit 2026-09-13 §5).
///
/// Five routes, each a [PageRouteBuilder] under the hood, and one rule: a
/// screen enters the way its *kind* enters, not the way the file that
/// pushed it happened to animate. Before this there were 13 platform-default
/// `MaterialPageRoute`s (a slide on iOS, a zoom on Android), three hand-made
/// fades of three lengths, one fade+scale for games and one instant overlay.
///
/// * [content] — the child's world: home → pack, quest map, reveal. Fade +
///   a gentle scale. `Hero`-compatible (the `HeroController` lives in
///   `MaterialApp`, so no extra wiring).
/// * [game] — a slightly deeper scale, the "step into the game" feel that
///   `games_tab._gameRoute` already had.
/// * [sheet] — the parent's world: paywall, dashboard, stats, word wall.
///   Slides up over a dimmed child screen so it reads as "a sheet on top",
///   not "the app changed".
/// * [overlay] — celebrations. Non-opaque fade over the screen that earned
///   them.
/// * [replace] — splash → home, onboarding → home. A plain fade.
///
/// Every route asks [MotionPolicy] from its navigator's context and, under
/// reduced motion, collapses both durations to zero — so the whole app goes
/// quiet with one flag instead of 26 call sites remembering to.
///
/// Anything still built as a `MaterialPageRoute` (third-party code, a
/// `showDialog` route) gets the same look through
/// [KidPageTransitionsBuilder]; wire it once in `main.dart`:
///
/// ```dart
/// // ThemeData(...)
/// pageTransitionsTheme: const PageTransitionsTheme(builders: {
///   TargetPlatform.android: KidPageTransitionsBuilder(),
///   TargetPlatform.iOS: KidPageTransitionsBuilder(),
/// }),
/// ```
///
/// `test/architecture/routes_test.dart` keeps `MaterialPageRoute(` and
/// `PageRouteBuilder(` out of every other file.
abstract final class KidRoutes {
  // Durations. Kept here as consts until DT.motion lands and the two are
  // folded together; values already match `DTMotion.route*/game*/sheet*/
  // overlay*` so nothing will move when they do.
  static final Duration contentIn = DT.motion.routeEnter;
  static final Duration contentOut = DT.motion.routeExit;
  static final Duration gameIn = DT.motion.gameEnter;
  static final Duration gameOut = DT.motion.gameExit;
  static final Duration sheetIn = DT.motion.sheetEnter;
  static final Duration sheetOut = DT.motion.sheetExit;
  static final Duration overlayIn = DT.motion.overlayEnter;
  static final Duration overlayOut = DT.motion.overlayExit;
  static final Duration replaceIn = DT.motion.replace;
  static final Duration replaceOut = DT.motion.replace;

  /// Barrier behind a [sheet]: the child's screen dims but stays visible.
  static const Color sheetBarrier = DT.barrierSheet;

  /// Barrier behind an [overlay]: darker, the celebration is the focus.
  static const Color overlayBarrier = DT.barrier;

  static const double _contentScaleFrom = 0.96;
  static const double _gameScaleFrom = 0.93;

  /// Home → pack, quest map, card reveal — anything in the child's zone
  /// that is "the next screen", not a game and not a parent sheet.
  static PageRoute<T> content<T>(Widget page) => _KidRoute<T>(
        page: page,
        duration: contentIn,
        reverseDuration: contentOut,
        transition: _fadeScale(_contentScaleFrom),
      );

  /// Into and out of a game. Formerly `games_tab._gameRoute`.
  static PageRoute<T> game<T>(Widget page) => _KidRoute<T>(
        page: page,
        duration: gameIn,
        reverseDuration: gameOut,
        transition: _fadeScale(_gameScaleFrom),
      );

  /// Parent-facing screens: paywall, dashboard, stats, word wall. Slides up
  /// from the bottom over a dimmed barrier; the route is non-opaque so the
  /// child's screen is still there underneath.
  static PageRoute<T> sheet<T>(Widget page) => _KidRoute<T>(
        page: page,
        duration: sheetIn,
        reverseDuration: sheetOut,
        opaque: false,
        barrierColor: sheetBarrier,
        transition: _slideUp,
      );

  /// Celebration overlays. Non-opaque fade; the screen that earned the
  /// celebration stays visible behind the barrier.
  static PageRoute<T> overlay<T>(Widget page) => _KidRoute<T>(
        page: page,
        duration: overlayIn,
        reverseDuration: overlayOut,
        opaque: false,
        barrierColor: overlayBarrier,
        transition: _fade,
      );

  /// Splash → home, onboarding → home: a plain fade for `pushReplacement`.
  static PageRoute<T> replace<T>(Widget page) => _KidRoute<T>(
        page: page,
        duration: replaceIn,
        reverseDuration: replaceOut,
        transition: _fade,
      );

  // -- transitions ---------------------------------------------------------

  static RouteTransitionsBuilder _fadeScale(double from) =>
      (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: from, end: 1).animate(curved),
            child: child,
          ),
        );
      };

  static Widget _fade(
    BuildContext _,
    Animation<double> animation,
    Animation<double> __,
    Widget child,
  ) =>
      FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      );

  static Widget _slideUp(
    BuildContext _,
    Animation<double> animation,
    Animation<double> __,
    Widget child,
  ) =>
      SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        )),
        child: child,
      );

  /// The [content] look, for [KidPageTransitionsBuilder].
  static Widget contentTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _fadeScale(_contentScaleFrom)(
        context,
        animation,
        secondaryAnimation,
        child,
      );
}

/// A [PageRouteBuilder] whose durations collapse to zero under reduced
/// motion. The policy is read from the navigator's context — the only
/// context a route has before it builds — and it is read lazily, when
/// `TransitionRoute.install` creates the controller, so the flag is
/// honoured at push time rather than at construction.
class _KidRoute<T> extends PageRouteBuilder<T> {
  _KidRoute({
    required Widget page,
    required Duration duration,
    required Duration reverseDuration,
    required RouteTransitionsBuilder transition,
    super.opaque,
    super.barrierColor,
  }) : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: transition,
        );

  bool get _reduce {
    final context = navigator?.context;
    return context != null && MotionPolicy.of(context).reduce;
  }

  @override
  Duration get transitionDuration =>
      _reduce ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _reduce ? Duration.zero : super.reverseTransitionDuration;
}

/// Gives every remaining `MaterialPageRoute` the [KidRoutes.content] look on
/// both platforms. Register it in `ThemeData.pageTransitionsTheme` for
/// `TargetPlatform.android` and `TargetPlatform.iOS` (see [KidRoutes]).
class KidPageTransitionsBuilder extends PageTransitionsBuilder {
  const KidPageTransitionsBuilder();

  @override
  Duration get transitionDuration => KidRoutes.contentIn;

  @override
  Duration get reverseTransitionDuration => KidRoutes.contentOut;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // A MaterialPageRoute fixes its duration before we can see the flag, so
    // under reduced motion we at least skip the motion itself.
    if (MotionPolicy.of(context).reduce) return child;
    return KidRoutes.contentTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
