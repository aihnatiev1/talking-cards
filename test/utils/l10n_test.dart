import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/l10n/plural_rules.dart';
import 'package:talking_cards/utils/l10n.dart';

void main() {
  group('AppS.call', () {
    test('uk returns the first argument verbatim', () {
      const s = AppS('uk');
      expect(s('Привіт', 'Hello'), 'Привіт');
    });

    test('en returns the second argument verbatim', () {
      const s = AppS('en');
      expect(s('Привіт', 'Hello'), 'Hello');
    });

    test('es hits the loaded table', () {
      AppS.tablesForTesting['es'] = {'Hello': 'Hola'};
      const s = AppS('es');
      expect(s('Привіт', 'Hello'), 'Hola');
      AppS.tablesForTesting.remove('es');
    });

    test('es miss falls back to en', () {
      AppS.tablesForTesting['es'] = {'Other key': 'Otra'};
      const s = AppS('es');
      expect(s('Привіт', 'Hello'), 'Hello');
      AppS.tablesForTesting.remove('es');
    });

    test('unknown locale without table falls back to en', () {
      const s = AppS('de');
      expect(s('Привіт', 'Hello'), 'Hello');
    });

    test('explicit key overrides the en-literal lookup', () {
      AppS.tablesForTesting['es'] = {
        'greeting.short': 'Hola',
        'Hello': 'WRONG',
      };
      const s = AppS('es');
      expect(s('Привіт', 'Hello', key: 'greeting.short'), 'Hola');
      AppS.tablesForTesting.remove('es');
    });
  });

  group('AppS.p', () {
    test('substitutes placeholders for uk and en', () {
      expect(
        const AppS('uk').p('Привіт, {name}!', 'Hello, {name}!',
            {'name': 'Оля'}),
        'Привіт, Оля!',
      );
      expect(
        const AppS('en')
            .p('Привіт, {name}!', 'Hello, {name}!', {'name': 'Emma'}),
        'Hello, Emma!',
      );
    });

    test('substitutes multiple and repeated placeholders', () {
      expect(
        const AppS('en').p('{a}+{a}={b}', '{a}+{a}={b}', {'a': 1, 'b': 2}),
        '1+1=2',
      );
    });

    test('plural number: a single numeric arg drives the category, whatever '
        'its name', () {
      AppS.tablesForTesting['es'] = {
        '{learned} words': {
          'one': '{learned} palabra',
          'other': '{learned} palabras',
        },
      };
      const s = AppS('es');
      expect(
        s.p('{learned} слів', '{learned} words',
            {'who': 'Ana', 'learned': 1}),
        '1 palabra',
      );
      expect(
        s.p('{learned} слів', '{learned} words',
            {'who': 'Ana', 'learned': 5}),
        '5 palabras',
      );
      AppS.tablesForTesting.remove('es');
    });

    test('plural number: with several numeric args, n/count wins', () {
      AppS.tablesForTesting['es'] = {
        '{done}/{total} stops': {
          'one': '{done}/{total} parada',
          'other': '{done}/{total} paradas',
        },
      };
      const s = AppS('es');
      expect(
        s.p('{done}/{total}', '{done}/{total} stops',
            {'done': 3, 'total': 5, 'n': 1}),
        '3/5 parada',
      );
      AppS.tablesForTesting.remove('es');
    });

    test('table template with plural forms picks the CLDR category', () {
      AppS.tablesForTesting['es'] = {
        '{n} cards': {
          'one': '{n} tarjeta',
          'other': '{n} tarjetas',
        },
      };
      const s = AppS('es');
      expect(s.p('{n} карток', '{n} cards', {'n': 1}), '1 tarjeta');
      expect(s.p('{n} карток', '{n} cards', {'n': 5}), '5 tarjetas');
      AppS.tablesForTesting.remove('es');
    });

    test('table plain-string template is used when present', () {
      AppS.tablesForTesting['es'] = {'Hello, {name}!': '¡Hola, {name}!'};
      const s = AppS('es');
      expect(
        s.p('Привіт, {name}!', 'Hello, {name}!', {'name': 'Ana'}),
        '¡Hola, Ana!',
      );
      AppS.tablesForTesting.remove('es');
    });

    test('table miss falls back to the en template', () {
      const s = AppS('es');
      expect(
        s.p('Привіт, {name}!', 'Hello, {name}!', {'name': 'Ana'}),
        'Hello, Ana!',
      );
    });

    test('key override works for p()', () {
      AppS.tablesForTesting['es'] = {'bubbles.popped': '¡{n} burbujas!'};
      const s = AppS('es');
      expect(
        s.p('Бульки: {n}', 'Bubbles: {n}', {'n': 3}, key: 'bubbles.popped'),
        '¡3 burbujas!',
      );
      AppS.tablesForTesting.remove('es');
    });
  });

  group('pluralCategory', () {
    test('uk: one / few / many', () {
      expect(pluralCategory('uk', 1), 'one');
      expect(pluralCategory('uk', 2), 'few');
      expect(pluralCategory('uk', 5), 'many');
    });

    test('uk: teens are many, x1/x2-x4 follow mod-10 rule', () {
      expect(pluralCategory('uk', 11), 'many');
      expect(pluralCategory('uk', 12), 'many');
      expect(pluralCategory('uk', 14), 'many');
      expect(pluralCategory('uk', 21), 'one');
      expect(pluralCategory('uk', 22), 'few');
      expect(pluralCategory('uk', 25), 'many');
      expect(pluralCategory('uk', 111), 'many');
    });

    test('uk: fractions are other', () {
      expect(pluralCategory('uk', 1.5), 'other');
    });

    test('en: one / other', () {
      expect(pluralCategory('en', 1), 'one');
      expect(pluralCategory('en', 2), 'other');
      expect(pluralCategory('en', 0), 'other');
    });

    test('es/pt and unknown locales use one / other', () {
      expect(pluralCategory('es', 1), 'one');
      expect(pluralCategory('es', 3), 'other');
      expect(pluralCategory('pt', 1), 'one');
      expect(pluralCategory('xx', 7), 'other');
    });
  });
}
