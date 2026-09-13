import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../utils/app_icons.dart';
import '../utils/design_tokens.dart';
import '../utils/kid_routes.dart';
import '../utils/motion.dart';
import 'kid_tap.dart';

/// The one scaffold for every child-facing screen (architecture-gap-audit
/// 2026-09-13 §1.7 / F6; ux-gap-audit G6).
///
/// Before this, 21 screens each built their own `Scaffold` + `AppBar` — a
/// 48 dp Material back arrow here, a 56 dp X there, a text title a toddler
/// cannot read, a progress bar of a different height in every game. The
/// shell fixes the parts that must be the same everywhere and leaves the
/// scene to the screen:
///
///  * **Header** — always the same height ([headerHeight]), the back / close
///    control always top-left and always [DTSize.tapBack] (72 dp). The
///    [title] slot is optional and *not* meant for text in the kid zone: pass
///    the pack cover, an emoji badge, or nothing. [trailing] is the matching
///    right-hand slot (an `x/y` counter, a shuffle button); when empty it is
///    reserved so the title stays centred.
///  * **Progress** — [progress] `0..1` draws an 8 dp pill under the header in
///    the [accent]. One height, one radius, one colour role, every game.
///  * **Body** — fills what is left, inside the safe area.
///  * **Bottom** — optional fixed action bar (game controls) under the body.
///  * **Mascot corner** — bottom-right slot above [bottom], reserved for Bloom
///    (ux-gap-audit G2); never covers the learning object because it sits in
///    the padding, not over the body's centre.
///
/// Colours come from `PackPalette.of(accent)`; the background is [DT.bgWarm]
/// unless a game keeps its pastel tint via [background].
///
/// A [Scaffold] is still underneath so `ScaffoldMessenger`, `Overlay` and
/// `resizeToAvoidBottomInset` keep working — the rule enforced by
/// `test/architecture/kid_screen_test.dart` is *no `AppBar`* in the kid zone,
/// not *no Scaffold*.
class KidScreen extends StatelessWidget {
  const KidScreen({
    super.key,
    required this.body,
    this.leading,
    this.showLeading = true,
    this.title,
    this.trailing,
    this.progress,
    this.accent = DT.brand,
    this.bottom,
    this.mascotCorner,
    this.background = DT.bgWarm,
    this.resizeToAvoidBottomInset,
  }) : _close = false;

  /// A game: close (X) instead of back, and usually a [progress] pill.
  const KidScreen.game({
    super.key,
    required this.body,
    this.leading,
    this.showLeading = true,
    this.title,
    this.trailing,
    this.progress,
    this.accent = DT.brand,
    this.bottom,
    this.mascotCorner,
    this.background = DT.bgWarm,
    this.resizeToAvoidBottomInset,
  }) : _close = true;

  final bool _close;

  /// Top-left control. Defaults to [KidBackButton] ([KidCloseButton] for
  /// [KidScreen.game]). Pass your own to change what the tap does.
  final Widget? leading;

  /// `false` hides the control but keeps its space, so the title does not
  /// jump between a screen that can go back and one that cannot.
  final bool showLeading;

  /// Optional. A cover, a badge, an icon — not a sentence.
  final Widget? title;

  /// Right-hand header slot: counters (`7/20`), a secondary control.
  final Widget? trailing;

  /// `0..1`. When non-null an 8 dp pill in [accent] sits under the header.
  final double? progress;

  /// Header tint and progress colour, through [PackPalette.of].
  final Color accent;

  final Widget body;

  /// Fixed area under the body — game action bars, "next picture" rows.
  final Widget? bottom;

  /// Bottom-right slot above [bottom]. Reserved for Bloom; empty for now.
  final Widget? mascotCorner;

  final Color background;
  final bool? resizeToAvoidBottomInset;

  /// Header band: a 72 dp control plus [DT.sp8] above and below.
  static const double headerHeight = 72 + DT.sp8 * 2;

  /// Height of the [progress] pill.
  static const double progressHeight = 8;

  /// Vertical space the progress row takes when [progress] is set: the pill
  /// plus [DT.sp8] below it, so a body can size itself without measuring.
  static const double progressRowHeight = progressHeight + DT.sp8;

  /// The nearest [KidScreen]'s accent, for a control built outside the
  /// header (a [KidBackButton] in a body). [DT.brand] when there is none.
  static Color accentOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KidScreenScope>()?.accent ??
      DT.brand;

