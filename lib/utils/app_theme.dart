import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'kid_routes.dart';

/// The app's single light theme, built from `DT`.
///
/// `main.dart` used to inline this and, on the way, grew a second background
/// colour (#FAF8F5) next to `DT.bgWarm` — two "creams" a pixel apart on
/// adjacent screens. Everything the theme decides now comes from tokens, so
/// the scaffold, the Flutter splash and the native launch screens agree.
///
/// Kid-facing headings, titles, body and button labels take the rounded
/// Nunito styles (G7); only `bodySmall` / `labelSmall` — the fine print a
/// parent reads — stay on Roboto.
/// Ink ripples are off: children get feedback from `KidTap` (scale + sound +
/// haptic), and a Material splash under it reads as a second, unrelated
/// reaction.
ThemeData buildAppTheme() {
  final base = ThemeData(
    colorSchemeSeed: DT.brand,
    useMaterial3: true,
    fontFamily: DT.kidFont,
    brightness: Brightness.light,
    scaffoldBackgroundColor: DT.bgWarm,
    splashFactory: NoSplash.splashFactory,
  );
  return base.copyWith(
    textTheme: _kidTextTheme(base.textTheme),
    colorScheme: base.colorScheme.copyWith(
      primary: DT.solid(DT.brand),
      surface: DT.surfaceWhite,
      onSurface: DT.textPrimary,
      outline: DT.outline,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _actionStyle()),
    filledButtonTheme: FilledButtonThemeData(style: _actionStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _actionStyle(outlined: true),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DT.solid(DT.brand),
        textStyle: DT.h2,
        minimumSize: const Size(72, 56),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DT.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: DT.display,
      contentTextStyle: DT.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DT.rXl),
        side: const BorderSide(color: DT.outline, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: DT.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
        side: BorderSide(color: DT.outline, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DT.bgWarm,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.rMd),
        borderSide: const BorderSide(color: DT.outline, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.rMd),
        borderSide: const BorderSide(color: DT.outline, width: 2),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: DT.brand,
      linearTrackColor: DT.disabled,
      borderRadius: BorderRadius.all(Radius.circular(DT.rMd)),
    ),
    // One transition language on both platforms: any MaterialPageRoute that
    // has not moved to KidRoutes yet still fades + scales like the rest.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: KidPageTransitionsBuilder(),
        TargetPlatform.iOS: KidPageTransitionsBuilder(),
      },
    ),
  );
}

/// Parent-zone dark theme. Mirrors the values `main.dart` shipped with; it
/// is deliberately *not* a redesign — the kid zone has no dark palette and
/// this exists only so the parent settings toggle keeps working.
ThemeData buildAppDarkTheme() {
  return ThemeData(
    colorSchemeSeed: DT.brand,
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DT.bgDark,
  );
}

/// Headline/title slots on `DT.display / h1 / h2 / tileTitle`; `bodyLarge`,
/// `bodyMedium` and `labelLarge` are Nunito as well (weight via
/// `DT.kidWeight`, because Nunito is a variable font); `bodySmall` and
/// `labelSmall` keep Roboto for parent copy.
TextTheme _kidTextTheme(TextTheme roboto) {
  final kidBody = DT.body.copyWith(
    fontFamily: DT.kidFont,
    fontVariations: DT.kidWeight(600),
    fontWeight: FontWeight.w600,
  );
  final kidLabel = DT.body.copyWith(
    fontFamily: DT.kidFont,
    fontVariations: DT.kidWeight(800),
    fontWeight: FontWeight.w800,
  );
  return roboto.copyWith(
    displayLarge: DT.display,
    displayMedium: DT.display,
    displaySmall: DT.h1,
    headlineLarge: DT.display,
    headlineMedium: DT.h1,
    headlineSmall: DT.h2,
    titleLarge: DT.h1,
    titleMedium: DT.h2,
    titleSmall: DT.tileTitle,
    bodyLarge:
        roboto.bodyLarge?.merge(kidBody.copyWith(fontSize: 16)) ??
        kidBody.copyWith(fontSize: 16),
    bodyMedium: roboto.bodyMedium?.merge(kidBody) ?? kidBody,
    bodySmall: roboto.bodySmall?.merge(DT.caption) ?? DT.caption,
    labelLarge: roboto.labelLarge?.merge(kidLabel) ?? kidLabel,
    labelMedium: roboto.labelMedium?.merge(DT.caption) ?? DT.caption,
    labelSmall: roboto.labelSmall?.merge(DT.caption) ?? DT.caption,
  );
}

// Base styling for Material actions; PlayAction adds the tactile lower edge.
ButtonStyle _actionStyle({bool outlined = false}) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(72, 72)),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  ),
  textStyle: const WidgetStatePropertyAll(DT.kidButton),
  elevation: const WidgetStatePropertyAll(0),
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? DT.disabled
        : outlined
        ? DT.surfaceWhite
        : DT.solid(DT.brand),
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? DT.textSecondary
        : outlined
        ? DT.solid(DT.brand)
        : DT.surfaceWhite,
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
  ),
  side: WidgetStatePropertyAll(
    outlined ? const BorderSide(color: DT.outline, width: 2) : BorderSide.none,
  ),
);
