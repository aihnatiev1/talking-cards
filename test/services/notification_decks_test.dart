import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Dart→asset migration of the notification copy decks: the JSON
/// files must be content-equal to the legacy hardcoded arrays (copied below
/// verbatim as fixtures from notification_service.dart before deletion).
///
/// streakSave templates use a {streak} placeholder; equality is checked
/// after substituting a sample streak value.

// ── Legacy Dart decks (verbatim fixtures) ─────────────────────────────────

const _dailyUk = [
  ('🐱', 'Кішка каже МЯУ! Повтори разом із малюком!'),
  ('🐶', 'Собака каже ГАВ-ГАВ! Час для карток!'),
  ('🐮', 'Корова каже МУ-У! Що ще живе на фермі?'),
  ('🐷', 'Свинка каже ХРЮ! Пограйте у картки разом!'),
  ('🐸', 'Жабка каже КВА! Вивчаємо нові слова?'),
  ('🦁', 'Лев каже Р-Р-Р! Тренуємо звук Р сьогодні?'),
  ('🐔', 'Курочка каже КО-КО! Нові картки чекають!'),
  ('🦆', 'Качка каже КРЯ! 5 хвилин — і малюк вивчить нове слово!'),
  ('🐝', 'Бджілка каже Ж-Ж-Ж! Час гратись з картками!'),
  ('🚗', 'Машина каже БІ-БІ! Вивчаємо транспорт?'),
  ('🔍', 'Знайди зайве! Чи впорається малюк сьогодні?'),
  ('🥁', 'КО-РО-ВА — три склади! Пограйте в «Рахуй склади»!'),
  ('↔️', 'Що протилежне до «ВЕЛИКИЙ»? Пограйте разом!'),
  ('🎤', 'Повтори за мною: РИБА, РАКЕТА, РУКА! Тренуємо вимову!'),
  ('🗂️', 'Розклади картки по купках! Нова гра чекає!'),
  ('🧠', 'Знайди пару! Тренуємо пам\'ять разом із малюком!'),
  ('🎧', 'Вгадай слово на слух! Вікторина вже відкрита!'),
  ('🦁', 'Звук Р: РАК, РИБА, РАКЕТА! Тренуємо разом!'),
  ('🦋', 'Звук Л: ЛЕВ, ЛИМОН, ЛІТАК! Грайте зі звуком Л!'),
  ('🐍', 'Ш-Ш-Ш! Звук Ш: ШАПКА, МИШКА, МАШИНА!'),
  ('⭐', 'Звук С: СЛОН, СОНЦЕ, СОБАКА! Логопедичний пак відкрито!'),
  ('🏃', 'Бігти, стрибати, їсти — вивчаємо дії разом!'),
  ('💃', 'ТАНЦЮВАТИ, СПІВАТИ, МАЛЮВАТИ — нові слова-дії!'),
  ('🤗', 'Обіймати, цілувати, допомагати — вчимо добрі дії!'),
  ('↔️', 'ВЕЛИКИЙ і МАЛЕНЬКИЙ, ДЕНЬ і НІЧ — вчимо протилежності!'),
  ('🔥', 'ГАРЯЧИЙ чи ХОЛОДНИЙ? Відгадай протилежність!'),
  ('🔥', 'Продовжуйте серію! Малюк вже так добре знає слова!'),
  ('🌟', 'Щоденні 5 хвилин — і мовлення розвивається!'),
  ('⭐', 'Маленькі кроки щодня — великий результат!'),
  ('🏆', 'Ви вже так далеко! Продовжуйте займатись щодня!'),
  ('💪', 'Сьогодні — нове слово, завтра — впевнена мова!'),
];

const _dailyEn = [
  ('🐱', 'Cats say MEOW! Say it together with your little one.'),
  ('🐶', 'Dogs say WOOF-WOOF! Card time with your little one.'),
  ('🐮', 'Cows say MOO! Who else lives on the farm?'),
  ('🐷', 'Pigs say OINK! Play a round of cards together.'),
  ('🐸', 'Frogs say RIBBIT! Ready for new words?'),
  ('🦁', 'Lions ROAR! A perfect day to learn the R sound.'),
  ('🐔', 'Hens say CLUCK! New cards are waiting.'),
  ('🦆', 'Ducks say QUACK! 5 minutes — one new word.'),
  ('🐝', 'Bees say BUZZ-Z-Z! Time to play with cards.'),
  ('🚗', 'Cars say BEEP-BEEP! Let\'s learn about transport.'),
  ('🔍', 'Spot the odd one out! Can your little one do it today?'),
  ('🥁', 'BA-NA-NA — three syllables! Try the "Count Syllables" game.'),
  ('↔️', 'What\'s the opposite of BIG? Play together!'),
  ('🎤', 'Repeat after me: FISH, ROCKET, HAND. Practice speaking!'),
  ('🗂️', 'Sort the cards into piles! A new game is waiting.'),
  ('🧠', 'Find the pair! Train memory with your little one.'),
  ('🎧', 'Guess the word by sound! The quiz is open.'),
  ('🦁', 'R sound: RABBIT, ROCKET, RING! Practice together.'),
  ('🦋', 'L sound: LION, LEMON, LEAF! Play with the L sound.'),
  ('🐍', 'SH-SH-SH! Sound SH: SHIP, FISH, SHOES!'),
  ('⭐', 'S sound: SUN, STAR, SNAKE! Speech pack is ready.'),
  ('🏃', 'Run, jump, eat — let\'s learn action words together.'),
  ('💃', 'DANCE, SING, DRAW — fresh action words to try.'),
  ('🤗', 'Hug, kiss, help — learn kind actions together.'),
  ('↔️', 'BIG and SMALL, DAY and NIGHT — learning opposites.'),
  ('🔥', 'HOT or COLD? Guess the opposite!'),
  ('🔥', 'Keep the streak going! Your little one knows so many words already.'),
  ('🌟', 'Daily 5 minutes — and speech keeps growing.'),
  ('⭐', 'Small steps every day — big results.'),
  ('🏆', 'You\'ve come so far! Keep practicing every day.'),
  ('💪', 'A new word today — confident speech tomorrow.'),
];

