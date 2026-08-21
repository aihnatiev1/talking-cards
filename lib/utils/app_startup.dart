/// Cold-start clock, shared between `main()` and the home screen so we can
/// measure how long a real device takes to reach usable UI.
///
/// Exists because startup was a blind spot: analytics showed installs that
/// fired `session_start` and nothing else, with no way to tell a hung splash
/// from a user who tapped Install by accident.
class AppStartup {
  AppStartup._();

  static final Stopwatch clock = Stopwatch();

  /// Guards `app_ready` so it stays one-per-cold-start even though the home
  /// screen can be built again (profile switch, back navigation).
  static bool readyLogged = false;

  static void begin() {
    if (!clock.isRunning) clock.start();
  }
}
