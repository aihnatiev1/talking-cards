# Аудит архітектурних прогалин — 2026-09-13

Обсяг: фундаменти `lib/`, що обмежують «відчуття» продукту. Не дублює `docs/design-audit-2026-09-08.md` (екранні знахідки), `docs/experience-audit-2026-09-13.md` (досвід, ігри) і `docs/design/*.md` (специфікації двох ігор) — посилається на них як «дизайн-аудит №N» / «аудит досвіду п. N». Усі кількості — з `rg` по `lib/` на стані гілки `fix/content-availability-contract` (включно з незакомміченими `playful_navigation_bar.dart`, `quest_journey_map.dart`).

## 0. Діагноз одним абзацем

Апка має **зачатки** кожної потрібної системи — `DT` токени, `KidTap`, `BloomMascot`, `GameCelebration`, `ConfettiBurst`, мікси для shake/confetti/game-state, `_gameRoute`, `IndexedStack + TickerMode` — але жодна з них не є **обов'язковим шляхом**. Кожен новий екран знову вирішує колір, тривалість, тап-фідбек, перехід і свято сам. Доказ: два найновіші віджети (`playful_navigation_bar`, `quest_journey_map`) містять 59 сирих `Color(0x…)` і власну шкалу натискання (.93/220 мс проти `DT.pressScale` .96/140 мс) — тобто система токенів не поглинає нову роботу. Топ-рівень (Duolingo ABC, Khan Kids, Sago Mini) відрізняється не якістю окремих екранів, а тим, що **рух, звук, персонаж і іконки — це один шар, через який проходить усе**. Саме цього шару немає.

## 1. Знахідки

### 1.1 Система дизайн-токенів

**Що є** (`lib/utils/design_tokens.dart`):
- Поверхні 3, текст 3, акценти 7 + тінти 7, семантика 3 (рядки 13–43).
- Spacing 7 кроків 4–32 (46–52), radius 4 кроки 12/16/22/28 (55–58), 2 тіні (69–83), `onTint()` (66–67).
- Motion: **лише 3 значення** — `pressScale`, `pressMs` 140, `enterMs` 260 (86–88). Кривих немає.
- Type: 6 стилів на Nunito/Roboto (103–151), `screenScale`/`responsiveFont` (156–161).

**Чого немає:** шкали тривалостей і кривих; розмірів тап-таргетів (правило 72dp з CLAUDE.md не закодоване ніде — кожен екран пише `72`, `56`, `64` руками); розмірів іконок і маскота; рівнів elevation; кольору бар'єра оверлеїв; ролей для темної теми; ролей «акцент паку → фон/текст/рамка» (є лише `onTint`).

**Паралельні джерела істини:**
- `lib/utils/constants.dart:3–6` — `kAccent #6C63FF`, `kTeal`, `kSoundRed`, `kStreakOrange`: 134 використання у 31 файлі. `kAccent` (індиго) взагалі відсутній у палітрі `DT` і при цьому є `colorSchemeSeed` теми (`main.dart:195`).
- `main.dart:198` `scaffoldBackgroundColor #FAF8F5` ≠ `DT.bgWarm #FFFBF0` — два «фонових» кольори.
- `main.dart:200–208` є `darkTheme`, але `DT` — константи для світлої теми; перевірок `Brightness.dark/isDark` — 12 у 5 файлах. Темна тема формально існує і фактично зламана дизайном.
- `playful_navigation_bar.dart:89–97` — власний `TextStyle` з літералом `'Nunito'` і три власні палітри `_accents/_tints/_inks`.

**Хардкод (lib/ повністю):**

| Патерн | Входжень | Файлів | Найгірші |
|---|---|---|---|
| `Color(0x` | 194 | 32 | playful_navigation_bar 31, quest_journey_map 28, DT 22, bubble_pop_screen 10, whatsnew_service 10, paywall 9, bloom 8 |
| `Colors.*` (white/grey/…) | 248 | 43 | packs_tab 19, paywall 19, parent_dashboard 17, card_reveal 13 |
| `Duration(milliseconds:` | 117 | 36 | onboarding 15, card_reveal 11, guess 7, memory_match 7 (у DT — 2) |
| `BorderRadius.circular(` | 167 | 45 | parent_dashboard 15, packs_tab 8, articulation 8 |
| `TextStyle(` | 313 | 43 | parent_dashboard 41, paywall 18, packs_tab 19 |
| `DT.display/h1/h2/tileTitle/body/caption` | 108 | 17 | games_tab 26, daily_hero_card 15 — адопція ~25 % |
| `screenScale/responsiveFont` | 53 | 10 | конкуруюча модель масштабування проти фіксованих `DT` розмірів |
| `Theme.of(context)` | 30 | 15 | здебільшого батьківські екрани |

