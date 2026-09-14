# Motion-аудит — Картки-розмовлялки (2026-09-13)

Мета: підняти якість руху з самооцінки 4/10 до рівня Duolingo ABC / Khan Kids. Аудит доповнює `docs/experience-audit-2026-09-13.md` §3 (пункти 11–15) і `docs/design-audit-2026-09-08.md` (№1, 13, 30) — їхні тези тут не повторюються, лише поглиблюються до рівня файлів, мілісекунд і кривих.

Метод: прочитано всі анімаційні віджети (`lib/widgets/*`), 15 екранів, оба таби, `AudioService.playSfx/playPraise/playInstruction`, `main.dart` (тема). Підрахунки — за `rg` по `lib/`. Код не змінювався.

Умовні позначення: RM = реагує на `MediaQuery.disableAnimationsOf`; ∞ = `repeat()` без умови зупинки; «—» = відсутнє.

---

## 0. Головні висновки (TL;DR)

1. **Найбільша перемога дитини — завершений пак — беззвучна.** `cards_screen.dart:450-452` викликає `AudioService.instance.stop()`, а `CelebrationOverlay` не грає ні `tada`, ні похвали. Водночас `showGameCelebration` (ігри) грає і `tada`, і `playPraise(always: true)`. Дві найважливіші нагороди в апці звучать по-різному, і найважливіша — ніяк.
2. **Випадковий тап на святі паку виводить на головну.** `CelebrationOverlay` обгорнутий у `GestureDetector(onTap: onDone)` на весь екран; `onDone` робить `pop()` оверлею і ще один `pop()` `CardsScreen`. Дитина тапає по конфеті — і опиняється на home.
3. **Hero-переходу немає.** `Hero(` не зустрічається в `lib/` жодного разу, але `cards_screen.dart:141` чекає 400 мс «на Hero-анімацію». Перехід home→пак — системний `MaterialPageRoute` (Android: Zoom, iOS: slide), тобто різний на двох платформах і не пов'язаний з плиткою, яку натиснула дитина.
4. **`CardRevealScreen` — найдорожчий екран апки**: 7 `AnimationController`, два з них `repeat()` без зупинки (`_glowCtrl`, `_confettiCtrl`), три повноекранні `CustomPaint` (промені, вибух, конфеті) без `RepaintBoundary`, плюс `BoxShadow blurRadius: 80, spreadRadius: 30`. Це 60 fps повноекранного перемальовування на старому планшеті, доки батько не натисне кнопку.
5. **Мова руху не одна, а вісім**: 8 різних реалізацій «натискання» (0.92 / 0.93 / 0.95 / 0.96; 100 / 120 / 140 / 220 мс; 4 різні криві), 4 різні індикатори «зараз звучить», 3 різні шейки «неправильно», 3 різні конфеті-пейнтери з двома палітрами, 5 різних «свят», 6 стилів переходів між екранами.
6. **Reduced motion підтримують 4 місця з ~45.** Решта 12 циклічних анімацій (пульси, боби, шимери, полум'я) ігнорують системний прапорець.
7. **Маскот статичний.** `BloomMascot` — гарний процедурний малюнок, але `shouldRepaint` спрацьовує лише при зміні `emotion` (2 значення), очі завжди закриті дужки, рот — фіксована усмішка. Єдина анімація — 480 мс bounce на тап. Він не дихає, не моргає, не слухає, не дивиться.

---

## 1. Інвентар анімацій

### 1.1 Віджети

| # | Файл | Що рухається | Тривалість | Крива | Тригер | Loop | RM | Звук | Хаптик |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `widgets/kid_tap.dart` | scale 1→0.96 (`AnimatedScale`) | `DT.pressMs` 140 | easeOut | tapDown/Up | — | — | `pop` 0.6 на `onTap` | light на `onTap` |
| 2 | `widgets/bloom_mascot.dart` | scale 1→1.15 (elasticOut перша половина) → лінійно назад; поворот ±0.06 на другій половині | 480 | elasticOut / linear | тап на маскота | — | — | — | light |
| 3 | `widgets/confetti_burst.dart` | 20 прямокутників від точки, гравітація `50·t²`, opacity 1→0 | 1000 | linear | mount | — | — (лише через `game_celebration`) | — | — |
| 4 | `widgets/celebration_overlay.dart` | 40 частинок падають зверху, обертання `t·speed·6` | 2500 | linear | mount | — | — | **—** | — |
| 4a | те саме | картка scale 0→1 | 600 | elasticOut | mount | — | — | — | — |
| 5 | `widgets/game_celebration_overlay.dart` | діалог fade + scale 0.85→1 | 260 (0 при RM) | easeOutBack | `showGameCelebration` | — | **так** | `tada` + `playPraise(always)` | — |
| 5a | те саме | `ConfettiBurst` за карткою | 1000 | — | mount | — | так (пропускається) | — | — |
| 6 | `widgets/streak_milestone_overlay.dart` | картка scale 0→1 | 600 | elasticOut | `showDialog` | — | — | **—** | — |
| 6a | те саме | полум'я: glow alpha 0.45→0.70, blur 20→30, spread 2→4, емодзі scale 1→1.08 | 1100 | easeInOut | mount | **∞** | — | — | — |
| 7 | `widgets/flash_card.dart` `_pressCtrl` | scale 1→0.95 | 120 | easeInOut | tapDown/Up | — | — | слово (speakCard) | — (на тап); medium на flip/long-press |
| 7a | `_pulseCtrl` | слово scale 1→1.15 | 1600 | easeInOut | `isSpeaking` | поки грає | — | — | — |
| 7b | `_entranceCtrl` | картка scale 0.85→1 | 500 | elasticOut | **кожен build елемента PageView** | — | — | — | — |
| 7c | `_flipCtrl` | rotateY 0→π, перспектива 0.001 | 400 | easeInOut | чип 🇬🇧 / тап на звороті | — | — | — | medium |
| 8 | `widgets/speaker_button.dart` | scale 1→1.2 | 500 | easeInOut | `isSpeaking && autoSpeak` | поки грає | — | — | — |
| 9 | `widgets/pack_grid_card.dart` | press scale (`DT`) | 140 | easeOut | tapDown/Up | — | — | `pop` через `KidTap.feedback()` | light |
| 9a | `_wobble` | rotate 0→−0.06→0.06→−0.04→0.03→0 (`TweenSequence`) | 600 | linear по сегментах | long-press | — | — | — | medium |
| 9b | `_shimmer` (seasonal) | glow alpha 0.25→0.60, blur 14→24, spread 0→2 | 1400 ×2 forward/reverse, кожні 30 с | linear | таймер | бурстами | — | — | — |
| 10 | `widgets/daily_hero_card.dart` hero | press scale (`DT`) | 140 | easeOut | tapDown/Up | — | — | **—** | light |
| 10a | `_pulse` | вся картка scale 1→1.02 | 1600 | easeInOut | mount, доки `!heroDone` | **∞** | — | — | — |
| 10b | `_TaskButton` press | scale (`DT`) | 140 | easeOut | tapDown/Up | — | — | **—** | light |
| 10c | `_TaskButton` active | scale 1→1.04 | 1200 | easeInOut | `isActive && !isDone` | **∞** | — | — | — |
| 10d | `_AllDoneRow` | нічого не рухається | — | — | tap | — | — | — | light |
| 11 | `widgets/treasure_card.dart` | press scale (`DT`) | 140 | easeOut | tapDown/Up | — | — | **—** | **—** |
| 11a | `_bob` | 🎁 translateY 0→−3 | 1400 | easeInOut | mount | **∞** | — | — | — |
| 12 | `widgets/quest_journey_map.dart` `_ambient` | активна зупинка translateY `−3·sin(πt)` | 3000 | sin | mount | ∞, **стоп при RM** | **так** | — | — |
| 12a | `_JourneyStop` press | scale 1→0.92 | 120 (0 при RM) | default (linear) | tapDown/Up | — | так | **—** | light |
| 12b | прогрес-смужки | колір | 350 (`AnimatedContainer`) | linear | зміна стану | — | — | — | — |
| 13 | `widgets/playful_navigation_bar.dart` `_TabButton` | контейнер колір/рамка/тінь; scale 0.93 на `InkWell.onHighlightChanged`; іконка slide −0.035 + scale 0.94→1.06 | 220 (0 при RM) | easeOutCubic | selected / highlight | — | **так** | `pop` (у `home_screen.onSelected`) | light (там само) |
| 14 | `widgets/swipe_hint.dart` | вхід scale 0.8→1 + opacity | 600 | easeOutBack | mount (один раз за життя профілю) | — | **так** (стоп-кадр 0.35) | — | — |
| 14a | `_loopCtrl` | рука 24→−24 px з паузами; 3 шеврони stagger 0.15 | 2000 | easeInOutCubic + власні envelope | mount | ∞ до dismiss | так | — | — |
| 14b | `_dismissCtrl` | opacity 1→0 | 300 | easeIn | перший свайп | — | — | — | — |
| 15 | `widgets/bubble_pop.dart` (`showBubblePop`) | бульбашка від тапу вгору за екран; дрейф sin; pop у останні 18% | 1200 + travel·4.5 (≈1.9–6.6 с) | easeOutCubic | тап по порожньому місцю | — | — | — | — |
| 16 | `widgets/quiz_option.dart` `_pressCtrl` | scale 1→0.92 | 100 | easeInOut | tapDown/Up | — | — | **—** | **—** |
| 16a | `_shakeCtrl` | translateX ±10·(1−t), меандр 8 півперіодів | 500 | «квадратна хвиля» | `isCorrectAnswer == false` | — | — | — | — |
| 16b | `AnimatedContainer` | колір/рамка/тінь правильно-неправильно | 250 | linear | стан | — | — | — | — |
| 17 | `widgets/streak_chip.dart` | glow 0.25→0.60, 🔥 scale 1→1.08 | 1400 ×2, кожні 30 с | easeInOut | таймер | бурстами | — | — | light на тап |
| 18 | `utils/shake_animation_mixin.dart` | translateX 0→−14→14→−14→14→0 | 380 | linear по сегментах | `shake(id)` | — | — | — | — (у викликачів medium) |
| 19 | `utils/confetti_overlay_mixin.dart` | вставляє `ConfettiBurst` в Overlay, знімає через `linger` | 1500 (за замовч.) | — | `showConfetti()` | — | — | — | — |

### 1.2 Екрани

| # | Файл | Що рухається | Тривалість | Крива | Тригер | Loop | RM | Звук | Хаптик |
|---|---|---|---|---|---|---|---|---|---|
| 20 | `screens/splash_screen.dart` | лого fade + scale 0.85→1 | 600 | easeIn / easeOutBack | precache готовий | — | — | — | — |
| 20a | перехід на Home/Onboarding | `PageRouteBuilder` fade | 400 | linear | init done | — | — | — | — |
| 21 | `screens/onboarding_screen.dart` `PageView` | зміна сторінки | 350 | easeInOut | «Далі» | — | — | — | selectionClick (аватар/вік) |
| 21a | точки прогресу | `AnimatedOpacity` 200 + `AnimatedContainer` ширина 8↔24 | 200 / 300 | linear | зміна сторінки | — | — | — | — |
| 21b | `_BouncingMascot` | translateY 0→−8 | 800 | easeInOut | mount; **зупинка через 2 с** (`animateTo(0)` 400 easeOut) | 2 с | — | — | — |
| 21c | `_MagicCard` `_breath` | scale 1→1.04 | 1600 | easeInOut | mount | **∞** | — | — | — |
| 21d | `_MagicCard` press | `DT.pressScale` поверх breath | 140 | easeOut | tapDown/Up | — | — | слово | medium (у `_onCardTap`) |
| 21e | `_MagicCard` слово | scale 1→1.08 | 220 | easeOut | `isSpeaking` | — | — | — | — |
| 21f | `AnimatedSwitcher` між картками | fade + scale 0.85→1 | 350 | easeOutBack in / easeIn out | зміна індексу | — | — | — | — |
| 21g | завершення | `showConfetti(linger 1800)` + `playPraise(always)` + затримка 1600 → `onComplete` | 1800 | — | 3-й тап | — | — | праise | — |
| 21h | перехід на Home | `PageRouteBuilder` fade | 400 | linear | `_finish` | — | — | — | — |
| 22 | `screens/card_reveal_screen.dart` `_envelopeCtrl` | конверт scale 0→1 (elasticOut, clamp 1.2) + shake `sin(6πt)·3·(1−t)` | 800 | elasticOut | mount | — | лише `skipAnimation` (не RM) | — | medium наприкінці |
| 22a | пауза | `Future.delayed` | 400 | — | — | — | — | — | — |
| 22b | `_openCtrl` | картка scale 0.3→1, rotate 0.3→0, translateY 100→0 | 600 | easeOutBack | фаза 2 | — | — | — | heavy |
| 22c | `_burstCtrl` | 50 кружків від центру, startDelay 0–0.25 | 1500 | easeOut | фаза 2 | — | — | — | — |
| 22d | `_bgCtrl` | radial-градієнт radius 0.6→1.2, alpha 0.5→1 | 1000 | easeOut | фаза 2 | — | — | — | — |
| 22e | `_settleCtrl` | картка scale 0.95→1 | 700 | elasticOut | фаза 3 (+500 мс) | — | — | `playWordOnly` | light |
| 22f | `_glowCtrl` | промені (`_RaysPainter`) + glow за карткою alpha 0.4→0.7, blur 80, spread 30 | 1600 | linear | фаза 3 | **∞** | — | — | — |
| 22g | `_confettiCtrl` | 45 конфеті, `Random(42)` перераховується кожен кадр | 5000 | linear | фаза 3 | **∞** | — | — | — |
| 22h | кнопки | `AnimatedOpacity` 0→1 | 400 | linear | фаза 3 + 600 мс | — | — | — | — |
| 23 | `screens/cards_screen.dart` `PageView` | rotateY `value·0.04`, scale 1→0.9, **`Opacity` 1→0.5** на кожну сторінку кожен кадр скролу | під час скролу | linear | свайп | — | — | слово через 500 мс дебаунс | light на `onPageChanged` |
| 23a | автоплей | `nextPage` | 400 | easeInOut | таймер | — | — | — | — |
| 23b | `CelebrationOverlay` | `PageRouteBuilder(opaque: false)` **без `transitionsBuilder`** → з'являється миттєво | 0 | — | останній звук + 1 с | — | — | **тиша** (`stop()` перед показом) | — |
| 23c | прогрес-бар паку | `LinearProgressIndicator` без анімації значення | — | — | — | — | — | — | — |
| 24 | `screens/guess_screen.dart` `_speakerPulse` | спікер 88 dp scale 1→1.15 | 800 | easeInOut | `isSpeaking` | поки грає | — | — | — |
| 24a | правильно | `ding` + `playPraise` (кожен 2-й) + `ConfettiBurst` центр екрана; наступний раунд через 800, слово через +300 | 800 + 300 | — | тап | — | — | ding, praise | medium |
| 24b | неправильно | `QuizOption` shake; повтор слова через 600 | 600 | — | тап | — | — | слово | light |
| 25 | `screens/repeat_game_screen.dart` `_exitCtrl` | картка translateY 0→−40 + **`Opacity`** 1→0 | 320 | easeIn | `_advance` | — | — | — | — |
| 25a | правильно | конфеті + затримка **1400** → exit | 1400 | — | кнопка | — | — | **—** (без `ding`) | light |
| 25b | неправильно | shake mixin 380 → exit | 380 | — | кнопка | — | — | — | medium |
| 26 | `screens/memory_match_screen.dart` `_TileWidget._ctrl` | flip rotateY 0→π | 380 | easeInOut | стан `isFlipped` | — | — | слово на тап | light на тап |
| 26a | `_bounceCtrl` | scale 1→1.18→1 | 320 | easeInOut | `isMatched` | — | — | `ding` + praise | medium |
| 26b | точки пар | ширина 10↔22 | 300 | easeOutBack | стан | — | — | — | — |
| 26c | неспівпадіння | **нічого**; flip назад через 900 | 900 | — | — | — | — | — | medium |
| 26d | фінал | конфеті linger 2000; `showGameCelebration` через 1200 | 1200 | — | останній матч | — | так (через 5) | tada+praise | heavy |
| 27 | `screens/bubble_pop_screen.dart` `Ticker` | фізика живих бульбашок, `ValueNotifier<int> _frame` (без setState) | безперервно | — | раунд | ∞ під час раунду | — | — | — |
| 27a | `_PoppingBubble` | скло scale 1→1.4 + fade (0–20%), 8 крапель 50 px, картинка 0.7→1.4 elasticOut → hover −10 → scale 0 + fade | `_kPopMs` | elasticOut / easeIn | тап | — | — | `pop` + слово | medium |
| 27b | `_PraiseFlash` | текст scale easeOutBack (0–30%), hold, translateY −30 + fade (70–100%) | 900 | easeOutBack | кожен 5-й pop | — | — | — | — |
| 27c | власний `_CelebrationOverlay` | (окрема реалізація, не `showGameCelebration`) | — | — | 20-й pop | — | — | конфеті | — |
| 28 | `screens/odd_one_out_screen.dart` | `AnimatedSwitcher` підказки 300; `_CardChip` `AnimatedContainer` 200 | 300 / 200 | linear | раунд / стан | — | — | слово; `ding`+praise | light / medium |
| 28a | правильно | конфеті; наступний раунд через 900 | 900 | — | тап | — | — | — | — |
| 29 | `screens/opposite_game_screen.dart` | `AnimatedSwitcher` питання 300; `_OptionTile` `AnimatedContainer` 200; **без press** | 300 / 200 | linear | раунд / стан | — | — | слово через 400; `ding`+praise; протилежне слово через 350; раунд через 1000 | light / medium |
| 30 | `screens/coloring_screen.dart` `_revealCtrl` | оверлей контуру 1→0 | 550 | easeOutCubic | 85 % відкрито | — | — | слово | medium |
| 30a | нижній бар | `AnimatedSwitcher` slide 0.4→0 + fade | 250 | easeOutBack | `_done` | — | — | `pop` на «нова картинка» | light |
| 31 | `screens/quest_map_screen.dart` `_PackPickerSheet` | плитки stagger 0.1·i, scale elasticOut (clamp 1.1); вибрана scale 1.2 (200) | 500 | elasticOut | відкриття шита | — | — | — | selectionClick |
| 31a | перехід на `CardRevealScreen` | `PageRouteBuilder` fade | 400 | linear | вибір паку + 300 | — | — | — | — |
| 32 | `screens/home_screen.dart` | `IndexedStack` + `TickerMode` — **перемикання табів без анімації** | 0 | — | таб | — | — | `pop` | light |
| 33 | `screens/paywall_screen.dart` | X `AnimatedOpacity` через 3 с (400); план `AnimatedContainer` 200 | 400 / 200 | linear | таймер / вибір | — | — | — | — |
| 33a | вхід | `MaterialPageRoute` (системний) | платформа | платформа | `runPaywallFlow` | — | — | — | — |
| 34 | `screens/rewards_screen.dart` | **жодної анімації** | — | — | — | — | — | — | — |
| 35 | `tabs/games_tab.dart` `_gameRoute` | fade (easeOut) + scale 0.93→1 (easeOutCubic) | 260 / reverse 200 | — | тап плитки гри | — | — | `pop` (`KidTap.feedback`) | light |
| 35a | `_BigGameTile` | scale 0.96 (140, **хардкод**, не `DT`) + `AnimatedOpacity` 0.85 для locked | 140 / 150 | easeOut | tapDown/Up | — | — | — | — |
| 36 | `tabs/packs_tab.dart` `_CategoryChip` | `KidTap` + `AnimatedContainer` колір | 140 | linear | тап | — | — | pop | light |
| 36a | `_TodayPlanIntroHint` | `AnimatedOpacity` 1→0 | 250 | linear | перший тап | — | — | — | — |

### 1.3 Переходи між екранами (маршрути)

| Стиль | Де | Тривалість |
|---|---|---|
| `MaterialPageRoute` (Android: Zoom M3, iOS: Cupertino slide) | `packs_tab.dart` ×6 (пак → `CardsScreen`, Parent dashboard, Word wall, cards-of-day), `quest_map_screen.dart` ×4, `paywall_flow.dart`, `home_screen.dart`, `cards_screen.dart:491` (replay), `stats_screen`, `articulation_screen` | ~300 системні |
| `PageRouteBuilder` fade | splash→home, onboarding→home, quest→card_reveal | 400 |
| `PageRouteBuilder` fade+scale | `_gameRoute` (усі ігри) | 260 / 200 |
| `PageRouteBuilder(opaque:false)` без transitionsBuilder | `CelebrationOverlay` (пак завершено) | 0 (миттєво) |
| `showGeneralDialog` fade+scale easeOutBack | `showGameCelebration` | 260 |
| `showDialog` (системний fade 150) | streak milestone, parental gate, notification opt-in | 150 |
| `showModalBottomSheet` | card-of-day меню, pack picker, батьківські контролі, профілі, what's new | системні |

`main.dart` не задає `pageTransitionsTheme`, тож 13 викликів `MaterialPageRoute` виглядають по-різному на Android і iOS.

---

## 2. Неузгодженості мови руху (з підрахунками)

### 2.1 Натискання — 8 реалізацій

| Реалізація | Scale | Мс | Крива | Звук | Хаптик | Де |
|---|---|---|---|---|---|---|
| `KidTap` | 0.96 | 140 | easeOut | pop 0.6 (на up) | light | `_CategoryChip`, (через `feedback()`) плитки паків, ігор, таби |
| Власний `GestureDetector` + `AnimatedScale(DT)` | 0.96 | 140 | easeOut | залежить | light / — | `PackGridCard`, `DailyHeroCard`, `_TaskButton`, `TreasureCard`, `_MagicCard` |
| `_BigGameTile` | 0.96 | 140 (хардкод) | easeOut | pop | light | `games_tab` |
| `FlashCard._pressCtrl` | 0.95 | 120 | easeInOut | слово | — | картка |
| `QuizOption._pressCtrl` | 0.92 | 100 | easeInOut | — | — | вікторина |
| `_JourneyStop` | 0.92 | 120 | linear | — | light | мапа квесту |
| `PlayfulNavigationBar._TabButton` | 0.93 | 220 | easeOutCubic (через `InkWell` highlight + splash) | pop | light | таб-бар |
| Без press | — | — | — | — | — | `_TileWidget` (memory), `_OptionTile` (opposite), `_CardChip` (odd one out), `SpeakerButton`, спікер у `GuessScreen`, `_AllDoneRow`, `BloomMascot` (лише bounce після up), усі `ElevatedButton`/`TextButton` у святах |

Підсумок: 4 значення scale, 4 тривалості, 4 криві, 8 з ~22 дитячих таргетів без жодного звуку на тап, 6 без хаптика. `DT.pressScale/pressMs` існують, але використовуються у 6 з 14 місць.

### 2.2 Зоопарк кривих і тривалостей

- **Криві: 7 різних, 62 використання.** `easeInOut` 18, `easeOut` 13, `easeOutBack` 9, `elasticOut` 8, `easeOutCubic` 7, `easeIn` 6, `easeInOutCubic` 1. `elasticOut` (8) використано для входу картки свята (600), картки `FlashCard` (500 — на кожен білд елемента PageView), маскота, `_settleCtrl`, `_envelopeCtrl`, плиток pack picker, бульбашки — це найдорожча для сприйняття крива (два овершути), яку гайдлайн радить «sparingly».
- **Тривалості: ~110 літералів `Duration(...)`, ~30 різних значень.** Натискання: 100/120/140/220. Вхід: 260/300/350/380/400/500/600. Пульси: 500/800/1100/1200/1400/1600/2000/3000. Затримки хореографії (`Future.delayed`): 300/350/400/500/600/700/800/900/1000/1100/1200/1300/1400/1600/1800. З токенів `DT` є лише `pressMs` (140) і `enterMs` (260); `enterMs` не використовується ніде за межами `design_tokens.dart`.
- **Затримки, не пов'язані з аудіо.** У 25+ місцях `Future.delayed` з магічним числом визначає, коли почнеться наступне слово/раунд. Приклади: `guess_screen` — раунд через 800, слово через +300 (разом 1100), тоді як `playPraise` (~1–1.5 с) грає паралельно; `opposite_game` — протилежне слово через 350 після `ding`+praise, раунд через 1000; `repeat_game` — 1400 «на конфеті» без звуку. Жоден з них не `await`-ить `Future` з `speakCard/playWordOnly`, хоча ці методи повертають `Future<void>` і вже використовуються з `await` у `onboarding_screen.dart:692`.

### 2.3 Індикатор «зараз звучить» — 4 мови

| Де | Що | Амплітуда | Період |
|---|---|---|---|
| `FlashCard` | слово | 1→1.15 | 1600 |
| `SpeakerButton` | кнопка | 1→1.20 | 500 |
| `GuessScreen` | спікер 88 dp | 1→1.15 | 800 |
| `_MagicCard` | слово | 1→1.08 (одноразово) | 220 |

Дитина 1–2 років вчиться зчитувати «зараз апка говорить» — це має бути один жест.

### 2.4 «Неправильно» — 3 шейки, 2 палітри

- `QuizOption._shakeCtrl`: ±10 px, квадратна хвиля (`(t·8).toInt().isEven`), 500 мс, колір `#FF6B6B`.
- `ShakeAnimationMixin`: ±14 px, `TweenSequence`, 380 мс, колір `#E53935` (odd one out, opposite, repeat).
- `MemoryMatch`: без руху, просто перевертається через 900 мс.

### 2.5 Свято — 5 реалізацій, 3 конфеті

| Реалізація | Звук | Конфеті | Маскот | Кнопки тапабельні з | Ризик |
|---|---|---|---|---|---|
| `CelebrationOverlay` (пак) | **—** | 40 падають, 2.5 с, палітра A | — | 0 мс, tap-anywhere = вихід | подвійний `pop` на home |
| `showGameCelebration` (4 ігри) | tada + praise | `ConfettiBurst` 20, палітра A | Bloom waving (статичний) | 0 мс | — |
| `bubble_pop._CelebrationOverlay` | конфеті через mixin | `ConfettiBurst` | ? | 0 мс | дубль коду |
| `streak_milestone_overlay` | **—** | — | Bloom 64 waving | 0 мс | ∞ полум'я |
| `CardRevealScreen` | слово | 50 burst + 45 rain ∞, палітра B | — | ~2300 мс | 7 контролерів, 2 ∞ |

Конфеті-пейнтери: `confetti_burst._BurstPainter`, `celebration_overlay._ConfettiPainter`, `card_reveal._BurstPainter` + `_ConfettiPainter`. Кожен створює `Paint()` на частинку на кадр (20–45 алокацій × 60 fps).

### 2.6 Reduced motion — 4 з ~45

Перевіряють `disableAnimationsOf`: `swipe_hint`, `quest_journey_map`, `playful_navigation_bar`, `game_celebration_overlay`. Ігнорують (у т. ч. ∞): `daily_hero_card` ×2, `treasure_card`, `streak_chip`, `pack_grid_card` shimmer, `flash_card` ×4, `speaker_button`, `guess_screen` спікер, `streak_milestone` полум'я, `card_reveal` ×7, `onboarding` breath + mascot, `celebration_overlay`, `confetti_burst` (коли не через game_celebration), `bubble_pop`, усі маршрути.

### 2.7 `Opacity` замість `FadeTransition` в анімованих піддеревах — 12

`cards_screen.dart:827` (на кожну сторінку `PageView` кожен кадр скролу — 3 `saveLayer` на кадр), `repeat_game_screen.dart:237`, `swipe_hint.dart` ×3, `bubble_pop.dart:111`, `bubble_pop_screen.dart` ×4, `daily_hero_card.dart:414` (статичний — ок), `quest_map_screen.dart:440`.

### 2.8 `RepaintBoundary` — 1 на всю апку

Лише `quest_journey_map.dart:267` (ландшафт). Жоден конфеті-пейнтер, жоден маскот, жоден пульсуючий hero не ізольований, тож `DailyHeroCard._pulse` (∞, 1.02) перемальовує весь home-скрол разом із гридом паків.

---

## 3. Маскот Bloom / Зайчик

### 3.1 Як намальований і анімований сьогодні

`lib/widgets/bloom_mascot.dart`: `CustomPainter` у просторі 120×120, `canvas.scale` до `size`. Порядок шарів: тінь → вуха (rotate ±0.22) → тіло (RRect 64×50) → голова (овал 70×64) → щоки → очі → ніс → рот → лапи. Палітра захардкоджена в пейнтері. `enum BloomEmotion { happy, waving }` — різниця лише в положенні правої лапи. Очі — дві дуги `quadraticBezierTo` (заплющені ^_^), рот — одна дуга. `shouldRepaint` = `emotion != old.emotion` → між тапами це статична картинка.

Анімація: один `_react` контролер 480 мс: перша половина scale `1 + elasticOut(2t)·0.15`, друга — лінійно назад + rotate `0.06·(1−...)`. Хаптик light. Нема idle, моргання, погляду, реакції на аудіо. Ззовні його рухають: `_BouncingMascot` (онбординг, translateY −8, 2 с), і статично ставлять у `showGameCelebration` (96 dp) та `streak_milestone` (64 dp).

Що добре: нуль ваги в assets; чіткий на будь-якому DPR; всі координати — константи, тобто його легко «розібрати» на параметри.

### 3.2 Що потрібно «живому персонажу» (орієнтир Duo / Kodi)

| Стан | Що рухається | Таймінг | Тригер |
|---|---|---|---|
| **Idle breathing** | тіло scaleY 1→1.025 (anchor знизу), голова translateY −1, вуха rotate ±2° у протифазі | 3200 мс sin, ∞ (стоп при RM / `TickerMode` / фон) | mount |
| **Blink** | очі: висота дуги → 0 → назад | 120 мс закрити, 80 мс відкрити; інтервал random 2.5–6 с; 10 % — подвійне моргання | таймер |
| **Look-at-tap** | зіниці (потрібні відкриті очі: додати білок + зіницю 3 px) зсув до 2.5 px у напрямку тапу; голова rotate до 3° | 180 мс easeOut → тримати 1.5 с → повернення 400 мс | глобальний тап (через `Listener` у корені екрана або переданий `Offset`) |
| **Listen / Speaking** | рот open 0→0.6 з шумом 6–9 Гц (без амплітуди аудіо — `isSpeaking` bool достатньо), вуха вгору 4°, очі трохи ширші | тривалість = `isSpeaking == true` | `AudioService.isSpeaking` |
| **Happy bounce** | існуючий 480 мс + вуха «підстрибують» на 60 мс пізніше | 480 | тап на маскота, правильна відповідь |
| **Celebrate** | стрибок translateY −18 (easeOutBack 260) → приземлення 200; обидві лапи вгору; очі ^_^; 2 стрибки | 700 | свято T1–T4 |
| **Sleepy** | очі напівзакриті, голова rotate −6°, повільне дихання 4500 мс, «z» бабл | після 20 с без вводу на home | таймер, скидається тапом |
| **Hint point** | права лапа витягується до цілі (rotate до −1.1), 2 боби головою | 900, повтор через 4 с ×3 | «підказка» гри або перший запуск екрана |
| **Sad-soft** (для «неправильно») | НЕ використовувати вираз смутку; лише нахил голови 4° + вуха вниз 200 мс → назад | 400 | помилка |

### 3.3 Rive vs Lottie vs pure Flutter для цього коду

| Критерій | Pure Flutter (риг з параметрів поверх існуючого пейнтера) | Rive | Lottie |
|---|---|---|---|
| Залежності (сьогодні: нуль) | 0 | `rive` + `rive_common` (C++ рантайм, +1.5–3 МБ до download size) | `lottie` (+~0.5 МБ, чистий Dart) |
| Asset | 0 КБ | `.riv` 50–250 КБ, у базовому APK (не в Play asset pack — маскот потрібен до завантаження контенту) | JSON 100–600 КБ на анімацію, без стейт-машини |
| Стейт-машина / вводи (`isSpeaking`, `lookX`) | ручна, повний контроль | нативна (inputs, blend states, listeners) | немає; лише сегменти таймлайну |
| Ітерації дизайнера | тільки через код | редактор, без релізу коду | After Effects |
| 60 fps на старому планшеті | ~25 draw calls, тривіально з `RepaintBoundary` | добре для одного персонажа; уникати растрових мешів і blur | залежить від кількості шарів; маски/градієнти дорогі |
| Офлайн | так | так | так |
| Ризик | повільний авторинг складних поз | новий нативний рантайм у дитячій апці, треба QA на Android API 26–28 | немає інтерактивності — не вирішує задачу |

**Рекомендація.** Lottie — ні (немає стейт-машини, найважче слухає вводи). Rive — так, але як **фаза 2**, коли з'явиться професійна ілюстрація (design-audit №18 уже планує «swap for illustrated version»). **Фаза 1 — pure Flutter зараз**, бо малюнок уже векторний і параметризується за день, а найбільший приріст дає не якість ліній, а наявність станів (дихання, моргання, «слухаю»).

**Фаза 1 (S–M, pure Flutter).**
- `lib/widgets/bloom/bloom_rig.dart`: `class BloomPose { double breath, blink, mouthOpen, lookX, lookY, headTilt, earL, earR, pawL, pawR, jump; }` — immutable, `==`.
- `class BloomController extends ChangeNotifier` з одним `Ticker`; `state` ∈ {idle, listening, happy, celebrate, sleepy, hint}; кожного кадру обчислює `BloomPose` з формул (sin для дихання, таймери для моргання, `SpringSimulation` для стрибка); `notifyListeners` лише коли поза змінилась > 1e-3.
- `_BloomPainter(pose)` — той самий малюнок, координати стають функціями `pose`; `shouldRepaint = pose != old.pose`.
- `BloomMascot` зберігає поточний публічний API (`size`, `emotion`, `interactive`) + додає `controller?` і `lookAt(Offset)`; існуючі виклики не ламаються.
- `RepaintBoundary` навколо `CustomPaint`; `TickerMode`/`AppLifecycleListener` зупиняють тікер; RM → лише blink і статичні пози (моргання не є «рухом» у сенсі vestibular).
- Бюджет: 0 КБ assets, ≤1 тікер на екран, ≤0.4 мс paint на кадр (виміряти в profile на Android API 28).

**Фаза 2 (M, Rive).**
- `.riv` ≤ 250 КБ у `assets/rive/bloom.riv`, стейт-машина `Bloom` з вводами: `isSpeaking: bool`, `tap: trigger`, `celebrate: trigger`, `mood: number (0 idle / 1 sleepy / 2 hint)`, `lookX/lookY: number −1..1`.
- `BloomMascot` внутрішньо обирає `RiveBloom` або `PainterBloom`; той самий `BloomController` мапить стан у вводи — жоден екран не змінюється.
- Тест архітектури (за зразком `test/architecture/asset_access_test.dart`): `RiveAnimation` імпортується лише в `lib/widgets/bloom/`.
- Fallback: якщо `.riv` не завантажився (виключено при bundling, але дешево) — пейнтер фази 1.

---

## 4. Рівні свята — хореографія

Загальні правила для всіх рівнів:
- Одна точка входу `celebrate(context, tier: CelebrationTier.x, ...)` у `lib/widgets/celebration/celebration.dart`; хореографія — іменовані `Interval` в одному master-контролері, а не `Future.delayed`.
- Звук ніколи не чекає анімації: sfx на 0 мс, голос — коли попереднє слово закінчилось (`await` `Future` з `playWordOnly`, cap 1200 мс), не за таймером.
- Кнопки: `IgnorePointer(ignoring: t < 600 мс)` + opacity 0.6→1 (`FadeTransition`) до 600 мс. Ніколи не блокувати системний back і не автозакривати — дитина має завжди мати вихід, а батько — час прочитати.
- Маскот: один `BloomController` на свято; `celebrate` → `idle` через 2.5 с.
- RM: усі візуальні `Interval` стискаються до 0–150 мс fade; конфеті вимкнено; звуки і 600 мс гейт кнопок лишаються (гейт — не motion, а захист від випадкових тапів).

### T0 — Micro success (правильний тап у грі)

| мс | Візуал | Звук | Хаптик |
|---|---|---|---|
| 0 | плитка scale 1→1.10 (easeOutBack 240) → 1; рамка кольору успіху (одна для всіх ігор: `DT.success`) | `ding` через `playSfxVaried(spread 0.08)` | medium |
| 0–420 | міні-вибух 10–12 частинок **з центру плитки**, не екрана; радіус ≤ 90 px | | |
| 120 | Bloom (48–64 dp у куті екрана гри, якщо є) → `happy` 480 | | |
| 200 | голос-похвала кожен 2-й раз (існуючий лічильник) | `playPraise` | |
| next | наступне слово стартує на `max(кінець похвали, 900)`; інші опції заблоковані до next, але спікер/повтор — тапабельний | `playWordOnly` | |

RM: без частинок і scale; лишаються колір, галочка, звуки.

Замінює: `guess_screen` (800+300), `odd_one_out` (900), `opposite` (350/1000), `memory_match` `_onMatch` (700 linger), `repeat_game` `_onCorrect` (1400 без звуку → додати `ding`).

### T1 — Round complete (кінець гри)

| мс | Візуал | Звук | Хаптик |
|---|---|---|---|
| −до 1200 | дочекатися кінця поточного слова (`await`, cap), гра лишається видимою | | |
| 0 | бар'єр 0→`0x66` (fade 200); картка scale 0.85→1 + fade (260, easeOutBack) — існуючий `showGameCelebration` | `tada` | medium |
| 0–1000 | `ConfettiBurst` 24 частинки з верхньої третини | | |
| 120 | Bloom `celebrate` (стрибок ×2, 700) | | |
| 400 | похвала | `playPraise(always: true)` | |
| 600 | «Ще раз» і «Готово» стають тапабельними (opacity 0.6→1, 200) | | |
| 2500 | Bloom → `idle` (дихання + моргання) | | |

RM: бар'єр і картка fade 120; без конфеті і стрибка; Bloom у позі `celebrate` статично.

Замінює: `bubble_pop_screen._CelebrationOverlay` (→ `showGameCelebration`), і `memory_match` затримку 1200 перед святом (→ `await`).

### T2 — Daily quest complete (`CardRevealScreen`)

Один master `AnimationController` 3200 мс з `Interval`-ами замість 7 контролерів; `skipAnimation` і RM → `value = 1`.

| мс | Візуал | Звук | Хаптик |
|---|---|---|---|
| 0–800 | конверт scale 0→1 (easeOutBack, не elasticOut) + shake `sin(6πt)·3·(1−t)` | тихий «шурхіт» (`pop` pitch 0.7, vol 0.4) | medium на 800 |
| 800–1150 | пауза (конверт «дихає» 1.02) | | |
| 1150–1750 | конверт розкривається: scale 1→0 + fade; картка translateY 100→0, rotate 0.3→0, scale 0.3→1 (easeOutBack) | `tada` на 1150 | heavy на 1150 |
| 1150–2400 | вибух 40 кружків (одноразово) + фон radial 0.6→1.2 | | |
| 1750 | слово | `playWordOnly` | light |
| 1750–2350 | settle scale 0.96→1 (easeOutBack 600) | | |
| 1750–4250 | конфеті-дощ **одна хвиля 2500 мс** і стоп; промені: 3 пульси (4800 мс) і стоп | | |
| 1900 | Bloom з'являється знизу-ліворуч (slide 300) → `celebrate` | | |
| 2350 | кнопки тапабельні (fade 0.6→1) | | |
| 2350+ | Bloom `idle`; glow за карткою — статичний (blur 40, не 80) | | |

RM: усе в кінцевому стані на 0 мс; слово на 300; кнопки на 600.

### T3 — Streak milestone (батьківський)

| мс | Візуал | Звук | Хаптик |
|---|---|---|---|
| 0 | діалог fade + scale 0.9→1 (260 easeOutCubic) замість elasticOut 600 | м'який дзвіночок (`ding` pitch 0.85) — сьогодні **тиша** | light |
| 0–3300 | полум'я: **3 пульси** (1100 ×3) і стоп у стані «тепле» | | |
| 300 | Bloom `happy` (один bounce), далі `idle` | | |
| 600 | «Так тримати!» тапабельна | | |

Без конфеті — це не дитяча нагорода, а батьківська довідка. RM: без пульсів.

### T4 — Pack complete / unlocked (`CelebrationOverlay`)

| мс | Візуал | Звук | Хаптик |
|---|---|---|---|
| −до 1000 | існуючий grace (verse 6 с / word 4 с) лишається; **прибрати** `AudioService.stop()` перед показом, якщо звук уже завершився | | |
| 0 | маршрут `KidRoutes.overlay` (fade 200, `opaque:false`) замість миттєвої появи; картка scale 0.85→1 (420 easeOutBack) | `tada` | medium |
| 0–2500 | 32 падаючі конфеті, одна хвиля | | |
| 150 | обкладинка паку scale 0.8→1 (300) | | |
| 300 | Bloom `celebrate` поруч з обкладинкою | | |
| 400 | похвала | `playPraise(always: true)` | |
| 600 | «Грати знову» / «Поділитись» / «На головну» тапабельні | | |
| 1500 | **tap-anywhere** дозволяється лише після 1500 і закриває ЛИШЕ оверлей (не `CardsScreen`) — або прибрати повністю | | |

Для розблокованого паку (після покупки або квесту) — той самий T4 з підзаголовком «Новий пак!» і `KidRoutes.content` з Hero обкладинки в `CardsScreen` після «Грати».

---

## 5. Переходи — специфікація

Створити `lib/utils/kid_routes.dart` (плоска структура, без go_router) і глобально задати `pageTransitionsTheme` у `main.dart`, щоб 13 існуючих `MaterialPageRoute` виглядали однаково на Android і iOS до міграції:

```dart
// main.dart → ThemeData(...)
pageTransitionsTheme: const PageTransitionsTheme(builders: {
  TargetPlatform.android: _KidFadeScaleTransitionsBuilder(),
  TargetPlatform.iOS: _KidFadeScaleTransitionsBuilder(),
}),
```

| Перехід | Примітив | Тривалість / крива | Деталі |
|---|---|---|---|
| **home → пак** (`KidRoutes.content(page, heroTag)`) | `PageRouteBuilder` fade + scale 0.96→1 + `Hero(tag: 'pack-cover-${pack.id}')` на `CardImage` плитки → ілюстрація в хедері `CardsScreen` (або перша картка) | 280 easeOutCubic / reverse 220 easeIn | `flightShuttleBuilder` віддає `CardImage` з `CardArtSize.tile` (уже декодований), на посадці — cross-fade на hero-розмір; `createRectTween: MaterialRectArcTween`. Перше слово на 400 мс (існуюче) — збігається з кінцем польоту + 120 мс. Hero працює з `PageRouteBuilder` без додаткових залежностей (`HeroController` уже в `MaterialApp`). Прибрати коментар про Hero у `cards_screen.dart:140` після реалізації. |
| **картка → картка** (`CardsScreen` PageView) | лишити `PageView` + `rotateY 0.04` + scale 1→0.9; **замінити `Opacity(1→0.5)` на затемнення через `ColorFiltered`/фон картки або прибрати**; `viewportFraction` 0.92→0.88 для «peek» наступної (див. design-audit №21) | фізика PageView | `FlashCard._entranceCtrl` (elasticOut 500) запускати лише при **першому** появленні активної картки (`isActive` став true), а не на кожен `initState` елемента; під час скролу гасити `_pulseCtrl`. Свайп = light хаптик (є) + тихий `pop` pitch 0.8 vol 0.3 на `onPageChanged`. |
| **вхід/вихід гри** (`KidRoutes.game(page)`) | існуючий `_gameRoute` fade + scale 0.93→1 | 260 / 200 | перенести з `games_tab.dart` у `kid_routes.dart`; використати також у `quest_map_screen.dart:208` (`GuessScreen` сьогодні через `MaterialPageRoute`). Голос-інструкція стартує на 200 мс (не в `postFrame` на 0), щоб не грати під час fade. |
| **перемикання табів** (`home_screen.dart`) | лишити `IndexedStack` + `TickerMode`; поверх — `Stack` з трьома `FadeTransition` (`AnimatedOpacity` еквівалент) + `IgnorePointer` для невидимих | fade-through 180: out 0–90, in 90–180 | без нових залежностей (`animations` пакет не потрібен). Контент не зсувається — для дитини важлива стабільність позицій. RM → миттєво (є). |
| **вхід пейволу** (`KidRoutes.sheet(page)`) | `PageRouteBuilder` slide знизу `Offset(0, 1)→0` + бар'єр 0→`0x33` | 320 easeOutCubic / reverse 240 easeIn | читається як «аркуш поверх дитячої апки», а не заміна екрана; батько закриває свайпом вниз (`Dismissible` або `DraggableScrollableSheet` не обов'язковий — достатньо X після 3 с, що вже є). Використати також для Parent dashboard і Word wall. |
| **оверлеї свят** (`KidRoutes.overlay(widget)`) | `PageRouteBuilder(opaque: false)` з fade 200 | 200 / 160 | замінює `cards_screen.dart:478` (без transitionsBuilder) і уніфікує з `showGeneralDialog` у `game_celebration_overlay`. |
| **splash → home / onboarding → home** | лишити fade | 400 → 320 | `KidRoutes.replace(page)`. |

