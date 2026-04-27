# CLAUDE.md — Картки-розмовлялки

## Project Overview

**Картки-розмовлялки** — дитяча мобільна апка для розвитку мовлення дітей **1–4 роки**. Під брендом **Skillar**.

**Платформи:** iOS + Android (Flutter)
**Аудиторія:** діти 1–4 роки (користувачі), батьки/логопеди (покупці)
**Мови:** українська (основна), англійська

### Суть продукту

Озвучені картки з зображеннями, розбиті на тематичні паки (Фрази, Дії, Протилежності, звукові паки Р/Л/Ш/С/З/Ж/Ч/Щ/Ц, Прикметники тощо). Дитина бачить картку, чує слово + речення. Використовується батьками вдома і логопедами на заняттях.

Поточний стан: **238 карток × 2 аудіо = 453 аудіофайли** в українській версії, англійська в розробці (424 картки).

## Tech Stack

- **Flutter** (latest stable)
- **Dart** (latest stable)
- **State management:** Riverpod 2.x з code generation (`@riverpod`)
- **Routing:** go_router
- **Локалізація:** `flutter_localizations` + `.arb` файли
- **Audio:** `just_audio` (кращий за `audioplayers` для складних плейлістів)
- **Storage:** `shared_preferences` для простих налаштувань, `hive` для прогресу
- **Animations:** Rive (складні), Lottie (готові), Flutter Animation API (прості)
- **Тестування:** flutter_test, mocktail, golden_toolkit

## Architecture

**Clean Architecture + feature-first structure:**

```
lib/
├── core/                    # Загальні утиліти, theme, constants, DI
│   ├── theme/
│   ├── router/
│   ├── constants/
│   ├── extensions/
│   └── utils/
├── features/
│   ├── packs/              # Список паків карток
│   │   ├── data/           # Repository, data sources
│   │   ├── domain/         # Entities, use cases
│   │   └── presentation/   # Screens, widgets, providers
│   ├── card_viewer/        # Перегляд картки (слово + аудіо)
│   ├── settings/
│   └── paywall/            # Майбутня монетизація
├── shared/                  # Переіспользуємі widgets
│   └── widgets/
└── main.dart
```

**Правила архітектури:**
- Feature не знає про інші features напряму
- Domain layer не залежить від Flutter (pure Dart)
- Repository повертає domain entities, не DTO
- UI читає providers, не викликає repo напряму
- Кожен use case = один клас з `call()` методом

## Code Style

- **Null safety:** завжди, без `!` де можна уникнути
- **Const constructors:** обов'язково для widgets без стану
- **Records + patterns** для tuple-like повернень і switch-ів
- **Sealed classes** для станів (loading/success/error)
- **Freezed** для моделей (immutable + equality + copyWith)
- **Extension methods** замість helper-класів де доречно
- **Keys:** правильні keys у списках і умовних widgets

**Naming:**
- Файли: `snake_case.dart`
- Класи: `PascalCase`
- Приватне: `_leadingUnderscore`
- Const: `kCamelCase` або `SCREAMING_SNAKE` для глобальних

## Audience-Specific Rules (КРИТИЧНО)

Це дитяча апка, і це диктує кожне рішення:

1. **Tap targets мінімум 72dp** (замість стандартних 48dp) — малі пальці, хаотичні тапи
2. **Audio feedback на кожну дію** — діти 1–2 років не читають
3. **Forgiving input** — випадкові тапи, довгі утримання, swipe не мають ламати UX
4. **Мінімум тексту в UI** — іконки + аудіо, текст тільки для батьків у settings
5. **Яскраві контрастні кольори** — WCAG AAA де можливо
6. **Анімації при кожній взаємодії** — візуальний зворотний зв'язок обов'язковий
7. **Parental Gate** перед налаштуваннями/покупками (Apple Kids category вимога)
8. **COPPA/GDPR-K compliance** — ніяких трекерів, ніякої реклами в дитячій зоні
9. **Offline-first** — контент має працювати без інтернету
10. **60fps навіть на слабких девайсах** — багато батьків дають дітям старі планшети