Висновок: токени є, але не є контрактом — немає ані тесту, ані структурного бар'єра, який би зупинив сирий колір.

### 1.2 Система руху

- **Пакетів анімації немає** (`pubspec.yaml:9–37`): ні `rive`, ні `lottie`, ні `flutter_animate`. Уся анімація — ручні `AnimationController`: **46** у 26 файлах, `Curves.` **62** у 28 файлах.
- **Цикли:** `.repeat(` — **16** місць в 11 файлах (`daily_hero_card:114,356`, `flash_card:99,132`, `speaker_button:55`, `streak_milestone_overlay:69`, `treasure_card:39`, `card_reveal_screen:101–102,132–133` (конфеті нескінченно), `onboarding:588,885`, `guess_screen:106`, `swipe_hint:67`, `quest_journey_map:65`). Гейт `MediaQuery.disableAnimationsOf` — **6** місць у 4 файлах (`swipe_hint:62`, `quest_journey_map:61,390`, `playful_navigation_bar:122`, `game_celebration_overlay:36,92`). Тобто 14 з 16 циклів ігнорують reduced-motion (аудит досвіду п. 13 — тут причина: політики немає, є розкидані `if`).
- **Переходи:** `MaterialPageRoute|PageRouteBuilder` — **26** місць у 10 файлах. Чотири різні визначення: дефолтний Material (packs_tab ×9, cards_screen, home), `_gameRoute` fade+scale 260/200 мс — приватна функція `games_tab.dart:24–39`; fade 400 мс `quest_map_screen:278–310`; fade `onboarding:146–149`, `splash:206–209`. Немає спільного `AppRoutes`.
- **Press-фідбек:** `KidTap` (`lib/widgets/kid_tap.dart`) — правильний примітив, але як віджет використаний **3** рази (kid_tap, packs_tab, cards_screen), `KidTap.feedback()` — 5 місць. Натомість `GestureDetector|InkWell|*Button(` — **95** у 43 файлах, `onTap:` — 79 у 34; власних `AnimatedScale|Transform.scale` — **26** у 18 файлах. `pack_grid_card.dart:116–128` дослівно дублює тіло `KidTap`; `flash_card` має власний `_pressCtrl`; `playful_navigation_bar:160–163` — своя шкала.
- Мікси `shake_animation_mixin`, `confetti_overlay_mixin`, `game_state_mixin` — хороші зерна, але прив'язані до `ConsumerState` (не можуть жити у чистих віджетах).
- Тести: `card_image.dart:172–181` фіксує реальну проблему — нескінченні цикли вішають `pumpAndSettle` (32 виклики у 12 тестах). Без глобальної політики руху кожен новий цикл = зламаний тест або `if` руками.

**Що потребує Rive/Lottie-пайплайн (для F4):**
- Пакет `rive` (+ ~1.5–2 МБ до бінарника), файли `.riv` 100–400 КБ на персонажа зі state machine — кладуться в **базовий модуль** (`assets/ui/rive/`), не в `pad_content` (правило 9 offline-first; PAD ~90 МБ, `asset_pack_service.dart:209`, доставляється після інсталу).
- Lazy-load: `RiveFile.asset` один раз через сервіс-синглтон з `warm()` на splash (аналог `AudioService.warm`, `audio_service.dart:569`); не в `initState` кожного екрана.
- Reduced-motion: state machine ставиться в rest-позу, не вимикається (інформація має лишатись — аудит досвіду п. 13).
- Widget-тести: Rive не рендериться у `flutter test` без бінарних asset-ів → потрібна абстракція рендерера з painter-фолбеком (див. F4).
- Lottie: без state machine і inputs — годиться лише для one-shot свят; для персонажа не підходить. Рекомендація: Rive для персонажа, власний `CustomPainter` для конфеті (вже є), Lottie не додавати.