Архітектурний тест: `MaterialPageRoute(` і `PageRouteBuilder(` дозволені лише в `lib/utils/kid_routes.dart` і `lib/services/paywall_flow.dart` (до міграції).

---

## 6. Примітив натискання — один `KidTap`

Специфікація (оновити `lib/widgets/kid_tap.dart` і `DT`):

| Параметр | Значення | Чому |
|---|---|---|
| Down | scale 1→**0.94**, 90 мс, `Curves.easeOutCubic`, стартує на `onTapDown` (не чекає `onTap`) | реакція до 100 мс сприймається як миттєва |
| Up | пружина назад: `SpringDescription(mass: 1, stiffness: 420, damping: 22)` через `AnimationController.animateWith(SpringSimulation)` — ≈200 мс з овершутом до 1.01; або дешевша заміна `easeOutBack` 180 | «живе» відпускання — те, що відрізняє Duolingo від Material |
| Хаптик | `HapticFeedback.lightImpact()` на **down** | найшвидший канал зворотного зв'язку; на 1–2-річних дітей «дзинь у пальці» діє краще за звук |
| Звук | `pop` через `playSfxVaried(spread 0.1, volume 0.6)` на `onTap` (up) | на down не можна — драг у GridView спричинив би «pop» без дії; варіація pitch уже є в `AudioService` |
| Long-press | `onLongPress` прокидається; scale повертається до 1 на початку long-press | wobble/favorite не мають виглядати як «застрягло натиснуте» |
| API | `KidTap({child, onTap, onLongPress, pressScale = DT.pressScale, sound = KidSound.pop | none, haptic = true, behavior})` + статичний `KidTap.feedback()` (лишити для сумісності) | один клас, без дублювання `GestureDetector` у кожному віджеті |
| RM | scale off; хаптик і звук лишаються | |
| Токени | `DT.pressScale = 0.94`, `DT.pressDownMs = 90`, `DT.pressUpMs = 200`, прибрати `DT.pressMs` після міграції | |

