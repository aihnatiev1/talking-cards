import 'package:flutter/material.dart';

import '../widgets/app_icon_painters.dart';
import 'design_tokens.dart';

/// The one icon language of the kid zone (ux-gap-audit 2026-09-13 §5.1
/// «Паперова іграшкова кімната»; architecture-gap-audit §2 F5).
///
/// Every glyph is vector art drawn by [AppIconPainter] in a 48×48 design
/// space — chubby paper cut-outs with a 2.5 dp ink outline, a two-tone
/// fill and, on coloured backgrounds, a white sticker edge. Material's
/// glyph font and emoji-as-icon are forbidden in the migrated kid-zone
/// files (`test/architecture/icons_test.dart`); Material stays in the
/// parent zone.
///
/// Semantic colours (spec §5.1): Мовлення = violet, Звуки = peach,
/// Світ = mint; Вгадай = sky, Пара = mint, Бульбашки = coral,
/// Повтори = peach, Зайве = violet, Протилежності = pink; the lock is a
/// smiling sunBurst padlock — never grey.
enum AppIcon {
  // ── Controls ────────────────────────────────
  back,
  close,
  sound,
  soundOff,
  play,
  replay,
  shuffle,
  home,
  check,
  lock,
  star,
  parent,

  // ── Pack categories ─────────────────────────
  catSpeech,
  catSounds,
  catWorld,

  // ── Games ───────────────────────────────────
  gameGuess,
  gameMatch,
  gameBubbles,
  gameRepeat,
  gameOdd,
  gameOpposites,
  gameArticulation,
  gameSort,
  gameSyllables,

  // ── Daily steps ─────────────────────────────
  stepListen,
  stepCards,
  stepQuest,

  // ── Quest-map landmarks (G13) ───────────────
  /// The listen stop reuses [stepListen] (an ear) and the star stop
  /// reuses [star]; these three are the landmarks that had no drawing.
  stopCardTree,
  stopBell,
  stopMicFlower,

  /// One footprint of the "little steps to the treasure" header.
  pawStep,

  // ── Rewards ─────────────────────────────────
  rewardChestClosed,
  rewardChestOpen,
  rewardGift,
  rewardTrophy,
  streakFlame,
  hint,

  // ── Album stickers (G14) ────────────────────
  /// The four streak-milestone stickers of the album, and the album
  /// itself (Bloom holds it in the header, and it labels the «Наліпки»
  /// tab of the treasure box).
  stickerUnicorn,
  stickerDragon,
  stickerRainbow,
  stickerButterfly,
  stickerAlbum,

  // ── Parent zone (G15) ───────────────────────
  /// The parent dashboard counts days; a paper wall calendar says so
  /// without an emoji. Parent-facing, but drawn in the same hand — the
  /// grown-up half of the app is the same universe (audit G15).
  calendar,

  // ── Main navigation (former `_ToyIcon` in PlayfulNavigationBar) ──
  navCards,
  navGames,
  navColoring;

