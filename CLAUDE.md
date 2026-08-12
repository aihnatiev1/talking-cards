# CLAUDE.md — Картки-розмовлялки

## Project Overview

**Картки-розмовлялки** — дитяча мобільна апка для розвитку мовлення дітей **1–4 роки**. Під брендом **Skillar**.

**Платформи:** iOS + Android (Flutter)
**Аудиторія:** діти 1–4 роки (користувачі), батьки/логопеди (покупці)
**Мови:** українська (основна), англійська

### Суть продукту

Озвучені картки з зображеннями, розбиті на тематичні паки (Фрази, Дії, Протилежності, звукові паки Р/Л/Ш/С/З/Ж/Ч/Щ/Ц, Прикметники тощо) + 10+ міні-ігор, водна розмальовка, щоденний квест. Дитина бачить картку, чує слово + речення. Використовується батьками вдома і логопедами на заняттях.

Поточний стан: **471 озвучена картка, 21 пак**, обидві мови живі (UA — основна, EN — бренд **FirstWords Cards**). У сторах: iOS (App Store), Android (Google Play).

## Tech Stack (реальний — перевірено 2026-08)

- **Flutter** (stable; Xcode Cloud пінить 3.41.5 для iOS CI)
- **State management:** ручний Riverpod — `StateNotifierProvider`/`Provider`, **БЕЗ codegen** (`@riverpod`/build_runner не використовуються — не запроваджуй їх для окремої фічі)
- **Routing:** звичайний `Navigator` + `MaterialPageRoute` (go_router НЕ використовується)
- **Локалізація:** власний хелпер `AppS` в `lib/utils/l10n.dart` (`s('укр', 'eng')`), НЕ .arb
- **Audio:** `flutter_soloud` (lazy-load з диска через `AudioService`) + `audio_session`
- **Storage:** `shared_preferences` (з префіксом профілю через `ProfileService`)
- **Монетизація:** `in_app_purchase` (Billing 8), SKU: `yearly_premium`, `monthly_premium`, `lifetime_premium`
- **Analytics:** Firebase Analytics через `AnalyticsService` (COPPA-обережно), Crashlytics
- **Тестування:** flutter_test (widget/unit; `flutter test test/`)

## Architecture (реальна — плоска, НЕ clean-arch)

```
lib/
├── models/        # CardModel, PackModel, ProfileModel...
├── providers/     # StateNotifierProvider-и (packs, profile, streak, srs...)
├── screens/       # Повноекранні екрани (cards, games, paywall, onboarding...)
├── tabs/          # Таби home_screen: packs_tab, games_tab
├── services/      # Синглтони: AudioService, PurchaseService, AnalyticsService...
├── widgets/       # Перевикористовувані віджети (parental_gate, bloom_mascot...)
├── utils/         # l10n (AppS), constants, design_tokens, міксини
└── main.dart
```

**Правила:**
- Синглтон-сервіси зі `instance`, UI читає providers
- Новий код має відповідати цьому плоскому стилю — НЕ запроваджуй features/-структуру, codegen чи go_router

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
7. **Parental Gate** перед батьківською зоною — Є в коді: `lib/widgets/parental_gate.dart` (math-питання словами + keypad); викликати `showParentalGate()` перед будь-якою новою батьківською/зовнішньою дією
8. **COPPA/GDPR-K compliance** — ніяких трекерів, ніякої реклами в дитячій зоні
9. **Offline-first** — контент має працювати без інтернету
10. **60fps навіть на слабких девайсах** — багато батьків дають дітям старі планшети

## Content Structure

Реальна модель — `lib/models/card_model.dart` (`CardModel`: id, sound/text, `audio` ключ, `image` ім'я webp). Дані карток — JSON у `assets/data/` (uk_cards.json тощо).

Структура asset-ів (реальна):
```
assets/
├── audio_mp3/     # ВСЯ озвучка (uk + en, ~923 mp3) + praise_/instr_ кліпи
├── audio_sfx/     # SFX винагороди: pop/ding/tada.wav
├── images/webp/   # ілюстрації карток (1 файл на картку, спільні для мов)
└── data/          # JSON карток/паків
```

Аудіо-ключі мапляться в `AudioService._audioMap`; playWordOnly ріже до слова за `assets/data/audio_word_lengths.json`. Аудіо ВЖЕ lazy-load'иться з диска — не повертай eager precache.

## Publishing Context

- **App Store:** категорія Education (4+), НЕ Kids category. Бренд EN — FirstWords Cards. Метадані версіонуються у `ios/fastlane/metadata/` (5 локалей: uk, en-US, en-GB, en-AU, en-CA), скріншоти — `ios/fastlane/screenshots/`. Xcode Cloud збирає і заливає білд на push у main (workflow "Default").
- **Google Play:** ФОП-акаунт; метадані у `android/fastlane/metadata/`.
- ASC API-доступ налаштований (див. memory `reference_appstore_api`) — версії/метадані/скріншоти/сабміт робляться через API.

## Current Priorities (оновлено 2026-08-12)

- v1.3.0 на App Review (нове ASO: назва/keywords/скріншоти + ігровий overhaul)
- Записати praise/інструкції через ElevenLabs (`tools/gen_praise_instructions.py` — чекає API-ключ)
- Нові ціни/SKU: yearly $29.99 / monthly $7.99 / lifetime $59.99 (US); 649/149/1299 грн (UA)
- Play: залити свіжий AAB + метадані
- Далі: рекапчур 2 скріншот-слотів (прогрес, профілі), Play Asset Delivery (розмір), weekly parent email

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
# Dev (флейворів немає)
flutter run

# Build release
flutter build ipa --release        # зазвичай робить Xcode Cloud на push у main
flutter build appbundle --release  # AAB для Play

# Tests + аналіз (мають бути зелені перед комітом)
flutter test
flutter analyze

# Стор-скріншоти (Remotion, gitignored marketing/)
cd marketing && npx remotion still src/index.ts StoreScreenshot out/store-v2/slot-1-en.png --props='{"locale":"en","slot":1}'

# Praise/інструкції озвучка (потрібен ELEVENLABS_API_KEY)
python3 tools/gen_praise_instructions.py --list-voices
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