### 1.3 Маскот Bloom

- `lib/widgets/bloom_mascot.dart`: `CustomPainter` у просторі 120×120 (рядки 96–316), **2 емоції** — `happy`, `waving` (enum, рядок 16), різниця — лише позиція правої лапи (290–310). Очі завжди заплющені (239). Одна реакція — bounce 480 мс на тап (53–58). Немає idle/blink/look-at/talk/sad/think, немає синхронізації з `AudioService.isSpeaking` (озвучка «говорить», зайчик мовчить).
- Використання: **9** місць у 8 файлах, розміри 64/88/96/112 розкидані (`streak_milestone:175`, `game_celebration:117`, `kid_word_wall:131,194`, `onboarding:815`, `bubble_pop:1148`, `parent_dashboard:455`, `packs_tab:1134`).
- Ad-hoc обгортки поза віджетом: `_BouncingMascot` (`onboarding_screen.dart:802–815`) — власна анімація; `docs/design/memory_match_redesign.md` §1 планує **другий ручний малюнок** силуету Bloom у `CardBackPainter` — так персонаж почне дрейфувати між файлами.
- Висновок: є **іконка**, а не **персонаж**. Немає `BloomController`/сцени, немає контракту «що Bloom робить у момент X», painter не має рігу (одна `Path` на елемент, анімувати частини неможливо без перепису).

### 1.4 Іконографія

- `Icons.` (Material) — **78** у 30 файлах, включно з дитячою зоною (`speaker_button:105`, `cards_screen` 4, `packs_tab` 9, `quest_journey_map` 10).
- Емодзі-гліфи — ~**248** входжень у 37 файлах (regex по діапазонах emoji; 85 з них — тексти нотифікацій, це не UI). У дитячій зоні: packs_tab 19, games_tab 13, articulation 16, onboarding 7.
- Іконка паку = емодзі-рядок з JSON (`pack_model.dart:9 final String icon`), `cover` webp опційний (14–18). Тобто «іконка» — це контент-дані, а не дизайн-система.
- Кастомний вектор: `_ToyIcon` — 3 іконки за індексом (`playful_navigation_bar.dart:207–308`), приватний клас.
- Немає `flutter_svg`, іконочного шрифту, реєстру (`enum AppIcon`), директорії `assets/ui/icons/`. Три візуальні мови з аудиту досвіду п. 16 — структурний корінь саме тут.

### 1.5 Система свята/фідбеку

Не один пайплайн, а **чотири** незалежні поверхні + два конфеті:

| Поверхня | Файл | Рух | Звук | Хаптик | Особливості |
|---|---|---|---|---|---|
| Пак пройдено | `celebration_overlay.dart` | власний 40-частинковий painter (246–278), `elasticOut` | **немає** (немає імпорту AudioService; `cards_screen` не викликає `playSfx/playPraise`) | немає | `Colors.black54`, `Theme.of` surface, `Colors.grey[600]`, `⭐` текстом (129), Material `Icons.replay/share` |
| Гра завершена | `game_celebration_overlay.dart` | `showGeneralDialog` + `ConfettiBurst` + Bloom | `tada` + praise (28–29) | немає | єдиний гейт reduced-motion (36, 92) |
| Streak milestone | `streak_milestone_overlay.dart` | нескінченний `_flame` (66–69), `elasticOut` | **немає** | немає | `🔥` 64sp (139–142), `Colors.grey[700]` |
| Card reveal | `card_reveal_screen.dart` | 7 контролерів, конфеті `repeat()` (101–102) | немає `playSfx` | — | власний glow |

- Два конфеті з **дубльованою палітрою** не з `DT`: `celebration_overlay.dart:232–236` = `confetti_burst.dart:62–66`.
- Хаптик: `HapticFeedback.` — **42** прямі виклики у 23 файлах без семантики події (light/medium вибирається на місці).
- SFX: 3 файли `pop/ding/tada.wav`, за коментарем `audio_service.dart:750` — «synthesized v1 placeholders». Praise/instr відсутні → `playPraise/playInstruction` мовчки no-op (753, 825, 836). Позитив: `playSfxVaried` з pitch spread (806–815) — правильний примітив «20 різних попів з одного файлу».
- Немає мапінгу подія → (звук, хаптик, візуальний рівень). Аудит досвіду п. 15 просить три рівні свята — зараз кожен екран збирає свій.