  @override
  Widget build(BuildContext context) {
    final control =
        leading ??
        (_close
            ? KidCloseButton(accent: accent)
            : KidBackButton(accent: accent));
    final progressValue = progress;
    return _KidScreenScope(
      accent: accent,
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: SafeArea(
          child: Column(
            children: [
              // An empty band is not a header. `showLeading: false` keeps
              // the control's space so a title does not jump between a
              // screen that can go back and one that cannot — but with no
              // title and no trailing there is nothing to hold in place,
              // and 88 dp of nothing above the content is just a gap.
              if (showLeading || title != null || trailing != null)
                _Header(
                  leading: showLeading
                      ? control
                      : const SizedBox.square(dimension: 72),
                  title: title,
                  trailing: trailing,
                ),
              if (progressValue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DT.sp24,
                    0,
                    DT.sp24,
                    DT.sp8,
                  ),
                  child: KidProgressPill(value: progressValue, accent: accent),
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: body),
                    if (mascotCorner != null)
                      Positioned(
                        right: DT.sp16,
                        bottom: DT.sp16,
                        child: mascotCorner!, // guarded by the `if` above
                      ),
                  ],
                ),
              ),
              if (bottom != null) bottom!, // guarded by the `if` above
            ],
          ),
        ),
      ),
    );
  }
}

class _KidScreenScope extends InheritedWidget {
  const _KidScreenScope({required this.accent, required super.child});

  final Color accent;

  @override
  bool updateShouldNotify(_KidScreenScope old) => old.accent != accent;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final Widget? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final centre = title;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DT.sp12,
        vertical: DT.sp8,
      ),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            leading,
            Expanded(
              child: centre == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DT.sp8),
                      child: Center(child: centre),
                    ),
            ),
            // The right slot is always the width of a control so the title
            // stays centred whether or not a screen puts something there.
            trailing ?? const SizedBox.square(dimension: 72),
          ],
        ),
      ),
    );
  }
}

/// The 8 dp progress pill: track in the accent's tint, fill in the accent.
/// Width follows [value] with [DTMotion.base] under full motion.
class KidProgressPill extends StatelessWidget {
  const KidProgressPill({super.key, required this.value, required this.accent});

  /// `0..1`; anything outside is clamped.
  final double value;
  final Color accent;

  /// Finder hook for the filled part.
  static const fillKey = ValueKey('kid_progress_fill');

