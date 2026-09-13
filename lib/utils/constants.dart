import 'design_tokens.dart';

/// Legacy aliases — new code uses `DT`.
///
/// These names predate the token file and are still read at ~130 call
/// sites. They now resolve to the same constants as `DT.brand` etc., so the
/// palette has one source of truth; the aliases stay so those call sites can
/// migrate at their own pace instead of in one sweep.
const kAccent = DT.brand;
const kSoundRed = DT.soundRed;
const kTeal = DT.teal;
const kStreakOrange = DT.streakOrange;
