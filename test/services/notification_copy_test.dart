import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/notification_service.dart';

/// A reminder is the only thing this app says to a parent while the phone
/// is in their pocket. It may invite; it may not frighten, and it may not
/// promise an outcome the app cannot see.
///
/// The app measures card views, answers in games and a grown-up's own
/// «Вийшло!» taps. It has no microphone. So no line may suggest a child
/// will speak better, nor that anything is lost by skipping a day.
void main() {
  final copy = NotificationService.allCopy();

  test('there is copy to check at all', () {
    expect(copy.length, greaterThan(40));
  });

  group('no fear of loss', () {
    // Lowercased substrings; each one is a way of saying "you will lose
    // something if you stop".
    const lossWords = [
      'втрат',
      'не розривай',
      'не втрачай',
      'рятує',
      'рятуй',
      'згорить',
      'скучили',
      'сумують',
      'lose',
      'losing',
      'lost',
      "don't break",
      'do not break',
      'streak will',
      'keep the streak',
      'miss you',
      'we miss',
    ];

    for (final line in copy) {
      test('«$line»', () {
        final lower = line.toLowerCase();
        for (final word in lossWords) {
          expect(
            lower.contains(word),
            isFalse,
            reason: 'loss/fear wording "$word" in: $line',
          );
        }
      });
    }
  });

  group('no promise about speech', () {
    const overclaims = [
      'мовлення',
      'заговорить',
      'говоритиме',
      'вивчить',
      'вивчено',
      'розвивається',
      'speech',
      'will speak',
      'will learn',
      'word learned',
      'words learned',
    ];

    for (final line in copy) {
      test('«$line»', () {
        final lower = line.toLowerCase();
        for (final word in overclaims) {
          expect(
            lower.contains(word),
            isFalse,
            reason: 'unmeasurable promise "$word" in: $line',
          );
        }
      });
    }
  });

  group('inviteCopy speaks from context', () {
    test('names the pack the family opened last', () {
      final (_, body) = NotificationService.inviteCopy(
        lang: 'uk',
        lastPackTitle: 'Тваринки',
      );
      expect(body, 'Сьогодні можна пограти зі знайомим паком «Тваринки».');
    });

    test('falls back to familiar words, at most three', () {
      final (_, body) = NotificationService.inviteCopy(
        lang: 'uk',
        familiarWords: const ['кіт', 'вода', 'м\'яч', 'собака'],
      );
      expect(body, contains('кіт, вода, м\'яч'));
      expect(body, isNot(contains('собака')));
    });

    test('says something calm when there is no context at all', () {
      final (title, body) = NotificationService.inviteCopy(lang: 'en');
      expect(title, contains('Cards are waiting'));
      expect(body, 'A few minutes of cards together, whenever it suits you.');
    });

    test('carries no day counter in either language', () {
      for (final lang in ['uk', 'en']) {
        final (title, body) = NotificationService.inviteCopy(
          lang: lang,
          lastPackTitle: 'Тваринки',
        );
        expect(RegExp(r'\d').hasMatch(title + body), isFalse);
      }
    });
  });

  test('win-back greets instead of mourning', () {
    for (final (_, body) in NotificationService.winBackUk) {
      expect(body, isNot(contains('Скучили')));
    }
    expect(
      NotificationService.winBackUk.any((c) => c.$2.startsWith('Раді бачити')),
      isTrue,
    );
    expect(
      NotificationService.winBackEn.any(
        (c) => c.$2.startsWith('Good to see you'),
      ),
      isTrue,
    );
  });
}