const _winBackUk = [
  ('👋', 'Скучили за картками! 3 хвилини — і нове слово вивчено.'),
  ('🎈', 'Час для карток! Повертайся до малюка сьогодні.'),
  ('📚', 'Нові картки чекають на малюка. Загляньте на 5 хвилин!'),
  ('🌈', 'Пам\'ятаєш своїх друзів-тваринок? Вони скучили!'),
  ('✨', 'Маленький перерив — і знову до нових слів!'),
  ('🧸', 'Картки сумують без малюка. Пограємо сьогодні?'),
  ('💬', 'Одне нове слово щодня — велика різниця за місяць.'),
];

const _winBackEn = [
  ('👋', 'We miss you! 3 minutes of cards — one new word learned.'),
  ('🎈', 'Shall we learn a word with your little one today?'),
  ('📚', 'Your cards are waiting. 5 minutes makes a difference.'),
  ('🌈', 'Remember your animal friends? They miss you!'),
  ('✨', 'A small break — and back to new words together!'),
  ('🧸', 'The cards miss your little one. Shall we play today?'),
  ('💬', 'One new word a day — a big difference in a month.'),
];

List<(String, String)> _streakSaveUk(int currentStreak) => [
      ('🔥', 'Серія $currentStreak днів — не втрачай! 5 хвилин на картки сьогодні?'),
      ('⭐', '$currentStreak днів поспіль — чудово! Одна картка — і серія жива.'),
      ('🎯', 'Малюк на серії $currentStreak днів. Трохи карток перед сном?'),
      ('🏅', 'Не розривай серію $currentStreak днів — одна картка рятує день.'),
    ];

List<(String, String)> _streakSaveEn(int currentStreak) => [
      ('🔥', 'Keep the $currentStreak-day streak alive! Just 5 minutes of cards.'),
      ('⭐', '$currentStreak days in a row! One card keeps the streak going.'),
      ('🎯', 'Your little one is on a $currentStreak-day roll. A quick card before bed?'),
      ('🏅', 'Don\'t break your $currentStreak-day streak — one card saves the day.'),
    ];

// Legacy title templates that lived inline in the scheduling methods.
const _dailyTitleUk = 'Час для карток!';
const _dailyTitleEn = 'Card time!';

// The paywall reminder copy that was UA-only (the bug fixed by the deck
// files: en users used to receive the Ukrainian text).
const _paywallReminderUk = (
  '🎁 Подарунок для нової родини',
  '3 дні безкоштовно — відкрий 234 картки для розвитку мовлення',
);

// ── Assertions ─────────────────────────────────────────────────────────────

void main() {
  Map<String, dynamic> load(String lang) => json.decode(
        File('assets/l10n/notifications_$lang.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  List<(String, String)> deck(Map<String, dynamic> decks, String key) =>
      [for (final e in decks[key] as List<dynamic>) (e['emoji'] as String, e['body'] as String)];

  group('notifications_uk.json', () {
    final decks = load('uk');

    test('daily deck equals legacy _cards', () {
      expect(deck(decks, 'daily'), _dailyUk);
    });

    test('winBack deck equals legacy _winBackUk', () {
      expect(deck(decks, 'winBack'), _winBackUk);
    });

    test('streakSave templates equal legacy _streakSaveUk', () {
      const streak = 7;
      final rendered = [
        for (final (emoji, body) in deck(decks, 'streakSave'))
          (emoji, body.replaceAll('{streak}', '$streak')),
      ];
      expect(rendered, _streakSaveUk(streak));
    });

    test('title templates equal legacy inline strings', () {
      expect(decks['dailyTitle'], _dailyTitleUk);
      expect(decks['streakSaveTitle'], 'Серія {streak} днів');
    });

    test('paywall reminder equals the legacy (previously UA-only) copy', () {
      final pr = (decks['paywallReminder'] as List<dynamic>).single;
      expect((pr['title'] as String, pr['body'] as String),
          _paywallReminderUk);
    });
  });

  group('notifications_en.json', () {
    final decks = load('en');

    test('daily deck equals legacy _cardsEn', () {
      expect(deck(decks, 'daily'), _dailyEn);
    });

    test('winBack deck equals legacy _winBackEn', () {
      expect(deck(decks, 'winBack'), _winBackEn);
    });

    test('streakSave templates equal legacy _streakSaveEn', () {
      const streak = 7;
      final rendered = [
        for (final (emoji, body) in deck(decks, 'streakSave'))
          (emoji, body.replaceAll('{streak}', '$streak')),
      ];
      expect(rendered, _streakSaveEn(streak));
    });

    test('title templates equal legacy inline strings', () {
      expect(decks['dailyTitle'], _dailyTitleEn);
      expect(decks['streakSaveTitle'], 'Streak day {streak}');
    });

    test('paywall reminder now has ENGLISH copy (bug fix)', () {
      final pr = (decks['paywallReminder'] as List<dynamic>).single;
      expect(pr['title'], isNot(_paywallReminderUk.$1));
      expect(pr['title'], startsWith('🎁'));
      expect((pr['body'] as String).toLowerCase(), contains('3 days free'));
    });
  });
}