  @override
  Widget build(BuildContext context) {
    final palette = PackPalette.of(accent);
    final t = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(t * 100).round()}%',
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          height: KidScreen.progressHeight,
          decoration: BoxDecoration(
            color: palette.tint,
            borderRadius: BorderRadius.circular(KidScreen.progressHeight),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            key: fillKey,
            duration: MotionPolicy.of(context).dur(DT.motion.base),
            curve: DT.motion.standard,
            width: constraints.maxWidth * t,
            height: KidScreen.progressHeight,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(KidScreen.progressHeight),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's `x/y` counter: dark text on white, ringed in the accent.
///
/// The first version of this pill was white on the accent — `DT.brand`
/// landed at 4.3:1 and a mint pack at 2.0:1, below AA, let alone the AAA
/// rule 5 of CLAUDE.md asks for. Turning it inside out keeps the colour
/// (now a 2 dp ring plus the soft shadow, which carry the pack identity
/// just as well) and puts [DT.textPrimary] on [DT.surfaceWhite] — 11.7:1,
/// the same figure on every pack, because the pair no longer depends on
/// the accent at all. Pinned by `test/widgets/kid_count_pill_test.dart`.
///
/// Sits in the [KidScreen.trailing] slot, so it reserves the 72 dp the
/// slot is worth and keeps the title centred.
class KidCountPill extends StatelessWidget {
  const KidCountPill({
    super.key,
    required this.label,
    this.accent,
    this.semanticsLabel,
  });

  /// Already-formatted text — `7/20`, `3/12 · 5`.
  final String label;

  /// Ring and shadow colour; the nearest [KidScreen]'s accent by default.
  final Color? accent;

  final String? semanticsLabel;

  /// Finder hook.
  static const pillKey = ValueKey('kid_count_pill');

  /// Text and background of the pill, as tested for contrast.
  static const foreground = DT.textPrimary;
  static const background = DT.surfaceWhite;

  /// Ring width. Thick enough to read as the pack's colour at a glance.
  static const double ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    final ring = accent ?? KidScreen.accentOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: Center(
        child: Container(
          key: pillKey,
          padding: const EdgeInsets.symmetric(
            horizontal: DT.sp12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ring, width: ringWidth),
            boxShadow: DT.shadowSoft(ring),
          ),
          child: Text(
            label,
            semanticsLabel: semanticsLabel,
            style: const TextStyle(
              fontFamily: DT.kidFont,
              fontVariations: [FontVariation('wght', 900)],
              fontSize: 16,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable pill in the kid zone: dark text on white, ringed in the pack
/// accent, inside a full 72 dp target.
///
/// Same reasoning as [KidCountPill] — the accent goes into the ring, the
/// shadow and the icon, never under the text — plus the two things a
/// counter does not need: a hit zone a toddler can find (CLAUDE.md rule 1)
/// and an [icon] that says what the tap does for a child who cannot read.
/// The icon is drawn in [DT.solid] of the accent (≥ 4.5:1 on white for
/// every pack; the raw mint is 2.0:1 and would be a ghost).
///
/// Contrast pinned by `test/widgets/kid_count_pill_test.dart`.
class KidActionPill extends StatelessWidget {
  const KidActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.accent,
    this.semanticsLabel,
  });

  /// Already-formatted text — a countdown, a short number.
  final String label;

  /// What the tap does, for a non-reader. Optional.
  final IconData? icon;

  final VoidCallback onTap;

  /// Ring, shadow and icon colour; the nearest [KidScreen]'s accent by default.
  final Color? accent;

  final String? semanticsLabel;

  /// Finder hook.
  static const pillKey = ValueKey('kid_action_pill');

  /// Text and background, as tested for contrast.
  static const foreground = DT.textPrimary;
  static const background = DT.surfaceWhite;
  static const double ringWidth = KidCountPill.ringWidth;

  /// The accent, darkened until it reads as an icon on [background].
  static Color iconColor(Color accent) => DT.solid(accent);

  @override
  Widget build(BuildContext context) {
    final ring = accent ?? KidScreen.accentOf(context);
    final glyph = icon;
    return KidTap(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: semanticsLabel ?? label,
        excludeSemantics: true,
        child: SizedBox(
          height: 72,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: Container(
                key: pillKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: DT.sp16,
                  vertical: DT.sp8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ring, width: ringWidth),
                  boxShadow: DT.shadowSoft(ring),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (glyph != null) ...[
                      Icon(glyph, size: 20, color: iconColor(ring)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: DT.kidFont,
                        fontVariations: [FontVariation('wght', 900)],
                        fontSize: 18,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icons for the header controls. One place, so the icon system being built
/// in parallel (ux-gap-audit G1) can swap Material glyphs for `KidIcon`
/// with a single edit.
Widget _ctrlIcon(AppIcon icon, Color color) =>
    AppIconView(icon, size: DT.size.iconMd, color: color);

/// 72 dp round back control. Pops by default; [onTap] overrides that.
class KidBackButton extends StatelessWidget {
  const KidBackButton({super.key, this.accent, this.onTap});

  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _KidControl(
    icon: AppIcon.back,
    label: 'Back',
    accent: accent ?? KidScreen.accentOf(context),
    onTap: onTap,
  );
}

/// 72 dp round close control for games. Pops by default; [onTap] overrides.
class KidCloseButton extends StatelessWidget {
  const KidCloseButton({super.key, this.accent, this.onTap});

  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _KidControl(
    icon: AppIcon.close,
    label: 'Close',
    accent: accent ?? KidScreen.accentOf(context),
    onTap: onTap,
  );
}

class _KidControl extends StatelessWidget {
  const _KidControl({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PackPalette.of(accent);
    return KidTap(
      // `maybePop`, not `pop`: a screen hosted as a tab has nothing under
      // it, and popping the last route leaves the child looking at black.
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.tint,
            border: Border.all(color: palette.border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: _ctrlIcon(icon, palette.onTint),
        ),
      ),
    );
  }
}

// ── Overlays ────────────────────────────────────────────────────────────────

/// Shows [overlay] through [KidRoutes.overlay] — the one entry point for
/// celebrations, unlock dialogs and every other card over a kid screen.
///
/// Overlays queue: if one is already showing, the next waits until it is
/// popped (experience-audit 2026-09-13 п. 9 — a streak milestone landing on
/// top of a pack celebration on top of an unlock dialog). The returned
/// future completes with the popped result once *this* overlay closes.
///
/// `celebrate()` in `lib/widgets/celebration.dart` should route through
/// here; that edit belongs to the celebration owner and is not made in F6.
Future<T?> showKidOverlay<T>(BuildContext context, Widget overlay) {
  final navigator = Navigator.of(context);
  return _KidOverlayQueue.run<T>(() {
    // The screen that asked may be gone by the time the queue reaches us.
    if (!navigator.mounted) return Future<T?>.value();
    return navigator.push(KidRoutes.overlay<T>(overlay));
  });
}

/// Drops any queued overlays and forgets the one showing. Tests only.
@visibleForTesting
void debugResetKidOverlayQueue() => _KidOverlayQueue.reset();

/// Whether an overlay pushed by [showKidOverlay] is currently on screen.
bool get isKidOverlayShowing => _KidOverlayQueue.showing;

abstract final class _KidOverlayQueue {
  static bool showing = false;
  static final Queue<void Function()> _waiting = Queue();

  static Future<T?> run<T>(Future<T?> Function() push) {
    if (!showing) {
      showing = true;
      return _finish(Future.sync(push));
    }
    final completer = Completer<T?>();
    _waiting.add(() {
      _finish(
        Future.sync(push),
      ).then(completer.complete, onError: completer.completeError);
    });
    return completer.future;
  }

  static Future<T?> _finish<T>(Future<T?> shown) async {
    try {
      return await shown;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst()();
      } else {
        showing = false;
      }
    }
  }

  static void reset() {
    showing = false;
    _waiting.clear();
  }
}