### 1.6 Покриття аудіо-фідбеком

Виклики `playSfx|playPraise|playInstruction` — **25** у 11 файлах, і всі — в іграх (`guess` 3, `memory` 3, `odd_one_out` 3, `opposite` 3, `bubble_pop` 2, `coloring` 2, `repeat` 1, `onboarding` 1) + `kid_tap`, `game_celebration`. **Нуль** прямих викликів у: `home_screen`, `packs_tab` (1 `KidTap`), `cards_screen` (1 `KidTap`), `quest_map_screen`, `rewards_screen`, `card_reveal_screen`, `kid_word_wall_screen`, `articulation_screen`, `daily_hero_card`, `treasure_card`, `speaker_button`, `flash_card` (лише `KidTap.feedback` на 188). Тобто весь навігаційний шар дитини (home → пак → картка → квест) звучить лише там, де випадково стоїть `KidTap`.

### 1.7 Композиція екранів

- `Scaffold(|AppBar(` — **38** у 21 файлі; кожен ігровий екран має власний хедер/X/прогрес.
- `app_card_shell.dart` — не shell екрана, а маленька градієнтна картка для двох hero-віджетів; радіус `16` (34) хардкод замість `DT.rLg`.
- Модалки: `showDialog|showModalBottomSheet|showGeneralDialog|SnackBar` — 19 у 8 файлах (packs_tab 6) — аудит досвіду п. 9 про чергу модалок має структурну причину: немає єдиної точки входу для оверлеїв.
- Позитив: `home_screen.dart:206–211` — `IndexedStack` + `TickerMode(enabled: _tab == i)` — офскрін-таби не тікають.

### 1.8 Пайплайн ілюстрацій і місце для UI-арту

- 248 webp у `assets/images/webp/` (базовий модуль: безкоштовні паки, превʼю ×5, обкладинки, splash) + 309 у `assets/pad_content/images/webp/` (платні, PAD fast-follow ~90 МБ — `asset_pack_service.dart:209`, `android/content_pack/build.gradle.kts:17`). `tools/compress_assets.py` ресайзить до 640 px (`image_cache_size.dart:5–11`); `tools/pad_split.py` розкладає за JSON.
- Доступ — лише `CardImage` (`card_image.dart:20–43`), стережеться `test/architecture/asset_access_test.dart` — забороняє літерали лише для `assets/images/webp/`, `assets/audio_mp3/`, `assets/pad_content/` (79–86). **UI-арт поза цими трьома теками дозволений** — місце для `assets/ui/` є, і `docs/design/bubble_pop_redesign.md` §1 уже пропонує `assets/images/scene/`.
- Зараз UI-арту майже немає: `assets/images/quest_map_bg.png`, `splash.webp`. Директорії для іконок/персонажа/сцен не існує; `pubspec.yaml:66–77` не має відповідних рядків (Flutter не бере піддиректорії рекурсивно).
- Бюджет: PAD прибрав платний контент з бази, отже базовий модуль має простір. Рекомендований ліміт для UI-арту (іконки + сцени + `.riv`) — ≤ 5 МБ; персонаж Rive ≈ 0.3 МБ, три сцени ≈ 1 МБ (за оцінкою bubble-спеки 0.33 МБ на сцену), 40 іконок webp @ 2 розміри ≈ 0.5 МБ.
- Розбіжність з CLAUDE.md («PNG @1x/2x/3x») — фактично один webp 640 px на картку; для UI-іконок теж варто один webp/вектор, а не три PNG.

### 1.9 Тестованість візуальної якості

- 35 тест-файлів; **golden-тестів — 0** (`matchesGoldenFile` не зустрічається). Немає `test/flutter_test_config.dart` (шрифт Nunito для goldens не завантажується).
- Є widget-тести на `kid_tap`, `playful_navigation_bar`, `quest_journey_map`, `card_image`, `memory_board_fit`; є **source-архітектурні тести** (`asset_access_test.dart`) — цей патерн («Dart не має internal-видимості, source-тест — чесна заміна лінту», рядки 5–10) і є інструмент, яким варто закріпити токени/рух/фідбек.

