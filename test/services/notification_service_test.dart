import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/notification_service.dart';
import 'package:talking_cards/services/purchase_service.dart';

/// The trial progress report is the one notification whose timing and text
/// decide money: it lands two days before the first charge. Its timing and
/// copy are pure functions so they can be pinned here without a plugin.
void main() {
  group('trialReportFireTime', () {
    final start = DateTime(2026, 9, 7, 14, 30);

    final reportDay = PurchaseService.kTrialDays - 2;

    test('is 19:00 two days before the first charge', () {
      expect(
        NotificationService.trialReportFireTime(start, start),
        DateTime(2026, 9, 7 + reportDay, 19),
      );
    });

    test('is gone once that evening has passed', () {
      expect(
        NotificationService.trialReportFireTime(
            start, DateTime(2026, 9, 7 + reportDay, 19, 1)),
        isNull,
      );
    });
  });

  group('trialReportCopy', () {
    test('Ukrainian, named child, best pack', () {
      final (title, body) = NotificationService.trialReportCopy(
        lang: 'uk',
        childName: 'Софійка',
        learnedWords: 23,
        bestPack: 'Звук Р',
      );
      expect(title, contains('з Картками'));
      expect(body, 'Скарбничка: Софійка знає 23 слова. Найкраще іде: Звук Р. '
          'Ще 2 дні безкоштовно.');
    });

    test('Ukrainian plural follows the count', () {
      final (_, body) = NotificationService.trialReportCopy(
        lang: 'uk', childName: null, learnedWords: 1, bestPack: null);
      expect(body, contains('1 слово.'));
      expect(body, contains('Малюк'));
    });

    test('nothing learned yet does not invent numbers', () {
      final (_, body) = NotificationService.trialReportCopy(
        lang: 'en', childName: 'Mia', learnedWords: 0, bestPack: 'Animals');
      expect(body, isNot(contains('0')));
      expect(body, contains('Mia'));
      expect(body, contains('2 free days left'));
    });

    test('English', () {
      final (title, body) = NotificationService.trialReportCopy(
        lang: 'en', childName: 'Mia', learnedWords: 12, bestPack: 'Animals');
      expect(title, contains('FirstWords'));
      expect(body, "Mia's word chest: 12 words. Best so far: Animals. "
          '2 free days left.');
    });
  });
}
