import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A request from inside a tab to show a different top-level tab.
///
/// `HomeScreen` owns which tab is visible, and a tab's own content sits far
/// below it in the tree; rather than thread a callback through every widget
/// on the way, a screen raises the index here and the home screen switches
/// with its usual fade-through and clears the request. Null means nothing
/// is pending.
///
/// Indices match [PlayfulNavigationBar]: 0 cards, 1 games, 2 coloring.
final homeTabRequestProvider = StateProvider<int?>((ref) => null);

/// Games — the tab "Обрати гру" means.
const int kGamesTabIndex = 1;

/// «Малюємо» — where the day's drawing step sends the child.
const int kDrawTabIndex = 2;