### 1.10 Перф-фундаменти під важку анімацію

- `RepaintBoundary` — 1 реальне використання (`quest_journey_map:267`) + рендер шерінгу. Статичні сцени не ізольовані.
- `imageCache.maximumSizeBytes` не налаштований (дефолт 100 МБ ≈ 45 декодів по 2.2 МБ) — сьогодні ок, але UI-сцени 3072 px (bubble-спека: 4.8 МБ на iPad) конкуруватимуть із картками.
- `IndexedStack + TickerMode` — є. `precacheImage ±2` у `cards_screen:177–190` — є. `cacheWidth` через `CardImage` — є.
- Одночасні цикли на home: hero-пульс (`daily_hero_card:114`, без гейту), streak-чип, ambient мапи (гейт є). Бюджету «≤ 2 цикли на екран» ніщо не забезпечує.
- `Opacity(` 17 у 12 файлах; `BackdropFilter` — 0 (з `swipe_hint` прибрали, коментар 141–142 — добре); `coloring_screen:643` — `saveLayer` кожен кадр painter-а — якщо туди додати Rive-Bloom, буде два дорогі шари.

## 2. Фундаменти, які треба побудувати (пріоритет і залежності)

Порядок: **F1 → F2 → F3 → (F6 ‖ F7) → F5 → F4**, F8 — наскрізно. Кожен наступний спирається на попередні; F4 (персонаж) свідомо останній, бо без F1–F3 анімований зайчик буде ще однією ізольованою анімацією.