## Content Structure

Контент зберігається в structured форматі. Картка має:

```dart
class Card {
  final String id;              // наприклад "sr01" (звук Р, картка 1)
  final String word;            // "РАК"
  final String? phrase;         // "Рак живе у річці!" (nullable для Adjectives)
  final String wordAudioPath;   // assets/audio/uk/sr01_word.wav
  final String? phraseAudioPath;
  final String imagePath;       // assets/images/sr01.webp
  final int wordDurationMs;     // 1000 (для таймінгу)
  final int? phraseDurationMs;  // 2000 або 3000
  final PackId packId;
}
```

Структура asset-ів:
```
assets/
├── audio/
│   ├── uk/                   # українська озвучка
│   └── en/                   # англійська озвучка
├── images/                   # WebP, різні resolutions
└── animations/               # Rive/Lottie
```

## Publishing Context

- **Apple Developer:** аккаунт є, проходили rejection по Terms of Use/EULA (вирішено)
- **Google Play:** ФОП-акаунт, проходили 12-tester/14-day closed testing з фрілансерами з Fiverr
- **Kids category** — дуже строгий review процес, всі правила виконуємо

## Current Priorities (оновлювати!)

- Фінальна озвучка 453 укр аудіофайлів (готується у TTS через ElevenLabs)
- Англійська версія — 424 картки, TTS-safe скрипт готовий
- Підготовка оновлення для App Store + Google Play
- Розробка паку "Числа" (в обговоренні)

---

## Agent System

Цей проект використовує спеціалізованих агентів для різних задач. Агенти описані в `.claude/agents/`.

### Коли викликати якого агента

| Задача | Агент |
|---|---|
| Нова фіча — з чого почати, як структурувати | `architect` |
| Написати/виправити Flutter код | `flutter-dev` |
| Дизайн екрану, компонента, кольорів | `ux-kids` |
| Анімації, переходи, Rive/Lottie | `animator` |
| Тести, edge-cases, golden tests | `qa` |
| Робота з контентом (озвучка, переклади, assets) | `content` |
| Підготовка релізу, store listing, ASO | `publisher` |
| Оптимізація performance, app size | `perf` |
| IAP, subscriptions, paywall | `monetization` |

### Workflow приклад

Задача: "Додати пак 'Числа'"
1. `architect` → структура фічі, нові entities, де інтегрувати
2. `content` → список чисел, тексти речень, структура аудіофайлів
3. `ux-kids` → макет екрану (grid, tap targets, кольори)
4. `flutter-dev` → код по плану
5. `animator` → мікроанімації тапів і переходів
6. `qa` → тести

### Як викликати

У Claude Code: `/agent architect` або згадай ім'я: "як би `architect` підійшов до цього?"

---

## Commands & Scripts

```bash
# Dev
flutter run --flavor dev

# Build release
flutter build ipa --release
flutter build appbundle --release

# Code generation (Riverpod, Freezed, go_router)
dart run build_runner watch --delete-conflicting-outputs

# Tests
flutter test
flutter test --update-goldens  # оновити golden files

# Локалізація
flutter gen-l10n
```

## Important Notes for Claude

- **Перед тим як писати код** — подумай чи не краще викликати `architect`
- **Ніколи не додавай трекери, рекламу, analytics-що-передає-дані дітей** — це KIDS apка
- **Будь-який новий UI компонент** має йти через перевірку `ux-kids` принципів (tap size, contrast, audio feedback)
- **Аудіо має завжди lazy-load'итися** — не завантажувати всі 453 файли в пам'ять
- **Image формат:** WebP з fallback на PNG. Розміри: @1x, @2x, @3x
- **При будь-якій зміні в контенті** (картках) — оновити `content` агента щоб згенерував нові asset маніфести

---

_Цей файл читається Claude Code автоматично при старті сесії в цьому репо._
