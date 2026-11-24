import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/play_session.dart';
import 'language_provider.dart';
import 'profile_provider.dart';

final playSessionProvider =
    StateNotifierProvider<PlaySessionNotifier, AsyncValue<PlayJournal>>((ref) {
      final id = ref.watch(profileProvider.select((value) => value.activeId));
      final language = ref.watch(languageProvider);
      // Captured key: writes from an old profile can never land in a new one.
      return PlaySessionNotifier('${id}_play_journal_${language}_v1');
    });

class PlaySessionNotifier extends StateNotifier<AsyncValue<PlayJournal>> {
  PlaySessionNotifier(this.storageKey) : super(const AsyncLoading()) {
    ready = _load();
  }
  final String storageKey;
  late final Future<void> ready;
  Future<void> _queue = Future.value();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      final journal = raw == null
          ? const PlayJournal()
          : PlayJournal.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (mounted) state = AsyncData(journal);
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
    }
  }

  Future<void> _update(PlayJournal Function(PlayJournal) change) {
    final operation = _queue.then((_) async {
      await ready;
      if (!mounted) return;
      final current = state.requireValue;
      final next = change(current);
      final prefs = await SharedPreferences.getInstance();
      // One payload commits session, evidence, and reward together.
      if (!await prefs.setString(storageKey, jsonEncode(next.toJson()))) {
        throw StateError('Could not save progress');
      }
      if (mounted) state = AsyncData(next);
    });
    _queue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> start(String topic, List<String> cardIds) => _update((journal) {
    final existing = journal.sessions[topic];
    if (existing != null &&
        !existing.complete &&
        existing.cardIds.length == cardIds.length &&
        existing.cardIds.every(cardIds.contains)) {
      return journal.put(existing);
    }
    return journal.put(
      PlaySession(topic: topic, cardIds: List.unmodifiable(cardIds)),
    );
  });

  Future<void> advance(String topic, int expectedStep) => _update((journal) {
    final session = journal.sessions[topic];
    // Idempotent against double taps and delayed callbacks from an old page.
    if (session == null || session.complete || session.step != expectedStep) {
      return journal;
    }
    return journal.put(
      session.copyWith(
        step: session.step + 1,
        misses: 0,
        hint: false,
        assisted: session.hint
            ? {...session.assisted, session.step}
            : session.assisted,
      ),
    );
  });

  Future<void> miss(String topic, int expectedStep) => _update((journal) {
    final session = journal.sessions[topic];
    if (session == null || session.step != expectedStep || session.complete) {
      return journal;
    }
    final misses = session.misses + 1;
    return journal.put(
      session.copyWith(misses: misses, hint: session.hint || misses >= 2),
    );
  });

  Future<void> hint(String topic, int expectedStep) => _update((journal) {
    final session = journal.sessions[topic];
    if (session == null || session.step != expectedStep || session.complete) {
      return journal;
    }
    return journal.put(session.copyWith(hint: true));
  });
}