Хто має перейти на `KidTap` (сьогодні — власний `GestureDetector` або без фідбеку):

1. `PackGridCard` (дублює `GestureDetector`+`AnimatedScale`; лишити `onLongPress: _triggerWobble`)
2. `DailyHeroCard` hero — без звуку
3. `_TaskButton` — без звуку
4. `_AllDoneRow` — без руху і звуку
5. `TreasureCard` — без звуку і хаптика
6. `_JourneyStop` (`quest_journey_map`) — 0.92/120/linear, без звуку
7. `PlayfulNavigationBar._TabButton` — замінити `InkWell` (Material splash — чужа мова руху)
8. `_BigGameTile` (`games_tab`) — хардкод 0.96/140
9. `QuizOption` — 0.92/100, без звуку і хаптика
10. `_TileWidget` (`memory_match`) — без press
11. `_OptionTile` (`opposite_game`) — без press
12. `_CardChip` (`odd_one_out`) — без press
13. `SpeakerButton` — без press, без хаптика
14. Спікер 88 dp у `GuessScreen` — без press
15. `FlashCard` — press частина (лишити flip і long-press як є)
16. `_MagicCard` (onboarding) — press поверх breath
17. Плитки `_PackPickerSheet` (`quest_map_screen`)
18. Кнопки свят (`ElevatedButton`/`TextButton`/`OutlinedButton` у `CelebrationOverlay`, `showGameCelebration`, `streak_milestone`, `CardRevealScreen`) — обгорнути у `KidTap` або задати `splashFactory: NoSplash.splashFactory` + `KidTap.feedback()`
19. `_IdleBar`/`_DoneBar` у `coloring_screen`
20. `BloomMascot` (тап → `KidTap` + `happy`)
21. `StreakChip`
22. Кнопки «Далі» онбордингу

