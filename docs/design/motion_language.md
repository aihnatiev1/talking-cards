# Мова руху — Картки-розмовлялки

Дата: 2026-09-13. Автор: `animator`. Статус: специфікація для `flutter-dev`, `ux-kids`, `qa`, `perf`. Код за цим документом не пишеться, окрім сигнатур §3.

Рішення власника, з якого все випливає: спочатку головний цикл карток + Bloom + звук, ігри потім. Дитина живе в картках (12 600 подій за 30 днів проти 400 в іграх), тому мова руху проєктується на картках і лише потім розповсюджується.

Джерела (у порядку пріоритету): CLAUDE.md правила 3, 6, 10 → `docs/experience-audit-2026-09-13.md` пп. 11, 12, 13, 15 → `docs/motion-audit-2026-09-13.md` (інвентар, T0–T4, §5 переходи, §6 KidTap) → `docs/architecture-gap-audit-2026-09-13.md` F1–F3 → `docs/ux-gap-audit-2026-09-13.md` §5.2–5.4 → `docs/design/bubble_pop_redesign.md` §3, §6 і `docs/design/memory_match_redesign.md` §4.

---

## 0. Стан коду, який цей документ застає (перевірено читанням 13.09)

Що вже зроблено і стає ядром мови, а не задачею:

| Є | Де | Що це означає для документа |
|---|---|---|
| `KidTap` v2: down 1→0.94 за 90 мс `easeOutCubic`, up — пружина `mass 1 / stiffness 420 / damping 22` з овершутом до ~1.01 (≈200 мс), хаптик light на down, `pop` (pitch ±0.1) на up, RM — без scale | `lib/widgets/kid_tap.dart:63,106-142`; `DT.pressScale/pressDownMs/pressUpMs` (`design_tokens.dart:89-91`) | Клас «прес» уже реалізований; «прес 140 мс» у bubble §3 і memory §4 — застарілий, поглинається (§2.5) |
| `reduceMotionOf(context)` як єдина перевірка RM | `lib/utils/motion.dart` (10 рядків), 20+ викликів | Файл не створюється з нуля — розширюється, `reduceMotionOf` лишається |
| Усі 12 `repeat(` гейтяться RM; `card_reveal` уже `repeat(count: 3)`; `streak_chip`/`pack_grid_card` — бурсти через `Timer` кожні 30 с | grep `\.repeat\(` | Питання п. 13 (RM) закрите на 12/12; відкрите питання п. 12 — петля чи акцент (§5) |
| Свято паку озвучене (`tada` + `playPraise`), tap-anywhere прибрано, гейт кнопок 600 мс, `RepaintBoundary` на конфеті | `cards_screen.dart:475-478`, `celebration_overlay.dart:53,100` + `test/widgets/celebration_overlay_test.dart` | P0 motion-аудиту закриті; ці тести стають приймальними для єдиного `Celebration` (§6) |
| `AudioService.speakCard/playWordOnly` повертають `Future`, що завершується **по кінцю кліпу** (полінг 50 мс), `isSpeaking: ValueNotifier<bool>`, `playSfx(pitch)` через `setRelativePlaySpeed` | `audio_service.dart:640-744, 784-802` | Хореографію можна вести від аудіо-подій, а не від `Future.delayed` |
| `IndexedStack` + `TickerMode` на табах | `home_screen.dart:205-211` | Приховані таби не тікають; fade-through — хвиля 2 |

Що не зроблено і є предметом документа:

- `Hero(` у `lib/` — 0. Home→пак — системний `MaterialPageRoute` (Android Zoom / iOS slide), 13 викликів, `pageTransitionsTheme` не задано (`main.dart:194-208`).
- `FlashCard._entranceCtrl` — `elasticOut` 500 мс на **кожен** білд елемента `PageView` (`flash_card.dart:64-71`); `_flipCtrl` 400 `easeInOut` (73-79); пульс слова 1.15 / 1600 (56-62), стоп — жорсткий `value = 0` (139-140).
- `CardsScreen`: `viewportFraction 0.92` (109), `Opacity 1→0.5` на кожну сторінку кожен кадр скролу (853-860), слово через фіксований дебаунс 500 мс від 50 % перетину (332), автоплей `nextPage(400, easeInOut)` (290-293), лічильник цифрами (743-745), прогрес-бар без анімації значення (762-767), свято через `PageRouteBuilder(opaque: false)` без `transitionsBuilder` — з'являється миттєво (504).
- Три святкування з різними затемненнями, кривими, звуком і Bloom (§6). Два різні шейки «неправильно» + один без руху. Чотири індикатори «зараз звучить».
- ≈120 літералів `Duration(milliseconds:` у 33 файлах, ~30 різних значень; `Curves.elasticOut` у 7 місцях.

---

## 1. Принципи

Сім правил. Кожне — з прикладом і антиприкладом з поточного коду.

### П1. Кожен дотик відповідає за ≤ 150 мс, трьома каналами
Хаптик — на `pointerDown` (0 мс), сквош досягає дна на 90 мс, звук — на up. Дитина 1–2 років не читає; тап без відчутної відповіді = «не зарахувано» = повторний тап = подвійна навігація.
- **Приклад:** `KidTap` — `HapticFeedback.lightImpact()` у `_down`, `animateTo(0.94, 90 мс)`, `pop` у `_tap`.
- **Антиприклад:** чип `🇬🇧 English ↻` на картці — голий `GestureDetector` (`flash_card.dart:284-297`): ні сквошу, ні звуку; пігулка автоплею (`cards_screen.dart:890`) — те саме.

### П2. Рух має причину: підказує дію, підтверджує успіх або показує стан звучання
Усе інше — декор, і декору в дитячій зоні нема. Три легітимні причини — і тільки три.
- **Приклад:** `SpeakerButton` розширює тінь 6→12, доки грає кліп (`speaker_button.dart:114`) — стан звучання; `card_reveal` glow `repeat(count: 3)` — підтверджує успіх і зупиняється.
- **Антиприклад:** 🎁 у `TreasureCard` гойдається −3 px вічно (`treasure_card.dart:54`); `StreakChip` пульсує кожні 30 с без події (`streak_chip.dart:55`).

### П3. Акцент → спокій. Ніколи петля
Вступний акцент ≤ 1600 мс (два «вдихи»), далі — нерухомість. Повтор — лише як підказка після бездіяльности, обмежена кількість разів. Бюджет: **0 вічних циклів** на екрані у спокої; єдина дозволена «жива» річ — стан звучання (обмежений `isSpeaking`) і, згодом, дихання Bloom.
- **Приклад:** `_BouncingMascot` в онбордингу: два боби, через 2 с `animateTo(0)` (`onboarding_screen.dart:610-617`) — це зразок, з якого робиться `AmbientLoop`.
- **Антиприклад:** полум'я у `streak_milestone_overlay.dart:82` — `repeat(reverse: true)` без кінця; `DailyHeroCard` дихає 1.02 доти, доки завдання не виконано (`daily_hero_card.dart:124`).

### П4. Фізика іграшки: сквош, один відскок, вага — не UI-ease і не «желе»
Одна крива появи з одним овершутом (`easeOutBack`), одна пружина для відпускання, одна пружина для сторінок. `elasticOut` (два-три коливання) — заборонений: іграшка підстрибує раз і стає, желе тремтить.
- **Приклад:** пружина `KidTap` — овершут до 1.01 і посадка; фізика `PageView` під пальцем.
- **Антиприклад:** картка свята `elasticOut` 600 мс (`celebration_overlay.dart:75`), вхід кожної картки `elasticOut` 500 (`flash_card.dart:69`), системні переходи `MaterialPageRoute` — різні на двох платформах і не пов'язані з тим, що натиснула дитина.

### П5. Звук не чекає на рух; рух не блокує дотик
Слово стартує від події (посадка картки, tap-up), а не від магічного числа. Кнопка тапабельна з першого кадру, окрім одного винятку — гейт 600 мс у великому святі, і це захист від пальця, що ще на склі, а не motion (лишається під RM).
- **Приклад:** `KidTap` викликає `onTap` на up, поки пружина ще летить; `_afterRouteTransition` чекає саме кінця маршруту, не таймера (`cards_screen.dart:156-171`).
- **Антиприклад:** `_speakCardDebounced` — 500 мс від 50 % перетину незалежно від того, коли картка справді стала (`cards_screen.dart:332`); `guess_screen` 800 + 300 мс таймерів поверх похвали ~1.2 с.

### П6. Масштаб свята = масштаб успіху
Одна картка — локальна відповідь без оверлею. П'ять карток — коротка сценка на екрані. Пак — оверлей з кнопками. Велике свято ніколи не приходить за маленьку дію, і навпаки.
- **Приклад:** `_PraiseFlash` у бульбашках — слово 52 sp злітає і гасне, гра не зупиняється.
- **Антиприклад:** повноекранне `showConfetti` на **кожну** пару у memory (`memory_match_screen.dart:171`); `black54` на 100 % екрана ховає картки в момент, коли дитина їх щойно пройшла (`celebration_overlay.dart:93`).