  /// Screen-reader label. English on purpose: the child does not read and
  /// the parent's assistive tech speaks whatever language it is set to;
  /// call sites that know the locale pass `semanticLabel` instead.
  String get label => switch (this) {
        AppIcon.back => 'Back',
        AppIcon.close => 'Close',
        AppIcon.sound => 'Sound on',
        AppIcon.soundOff => 'Sound off',
        AppIcon.play => 'Play',
        AppIcon.replay => 'Replay',
        AppIcon.shuffle => 'Shuffle',
        AppIcon.home => 'Home',
        AppIcon.check => 'Done',
        AppIcon.lock => 'Locked',
        AppIcon.star => 'Star',
        AppIcon.parent => 'Parents',
        AppIcon.catSpeech => 'Speech',
        AppIcon.catSounds => 'Sounds',
        AppIcon.catWorld => 'World',
        AppIcon.gameGuess => 'Guess the word',
        AppIcon.gameMatch => 'Find the pair',
        AppIcon.gameBubbles => 'Pop the bubbles',
        AppIcon.gameRepeat => 'Repeat after me',
        AppIcon.gameOdd => 'Odd one out',
        AppIcon.gameOpposites => 'Opposites',
        AppIcon.gameArticulation => 'Articulation',
        AppIcon.gameSort => 'Sort it',
        AppIcon.gameSyllables => 'Count syllables',
        AppIcon.stepListen => 'Listen',
        AppIcon.stepCards => 'Cards',
        AppIcon.stepQuest => 'Quest',
        AppIcon.stopCardTree => 'Card tree',
        AppIcon.stopBell => 'Bell',
        AppIcon.stopMicFlower => 'Flower microphone',
        AppIcon.pawStep => 'Step',
        AppIcon.rewardChestClosed => 'Treasure chest',
        AppIcon.rewardChestOpen => 'Open treasure chest',
        AppIcon.rewardGift => 'Gift',
        AppIcon.rewardTrophy => 'Trophy',
        AppIcon.streakFlame => 'Streak',
        AppIcon.hint => 'Hint',
        AppIcon.stickerUnicorn => 'Unicorn sticker',
        AppIcon.stickerDragon => 'Dragon sticker',
        AppIcon.stickerRainbow => 'Rainbow sticker',
        AppIcon.stickerButterfly => 'Butterfly sticker',
        AppIcon.stickerAlbum => 'Sticker album',
        AppIcon.calendar => 'Days',
        AppIcon.navCards => 'Cards',
        AppIcon.navGames => 'Games',
        AppIcon.navColoring => 'Coloring',
      };
}

/// The glyph of one game, by its `gameDefinitions` id
/// (`lib/providers/game_stats_provider.dart`).
///
/// The parent dashboard used to print the game's emoji next to its name
/// while the games tab drew the real badge — two icon languages for the
/// same seven games (G15). An unknown id (a game added to the stats table
/// before it has art) falls back to the generic games glyph rather than
/// throwing on a parent's screen.
AppIcon appIconForGame(String id) => switch (id) {
      'quiz' => AppIcon.gameGuess,
      'memory' => AppIcon.gameMatch,
      'sort' => AppIcon.gameSort,
      'odd_one_out' => AppIcon.gameOdd,
      'opposite_game' => AppIcon.gameOpposites,
      'syllable_game' => AppIcon.gameSyllables,
      'repeat_game' => AppIcon.gameRepeat,
      'bubble_pop' => AppIcon.gameBubbles,
      'articulation' => AppIcon.gameArticulation,
      _ => AppIcon.navGames,
    };

/// Renders one [AppIcon].
///
/// `size` defaults to `DT.size.iconMd` (32 dp) — resolved in `build`
/// because `DTSize` fields are instance finals, not compile-time constants.
/// `color` overrides the icon's semantic accent (e.g. white on a saturated
/// button); the ink outline stays. `sticker` adds the 1.5 dp white paper
/// edge for icons that sit on a coloured or photographic background.
///
/// Each icon is wrapped in a `RepaintBoundary`: the art is static, so a
/// pulsing parent (`AmbientLoop`) does not re-rasterise the vector every
/// frame.
class AppIconView extends StatelessWidget {
  final AppIcon icon;
  final double? size;
  final Color? color;
  final bool sticker;

  /// Draws the icon as one flat shape in this colour — no two-tone, no
  /// ink outline, no doodles. The album's «not yet» state (G14): the
  /// child sees a shape worth wanting, not a padlock.
  final Color? silhouette;

  /// Overrides [AppIcon.label] when the call site knows the locale.
  final String? semanticLabel;

  const AppIconView(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.sticker = false,
    this.silhouette,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final side = size ?? DT.size.iconMd;
    return Semantics(
      label: semanticLabel ?? icon.label,
      image: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: side,
          child: CustomPaint(
            isComplex: true,
            painter: AppIconPainter(
              icon,
              color: color,
              sticker: sticker,
              silhouette: silhouette,
            ),
          ),
        ),
      ),
    );
  }
}