---

## 7. Performance guardrails

| Рекомендація | Guardrail |
|---|---|
| `KidTap` з пружиною | `SpringSimulation` створюється на up (одна алокація на тап — ок). Не використовувати `AnimatedScale` з `Duration` — вона не вміє spring; один `AnimationController` на `KidTap`. У списках (`GridView` 21 плитка) — це 21 контролер у стані idle без тікера: тікер працює лише під час натискання. |
| Bloom риг (фаза 1) | `RepaintBoundary` навколо `CustomPaint`; один `Ticker` на контролер; `notifyListeners` лише при зміні пози > 1e-3; зупиняти через `TickerMode` (уже є в `home_screen`) і `AppLifecycleListener.onHide`; при RM — лише моргання. Ціль: paint ≤ 0.4 мс на кадр, перевірити `flutter run --profile` на Android API 28 планшеті (DevTools → Performance → Raster). |
| Bloom (фаза 2, Rive) | `.riv` без растрів, без blur/feather; ≤ 60 кісток; `RiveAnimation` під `RepaintBoundary`; ізолювати імпорт `rive` архітектурним тестом; заміряти download size до/після (ціль +≤3 МБ). |
| Конфеті | один спільний `ConfettiPainter` з передобчисленими частинками, один `Paint` на кадр (колір через `paint.color = ...`), ліміт 24 на телефоні / 40 на `shortestSide ≥ 600`; завжди `RepaintBoundary` + `IgnorePointer`; одноразовий `forward()`, ніколи `repeat()`. `card_reveal._ConfettiPainter` — прибрати `Random(42)` у `paint()`, передобчислити список. |
| Свята T1–T4 | один master `AnimationController` + `Interval` замість 7 контролерів і `Future.delayed`; всі повноекранні `CustomPaint` — у власних `RepaintBoundary`; `BoxShadow blurRadius ≤ 40`, `spreadRadius ≤ 10` (сьогодні 80/30 у `card_reveal`); glow-пульси — фіксована кількість повторів (`repeat(count:)` через `TweenSequence` або лічильник статусу). |
| Hero home→пак | політ на `CardArtSize.tile` (уже в кеші), не на hero-розмірі; `Hero` лише на `CardImage` (безпечний до недоставлених asset pack — правило CLAUDE.md); `placeholderBuilder` — тінт паку, щоб не блимав білий. |
| Свайп карток | прибрати `Opacity` в `itemBuilder` (3 `saveLayer` на кадр скролу); `FlashCard` під `RepaintBoundary`; `_entranceCtrl` лише один раз на активну картку; `_pulseCtrl` тільки для `isActive`. |
| Перемикання табів | fade-through 180 мс без зміни `IndexedStack` (стан табів зберігається); `IgnorePointer` для прихованих табів; `TickerMode` вже є. |
| Пейвол-sheet | бар'єр `0x33` без `BackdropFilter` (saveLayer на весь екран). |
| Циклічні анімації | бюджет **≤ 1 ∞-цикл на екран** (сьогодні home: hero pulse + task pulse + streak burst + shimmer = 4); кожен `repeat()` має умову зупинки; єдиний хелпер `MotionPolicy.of(context)` → `{reduce: bool, dur(Duration): Duration}` для `disableAnimationsOf`, використовувати замість 4 локальних перевірок. |
| Аудіо-синхронізація | `await` `Future` з `speakCard/playWordOnly` з `.timeout(1200 мс)` замість `Future.delayed`; `playPraise` і наступне слово — послідовно, не паралельно. |
| Вимірювання | у profile-збірці — `SchedulerBinding.addTimingsCallback` під час свят: логувати частку кадрів > 16.6 мс агреговано (без ідентифікаторів, COPPA-нейтрально) в `AnalyticsService` як `celebration_jank_pct`; поріг регресії 5 %. |
| Архітектурні тести (за зразком `test/architecture/asset_access_test.dart`) | (a) `Duration(milliseconds:` літерали заборонені в `lib/widgets/` і `lib/screens/` — лише через `DT`/`Motion` токени; (b) `MaterialPageRoute(`/`PageRouteBuilder(` — лише в `kid_routes.dart`; (c) `Opacity(` всередині файлу, що імпортує `AnimationController` — попередження; (d) `repeat()` без `reverse:`/умови — попередження. |