| # | Фундамент | Зусилля | Залежить від | Що входить |
|---|---|---|---|---|
| **F1** | **Design Tokens v2** — один контракт | M | — | Розширити `DT`: `motion` (тривалості instant 80 / quick 140 / base 220 / enter 260 / slow 400 / celebrate 600; криві standard `easeOutCubic`, emphasized `easeOutBack`, playful `elasticOut`), `size` (tapMin 72, tapBack 72, icon 24/32/48, mascot 64/96/140), elevation 3 рівні, `barrier`, ролі паку `PackPalette.of(color)` (bg/border/onTint — узагальнення `BoardTheme` з memory-спеки). Влити `constants.dart` у `DT` (`kAccent → DT.brand`). `buildAppTheme()` у `lib/utils/app_theme.dart`, звідки `main.dart` бере `ThemeData`; один фон. **Не** будувати dark-палітру для дитячої зони зараз — прибрати `darkTheme` або лишити лише для батьківських екранів. Source-тест `test/architecture/design_tokens_test.dart`: `Color(0x` лише в `design_tokens.dart` + allowlist «арт-painter-ів» (bloom, `_ToyIcon`, quest map landscape); `Duration(milliseconds:` лише через `DT.motion`; заборона літерала `'Nunito'`. Мігрувати 43 файли поступово, тест спочатку з поточним списком порушників, який лише зменшується. |
| **F2** | **Motion system** | M | F1 | `lib/utils/motion.dart`: `MotionPolicy.of(context)` (full / reduced / test) — одна відповідь на `disableAnimations` і на `pumpAndSettle`. `AmbientLoop` віджет — єдиний власник `repeat()` (сам поважає `TickerMode` і політику, зупиняється через N секунд «вступного акценту» — аудит досвіду п. 12); мігрувати 16 циклів. `AppRoutes` у `lib/utils/app_routes.dart`: `kidPage()`, `overlay()`, `reveal()` — три спільні `PageRouteBuilder`, замінюють 26 місць і `_gameRoute`. `KidTap` стає обов'язковим для дитячої зони: замінити 26 власних `AnimatedScale` і оголений `GestureDetector` у `pack_grid_card`, `flash_card`, `speaker_button`, `playful_navigation_bar`, `daily_hero_card`, `treasure_card`, чипи, плитки ігор. Source-тест: `.repeat(` лише в `ambient_loop.dart`; `MaterialPageRoute|PageRouteBuilder` лише в `app_routes.dart` (+ allowlist paywall_flow/splash). |
| **F3** | **Feedback pipeline** | S–M | F1, F2 | `lib/services/feedback_service.dart` (синглтон за стилем проєкту): `KidFeedback.event(FeedbackEvent)` де `enum FeedbackEvent { tap, select, correct, wrong, lockedHint, roundDone, gameDone, packDone, milestone, reveal }` → таблиця (sfx-ім'я + pitch spread, `HapticFeedback` тип, рівень візуалу). Один `Celebration` віджет із рівнями `local / round / scene` (аудит досвіду п. 15) замість трьох оверлеїв; один `ConfettiPainter` з `DT` палітрою (видалити дубль). `KidTap.feedback()` викликає `KidFeedback.event(tap)`. Source-тест: `HapticFeedback.` і `playSfx(` лише у feedback_service/kid_tap. Контент: 8–12 реальних SFX + praise/instr (уже в планах, `tools/gen_praise_instructions.py`). |
| **F6** | **KidScreen shell** | S–M | F1–F3 | `lib/widgets/kid_screen.dart`: safe area, `DT.bgWarm`, слот хедера з 72dp back/X у фіксованій позиції, опційна прогрес-пігулка, слот «Bloom-кут» (під навчальним об'єктом — п. 18), одна точка `showKidOverlay()` з чергою (закриває п. 9 про модалки). Мігрувати ігри першими (7 екранів), потім cards/quest. Замінює 21 власний `Scaffold`/хедер. |
| **F7** | **Тести візуальної якості** | S | F1 | `test/flutter_test_config.dart` (шрифт Nunito, фіксований `MotionPolicy.test`); golden-и: `DT` swatch/типографіка, `KidTap` стани, `BloomMascot` емоції, `Celebration` рівні, `KidScreen`; source-тести з F1–F3. Golden — на CI лише для Linux-рендерера або з `tolerance`, щоб Xcode Cloud не червонів через антиаліасинг. |
| **F5** | **Icon system** | M | F1, `content` | `lib/utils/app_icons.dart`: `enum AppIcon` + `AppIconView(icon, size: DT.size.iconMd)`; джерело — `assets/ui/icons/*.webp` (експорт з фігми/ілюстратора у стилі карток) або `CustomPainter` як `_ToyIcon` для перших 6–8 керуючих (back, close, sound, replay, lock, star, play, parent). `PackModel.icon` (емодзі) перестає бути UI: усі 21 пак отримують `cover` webp (уже підтримується, `pack_model.dart:14–18`), ігри — cover-арт замість емодзі. Material Icons лишаються у батьківській зоні. `pubspec.yaml`: рядок `assets/ui/icons/`. Source-тест: `Icons.` заборонено у списку файлів дитячої зони. |
| **F4** | **Character system (Bloom)** | L | F1, F2, F3, художник | `lib/widgets/bloom/`: `BloomMascot` стає фасадом над `MascotRenderer` з двома реалізаціями — `PaintedBloom` (поточний painter, фолбек для тестів і `ArtPending`) і `RiveBloom` (`assets/ui/rive/bloom.riv`, state machine з inputs `mood` {idle, greet, listen, cheer, think, sleepy, wave}, `talking` bool, `tap` trigger). `BloomController` (ChangeNotifier) з `say(audioKey)` → `talking` синхронно з `AudioService.isSpeaking`; `CharacterService.instance.warm()` на splash (lazy, один `RiveFile` на процес). Розміри лише з `DT.size.mascot*`. Прибрати `_BouncingMascot` з onboarding; силует для сорочки карти (memory-спека) експортувати з `bloom_mascot.dart` як `BloomSilhouettePainter`, а не малювати вдруге. Пакет `rive` — єдина нова залежність цього плану. |
| **F8** | **Перф-фундаменти** | S | F2 | Явний `imageCache.maximumSizeBytes` за RAM пристрою у `app_startup`; `RepaintBoundary` довкола статичних шарів сцен (як у bubble-спеці §1); debug-лічильник активних `AmbientLoop` з `assert(≤ 2)` на екран; профіль на старому планшеті після F4. |

Оцінка сумарно: F1–F3+F7 ≈ 2 спринти; F5–F6 ≈ 1–1.5; F4 ≈ 2 (з арт-ітераціями). Найбільший важіль за мінімальні зусилля — F1+F2+F3: після них кожна екранна правка з дизайн-аудиту лягає в систему, а не поверх неї.

## 3. Чого НЕ робити (узгоджено з CLAUDE.md)

1. **Ніякого codegen** — токени, події фідбеку, стани Bloom описувати вручну (`enum`, `sealed class`), без `@riverpod`/`freezed`+build_runner для цього шару.
2. **Ніякого `go_router`** — `AppRoutes` це лише фабрики `PageRouteBuilder` поверх звичайного `Navigator`.
3. **Ніякої `features/`-структури** — нові файли лягають у `lib/utils/` (motion, app_theme, app_icons, app_routes), `lib/widgets/` (kid_screen, ambient_loop, celebration, bloom/), `lib/services/` (feedback_service, character_service).
4. **Арт карток — лише через `CardImage`**; ніяких `Image.asset`/`AssetImage` над `assets/images/webp/`, `audio_mp3/`, `pad_content/`. UI-арт живе окремо в `assets/ui/` і саме тому може використовувати `AssetImage` напряму — з `errorBuilder`.
5. **UI-арт, `.riv`, SFX — не в `pad_content`**: перша хвилина дитини не чекає на PAD.
6. **Не повертати eager precache** — ні аудіо, ні Rive: `warm()` на splash для одного файлу персонажа, решта lazy.
7. **Не додавати `flutter_animate`/`lottie`** до появи `MotionPolicy` — вони обійдуть політику reduced-motion і тестовий режим. Rive — лише через `MascotRenderer`, не як розсипані `RiveAnimation.asset` по екранах.
8. **Не будувати темну палітру для дитячої зони** — одна тема; енергію на це витрачати після F4.
9. **Не заводити нові палітри у віджетах** (прецедент `playful_navigation_bar`); арт-painter-и (Bloom, `_ToyIcon`, landscape мапи) — у явному allowlist source-тесту, і це єдине виключення.
10. **Не переписувати існуючі painter-и під токени заради токенів** — це ілюстрація, не UI.
11. **Ніяких `BackdropFilter`/`ShaderMask`** у дитячій зоні (правило 10; `swipe_hint` уже це пройшов).
12. **Ніяких нескінченних `repeat()` поза `AmbientLoop`**, ніяких нових емодзі як UI-іконок, ніяких `HapticFeedback.*` поза `FeedbackService`.
13. **Не чіпати `parental_gate`, `PurchaseService`, `AssetPackService`** у межах цього плану — вони не є причиною «4/10».

## 4. Наступні кроки

1. `architect` (цей документ) → узгодити з власником F1–F3 як один «foundation sprint».
2. `flutter-dev` — F1 (tokens v2 + source-тест з початковим списком порушників), потім F2, F3.
3. `content` — бриф художнику: 8 керуючих іконок + 21 обкладинка паків у стилі карток; бриф Rive-аніматору: Bloom із 7 станами + `talking`; реальні SFX (8–12) і praise/instr.
4. `animator` — таблиця `DT.motion` (значення/криві) і сценарії `Celebration` трьох рівнів; специфікація state machine Bloom.
5. `ux-kids` — після F6 переглянути ігрові специфікації (`docs/design/*.md`) на використання `KidScreen`/`Celebration` замість власних шарів.
6. `qa` — F7: golden-и та source-тести; перевірка reduced-motion і silent-mode через `MotionPolicy`/`FeedbackService`.
7. `perf` — F8 після появи першої Rive-сцени: профіль на планшеті 2016 року.

## 5. Що вже добре і має стати ядром систем

`DT` як ідея та `onTint`; `KidTap` (правильна тріада хаптик+звук+scale); `playSfxVaried`; `game_celebration_overlay` (єдиний гейт reduced-motion, Bloom + praise + одна велика кнопка); `_gameRoute`; `IndexedStack + TickerMode`; `CardImage` з sealed-результатом; `asset_access_test` як патерн архітектурного тесту; `_ToyIcon` як доказ, що кастомний вектор у стилі апки можливий без пакетів; коментарі-обґрунтування в коді (наприклад `card_image.dart:172–181`) — цю культуру варто перенести на нові фундаменти.