### П7. Reduce-motion прибирає переміщення, не інформацію
Під `disableAnimations` дозволені: зміна кольору, opacity-fade ≤ 120 мс, заповнення прогресу, зміна пози/іконки. Заборонені: translate, scale, rotate, частинки, Hero-польоти, петлі. Кожен клас руху має гілку «що бачить дитина при RM» (§2.3), і в ній завжди лишається колір, іконка або звук.
- **Приклад:** `TreasureCard` під RM — кільце прогресу і підпис «n / total» несуть стан; `SpeakerButton` — тінь.
- **Антиприклад:** автоплей `nextPage(400)` і всі `PageRouteBuilder`-фейди 400 мс (splash, onboarding, quest) ігнорують RM; `card_reveal_screen.dart:59` дублює перевірку власним геттером замість спільної політики.

---

## 2. Таблиця таймінгів і кривих — ядро

### 2.1 Шкала тривалостей (11 значень, інших у дитячій зоні нема)

| Токен | мс | Для чого |
|---|---|---|
| `Motion.instant` | 80 | сквош перед лопом, миттєві зміни стану |
| `Motion.pressDown` | 90 | = `DT.pressDownMs` — низ сквошу |
| `Motion.quick` | 120 | затримка слова після посадки; RM-crossfade; зміна кольору чипа |
| `Motion.pressUp` | ≈200 | = `DT.pressUpMs` — візуальний час пружини `Motion.spring` |
| `Motion.snap` | 200 | «стук» успіху 1→1.06→1, посадка, pop бейджа |
| `Motion.base` | 260 | = `DT.enterMs` — поява елемента, заповнення прогресу, fade кнопок |
| `Motion.route` / `Motion.routeBack` | 280 / 220 | перехід екрана вперед / назад (п. 11: 220–320) |
| `Motion.flip` | 320 | фліп картки (спільний з memory §4) |
| `Motion.page` | 380 | автоперегортання сторінки; орієнтир посадки пружини свайпу |
| `Motion.enterBig` | 420 | вхід картки свята, reveal, спавн бульбашки |
| `Motion.reaction` | 600 | реакція Bloom, повний малий успіх |
| `Motion.pulse` | 900 | період пульсу «зараз звучить» (sin) |
| `Motion.burst` | 1200 | одна хвиля конфеті великого свята |
| `Motion.intro` | 1600 | бюджет вступного акценту (2 вдихи по 800) |
| `Motion.idleFirst` / `Motion.idleRepeat` | 4000 / 8000 | бездіяльність до першої / повторної підказки (перевизначається за віком, memory §6) |

Стелі: жоден перехід > 420 мс, жодна реакція > 600 мс, жоден ефект > 1200 мс, вступ > 1600 мс. `Future.delayed` з числом у дитячій зоні — заборонений; хореографія — `Interval` в одному контролері або подія аудіо.

### 2.2 Криві

| Токен | Flutter | Коли |
|---|---|---|
| `Motion.toy` | `Curves.easeOutBack` | з'являється, «підстрибує раз»: вхід картки свята, pop успіху, spawn |
| `Motion.settle` | `Curves.easeOutCubic` | рухається до спокою: сквош вниз, маршрут вперед, заповнення прогресу, поява елемента |
| `Motion.leave` | `Curves.easeIn` | зникає: маршрут назад, dismiss, вихід елемента |
| `Motion.turn` | `Curves.easeInOutCubic` | одне міняється на інше: фліп, антиципація автоплею, swap |
| `Motion.breathe` | `Curves.easeInOut` | пульс/вдих (тільки в `SpeakingPulse` і `AmbientLoop`) |
| `Motion.spring` | `SpringDescription(mass: 1, stiffness: 420, damping: 22)` | відпускання після пресу (= `KidTap.spring`, переїжджає в `Motion`) |
| `Motion.pageSpring` | `SpringDescription.withDampingRatio(mass: 1, stiffness: 160, ratio: 1.0)` | посадка сторінки `PageView`: критично задемпфована, ≈ 320–380 мс, без відскоку — «вага» картки |

Заборонено: `Curves.elasticOut`, `Curves.bounceOut`, лінійна крива для кольору/opacity довше 120 мс, Material `InkSplash` у дитячій зоні.

### 2.3 Класи руху

Колонка «RM» — що бачить дитина при `disableAnimations`; інформація має лишитись.

| Клас | Токени | Тривалість | Крива | Масштаб / зсув | Звук · хаптик | RM |
|---|---|---|---|---|---|---|
| **Прес down** | `pressDown`, `pressScale` | 90 | `settle` | 1 → 0.94 | — · light на down | без scale; хаптик лишається |
| **Прес up** | `spring` | ≈200 | пружина | 0.94 → 1.01 → 1.00 | `pop` pitch ±0.1 vol 0.6 (або звук цілі) · — | без scale; звук лишається |
| **Поява елемента** | `base`, `enterOffset`, `enterScale` | 260 (stagger 40, ≤ 9 елементів анімовано, решта миттєво) | `settle` | opacity 0→1, translateY 12→0, scale 0.94→1 | — | fade 120 |
| **Перехід екрана вперед** | `route` | 280 | `settle` | fade 0→1 + scale 0.96→1; Hero обраної ілюстрації по `MaterialRectArcTween`, cross-fade у ціль з 60 % | — | fade 120, `HeroMode(enabled: false)` |
| **Перехід екрана назад** | `routeBack` | 220 | `leave` | fade 1→0 + scale 1→0.96; Hero назад у плитку | — | fade 120 |
| **Фліп** | `flip` | 320 | `turn` | rotateY 0→π, перспектива 0.001; підйом scale 1→1.04 (пік 160)→1; тінь offset 4→12 | — · medium на старті | crossfade лице↔зворот 120 |
| **Свайп / сторінка** | `pageSpring`, `neighbourScale`, `neighbourTilt` | посадка ≈ 380; поріг 35 % ширини або fling ≥ 300 px/с | пружина | сусід 0.92, rotateY 0.04 рад; **без Opacity** | light на 50 % (є) · `pop` pitch 0.8 vol 0.3 на посадці | фізика від пальця лишається (це не анімація); програмний `nextPage` → 0 |
| **Успіх S** (одна картка, правильний тап, лоп) | `snap`, `popScale`, `reaction` | ≤ 600, без оверлею | `toy` | ціль 1→1.08→1 за 200; в іграх — ≤ 12 частинок з точки події, радіус ≤ 90 dp, 500 мс; на картці нагорода = слово, без частинок; Bloom S `happy` | `ding` pitch ±0.08 (в іграх) · medium | колір/рамка успіху + звук; без частинок і scale |
| **Успіх M** (5 карток поспіль, пара, N-й лоп) | `reaction`, `knockScale` | ≤ 900, без оверлею | `toy` | «стук» 1→1.06→1 за 200; прогрес заповнюється 260; 12 іскор **від Bloom**, не від картки; Bloom S стрибок 8 dp зі squash 0.94/1.06 (600) | `ding` драбинкою +0.06 за крок + похвала кожен 2-й · medium | поза Bloom + бар + звук |
| **Успіх L** (пак, раунд, скриня, серія) | `route`(overlay 200), `enterBig`, `burst`, `gate` | оверлей до дії дитини; візуал 1200 | `toy` | dim `DT.textPrimary` α .35 за 200; картка 0.85→1 за 420; обкладинка 0.8→1 (150–450); конфеті одна хвиля 24 (телефон) / 40 (планшет) за 1200; Bloom M `celebrating` на 300; кнопки живі з 600 | `tada` 0 · medium; похвала 400 · — | dim + картка статично, без конфеті; звук і гейт лишаються |
| **М'який промах** | `flip`(320), `missTilt` | 320 | `breathe` | rotateZ 0→−3°→+3°→0 (нахил «хм?», не шейк); колір **не** червоний; Bloom `encourage` нахил 8° | `miss` тихий (маримба/повітря) vol .4 · selectionClick | тільки звук + хаптик; рамка не змінюється |
| **Підказка на бездіяльність** | `idleFirst`, `idleRepeat`, `nudgeOffset` | 400 на цикл, ≤ 3 цикли, повтор ≤ 3 серії | `breathe` | ціль scale 1→1.03→1 + rotateZ ±1.5°; для свайпу — картка «підглядає» на 24 dp у напрямку жесту і повертається | `hint_whistle` тихо на 2-й серії · — | статична підказка (пігулка/іконка) без руху |
| **Вихід елемента** | `quick` | 120 | `leave` | opacity 1→0, scale 1→0.96 | — | миттєво |
| **Стан звучання** | `pulse`, `pulseScale` | доки `isSpeaking`; ease-out 150 на стопі | sin | слово 1.00↔1.06; спікер — glow α .25↔.5 у тому ж ритмі, без scale | — | без руху; тінь спікера 6→12 (є) несе стан |
| **Антиципація автоплею** | `base`, `leanOffset` | 260 | `turn` | картка translateX −10 dp, rotateY −0.02, далі безперервно у `nextPage` | — | без нахилу; кільце-таймер лишається |