---

## 8. Пріоритети

| P | Що | Файли | Розмір |
|---|---|---|---|
| **P0** | Озвучити свято паку (`tada` + `playPraise(always)`), прибрати tap-anywhere → home | `cards_screen.dart:450-509`, `celebration_overlay.dart` | S |
| **P0** | `CardRevealScreen`: зупинити ∞ `_glowCtrl`/`_confettiCtrl`, `RepaintBoundary` на 3 пейнтери, blur 80→40 | `card_reveal_screen.dart` | S |
| **P0** | `KidTap` v2 (0.94 / 90 / spring / хаптик на down) + міграція 22 таргетів | `kid_tap.dart`, `design_tokens.dart`, список §6 | M |
| **P1** | `kid_routes.dart` + `pageTransitionsTheme`; Hero плитки → `CardsScreen` | `main.dart`, `packs_tab.dart`, `cards_screen.dart`, `pack_grid_card.dart` | M |
| **P1** | Єдине `celebrate()` з тирами T0–T4, `await` аудіо замість `Future.delayed` | `game_celebration_overlay.dart`, 5 ігор | M |
| **P1** | `MotionPolicy` + RM для 12 циклів; бюджет 1 ∞ на екран | `daily_hero_card`, `treasure_card`, `streak_chip`, `pack_grid_card`, `flash_card`, `speaker_button`, `guess_screen`, `streak_milestone_overlay`, `onboarding_screen` | S |
| **P1** | Bloom фаза 1: дихання, моргання, listening, celebrate | `bloom_mascot.dart` → `widgets/bloom/` | M |
| **P2** | Один індикатор «звучить» (слово scale 1.06 / 900 мс sin) для `FlashCard`, `SpeakerButton`, `GuessScreen`, `_MagicCard` | 4 файли | S |
| **P2** | Один шейк «неправильно» (mixin, 380, ±12) для `QuizOption`; nod для memory mismatch | `quiz_option.dart`, `memory_match_screen.dart` | S |
| **P2** | Один `ConfettiPainter`; прибрати `Opacity` зі скролу карток | `confetti_burst.dart`, `celebration_overlay.dart`, `card_reveal_screen.dart`, `cards_screen.dart:827` | S |
| **P2** | Fade-through табів 180 мс | `home_screen.dart` | S |
| **P3** | Bloom фаза 2 (Rive) після професійної ілюстрації | `widgets/bloom/`, `pubspec.yaml` | M–L |
