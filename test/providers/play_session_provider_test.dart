import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talking_cards/providers/play_session_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persists help, resumes position and grants reward atomically once',
    () async {
      final store = PlaySessionNotifier('alice_uk');
      await store.ready;
      await store.start('friends', ['cow', 'cat', 'dog']);
      for (var step = 0; step < 3; step++) {
        await store.advance('friends', step);
      }
      await store.miss('friends', 3);
      await store.miss('friends', 3);
      expect(store.state.requireValue.current!.hint, isTrue);
      store.dispose();
      final resumed = PlaySessionNotifier('alice_uk');
      await resumed.ready;
      expect(resumed.state.requireValue.current!.step, 3);
      await resumed.start('friends', ['cow', 'cat', 'dog']);
      expect(resumed.state.requireValue.current!.hint, isTrue);
      await Future.wait([
        resumed.advance('friends', 3),
        resumed.advance('friends', 3),
      ]);
      expect(resumed.state.requireValue.current!.step, 4);
      expect(resumed.state.requireValue.current!.assisted, {3});
      for (var step = 4; step < 7; step++) {
        await resumed.advance('friends', step);
      }
      await resumed.advance('friends', 6);
      expect(resumed.state.requireValue.rewards, {'friends'});
      final prefs = await SharedPreferences.getInstance();
      final raw =
          jsonDecode(prefs.getString('alice_uk')!) as Map<String, dynamic>;
      expect(raw['rewards'], ['friends']);
      expect(raw['sessions']['friends']['step'], 7);
      await resumed.start('friends', ['cow', 'cat', 'dog']);
      expect(resumed.state.requireValue.current!.step, 0);
      expect(resumed.state.requireValue.rewards, {'friends'});
      resumed.dispose();
    },
  );

  test(
    'profiles and languages are isolated and switching topic keeps progress',
    () async {
      final alice = PlaySessionNotifier('alice_uk');
      final bob = PlaySessionNotifier('bob_uk');
      final english = PlaySessionNotifier('alice_en');
      await Future.wait([alice.ready, bob.ready, english.ready]);
      await alice.start('friends', ['a', 'b', 'c']);
      await alice.advance('friends', 0);
      await alice.start('pond', ['d', 'e', 'f']);
      await alice.start('friends', ['a', 'b', 'c']);
      expect(alice.state.requireValue.current!.step, 1);
      expect(alice.state.requireValue.sessions.length, 2);
      expect(bob.state.requireValue.sessions, isEmpty);
      expect(english.state.requireValue.sessions, isEmpty);
      alice.dispose();
      bob.dispose();
      english.dispose();
    },
  );

  test(
    'unknown version is preserved rather than silently overwriting progress',
    () async {
      const raw = '{"version":99,"rewards":["friends"]}';
      SharedPreferences.setMockInitialValues({
        'future': raw,
        'quest_reward_claimed': true,
      });
      final store = PlaySessionNotifier('future');
      await store.ready;
      expect(store.state.hasError, isTrue);
      await expectLater(
        store.start('friends', ['a', 'b', 'c']),
        throwsA(anything),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('future'), raw);
      expect(prefs.getBool('quest_reward_claimed'), isTrue);
      store.dispose();
    },
  );
}