Правило округлення: значення, якого нема в шкалі §2.1, округлюється до найближчого токена (вихід елемента 160 → 120, антиципація 240 → 260). Шкала не розширюється заради одного місця; якщо токена нема — спрощується хореографія.

### 2.4 Політика reduce-motion (єдина для всіх рядків)

- **Дозволено під RM:** opacity-fade ≤ 120 мс (`MotionPolicy.fade`), зміна кольору/рамки, заповнення прогресу і «кільце-таймер» (це інформація), зміна пози Bloom/іконки, увесь звук, хаптик, гейт кнопок 600 мс.
- **Заборонено:** translate/scale/rotate, частинки, Hero, петлі, `nextPage` з тривалістю.
- **Читати політику** у `didChangeDependencies` або на початку жесту (`KidTap` читає на down, бо на up елемент може вже виходити з дерева) — ніколи в `dispose`.
- **Тест-режим** = RM з нулями: `pumpAndSettle` завершується на будь-якому екрані.

### 2.5 Поглинання двох ігрових спек

| Спека каже | Стає в мові руху | Відхилення |
|---|---|---|
| memory §4: «прес `DT.pressScale` .96 за `DT.pressMs` 140» | `KidTap`: 0.94 за 90 + `Motion.spring` | .96/140 застаріло разом із `DT.pressMs` (deprecated) |
| memory §4: «фліп 320 `easeInOutCubic`, підйом .96→1.06→1.00» | `Motion.flip` + `Motion.turn`; підйом 1→1.04 (пік 160) | амплітуда підйому 1.06→1.04: на плитці 177 dp 1.06 = +11 dp у 12-dp gap |
| memory §4: «матч 200 `easeOutBack`, стук 1.06» | `Motion.snap` + `Motion.toy` + `Motion.knockScale` | без змін |
| memory §4: «слово на 120 мс» | `Motion.quick` після події (tap-up / посадка) | без змін |
| memory §4: «іскри 500, ≤ 12 частинок» | успіх S/M: 12 частинок як `Interval(0, 0.83)` у контролері `reaction` 600 (= 500 мс) | без змін по факту |
| memory §4: «промах: повернення 320 без підйому» | `Motion.flip` + `Motion.turn`, `Motion.missTilt` для Bloom | без змін |
| memory §4: «здача 280 stagger ≤ 40, ≤ 720» | `Motion.base` 260 + `Motion.stagger` 40, ≤ 9 елементів (решта миттєво) | 280→260; для 16 карт анімуються 9, решта з'являються на місці |
| memory §4: `motion(BuildContext, int ms)` | `motion(BuildContext, Duration)` | int-варіант не створюється |
| bubble §3: «спавн scale 0.6→1.08→1.0 `elasticOut` 420» | `Motion.enterBig` + `Motion.toy` (один овершут ≈1.07) | `elasticOut` заборонений (П4) |
| bubble §3: «squash 60 → вибух 140 → краплі 220 → reveal 420 → hold ≤ 1600» | `instant` 80 → `quick` 120 → `snap` 200 → `enterBig` 420 → hold від аудіо (`isSpeaking`), не токен | 60→80, 140→120, 220→200 — невідчутно, зате один набір |
| bubble §6: «похвала 150 in / hold 700 / out 900» | in `snap` 200 `toy`, out `snap` `leave`, разом ≤ `pulse` 900 | без змін по відчуттю |
| bubble §2: «Bloom підскок 240 spring, debounce 350» | `Motion.spring` (≈200), debounce = `Motion.page` 380 | без змін по відчуттю |
| обидві: «кожен елемент має гілку `disableAnimations`» | `MotionPolicy` §2.4 — одна гілка на клас, не на елемент | спрощення |

---

## 3. `lib/utils/motion.dart` — сигнатури

Файл існує (`reduceMotionOf`). Розширюється так, щоб 20 нинішніх викликів не змінилися.

```dart
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'design_tokens.dart';

/// Існує сьогодні; лишається як шорткат для `MotionPolicy.of(context).reduce`.
bool reduceMotionOf(BuildContext context);

/// full — звичайний режим; reduced — системний прапорець або MotionScope;
/// test — як reduced, але виставляється лише через MotionScope у тестах.
enum MotionMode { full, reduced, test }

/// Одна відповідь на «чи рухати?» — читає MotionScope, інакше
/// MediaQuery.disableAnimationsOf. Читати в didChangeDependencies або на
/// початку жесту, ніколи в dispose.
final class MotionPolicy {
  const MotionPolicy(this.mode);
  final MotionMode mode;

  static MotionPolicy of(BuildContext context);

  bool get reduce => mode != MotionMode.full;

  /// Тривалість руху: Duration.zero при reduce.
  Duration dur(Duration d);

  /// Тривалість fade, який дозволено лишити під reduce: Motion.rmFade (120).
  Duration fade(Duration d);

  /// Скільки частинок можна намалювати: 0 при reduce, інакше
  /// Motion.particlesPhone / particlesTablet за shortestSide ≥ 600.
  int particles(BuildContext context);
}

/// Перевизначення політики для піддерева — тести (`MotionMode.test`),
/// debug-меню, golden-и. У проді не використовується.
final class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.mode, required super.child});
  final MotionMode mode;
  static MotionMode? maybeOf(BuildContext context);
  @override
  bool updateShouldNotify(MotionScope old) => old.mode != mode;
}

/// Шорткат: `motion(context, Motion.flip)` → Duration.zero при reduce.
Duration motion(BuildContext context, Duration d);

/// Іменовані константи §2.1–2.3. Єдине місце, де в дитячій зоні
/// дозволено писати `Duration(milliseconds:` і `SpringDescription(`.
abstract final class Motion {
  // Тривалості
  static const instant   = Duration(milliseconds: 80);
  static const pressDown = DT.pressDownMs;             // 90
  static const quick     = Duration(milliseconds: 120);
  static const pressUp   = DT.pressUpMs;               // ≈200, пружина
  static const snap      = Duration(milliseconds: 200);
  static const base      = DT.enterMs;                 // 260
  static const route     = Duration(milliseconds: 280);
  static const routeBack = Duration(milliseconds: 220);
  static const flip      = Duration(milliseconds: 320);
  static const page      = Duration(milliseconds: 380);
  static const enterBig  = Duration(milliseconds: 420);
  static const reaction  = Duration(milliseconds: 600);
  static const pulse     = Duration(milliseconds: 900);
  static const burst     = Duration(milliseconds: 1200);
  static const intro     = Duration(milliseconds: 1600);
  static const idleFirst  = Duration(seconds: 4);
  static const idleRepeat = Duration(seconds: 8);
  static const rmFade    = quick;
  /// Гейт кнопок великого свята — захист, не motion; не проходить через dur().
  static const gate      = Duration(milliseconds: 600);
  static const stagger   = Duration(milliseconds: 40);
  static const staggerMax = 9;

  // Амплітуди
  static const pressScale     = DT.pressScale;  // 0.94
  static const popScale       = 1.08;
  static const knockScale     = 1.06;
  static const pulseScale     = 1.06;
  static const neighbourScale = 0.92;
  static const neighbourTilt  = 0.04;  // рад
  static const enterOffset    = 12.0;  // dp
  static const enterScale     = 0.94;
  static const missTilt       = 0.052; // рад ≈ 3°
  static const nudgeOffset    = 24.0;  // dp
  static const leanOffset     = 10.0;  // dp, антиципація автоплею
  static const particlesPhone  = 24;
  static const particlesTablet = 40;

  // Криві
  static const toy     = Curves.easeOutBack;
  static const settle  = Curves.easeOutCubic;
  static const leave   = Curves.easeIn;
  static const turn    = Curves.easeInOutCubic;
  static const breathe = Curves.easeInOut;

  // Пружини
  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 22);
  static final pageSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 160, ratio: 1.0);
}
```

Супутні контракти (окремі файли, плоска структура; лише сигнатури, щоб `flutter-dev` знав, куди що класти):

```dart
// lib/widgets/ambient_loop.dart — ЄДИНИЙ власник repeat() у дитячій зоні.
// Робить `cycles` циклів `period` на mount і на кожному rising edge `active`,
// потім стоїть на t = 0. Якщо задано rearmAfter — повторює серію після
// бездіяльності (будь-який pointer у піддереві Listener скидає таймер),
// не більше maxSeries разів. Поважає MotionPolicy і TickerMode; під reduce
// будує child з t = restValue і не створює тікера.
class AmbientLoop extends StatefulWidget {
  const AmbientLoop({
    required this.builder,          // Widget Function(BuildContext, double t, Widget? child)
    required this.period,           // напр. Duration(milliseconds: 800)
    this.cycles = 2,
    this.rearmAfter,                // Motion.idleRepeat або null = без повтору
    this.maxSeries = 3,
    this.active = true,
    this.restValue = 0.0,
    this.child,
  });
}

// lib/widgets/speaking_pulse.dart — ЄДИНИЙ індикатор «зараз звучить».
// scale 1.0↔pulseScale по sin з періодом Motion.pulse, доки listenable == true;
// на false — animateTo(1.0, 150 мс, settle), не жорсткий стоп.
class SpeakingPulse extends StatefulWidget {
  const SpeakingPulse({
    required this.child,
    this.listenable,                // за замовчуванням AudioService.instance.isSpeaking
    this.scale = Motion.pulseScale,
    this.glowOnly = false,          // для SpeakerButton: без scale, лише alpha .25↔.5
  });
}

// lib/utils/app_routes.dart — три спільні маршрути замість 26 місць.
abstract final class AppRoutes {
  /// fade 0→1 + scale .96→1 за Motion.route / routeBack; heroTag вмикає
  /// HeroMode; під reduce — fade rmFade без Hero.
  static Route<T> kidPage<T>(Widget page, {String? heroTag});
  /// opaque: false, fade за 200 / 160 — для свят L і будь-яких оверлеїв.
  static Route<T> overlay<T>(Widget page);
  /// slide знизу 320 / 240 — пейвол, батьківські шити (хвиля 2).
  static Route<T> sheet<T>(Widget page);
}
```

### Як це співвідноситься з `DT.pressMs / enterMs`

- `DT.pressScale`, `DT.pressDownMs`, `DT.pressUpMs` — **лишаються** джерелом істини для пресу (`KidTap` і `test/widgets/kid_tap_test.dart` на них посилаються); `Motion.pressDown/pressUp/pressScale` — аліаси на них.
- `DT.enterMs` — лишається, `Motion.base` = аліас.
- `DT.pressMs` (deprecated 140) — **видалити** після заміни єдиного виклику `packs_tab.dart:1242` на `Motion.quick` (зміна кольору чипа — 120, не 140).
- `KidTap.spring` → `Motion.spring`; у `KidTap` лишити `static const spring = Motion.spring` для сумісності.
- Architecture-gap F1 пропонує простір `DT.motion`. Рішення: motion-токени живуть **лише** в `Motion` (`motion.dart`); `DT` зберігає трійку пресу для сумісности. Два будинки для одного числа — це шлях назад до 30 значень.

### Контракт для `flutter-dev` у три рядки

```dart
final m = MotionPolicy.of(context);                       // 1. політика — один раз у didChangeDependencies
_flip.duration = m.dur(Motion.flip);                      // 2. будь-який рух — через токен і dur()
return AnimatedOpacity(duration: m.fade(Motion.base), …); // 3. fade під reduce — через fade(), не dur()
```

Правила: `Duration(milliseconds:` у `lib/widgets|screens|tabs` — падіння source-тесту (§8, `test/architecture/motion_test.dart`); `repeat(` лише в `ambient_loop.dart` і `speaking_pulse.dart`; `MaterialPageRoute|PageRouteBuilder` лише в `app_routes.dart` (+ allowlist `paywall_flow.dart`, `splash_screen.dart`); `Curves.elasticOut` — 0 входжень.

---

## 4. Головний цикл карток — покадрово

Позначення: T0 — момент, від якого йде відлік у рядку; «є» — реалізовано сьогодні; «слот Bloom» — узгодити з `docs/design/bloom_character.md` (на момент написання файлу нема; орієнтир — `ux-gap-audit` §5.2: розміри S 56 / M 96 / L 160, стани `idle / listening / happy / celebrating / encourage / hint / wave`, `BloomController.set/pulse`, автопідписка `listening` на `isSpeaking`). Bloom S сидить у кутку **поза карткою** (нижній лівий, під `PageView`, навпроти `SwipeHint`) — місце підтверджує `ux-kids`.

### 4.1 Відкриття пака з головного екрана

Сьогодні: `KidTap` на плитці → `MaterialPageRoute` (`packs_tab.dart:276/298/305`) → системний перехід → `_afterRouteTransition` → слово одразу.

| t, мс | Що відбувається | Де / статус |
|---|---|---|
| 0 | pointerDown на плитці: хаптик light; сквош 1→0.94 за 90 `settle` | `KidTap` — є |
| ~80–150 | pointerUp: пружина назад; `pop`; `onTap` → `Navigator.push(AppRoutes.kidPage(CardsScreen(pack), heroTag: 'pack-${pack.id}'))` | `packs_tab._onPackTap` — замінити 3 `MaterialPageRoute` |
| T0 = push | Маршрут: fade 0→1 + scale 0.96→1 за 280 `settle`. **Hero:** `CardImage` плитки (`pack_grid_card.dart:166-170`, тайловий декод — уже в кеші) обгорнутий у `Hero(tag)`; ціль — панель арту **активної** картки (`FlashCard._artPane`, індекс `resumeIndex`), обгорнута в той самий `Hero` лише для `index == _currentIndex`. Політ по `MaterialRectArcTween`; `flightShuttleBuilder` малює тайлову картинку, з 60 % польоту (168 мс) cross-fade у hero-арт картки (обкладинка пака й перша картка — різні файли, тому не морф, а перехід). `placeholderBuilder` — тінт пака, щоб не блимало білим | нове; `Hero` лише на `CardImage` — безпечно до недоставлених asset pack (правило CLAUDE.md) |
| T0 + 280 | Посадка: маршрут завершено; `_afterRouteTransition` спрацьовує | є |
| T0 + 400 | Перше слово: `speakCard` = посадка + `Motion.quick` (120) | `cards_screen.dart:143-150` — додати +120 замість «одразу» |
| T0 + 400… | `SpeakingPulse` слова 1.00↔1.06 / 900 sin; спікер glow у тому ж ритмі; **слот Bloom:** `listening` | `FlashCard`, `SpeakerButton` |
| T0 + 4000 | Якщо жодного дотику — підказка свайпу (4.5) | `SwipeHint` — змінити тригер з mount на idle |

RM: маршрут fade 120, `HeroMode(enabled: false)`, слово на +120 після fade.

Входи без плитки (квест-зупинка, deep link, «Продовжимо?»): той самий `AppRoutes.kidPage` без `heroTag` — Hero без пари не летить, лишається fade+scale маршруту. Картка при цьому **не** отримує власної анімації появи: маршрут уже масштабує 0.96→1.

### 4.2 Поява першої картки

- Перша картка **не має окремої анімації входу**: її поява — це посадка Hero (4.1) або fade+scale маршруту. `FlashCard._entranceCtrl` (`elasticOut` 500 на кожен білд, `flash_card.dart:64-71`) — **видалити**. Це закриває і перф-проблему (контролер на кожен елемент `PageView`), і П4.
- Сусідні картки видно з обох боків: `viewportFraction 0.92 → 0.88` (peek ≈ 23 dp на 390 dp), масштаб 0.92, rotateY 0.04 — глибина замість прозорості; `Opacity` з `itemBuilder` прибрати (§7).
- Якщо контент пака ще їде з Play (`ContentDownloadView`) і приїхав: `AnimatedSwitcher` з `Motion.base` 260 `settle` (opacity + translateY 12 + scale 0.94). RM: fade 120.

### 4.3 Тап по картці

| t, мс | Що | Де / статус |
|---|---|---|
| 0 | pointerDown: хаптик light; сквош 1→0.94 за 90 | `KidTap(sound: none)` — є |
| up (≈80–150) | пружина назад (овершут 1.01 на ~110 мс після up, спокій ~200); `speakCard` викликається **на up**, не після пружини | є |
| up + 30…150 | старт кліпу. Затримка — це lazy-load `_getSource` з диска: перше слово нового пака може запізнитись на ~100 мс. Пропозиція для `perf`: гріти **один** наступний кліп при `onPageChanged` (як `precacheImage ±2`); це не eager precache всієї бібліотеки, який забороняє CLAUDE.md | `AudioService` — S, узгодити з `perf` |
| start | `isSpeaking = true` → `SpeakingPulse` слова 1.00↔1.06 / 900; спікер glow; **слот Bloom:** `listening` (вуха на 6°, нахил 4°, боб 2 px / 300 мс — з `ux-gap` §5.2) | `FlashCard._wordPane`, `SpeakerButton` |
| end | `isSpeaking = false` → пульс `animateTo(1.0, 150, settle)` замість `stop(); value = 0` (сьогодні стрибок 1.15→1.0, `flash_card.dart:139-140`); Bloom → `idle` | `SpeakingPulse` |
| повторний тап під час слова | `speakCard` робить `stop()` і грає знову (є) — пульс не рестартує, продовжує | є |
| long-press | пружина відпускається на старті long-press (є); улюблене: бейдж-серце pop 0→1 за 200 `toy` + `KidTap.feedback()` (є) + хаптик medium | `flash_card.dart:191-195` — додати pop бейджа (сьогодні з'являється миттєво) |

Це успіх S у чистому вигляді: сама картка не «святкує» окремо від слова — слово і є нагородою. Жодних іскор на кожен тап.

RM: без сквошу і пульсу; хаптик, слово, тінь спікера 6→12.

### 4.4 Свайп на наступну

| t | Що | Де / статус |
|---|---|---|
| палець на склі | `PageView` тягне 1:1; поточна картка 1→0.92 і rotateY до 0.04, сусідня 0.92→1 — глибина без `Opacity` | `cards_screen.dart:835-861` — прибрати `Opacity`, `RepaintBoundary` всередину `Transform` (§7) |
| відпускання | `CardPhysics extends PageScrollPhysics`: `spring = Motion.pageSpring` (mass 1 / k 160 / ratio 1.0 — критично задемпфована, посадка ≈ 320–380 мс, **без відскоку**: картка важка, як справжня); поріг перегортання **35 % ширини у напрямку руху** замість 50 % (перевизначити `createBallisticSimulation`); fling від `minFlingVelocity` 300 px/с. Це «вага»: не додаємо сквош поверх — пружина і є фізика, два рухи одного стану — шум | нове, у `cards_screen.dart` або `lib/utils/card_physics.dart` |
| 50 % перетину | `onPageChanged`: хаптик light (є); лічильник `n/N`; прогрес-бар `value` анімується 260 `settle` (сьогодні стрибає, `LinearProgressIndicator` → `TweenAnimationBuilder`) | є / доповнити |
| `ScrollEndNotification` | посадка: `pop` pitch 0.8 vol 0.3 — звук ваги; `SwipeHint.dismiss()` (є, через `_userSwiping`) | `NotificationListener` уже є (779) |
| посадка + 120 | слово (`Motion.quick`) — замість дебаунсу 500 від 50 % (`cards_screen.dart:332`). Якщо палець не відпускає (ScrollEnd не приходить) — слово не грає: картка ще не «на місці» | замінити `_speakCardDebounced` |
| кожна 5-та картка **вперед** (за сесію, `index > prev`) | успіх M (4.6) після кінця слова | нове |

Свайп назад — та ж фізика, слово так само на посадці. Свайп вперед на останній картці за край → `_skipEndWait` (є) → L одразу (4.7).

RM: фізика від пальця лишається (жест дитини — не анімація); `pop` і слово так само; програмних рухів нема.

### 4.5 Підказка свайпу (бездіяльність)

Сьогодні `SwipeHint` з'являється на mount і крутиться до першого свайпу (`swipe_hint.dart:68`), запам'ятовується глобально (аудит п. 05).

| t | Що |
|---|---|
| посадка + 4000 (`idleFirst`) без дотику | пігулка входить 260 `settle`; серія 3 цикли по 2000 (рука + шеврони, є) через `AmbientLoop(cycles: 3, rearmAfter: idleRepeat, maxSeries: 3)`; синхронно картка «підглядає»: `PageController.animateTo(+24 dp)` і назад за 400 `breathe` на початку кожного циклу — дитина бачить, що збоку є ще картка |
| будь-який дотик | таймер скидається; успішний свайп → `dismiss()` + per-profile `swipe_gesture_learned` (є) |
| 2-га серія | `hint_whistle` тихо; 3-тя — остання; далі спокій |

RM: пігулка статична на кадрі .35 (є), без «підглядання».

### 4.6 Фліп на зворот

| t, мс | Що | Де / статус |
|---|---|---|
| 0 | pointerDown на чипі `🇬🇧`: хаптик light, сквош 0.94 — чип стає `KidTap(sound: none)`; хіт-зона 56 dp | `flash_card.dart:284-297` — замінити `GestureDetector` |
| up | старт: rotateY 0→π за **320** `turn` (замість 400 `easeInOut`); підйом scale 1→1.04 (пік на 160)→1.00; тінь `offset 4→12, blur 16→24` лише якщо картка під `RepaintBoundary` (інакше тінь не анімувати — перемальовка blur щокадру); хаптик medium (є) | `flash_card.dart:73-79, 144-153` |
| 160 | кут π/2 — сторона міняється (`_showBack` при `value ≥ 0.5`, є) | є |
| 320 | посадка; спікер ховається (`_isFlipped`, є). Зворот озвучки не має — тиша | є |
| тап по звороту | фліп назад так само; слово переду **не** грає автоматично — це повернення, не нова картка | є |

Правило: під час фліпу тапи приймаються (`_flipCtrl.isAnimating → return` лишити лише для повторного фліпу, не для слова).

RM: `AnimatedSwitcher` crossfade лице↔зворот 120, без обертання й підйому.

### 4.7 П'ята картка поспіль — успіх M

Сьогодні між картками нічого нема (`ux-gap` №9 F4). Лічильник — forward-перегляди за сесію (`index > prev`), тобто «Продовжити» з 7-ї дає M на 12-й. Якщо в ту ж секунду закривається квест-крок «Переглянь 5 карток» — один M, не два.

| t, мс | Що | RM |
|---|---|---|
| 0 = `isSpeaking → false` після слова 5-ї картки | `ding` pitch 1.00 + 0.06·(k−1), k — номер п'ятірки (драбинка як `match` у memory); хаптик medium | звук + хаптик |
| 0–600 | **слот Bloom** S (56 dp, кут): `happy` — стрибок 8 dp зі squash 0.94/1.06, очі ^^ 600 мс; до Bloom-фази 1 — існуючий `BloomMascot` bounce 480 (`_react`), поза `waving` | зміна пози |
| 0–500 | 12 іскор (`DT.sunBurst` + акцент пака) **від Bloom**, не від картки (п. 18: не над навчальним об'єктом), радіус ≤ 90 dp, один `CustomPainter`, `RepaintBoundary`, `IgnorePointer` | — |
| 0–200 | прогрес-бар: «стук» scaleY 1→1.06→1 `toy` поверх заповнення | заповнення |
| 200 | похвала голосом `playPraise` (кожен 2-й — ліміт є) | звук |
| будь-коли | свайп не блокується; M добігає сам | — |

Жодного тексту, жодного оверлею, ≤ 900 мс сумарно. Бульбашки/memory використовують той самий M (N-й лоп, пара) — з тими ж 12 іскрами, тим самим стуком.

### 4.8 Остання картка → пак пройдено — успіх L

Сьогодні: grace 4 с (вірші 6 с) тиші → +1 с → `stop()` + `tada` + `praise` одночасно → оверлей миттєво, `black54`, картка `elasticOut` 600, 40 конфеті 2.5 с, без Bloom, три Material-кнопки з `KidTap.feedback()`.

| t, мс | Що | RM |
|---|---|---|
| −(grace) | Grace-вікно лишається як є — це аудіо-політика (дитина може ще раз тапнути слово); breather 1000 → **600** | так само |
| 0 | `AppRoutes.overlay(CelebrationOverlay(...))` — fade 200 замість миттєвої появи (`cards_screen.dart:504`); dim `DT.textPrimary` α .35 (теплий, картки просвічують) замість `black54`; `tada`; хаптик medium; `AudioService.stop()` — лише якщо ще говорить | dim fade 120; звук |
| 0–420 | картка свята scale 0.85→1 `toy` (замість `elasticOut` 600) | статично |
| 150–450 | обкладинка пака (`CardImage`, 96 dp) 0.8→1 `toy` | статично |
| 0–1200 | конфеті **одна хвиля**: 24 (телефон) / 40 (планшет) частинок з верхньої третини, один `Paint`, `RepaintBoundary` + `IgnorePointer`; за 1200 — все на землі й нуль тікерів | нема |
| 300 | **слот Bloom** M (96 dp) `celebrating` (подвійний стрибок, 1400, потім `idle`); до фази 1 — `BloomMascot(size: 96, emotion: waving)` статично, як у грі | поза |
| 400 | похвала `playPraise(always: true)` — **після** `tada`, не разом (сьогодні одночасно, `cards_screen.dart:476-478`) | звук |
| 600 | кнопки живі: opacity .35→1 за 260 (є гейт, `celebration_overlay.dart:53`); кнопки — `KidTap` навколо вигляду `ElevatedButton` з `IgnorePointer` (як у `game_celebration_overlay.dart:146-168`), «Грати знову» 72 dp | гейт лишається |
| дія | «На головну»: оверлей fade-out 160 → `CardsScreen` pop 220 `leave` → Hero арту поточної картки летить у плитку (4.10). «Грати знову»: `pushReplacement(AppRoutes.kidPage(CardsScreen))` без `heroTag` — fade 280, картка з `resumeIndex` 0 | fade 120 |

Аудіо-таймлайн (0 / 400) фіксований і **не** проходить через `MotionPolicy.dur` — під RM звук той самий. Візуал — один master-контролер 1200 з `Interval`-ами, не сім контролерів і не `Future.delayed`.

Для заблокованого пака (кінець прев'ю) — `_showUnlockDialog` лишається діалогом, це батьківський шит, не свято; хвиля 2 переводить його на `AppRoutes.sheet`.

### 4.9 Автоплей

Сьогодні: кінець слова → 3 с (5 с без звуку/при mute) → цифри в пігулці → `nextPage(400, easeInOut)`. Цифра для 1–4 років нічого не каже.

| t, мс | Що | RM |
|---|---|---|
| 0 = кінець слова | озброєння: на пігулці автоплею замість цифри — **кільце**, що розряджається лінійно 3000 (5000 без звуку). Цифра лишається для батьків малим текстом. Кільце — інформація «зараз перегорнеться», тому лишається під RM | кільце є |
| 3000 − 260 | антиципація: картка нахиляється у напрямку гортання — translateX −10 dp, rotateY −0.02 за 260 `turn`, і з цього положення безперервно переходить у гортання | без нахилу |
| 3000 | `nextPage(motion(context, Motion.page), Motion.settle)` — 380, той самий характер посадки, що у свайпу; хаптик light на 50 % (є) | `nextPage(0)` = jump |
| 3000 + 380 + 120 | слово наступної | слово так само |
| тап по пігулці | пауза (є); тап по картці — слово і рестарт озброєння (є) | так само |

### 4.10 Повернення на головний

| t, мс | Що | RM |
|---|---|---|
| 0 | pointerDown на «назад» 64 dp: хаптик, сквош (є, `_BackButton` на `KidTap`) | хаптик |
| up | `maybePop` → маршрут назад 220 `leave` (fade 1→0, scale 1→0.96); Hero: арт **поточної** картки летить назад у плитку пака (якщо плитка в дереві; якщо грид прокручено і плитки нема — просто fade), cross-fade у обкладинку з 40 % | fade 120 |
| 220 | home у збереженому місці (`IndexedStack` зберігає скрол — є); плитка: прогрес-бар заповнюється 260 `settle`; якщо пак щойно пройдено — бейдж ✓ pop 0→1 за 200 `toy` — слід успіху в каталозі | заповнення, бейдж миттєво |
| dispose | `AudioService.stop()` якщо не `_celebrating` (є) | — |

Таб-перемикання (не частина циклу, але «повернення»): `IndexedStack` лишається, поверх — fade-through 180 (out 0–90, in 90–180) без зсуву контенту — хвиля 2.

---

## 5. Циклічні анімації — вердикт по кожній

Усі 12 `repeat(` уже гейтяться RM. Питання тут — п. 12: чи це підказка дії / стан, чи декор.

| Файл:рядок | Що рухається | Причина за П2 | Вердикт |
|---|---|---|---|
| `widgets/swipe_hint.dart:68` | рука + шеврони, 2000, ∞ до першого свайпу, старт на mount | підказка дії | **Лишити, змінити тригер:** старт після `idleFirst` 4 с, `AmbientLoop(cycles: 3, rearmAfter: idleRepeat, maxSeries: 3)`, per-profile «навчився» (є) |
| `widgets/daily_hero_card.dart:124` | вся картка 1.02 / 1600, ∞ доки `!heroDone` | підказка дії, але вічна | **Замінити на акцент:** 2 вдихи (`intro` 1600) після появи, спокій; повтор 2 вдихи після 8 с бездіяльности на home. `AmbientLoop(cycles: 2, rearmAfter: idleRepeat)` |
| `widgets/daily_hero_card.dart:364` | `_TaskButton` 1.04 / 1200, ∞ доки active | стан «наступний крок» | **Замінити на одноразовий акцент:** при переході в `active` — pop 1→1.06→1 за 200 `toy` + 2 вдихи; далі стан несуть рамка й тінт (є) |
| `widgets/flash_card.dart:137` | слово 1.15 / 1600 доки `isSpeaking` | стан звучання | **Лишити як `SpeakingPulse`:** 1.06 / 900, ease-out 150 на стопі. Обмежено аудіо — не ∞ |
| `widgets/streak_milestone_overlay.dart:82` | полум'я glow/scale 1100, ∞ | декор | **Замінити:** 3 пульси (3300) і спокій у «теплому» стані — як `card_reveal` `repeat(count: 3)` |
| `widgets/quest_journey_map.dart:66` | активна зупинка −3·sin, 3000, ∞ | підказка цілі | **Лишити, обмежити:** 3 цикли після появи/зміни активної зупинки, повтор через `idleRepeat`; це єдиний ambient на екрані мапи |
| `widgets/treasure_card.dart:54` | 🎁 −3 px / 1400, ∞ | декор | **Прибрати петлю:** одноразовий боб (2 підскоки, 600 `reaction`) при зміні `done` і при `allDone` |
| `widgets/speaker_button.dart:69` | кнопка 1.2 / 500 доки `isSpeaking` | стан звучання | **Замінити scale на glow:** `SpeakingPulse(glowOnly: true)` — alpha .25↔.5 у ритмі 900, той самий ритм, що слово. Два різні рухи одного стану (слово 1600 + кнопка 500) — це два стани |
| `screens/onboarding_screen.dart:610` | маскот −8 / 800, стоп через 2 с | вступний акцент | **Лишити** (це зразок); переписати на `AmbientLoop(cycles: 2)` — прибрати `Timer` + `animateTo` |
| `screens/onboarding_screen.dart:916` | `_MagicCard` 1.04 / 1600, ∞ | підказка дії (єдина ціль) | **Замінити на акцент:** 2 вдихи після появи картки, повтор після `idleFirst` 4 с (маля ще не знає, що робити — тут повтор доречний), `maxSeries: 3` |
| `screens/guess_screen.dart:120` | спікер 88 dp 1.15 / 800 доки `isSpeaking` | стан звучання | **Замінити на `SpeakingPulse`** 1.06 / 900 |
| `screens/card_reveal_screen.dart:156` | glow `count: 3`, конфеті `forward()` | підтверджує успіх, обмежено | **Лишити;** період glow 1600 → `Motion.pulse` 900 (3 пульси = 2700 мс) |
| `widgets/streak_chip.dart:55` (`Timer` 30 с) | 2 пульси кожні 30 с | декор | **Прибрати таймер:** 2 пульси лише при зміні `streak` (подія) |
| `widgets/pack_grid_card.dart:73` (`Timer` 30 с) | сезонний shimmer 2 пульси кожні 30 с | підказка «нове» | **Одна серія на появу, без таймера;** ✨-бейдж несе стан |

Після цього на home у спокої — **0** петель (сьогодні 4: hero + task + streak + shimmer); на `CardsScreen` — 0 у спокої, 1 під час слова; на мапі — 1 обмежена. Це і є бюджет §7.

---

## 6. Три святкування → одне

### 6.1 Що є

| | `CelebrationOverlay` (пак) | `showGameCelebration` (ігри ×5) | `showStreakMilestone` (серія) |
|---|---|---|---|
| Файл | `widgets/celebration_overlay.dart` | `widgets/game_celebration_overlay.dart` | `widgets/streak_milestone_overlay.dart` |
| Маршрут | `PageRouteBuilder(opaque:false)` **без переходу** (з `cards_screen:504`) | `showGeneralDialog` fade+scale .85→1, 260 `easeOutBack`, 0 при RM | `showDialog` (системний fade 150) |
| Затемнення | `black54` (0x8A) | `0x66000000` | `black α .55` (0x8C) |
| Вхід картки | scale 0→1 `elasticOut` 600 | у маршруті | scale 0→1 `elasticOut` 600 |
| Звук | у викликача: `stop` + `tada` + `praise` одночасно | усередині: `tada` + `praise(always)` одночасно | **тиша** |
| Bloom | нема | 96 dp `waving` статично | 64 dp `waving` статично |
| Конфеті | 40 падають 2500, `Paint` на частинку на кадр | `ConfettiBurst` 20 з точки, 1000 | нема; полум'я ∞ |
| Кнопки | 3 Material (`NoSplash` + `KidTap.feedback()`), гейт 600 | `KidTap` навколо `ElevatedButton` 72 dp + `TextButton` | `KidTap` навколо `ElevatedButton` |
| RM | конфеті off, картка статична | 0 мс, конфеті off | лише полум'я off |
| Тести | `celebration_overlay_test.dart` (тап по конфеті не закриває; гейт 600; settles) | — | — |

Спільне: біла/сурфейс картка 28 r, заголовок «Молодець!», одна головна дія, ігнор тапу поза кнопками. Різне — все інше, і саме різне дитина зчитує як «п'ять різних апок».

### 6.2 Один компонент

`lib/widgets/celebration.dart`:

```dart
enum CelebrationScale { small, medium, large }

/// small/medium — без маршруту, вставка в Overlay біля origin, самознищення;
/// large — AppRoutes.overlay з картою, Bloom M, конфеті й діями.
Future<void> celebrate(
  BuildContext context, {
  required CelebrationScale scale,
  Offset? origin,                 // small/medium: звідки іскри (позиція Bloom або цілі)
  CelebrationContent content = const CelebrationContent(),
});

final class CelebrationContent {
  const CelebrationContent({
    this.title, this.subtitle, this.childName = '',
    this.hero,                    // Widget? — CardImage обкладинки / медаль; ніколи емодзі-герой
    this.accent = DT.coral,
    this.isEn = false,
    this.actions = const [],      // List<CelebrationAction>: перша — 72 dp головна, решта — текст 15 sp для батька
    this.confetti = true,         // milestone: false
    this.praise = true,           // milestone: false → м'який `ding` pitch .85 замість `tada`
    this.bloom = BloomEmotion.waving, // слот: celebrating після Bloom-фази 1
  });
}
```

Мапа тирів (щоб не з'явився шостий словник): `small` = T0 = `micro`; `medium` = 5 карток / пара / N-й лоп (у `ux-gap` пара — micro; тут пара — medium за брифом власника); `large` = T1 round = T4 pack = `round`, а також T2 `daily` і T3 `milestone` як **контент** `large`, не як окрема хореографія.

Хореографія `large` — §4.8 (0 dim → 420 картка → 150–450 герой → 300 Bloom → 400 похвала → 600 кнопки → 1200 конфеті на землі). `medium` — §4.7. `small` — рядок «Успіх S» §2.3.

### 6.3 Як звести, не зламавши виклики

| Виклик | Стає | Зміна для викликача |
|---|---|---|
| `CelebrationOverlay(packTitle, packIcon, packCover, color, isEn, onShare, onReplay, onDone)` як сторінка маршруту в `cards_screen:506` | Віджет лишається з тією ж сигнатурою; `build` = спільна `_CelebrationCard(scale: large, content: …)`; звук переїжджає всередину (викликач більше не грає `tada`/`praise` — прибрати `cards_screen:475-478`) | `PageRouteBuilder` → `AppRoutes.overlay` (1 рядок) |
| `showGameCelebration(context, isEn, childName, onAgain, onDone, subtitle)` ×5 | Тонка обгортка над `celebrate(scale: large, content: CelebrationContent(title: 'Молодець, $name!', actions: [again, done]))` | 0 |
| `showStreakMilestone(context, milestone, childName, isEn, onCelebrated)` | Обгортка над `celebrate(scale: large, content: CelebrationContent(hero: 🔥-бейдж з 3 пульсами, confetti: false, praise: false, actions: [keepGoing]))`; `await` → `onCelebrated()` (є) | 0 |
| `bubble_pop_screen._CelebrationOverlay` | видаляється на користь `showGameCelebration` (bubble §6 уже так каже) | за bubble-спекою |
| `card_reveal_screen` (T2 daily) | `large` з `hero: CardImage картки` — хвиля 3+, після Bloom | окремо |
| `ConfettiBurst` (mixin, 4 гри) для правильної відповіді | `celebrate(scale: small, origin: центр плитки)` | заміна виклику 1:1 |

Приймальні тести: `celebration_overlay_test.dart` (три сценарії) мають лишитися зеленими без змін — це і є контракт «не зламати». Додаються: `celebrate(large)` під `MotionMode.test` settles за один `pumpAndSettle`; `tada` і `praise` не в одному кадрі (порядок викликів у fake `AudioService`); `medium` не блокує тап по картці (тап під час іскор доходить).

Один `ConfettiPainter` для всіх: передобчислені частинки, один `Paint` (колір через `paint.color =`), палітра `DT`, форми — прямокутник/коло/зірка як дудли на картках; ліміт з `MotionPolicy.particles`. Видаляються `celebration_overlay._ConfettiPainter`, `card_reveal._ConfettiPainter/_BurstPainter`.

---

## 7. Продуктивність (правило № 10: 60 fps на планшетах 2016 року)

### 7.1 Що дорого і що з цим робити — саме в циклі карток

| Дорого сьогодні | Чому | Рішення |
|---|---|---|
| `Opacity(1→0.5)` на кожну сторінку кожен кадр скролу (`cards_screen:853`) | 2–3 `saveLayer` на кадр на весь розмір картки | Прибрати. Глибину дає scale 0.92 + rotateY |
| `Transform(rotateY, scale)` над `FlashCard` з `BoxShadow blur 16` | тінь з blur перерастеризується щокадру під змінною матрицею | `RepaintBoundary` **всередині** `Transform` навколо `FlashCard`: картка растеризується раз, скрол — лише композитор |
| `_entranceCtrl` `elasticOut` 500 на кожен `initState` елемента `PageView` | контролер + тікер на кожну побудовану сторінку, і це видно як «желе» | Видалити (§4.2) |
| Пульс слова `ScaleTransition` над `Text` у `FittedBox` | без boundary тягне перемальовку всієї word-панелі | `RepaintBoundary` навколо `SpeakingPulse` |
| `LinearProgressIndicator` без анімації → з анімацією | дешево (6 dp смуга) | ок, `TweenAnimationBuilder` |
| Hero-політ | `flightShuttleBuilder` з hero-декодом = ще один decode 2.2 МБ під час переходу | Летить **тайлова** картинка (`CardArtSize.tile`, уже в кеші); cross-fade у hero-арт, який `precacheAround` уже гріє |
| Конфеті 40 × 2500 мс, `Paint()` на частинку на кадр (`celebration_overlay:317`) | 40 алокацій × 60 fps × 2.5 с на весь екран | 24/40 × 1200, один `Paint`, `RepaintBoundary` + `IgnorePointer`; після 1200 — нуль тікерів |
| `BoxShadow blurRadius 30` на картці свята під `ScaleTransition` | blur під scale щокадру 420 мс | картка свята під `RepaintBoundary`; blur ≤ 24 у анімованих шарах, ≤ 40 у статичних |

Заборонено в дитячій зоні: `BackdropFilter`, `ShaderMask`, `ImageFilter.blur` (SwipeHint уже це пройшов, `swipe_hint.dart:141-142`), `Opacity` в анімованих піддеревах (→ `FadeTransition`), анімація `width/height` (→ `Transform.scale`), `Random` у `paint()`.

### 7.2 Бюджети

- **Одночасно:** ≤ 2 транзієнтні рухи + ≤ 1 стан звучання на екрані. Виняток — L-свято: dim + картка + конфеті + Bloom = 4 на 1200 мс, далі спокій (це фінальний акцент, П3).
- **У спокої:** 0 тікерів на `CardsScreen` і home (після §5); пізніше +1 — дихання Bloom.
- **Частинки:** ≤ 24 на телефоні (`shortestSide < 600`), ≤ 40 на планшеті; ≤ 1 повноекранний `CustomPaint` одночасно.
- **Тіні:** blur ≤ 24 під анімацією, ≤ 40 статично; `spreadRadius` ≤ 10.
- **Контролери:** ≤ 3 на екран у циклі карток (`_flipCtrl`, `SpeakingPulse`, master свята), не рахуючи `KidTap` (тікер лише під час пресу) — замість сьогоднішніх 3 у `FlashCard` × кожна побудована сторінка.
- **Декод:** Hero і плитки — `tile`; картка — `hero`; ширини мають збігатися з `precacheAround` (є).

### 7.3 `RepaintBoundary` — де саме

1. Всередині `Transform` сторінки `PageView`, навколо `FlashCard` (скрол = композитор).
2. Навколо `SpeakingPulse` у word-панелі.
3. Навколо `CustomPaint` конфеті/іскор (є в `celebration_overlay`, немає в `ConfettiBurst` — додати).
4. Навколо картки L-свята (blur під scale).
5. Навколо `BloomMascot` (у майбутньому — свій тікер).
6. Навколо статичного `_LetterArt` (звукові паки: градієнт + тінь blur 20 під фліпом).

### 7.4 Як вимірювати

- `flutter run --profile` на Android API 28 планшеті і iPad Air 2; DevTools → Performance → Raster під час: свайп 10 карток підряд, фліп ×5, L-свято.
- У profile-збірці: `SchedulerBinding.addTimingsCallback` під час L-свята — частка кадрів > 16.6 мс агреговано в `AnalyticsService` як `celebration_jank_pct` (без ідентифікаторів, COPPA-нейтрально); поріг регресії 5 %.
- Критерій «сцена не перемальовується»: після посадки картки і кінця слова у профайлері 0 repaint протягом 5 с.

---

## 8. Хвилі і hand-off

S ≤ ½ дня, M 1–2 дні, L 3+.

### Хвиля 1 — `motion.dart` + головний цикл карток (S / M / L)

| # | Що | Хто | Розмір |
|---|---|---|---|
| 1.1 | `motion.dart`: `MotionPolicy`, `MotionScope`, `motion()`, `Motion` (§3); `KidTap.spring → Motion.spring`; прибрати `DT.pressMs` (заміна в `packs_tab:1242`) | flutter-dev | S |
| 1.2 | `AmbientLoop`, `SpeakingPulse` (§3) + тести: під `MotionMode.test` `pumpAndSettle` завершується; `cycles` виконуються рівно N разів | flutter-dev + qa | M |
| 1.3 | `AppRoutes.kidPage/overlay`; `pageTransitionsTheme` у `main.dart` на той самий fade+scale, щоб 13 `MaterialPageRoute` виглядали однаково до міграції | flutter-dev | S |
| 1.4 | Hero плитка → активна картка (§4.1) з `HeroMode`, `flightShuttleBuilder` на тайловому декоді, зворотний політ (§4.10); `packs_tab._onPackTap` ×3 на `AppRoutes.kidPage` | flutter-dev | M |
| 1.5 | `CardsScreen`: прибрати `Opacity`, `RepaintBoundary` у `Transform`, `viewportFraction .88`, `CardPhysics` (§4.4), слово на `ScrollEnd + quick`, прогрес-бар анімований, `pop` посадки | flutter-dev | M |
| 1.6 | `FlashCard`: видалити `_entranceCtrl`; фліп 320 `turn` + підйом; чип 🇬🇧 → `KidTap`; пульс → `SpeakingPulse`; бейдж-серце pop | animator (таймінги) + flutter-dev | S |
| 1.7 | Успіх M кожні 5 вперед (§4.7): лічильник, `ding`-драбинка, іскри від Bloom, стук бару; дедуп із квест-кроком | flutter-dev | S |
| 1.8 | Успіх L (§4.8): `AppRoutes.overlay`, dim `textPrimary` α.35, `toy` 420, конфеті 24/40 × 1200 одним painter-ом, звук усередині (tada 0 / praise 400), Bloom M слот, кнопки на `KidTap` | flutter-dev | M |
| 1.9 | Автоплей (§4.9): кільце замість цифри для дитини, антиципація 260, `nextPage` через `motion()` | flutter-dev | S |
| 1.10 | `SwipeHint` на idle (§4.5) через `AmbientLoop`; «підглядання» картки | flutter-dev | S |
| 1.11 | Місце Bloom S на `CardsScreen` (кут поза карткою), колір dim, вигляд кільця автоплею і пігулки лічильника | ux-kids | S |
| 1.12 | Прогрів наступного аудіо-кліпу на `onPageChanged` (один файл) — так/ні | perf | S |
| 1.13 | Тести хвилі 1 (нижче) | qa | M |

**Що тестує `qa` у хвилі 1** (зразки: `test/widgets/kid_tap_test.dart` — семплінг пружини через `pump(10 мс)×30`; `celebration_overlay_test.dart` — гейт через `pump(300)` / `pump(400)`; `card_reveal_settles_test.dart` — RM):

- **Прес** — існуючий `kid_tap_test` без змін (контракт `DT.pressDownMs/pressScale`).
- **Фліп:** тап по чипу → `pump()` → `pump(Motion.flip ~/ 2)` → лице не знайдено (`_showBack`), `pump(Motion.flip ~/ 2)` → зворот; під `MotionScope(test)`: після одного `pump()` — зворот одразу.
- **Слово після посадки:** fake `AudioService` (лічильник `speakCard`); `fling` → `pump(Motion.page)` → 0 викликів; `pump(Motion.quick)` → 1. Під `test` — той самий порядок (посадка миттєва, слово через 120 — це не motion).
- **Опасіті прибрано:** `find.descendant(of: PageView, matching: byType(Opacity))` → `findsNothing`.
- **M кожні 5:** 5 свайпів вперед → один `ding`; 4 → нуль; «Продовжити» з індексу 7 → `ding` на 12-му.
- **L:** три існуючі тести `celebration_overlay_test.dart` зелені; `tada` і `praise` — різні кадри (`pump(Motion.enterBig)` між ними); `pumpAndSettle(100)` завершується (одна хвиля конфеті).
- **Hero:** `find.byType(Hero)` — рівно один на екрані карток (тільки активна картка); під `test` — `HeroMode.enabled == false`.
- **AmbientLoop:** `cycles: 2, period: 800` → після `pump(1600)` `t == restValue` і тікер не активний; під `test` — `pumpAndSettle` без таймауту.
- **Source-тест `test/architecture/motion_test.dart`** (зразок `asset_access_test.dart`): (a) `Duration(milliseconds:` поза `motion.dart`/`design_tokens.dart`/`audio_service.dart` — лише в allowlist поточних 33 файлів, який **тільки зменшується** (тест падає, якщо файл з allowlist більше не порушує — щоб список чистили); (b) `.repeat(` лише в `ambient_loop.dart`, `speaking_pulse.dart` (+ тимчасовий allowlist §5 до хвилі 3); (c) `MaterialPageRoute(|PageRouteBuilder(` лише в `app_routes.dart`, `paywall_flow.dart`, `splash_screen.dart` (+ allowlist до хвилі 2); (d) `Curves.elasticOut` — allowlist поточних 7, зменшується до 0.

### Хвиля 2 — усі екрани на нову мову

| # | Що | Хто | Розмір |
|---|---|---|---|
| 2.1 | 26 маршрутів → `AppRoutes` (`kidPage` для паків/ігор/квесту, `sheet` для пейволу/дашборду/розблокування); `_gameRoute` з `games_tab` переїжджає | flutter-dev | M |
| 2.2 | Fade-through табів 180 поверх `IndexedStack` | flutter-dev | S |
| 2.3 | Решта `KidTap`-міграції з motion-аудиту §6 (чипи, `_TileWidget`, `_OptionTile`, `_CardChip`, спікер 88 dp, кнопки онбордингу) | flutter-dev | M |
| 2.4 | Один індикатор звучання: `guess_screen`, `speaker_button`, `_MagicCard` → `SpeakingPulse` | flutter-dev | S |
| 2.5 | Один м'який промах: `QuizOption._shakeCtrl` (±10, 500, меандр) і `ShakeAnimationMixin` (±14, 380) → нахил ±3° 320 `breathe` в міксині (`Transform.rotate` замість `translate`), `QuizOption` на міксин; без червоного | animator + flutter-dev | S |
| 2.6 | Поява списків: грид паків, плитки ігр, опції — `Motion.base` + stagger 40, ≤ 9 | flutter-dev | S |
| 2.7 | `Duration`-літерали → токени у 33 файлах; allowlist (a) до нуля; `Future.delayed` у грах → події аудіо (`await speakCard`, `isSpeaking`) | flutter-dev | M |
| 2.8 | Ігрові спеки bubble/memory виконуються **з токенами §2.5** (правки таблиць у самих спеках — 1 абзац кожна) | ux-kids | S |
| 2.9 | `HapticFeedback.*` з віджетів → `KidTap`/`FeedbackService` (architecture F3) | flutter-dev | S |

### Хвиля 3 — святкування в одне, циклічні прибрати

| # | Що | Хто | Розмір |
|---|---|---|---|
| 3.1 | `celebration.dart` + `CelebrationScale`; три обгортки (§6.3); один `ConfettiPainter`; видалити два дублі painter-ів і `bubble._CelebrationOverlay` | flutter-dev | M |
| 3.2 | Вердикти §5 через `AmbientLoop`: hero/task/treasure/streak/shimmer/magic/milestone; allowlist (b) до двох файлів | flutter-dev | S |
| 3.3 | `card_reveal_screen` → `celebrate(large)` з master-контролером замість 7 | flutter-dev | M |
| 3.4 | Bloom-фаза 1 підключається у слоти §4 (`listening`, `happy`, `celebrating`) — за `bloom_character.md` | flutter-dev + animator | за окремою спекою |
| 3.5 | Профіль на планшеті 2016: свайп, фліп, L; `celebration_jank_pct` | perf | S |
| 3.6 | Golden-и `Celebration` трьох масштабів під `MotionMode.test`; source-тести (a)–(d) без allowlist | qa | M |

---

## 9. Рішення, потрібні від власника

1. Поріг перегортання 35 % замість 50 % і `minFlingVelocity` 300 px/с замість 50 — гіпотеза «прощення жесту» (правило 3: повільний дотяг рахується, випадковий смик — ні); перевірити на 3–5 дітях до фіксації.
2. Кільце-таймер автоплею замість цифри для дитини (цифра лишається батькам) — зміна вигляду пігулки, яка сьогодні у «не чіпати» ігрових спек за аналогією.
3. Успіх M саме на **5** карток (а не 3 для L1 / 7 для L3) — стартове число; за віком можна розвести пізніше через `ProfileModel.level`, як у memory §6.
4. Прогрів одного наступного аудіо-кліпу — межа з правилом «не повертай eager precache».
5. Dim свята `DT.textPrimary` α .35 — це рішення `ux-gap` G3; підтвердити, бо змінює всі три святкування одразу.
