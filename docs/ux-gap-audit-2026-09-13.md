# UX gap-аудит «Картки-розмовлялки» проти планки 9/10 — 2026-09-13

Автор: ux-kids. Мета власника: з 4/10 до рівня Duolingo ABC / Khan Academy Kids / Sago Mini (8–10/10): власні дитячі іконки, живий маскот, радісні екрани «ура», підбадьорення, єдина ігрова візуальна мова.

Матеріал: код усіх `lib/screens/*.dart`, `lib/tabs/*.dart`, ключових `lib/widgets/*` (bloom_mascot, playful_navigation_bar, kid_tap, pack_grid_card, daily_hero_card, treasure_card, quest_journey_map, game_celebration_overlay, celebration_overlay, streak_milestone_overlay, confetti_burst, flash_card, quiz_option, speaker_button, swipe_hint, streak_chip, parental_gate, notification_opt_in_dialog, content_download_view, card_image, bubble_pop), `design_tokens.dart`, `constants.dart`, `main.dart`, `pubspec.yaml`, `assets/data/uk_cards.json` (іконки паків). Без запущеного пристрою — це аудит реалізації, не живої збірки.

Спирається на і НЕ повторює: `docs/design-audit-2026-09-08.md` (30 знахідок; далі «А1-№»), `docs/experience-audit-2026-09-13.md` (28 пунктів; далі «А2-№»), `docs/design/bubble_pop_redesign.md` і `docs/design/memory_match_redesign.md` (готові специфікації двох ігор — тут лише посилання).

---

## 0. Резюме

**Що вже зроблено після А1 (і тому не входить у gap):** `KidTap` (хаптик + pop + scale 0.96) на плитках паків, чипах, таб-барі, плитках ігр; back 64dp у CardsScreen; таймер і 🧠 винесені в long-press батьківський шит; серце → long-press; слово на картці через `DT.onTint` і Nunito; swipe-hint у кольорі паку, per-profile; детермінований порядок карток + resume; About за гейтом; magic moment «дихає», маскот завмирає через 2 с; «You did it» без модалки; welcome/нагадування прибрані з першої сесії; coloring без негативних емоцій + постійна 72dp кнопка; streak від 2; hint лише для non-Pro; landscape на планшетах; власний `PlayfulNavigationBar` з трьома намальованими іграшками; нова `QuestJourneyMap` з ландшафтом.

**Де апка сьогодні (моя оцінка 5.3/10 по дитячій зоні, 6.5/10 по батьківській).** Візуально є два «острови 8/10»: акварельні ілюстрації карток і нова навігаційна панель / мапа квесту. Все інше — Material-каркас навколо них: `AppBar` з текстовим заголовком у шести іграх, стандартні `IconButton` 48dp, `ElevatedButton`, `LinearProgressIndicator`, `SnackBar`, `Dialog`. Три мови іконок (емодзі / Material / три власні) — це головна причина відчуття «4/10» у власника: око не бачить одного автора.

**Три системні розриви до 9/10:**

1. **Немає системи іконок.** 21 іконка паків — емодзі й кириличні літери в JSON (`"icon": "🐾"`, `"Р"`); бейджі ігр — емодзі (🎧🧠🫧🎤🔍↔️👅); кроки дня — 🔊🃏🗺️; зупинки квесту — `Icons.hearing_rounded`, `Icons.collections_rounded`…; нагороди — 🔥🎁🏆⭐❓🔒; аватари — емодзі. У Khan Kids і Sago Mini кожна іконка — міні-ілюстрація в стилі контенту.
2. **Bloom — статуетка, не персонаж.** Два стани (`happy`, `waving`), очі завжди закриті, жодного idle/blink, не реагує на звук, на правильну/неправильну відповідь, з'являється у 6 місцях (онбординг, банер скарбнички 44dp, word wall, 3 фінальні діалоги) і відсутній там, де дитина проводить 90 % часу: home hero, CardsScreen, усі ігрові дошки, coloring, мапа. Голосу немає — `praise_*.mp3`/`instr_*.mp3` не згенеровані, тож `playPraise`/`playInstruction` мовчать у всій апці.
3. **П'ять різних «свят» і одне мовчання.** `CelebrationOverlay` (пак: black54, ⭐ 48px, три Material-кнопки), `showGameCelebration` (0x66, Bloom, «Ще раз»), `_CelebrationOverlay` у бульбашках (0xCC, свій шаблон), `_MilestoneDialog` (🔥 64px), `CardRevealScreen` (темний фон, безкінечне конфеті + glow — А2-12). Мікро-фідбек — один `ConfettiBurst` на 20 прямокутників. Звук — синтезовані заглушки `pop/ding/tada` (`audio_service.dart:750`). На помилку — shake і, у двох іграх, червона рамка з ❌.

Далі — матриця, 15 розривів з планом і бриф візуального напряму.

---

## 1. Шкала і осі

| Ось | Що міряю | 9–10 | 5 | 1–3 |
|---|---|---|---|---|
| **V** Візуальна ідентичність | власна графіка vs Material/емодзі; колір; форми; шрифт | усе намальоване в одному стилі, Nunito/Fredoka, DT-палітра | ілюстрації свої, хром Material, емодзі як іконки | системний Material без адаптації |
| **C** Присутність персонажа | чи є маскот, чи реагує, чи веде | персонаж живий, реагує на кожну дію, підказує | статичний маскот у діалозі | немає |
| **M** Motion і фідбек | press, entrance, transitions, звук+хаптик на кожен тап | 3 фідбеки скрізь, spring, ≤2 одночасні анімації, звук на все | press-scale є, звук частково, переходи системні | без реакції |
| **F** Свято / підбадьорення | success, mistake, completion | tiered, персонаж, голос, безпечна помилка | конфеті + текст «Молодець» | нічого або червоне ❌ |
| **K** Kid-legibility | ≥72dp, без тексту, оперує 2-річний | всі таргети ≥72, нуль тексту в дитячій зоні | таргети змішані 48–72, текст-інструкції | текстовий UI |
| **P** Батьківська зона | там де є: читабельність, гейт, чесність | — | — | — |

---

## 2. Матриця (екран × ось)

Оцінки 1–10. «—» — ось не застосовна. Обґрунтування по одному рядку на ось — у §3.

| # | Екран / компонент | Файл | V | C | M | F | K | P | Сер. |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Splash | `screens/splash_screen.dart` | 5 | 1 | 4 | — | 7 | — | 4.3 |
| 2 | Onboarding: setup + вік | `screens/onboarding_screen.dart` | 4 | 2 | 4 | — | 6 | 7 | 4.6 |
| 3 | Onboarding: magic moment | `onboarding_screen.dart` `_MagicMomentPage` | 7 | 6 | 7 | 6 | 8 | — | 6.8 |
| 4 | Home shell + PlayfulNavigationBar | `screens/home_screen.dart`, `widgets/playful_navigation_bar.dart` | 8 | 1 | 7 | — | 8 | — | 6.0 |
| 5 | PacksTab: хедер + чипи + грид | `tabs/packs_tab.dart`, `widgets/pack_grid_card.dart` | 5 | 2 | 6 | 3 | 6 | 6 | 4.7 |
| 6 | DailyHeroCard (hero + кроки дня) | `widgets/daily_hero_card.dart` | 4 | 1 | 5 | 3 | 4 | — | 3.4 |
| 7 | TreasureBoxBanner / TreasureCard | `packs_tab.dart`, `widgets/treasure_card.dart` | 4 | 4 | 4 | — | 5 | — | 4.3 |
| 8 | CardsScreen + FlashCard + Speaker + SwipeHint | `screens/cards_screen.dart`, `widgets/flash_card.dart`, `speaker_button.dart`, `swipe_hint.dart` | 7 | 1 | 7 | 4 | 7 | 7 | 5.5 |
| 9 | CelebrationOverlay (пак пройдено) | `widgets/celebration_overlay.dart` | 3 | 1 | 5 | 4 | 4 | — | 3.4 |
| 10 | Unlock dialog (кінець превʼю) | `cards_screen.dart` `_showUnlockDialog` | 3 | 1 | 3 | — | 3 | 6 | 3.2 |
| 11 | GamesTab | `tabs/games_tab.dart` | 6 | 1 | 6 | — | 5 | 6 | 4.8 |
| 12 | GuessScreen + QuizOption | `screens/guess_screen.dart`, `widgets/quiz_option.dart` | 4 | 1 | 6 | 5 | 6 | — | 4.4 |
| 13 | MemoryMatch | `screens/memory_match_screen.dart` (є спека) | 3 | 1 | 5 | 5 | 6 | — | 4.0 |
| 14 | BubblePop | `screens/bubble_pop_screen.dart` (є спека) | 5 | 2 | 7 | 6 | 7 | — | 5.4 |
| 15 | RepeatGame | `screens/repeat_game_screen.dart` | 3 | 1 | 4 | 4 | 3 | 6 | 3.5 |
| 16 | OddOneOut | `screens/odd_one_out_screen.dart` | 3 | 1 | 4 | 3 | 4 | — | 3.0 |
| 17 | OppositeGame | `screens/opposite_game_screen.dart` | 3 | 1 | 4 | 3 | 4 | — | 3.0 |
| 18 | Articulation | `screens/articulation_screen.dart` | 2 | 1 | 4 | 4 | 2 | 6 | 3.2 |
| 19 | Coloring | `screens/coloring_screen.dart` | 5 | 1 | 6 | 5 | 6 | 5 | 4.7 |
| 20 | QuestMap + QuestJourneyMap + PackPicker | `screens/quest_map_screen.dart`, `widgets/quest_journey_map.dart` | 7 | 1 | 6 | 4 | 5 | — | 4.6 |
| 21 | CardRevealScreen | `screens/card_reveal_screen.dart` | 5 | 1 | 6 | 6 | 4 | — | 4.4 |
| 22 | GameCelebrationOverlay | `widgets/game_celebration_overlay.dart` | 5 | 5 | 6 | 5 | 7 | — | 5.6 |
| 23 | StreakMilestoneOverlay | `widgets/streak_milestone_overlay.dart` | 4 | 4 | 5 | 5 | 5 | 6 | 4.8 |
| 24 | KidWordWall (Скарбничка) | `screens/kid_word_wall_screen.dart` | 5 | 4 | 6 | — | 6 | — | 5.3 |
| 25 | BloomMascot (компонент) | `widgets/bloom_mascot.dart` | 6 | 3 | 4 | — | — | — | 4.3 |
| 26 | ContentDownloadView | `widgets/content_download_view.dart` | 4 | 1 | 3 | — | 7 | 8 | 4.6 |
| 27 | Paywall | `screens/paywall_screen.dart` | 5 | 1 | 4 | — | — | 7 | 4.3 |
| 28 | ParentDashboard | `screens/parent_dashboard_screen.dart` | 5 | 2 | 4 | — | — | 7 | 4.5 |
| 29 | Stats + Rewards | `screens/stats_screen.dart`, `rewards_screen.dart` | 3 | 1 | 3 | 3 | 3 | 5 | 3.0 |
| 30 | ProfileSelector + ParentalGate + Notif opt-in + About | `screens/profile_selector_screen.dart`, `widgets/parental_gate.dart`, `notification_opt_in_dialog.dart`, `packs_tab.dart` `_showAbout` | 4 | 1 | 4 | — | — | 7 | 4.0 |

**Середнє дитячої зони (1–26): ≈4.6. Батьківської (27–30): ≈6.8 за P, ≈4.3 за V.** Найкращі: нав-бар, мапа, CardsScreen, magic moment. Найгірші: RepeatGame, OddOneOut, Opposite, Articulation, Stats/Rewards, DailyHeroCard.

---

## 3. Обґрунтування по екранах (один рядок на ось)

### 1. Splash
- V 5 — статичний `splash.webp` 280dp у `ClipRRect(64)` + стандартний `CircularProgressIndicator` (kAccent); бренд є, стилю «дитячого старту» немає.
- C 1 — Bloom відсутній; перший екран апки без персонажа.
- M 4 — fade+scale 600ms easeOutBack; далі спінер Material; немає переходу «маскот прокидається».
- K 7 — нічого тапати, нічого читати; ок.

### 2. Onboarding: setup + вік
- V 4 — `TextField` з `OutlineInputBorder`, емодзі-аватари 26sp у сірих квадратах, 🎂 64sp, кнопка `ElevatedButton`; Roboto; це анкета, не гра.
- C 2 — маскота на цих сторінках немає (він з'являється лише на magic moment).
- M 4 — `AnimatedContainer` 150–200ms на вибір, `HapticFeedback.selectionClick`, без звуку; сторінки гортаються стандартним `PageView` 350ms.
- K 6 — вікові тайли ≈165×143dp (еталон), але аватари ~50dp; це дорослі сторінки — прийнятно.
- P 7 — імʼя необовʼязкове, вік визначає контент; чесно.

### 3. Onboarding: magic moment
- V 7 — картка `colorBg` + 3dp рамка акценту, слово Nunito 900 `onTint`, баббл білий 20r; але баббл — текст 15sp, а дитина не читає.
- C 6 — Bloom 96dp waving, бобає 2 с і завмирає (правильно), баббл тексту; не реагує на тап картки, не «слухає» слово, «You did it» лишається текстом у бабблі.
- M 7 — breath 1.04/1600ms, press-scale, слово 1.08 під час `isSpeaking`, `AnimatedSwitcher` easeOutBack; хаптик medium; звук — саме слово (це і є фідбек).
- F 6 — конфеті + `playPraise` (мовчить, файлів нема) + авто-перехід 1.6 с; без голосу похвала неповна.
- K 8 — одна ціль, ≥220dp, центр; підпис «Натисни на картку…» 16sp зайвий для дитини (лишити для батька — ок).

### 4. Home shell + PlayfulNavigationBar
- V 8 — три власні намальовані іграшки (книжки/стілець-ігри/палітра), тінт активного таба, білий контур, Nunito 13sp — саме та мова, яку треба поширити на всю апку.
- C 1 — на home персонажа немає, окрім 44dp у банері скарбнички (з'являється лише після 1 «вивченого» слова).
- M 7 — press .93, slide+scale активного, `KidTap.feedback` при перемиканні; `IndexedStack` без переходу між табами (для дітей ок).
- K 8 — таб ≥76dp, 3 таби, лейбли 13sp (для батьків ок, дитина обирає за іконкою).

### 5. PacksTab (хедер, чипи, грид)
- V 5 — заголовок «🗣️ Картки-розмовлялки» 19sp bold Roboto з емодзі; чипи з емодзі 💬🔤🌍 + текст; `PackGridCard` білі плитки з ілюстрацією (добре), титул 12.5sp `accent` (контраст ≈2.6–3:1, А1-3 не виправлено для титулів), бейджі — Material `lock/check` + емодзі ✨; `(i)` сіра Material-іконка.
- C 2 — нема; порожній стан помилки — 🐢 емодзі.
- M 6 — KidTap на плитках і чипах, wobble на long-press, seasonal shimmer бурстами, амбієнтні бульбашки на тап у порожнє місце (Sago-style — гарно); але жодного entrance stagger для гриду, `MaterialPageRoute` у CardsScreen без Hero.
- F 3 — completed = 13px зелена галочка `#22C55E`; жодної реакції гриду на щойно завершений пак.
- K 6 — плитки ≈103–118dp (А1-12 не виправлено: 3 колонки на телефоні), чипи 56dp (<72), `(i)` 48dp біля краю; титули читає батько.
- P 6 — About-шит за гейтом, long-press на (i) — ок; Material `SettingsActionRow`.

### 6. DailyHeroCard
- V 4 — бейдж 10sp `accent` на тінті (нижче AA), титул 21sp Roboto w900, play — `Icons.play_arrow_rounded` у 38dp кружку, кроки — емодзі 22sp + текст 12sp; типовий Material-card.
- C 1 — немає; це головний блок home і найкраще місце для Bloom-запрошення.
- M 5 — пульс 1.02/1600 repeat (єдиний дозволений — ок), press-scale, хаптик light; **без sfx** (не через KidTap); `_TaskButton` — те саме.
- F 3 — heroDone = зелена галочка; allDone = «Все на сьогодні готово! 🎉» 14sp текст. Жодного руху/звуку при виконанні кроку.
- K 4 — ілюстрація 78–94dp, play 38dp, кроки 54dp — усе нижче 72 (А1-10 не виправлено); підписи кроків текстові.

### 7. TreasureBoxBanner / TreasureCard
- V 4 — градієнт kAccent→kTeal (індиго→бірюза, поза DT-палітрою), Bloom 44dp, `Icons.chevron_right`; `TreasureCard` — 🎁/🏆 емодзі в `CircularProgressIndicator`-кільці.
- C 4 — Bloom є, але декоративний, `interactive: false`, не реагує на зростання лічильника.
- M 4 — хаптик light без sfx; bob −3px repeat forever (А2-12).
- K 5 — банер ≈64dp високий, текст 11–12sp; число 22sp — читабельне.

### 8. CardsScreen + FlashCard + SpeakerButton + SwipeHint
- V 7 — картка біла 20r з ілюстрацією 68 %, слово Nunito 900 `onTint` (72sp для літер — сильно); але хедер — `AppBar` з емодзі паку 24sp + титул Roboto, лічильник «3/24» 16sp, `LinearProgressIndicator` 6dp; спікер `kTeal`/`kSoundRed` (кольори поза DT), чип «🇬🇧 English ↻» 12sp сірий.
- C 1 — Bloom відсутній на екрані, де дитина проводить найбільше часу.
- M 7 — press 0.95, pulse слова під звук, entrance elasticOut, 3D-нахил сторінок, хаптик на page change, дебаунс 500ms; back через KidTap; **SpeakerButton без хаптика/sfx**; flip 400ms.
- F 4 — на останній картці — `CelebrationOverlay` (див. №9); між картками жодного «ще одна!»; long-press серце — pop + хаптик, бейдж з'являється (ок).
- K 7 — back 64dp (<72, але прийнятно), спікер 56dp (<72), картка величезна; лічильник і титул — текст, але для батьків.
- P 7 — long-press на титулі → батьківський шит (Автогортання, Memory) — правильний патерн; банер превʼю з кнопкою «Розблокувати» 36dp у дитячій зоні без гейту (А1-15 частково: тап на замок → превʼю, але кнопка у банері й «Розблокувати все» в діалозі — без гейту).

### 9. CelebrationOverlay (пак пройдено)
- V 3 — `Colors.black54` фон, ⭐ емодзі 48sp, «Молодець!» 32sp Roboto bold, три `ElevatedButton/OutlinedButton` з Material-іконками `replay/share`, кнопка «Поділитись 🎉» бірюзова.
- C 1 — Bloom відсутній (у `showGameCelebration` він є — непослідовно).
- M 5 — elasticOut 600ms, конфеті 2.5 с 40 частинок (падіння); без звуку взагалі (немає `tada`, немає praise).
- F 4 — це найважливіше «ура» апки (пак пройдено, перший раз → review) і воно найбідніше з п'яти реалізацій.
- K 4 — три текстові кнопки ~52dp; Share у дитячій зоні без гейту (обхід: рейтинг 4+, але CLAUDE.md п.7 каже гейт).

### 10. Unlock dialog (кінець превʼю)
- V 3 — стандартний `Dialog`, іконка паку емодзі 56sp, ряд емодзі превʼю, Roboto.
- C 1 — немає.
- M 3 — системна поява діалогу, без звуку.
- K 3 — дитина бачить текст «Сподобалось? Ще 12 карток чекають!» і кнопку покупки без гейту.
- P 6 — «Може пізніше» видиме; чесно.

### 11. GamesTab
- V 6 — плитки з ілюстрацією + тінт + подвійна тінь (гарно), але бейджі — емодзі 🎧🧠🫧🎤🔍↔️ у білих колах, 🔒 емодзі, `AppBar` «🎮 Ігри», секції з емодзі 🧸👨‍👧🎓, «Артикуляційна» — `ListTile` з `Icons.record_voice_over` (А1-24 не вирішено).
- C 1 — немає.
- M 6 — press 0.96 + KidTap.feedback, `_gameRoute` fade+scale 260ms (єдиний нестандартний перехід у апці — правильний напрям); без entrance stagger.
- K 5 — плитки великі; але підзаголовки 12sp, «1–3 роки / 3+ / мовленнєва терапія», заблокована → `SnackBar` з текстом (А1-23 частково: є sfx, але текст лишився).
- P 6 — lockedHint пояснює що купити; веде в paywall без гейту.

### 12. GuessScreen + QuizOption
- V 4 — `AppBar` з `Icons.arrow_back_ios` 48dp + «🎧 Вгадай звук» текст; спікер 88dp kAccent з `Icons.volume_up`; опції — тінт `colorBg` 24r, слово **`kSoundRed` (#D63031) хардкод** (А1-19 залишилось тут), правильна = `kTeal`.
- C 1 — немає.
- M 6 — спікер пульсує під звук, press 0.92, shake на помилку, конфеті-burst; хаптик лише в результаті, не на dotDown; `ding` — заглушка.
- F 5 — правильно: ding + praise (мовчить) + конфеті + 800ms далі; помилка: light хаптик, повтор слова — гуманно; фінал — `showGameCelebration`.
- K 6 — опції великі (2×2), back 48dp у куті; прогрес-бар без тексту — добре.

### 13. MemoryMatch
- V 3, C 1, M 5, F 5, K 6 — повністю покрито `docs/design/memory_match_redesign.md` (сорочка з печаткою Bloom, BoardTheme, «стіл»). Тут не дублюю; лише фіксую: `#FAFAFF` фон, `#4CAF50` третій відтінок зеленого в апці, `IconButton` back 22px.

### 14. BubblePop
- V 5, C 2, M 7, F 6, K 7 — повністю покрито `docs/design/bubble_pop_redesign.md` (лука, Bloom з паличкою, `BoxFit.cover`). Фіксую сильне: `_PraiseFlash` 52sp Nunito — зразок мікро-свята без діалогу; X 56dp + пігулка «7/20».

### 15. RepeatGame
- V 3 — `AppBar` текст, фон `#EAFFF5` (поза DT), картка `colorBg` 28r, слово 34sp Roboto `colorAccent` (контраст ≈2.5:1), «Натисни, щоб послухати» 11sp `grey[400]` (контраст ≈1.9:1), дві Material-кнопки з емодзі ❌✅.
- C 1 — немає, хоча це гра «разом з дорослим» — ідеальне місце для Bloom, що «слухає».
- M 4 — exit slide 320ms, shake на «не вийшло», хаптик; без sfx на кнопки; крапки прогресу 8–10dp.
- F 4 — правильно: конфеті 1.4 с (без звуку — praise мовчить, ding не грає); практичний раунд помилок — гарна педагогіка без покарання.
- K 3 — «Скажи: «Кіт»» 16sp — інструкція для дорослого посеред дитячого екрана; кнопки ~54dp; ❌ на кнопці читається як «погано».
- P 6 — А2-21 (чесна спільна гра) актуально; є «Не вийшло», нема «разом з дорослим» маркера.

### 16. OddOneOut
- V 3 — `AppBar` текст, фон `#F0EEFF`, мініатюри 44dp + ❓ 36sp, «Яка картка зайва?» 15sp, плитки `colorBg`, слово 13sp, **правильна = `#E8F5E9`/`#43A047` + ✅, неправильна = `#FFEBEE`/`#E53935` + ❌**.
- C 1 — немає.
- M 4 — shake, конфеті-burst, хаптик; без press-scale на плитках, без sfx на тап (є слово).
- F 3 — червона рамка + ❌ на помилку суперечить «forgiving»; фінал через `showGameCelebration`.
- K 4 — плитки великі, але 44dp підказки і текстове питання; back 48dp Material.

### 17. OppositeGame
- V 3 — те саме, що №16: `AppBar`, `#F8F0FF`, ↔️ емодзі + «Що протилежне?» 14sp `grey[600]`, «торкнись» 11sp `grey[400]`, зелений/червоний ✅❌.
- C 1 — немає.
- M 4 — `AnimatedSwitcher` 300ms, shake, конфеті; без press-scale; `_OptionTile` без хаптика на тап.
- F 3 — правильно: ding + praise (мовчить) + слово-пара (гарна педагогіка); помилка: ❌ і червоне 1.3 с.
- K 4 — опції горизонтальні 80dp-картинка + текст 22sp; питання текстове; back 48dp.

### 18. Articulation
- V 2 — 👅🪡🕐🎠🍄 емодзі 40–128sp як ілюстрації, `kAccent` тінти, `ListView` кроків з номерами в кружках, `CircularProgressIndicator` таймер.
- C 1 — немає.
- M 4 — bounce емодзі 1.25 на реп, конфеті, хаптик; кнопки Material 64dp.
- F 4 — «🎉 Молодець! Виконано 5 разів!» текст; без звуку.
- K 2 — це повністю текстовий екран (кроки читає батько — задум), але він живе в дитячому табі «Ігри».
- P 6 — банер «Батьки читають вголос» чесний; місце екрана — батьківський дашборд або окремий режим «разом» (А1-24).

### 19. Coloring
- V 5 — механіка проявлення — сильна; але `AppBar` «Розмальовки водою», інструкція 14sp `grey.shade700`, фон `#F7F2FF`, кнопка `Icons.shuffle_rounded` у `DT.violet` (єдина 72dp кругла кнопка з DT — правильно), done-bar з 🎉 емодзі; `_PaywallGate` — 🎨 96sp + 💎.
- C 1 — немає (А1-26 пропонував Bloom + анімовану руку замість тексту — не зроблено).
- M 6 — reveal fade 550ms, done-bar slide easeOutBack, `pop` + хаптик на «нова картинка»; спінер Material під час завантаження.
- F 5 — конфеті + слово при 85 %; без praise-голосу, без Bloom; після 3 малюнків — пейвол у дитячій зоні без гейту.
- K 6 — кнопка 72dp, канвас на весь екран; текстова інструкція зайва.
- P 5 — пейвол-гейт всередині дитячого табу, `Tooltip` для батьків — ок.

### 20. QuestMap + QuestJourneyMap + PackPicker
- V 7 — намальований ландшафт (`_LandscapePainter`: пагорби, стежка з пунктиром, дерева), Nunito, градієнтні «камені» зупинок з білим обідком — це другий острів якості. Але іконки зупинок — **Material** (`hearing`, `collections`, `music_note`, `star`, `record_voice_over`, `redeem`, `explore`), скарб — `Icons.redeem` + `lock`; `_PackPickerSheet` — емодзі 28sp + текст 11sp + «5/24» 10sp `grey[400]`; snackbar «🎉 Усі паки вже відкрито».
- C 1 — на мапі немає мандрівника; активна зупинка бобає, а Bloom мав би стояти на ній.
- M 6 — bob активної ±3px 3 с (єдиний loop, gate `disableAnimations` — правильно), press .92 120ms, хаптик; без sfx; `AnimatedContainer` 350ms смужок прогресу; вхід у зупинки — `MaterialPageRoute`.
- F 4 — заверши 5 → `CardRevealScreen`; проміжних «ура» при завершенні зупинки немає (повернувся — камінь просто зелений).
- K 5 — камені 76×62dp (<72 по висоті), лейбли 14sp + статус 10sp текст «Заверши 5 зупинок»; заголовок «Маленькі кроки до скарбу» 14sp і «2/5».

### 21. CardRevealScreen
- V 5 — темний фон з пакового кольору, промені, конфеті — «казино-стиль», відірваний від теплої паперової апки; конверт — градієнтний квадрат з емодзі паку + 🎁; кнопки Material з `Icons.home`.
- C 1 — немає; нагороду вручає ніхто.
- M 6 — envelope elasticOut → fly easeOutBack → settle; хаптики medium/heavy/light; **glow і конфеті `repeat()` безкінечно** (А2-12), 7 контролерів.
- F 6 — слово озвучується; візуально насичено, але без persona і голосу.
- K 4 — close 48dp біля краю, кнопки текстові «До розділу "Тваринки"», прогрес «6 ▬▬▬ 24» цифри.

### 22. GameCelebrationOverlay
- V 5 — біла картка 28r, Bloom 96dp, `DT.h1`, одна велика кнопка 72dp `kAccent` — найближче до цілі серед свят; але `ElevatedButton` Material, `kAccent` індиго.
- C 5 — Bloom waving статичний; не танцює, не говорить.
- M 6 — easeOutBack 260ms, `ConfettiBurst` 20 частинок за карткою; `tada` заглушка; `disableAnimations` враховано.
- F 5 — без рахунку (правильно), «Молодець, Софійко!» — текст; голос мовчить.
- K 7 — «Ще раз» 72dp, «Готово» для батька 15sp — правильний розподіл.

### 23. StreakMilestoneOverlay
- V 4 — 🔥 64sp у градієнтному колі, `kStreakOrange`, `m.bonusEmoji` 36sp, Roboto; Material-кнопка 48dp.
- C 4 — Bloom 64dp waving у рядку з емодзі — випадковий сусід.
- M 5 — elasticOut 600ms, flame glow `repeat` (loop без сенсу, А2-12); без звуку.
- F 5 — це milestone-tier, а виглядає як round-tier з іншим кольором.
- K 5 — «Серія 7 днів!» — батьківський текст, дитина бачить вогонь; кнопка 48dp.
- P 6 — «Так тримати!» — ок для батька; review-запит після — доречно.

### 24. KidWordWall (Скарбничка)
- V 5 — хедер градієнт kAccent→kTeal з Bloom 64dp, плитки `colorBg` 16r зі словом 12sp `colorAccent`; `AppBar` Material back.
- C 4 — Bloom є у хедері та порожньому стані (96dp) — правильне місце, але статичний.
- M 6 — тап плитки: pulse 1.08 + glow + слово + selectionClick — гарний мікро-фідбек; без entrance.
- K 6 — плитки ~110dp (3 колонки), текст «Слова Софійки» для батька; порожній стан — текст 14sp.

### 25. BloomMascot (компонент)
- V 6 — процедурний, чистий, теплий; але очі завжди закриті ^^ (читається «спить»), ніс-трикутник, тіло-капсула; пропорції на 44dp губляться (вуха/щоки зливаються).
- C 3 — 2 емоції, реакція лише на прямий тап (bounce 480ms + хаптик); немає idle, blink, listening, sad/encourage, sleepy, hint (вказує); `shouldRepaint` лише на emotion — не анімований painter.
- M 4 — один `AnimationController`, elasticOut; без звуку голосу.

### 26. ContentDownloadView
- V 4 — ☁️ 96sp емодзі, `LinearProgressIndicator` 14dp, `FilledButton` 72dp.
- C 1 — немає; Bloom, що «чекає з парасолькою», зробив би паузу дружньою.
- M 3 — статичний (свідомо, 60fps) — ок, але хоча б один вступний акцент.
- K 7 / P 8 — одна дія, 72dp, чесний текст для батька.

### 27. Paywall
- V 5 — банер градієнт kAccent/amber 0.18 з 🎉/🎁/🔓 48sp, benefit-рядки з Material `grid_view/volume_up/auto_awesome`, зірки `Icons.star_rounded`, план-тайли з радіо-кружком; Roboto; охайно, але generic-SaaS.
- C 1 — немає; у Duolingo/Lingokids пейвол «продає» персонаж і дитина на ілюстрації.
- M 4 — `AnimatedContainer` 200ms вибір; X fade 400ms через 3 с.
- P 7 — сticky CTA, чесний trial-текст, «Продовжити з безкоштовними» 56dp, restore, юр-лінки; skip видимий (А1-8 виправлено); «Rated 5.0 by parents» без країни (А1-7 виправлено).

### 28. ParentDashboard
- V 5 — M3 `TabBar` 6 табів, `_StatCard` з емодзі 🔥📚✅📅, `SwitchListTile`, `Icons.emoji_events_outlined`; читабельно.
- C 2 — Bloom імпортовано (word_wall_share) — у самому дашборді немає.
- M 4 — системні переходи; ок для батьків.
- P 7 — Overview/Week/Words/Packs/Games/Mistakes — змістовно; А2-28 (переглянули ≠ вивчили) актуально; закриття `Icons.close`.

### 29. Stats + Rewards
- V 3 — градієнт `Color(0xFFFF6B6B)→0xFFFF8E53` хардкод, 🔥 48sp, значки — емодзі 44sp у сірих квадратах з 🔒 12sp, бонус-картки — ❓ 36sp; Roboto; `Icons.arrow_back_ios` 48dp.
- C 1 — немає.
- M 3 — без анімацій (окрім системних).
- F 3 — «Нагороди» без жодного свята: отримані значки виглядають як неотримані з жовтим тінтом.
- K 3 — це дитяча колекція (за задумом), а виглядає як таблиця; доступ через StreakChip у дитячому хедері без гейту, Share у `StatsScreen` без гейту.
- P 5 — статистика чесна (А2-02 виправлено: `unlockedRewards`).

### 30. ProfileSelector + ParentalGate + Notif opt-in + About
- V 4 — `AlertDialog`, `TextField`, чипи мов з прапорами 🇺🇦🇬🇧, рівні 🍼🐣🌟🚀, gate — `TextButton` кейпад 64×56 `kAccent` 0.08; 🔔 56sp; Material `SettingsActionRow`.
- C 1 — немає (для гейту — і не треба; для opt-in — Bloom з дзвіночком доречний).
- M 4 — selectionClick; системні діалоги.
- P 7 — гейт словами + кейпад, 3 промахи → закрити — правильно; About за гейтом; opt-in з поясненням і «Не зараз» — чесно.

---

## 4. Топ-15 розривів до 9/10

Формат: що робить конкурент → що змінити у нас → файли → зусилля (S ≤ 1 день, M 2–5 днів, L > тижня, включно з ілюстрацією).

### G1. Одна система іконок замість трьох мов (емодзі + Material + власні) — **L**
- **Конкурент:** Khan Kids — кожна іконка (навігація, предмети, нагороди) намальована в стилі контенту тією ж рукою; Sago Mini — іконка = міні-іграшка з м'яким контуром.
- **Змінити:** намалювати набір ≈45 іконок за спекою §5.1 і підключити через один `KidIcon` віджет (`assets/images/icons/*.webp` @1x/2x/3x або `CustomPainter`, як у нав-барі). Покрити: 21 іконка паків (JSON `"icon"` → `"iconAsset"`), 3 категорії (💬🔤🌍), 6 бейджів ігр, 3 кроки дня (🔊🃏🗺️), 6 зупинок квесту (Material), скриня/подарунок/кубок (🎁🏆), вогник серії (🔥), статус-бейджі (lock/check/✨/downloading), керування (back, close, speaker on/off, play, shuffle, replay, home), 12 аватарів дитини, хмаринка завантаження (☁️), черепашка помилки (🐢). Емодзі лишити тільки як `fallbackEmoji` у `CardImage`.
- **Файли:** `assets/data/uk_cards.json`, `en_cards.json` (`icon`), `models/pack_model.dart`, `tabs/packs_tab.dart` (`_categoryIcons`, хедер), `tabs/games_tab.dart` (`badge`), `widgets/daily_hero_card.dart`, `widgets/quest_journey_map.dart` (`_icons`), `widgets/treasure_card.dart`, `widgets/streak_chip.dart`, `widgets/pack_grid_card.dart` (`_StatusBadge`), `screens/cards_screen.dart` (`_BackButton`, title emoji), `widgets/speaker_button.dart`, `screens/coloring_screen.dart` (`_NewPictureButton`), `screens/onboarding_screen.dart` (`_avatars`), `widgets/content_download_view.dart`, `screens/rewards_screen.dart`, новий `widgets/kid_icon.dart`.
- **Ефект:** усуває головну причину «4/10» — вигляд «зібрано з готового».

### G2. Bloom як живий персонаж (стани + присутність + голос) — **L**
- **Конкурент:** Duolingo ABC — персонажі моргають, дивляться на ціль, стрибають на правильну відповідь, «зітхають» на помилку; Khan Kids — Kodi веде, вказує лапою, чекає поруч, ніколи не перекриває завдання.
- **Змінити:** `BloomMascot` v2 за спекою §5.2 — 7 станів з переходами, очі відкриті за замовчуванням (blink), реакція на `AudioService.isSpeaking` (вуха), на success/miss через `BloomController`. Розмістити: S-компаньйон 56dp у кутку `DailyHeroCard`, `CardsScreen` (нижній лівий кут під карткою), усіх ігрових дошок (правий нижній, під навчальним обʼєктом — А2-18), `Coloring`, стартовий вузол `QuestJourneyMap`; M 96dp у всіх святах; L 160dp на Splash (прокидається) і magic moment. Голос: 6 коротких кліпів (привіт, ура×3, спробуй ще, бувай) — ElevenLabs через `tools/gen_praise_instructions.py`.
- **Файли:** `widgets/bloom_mascot.dart` (переписати painter на анімований, додати `BloomState`, `BloomController`), `screens/splash_screen.dart`, `widgets/daily_hero_card.dart`, `screens/cards_screen.dart`, усі `*_screen.dart` ігр, `screens/coloring_screen.dart`, `widgets/quest_journey_map.dart`, `services/audio_service.dart` (`playBloom(state)`).
- **Примітка:** якщо ілюстратор дасть Rive-файл — `rive` не в стеку; тримати CustomPainter або спрайти webp (обидва без нових залежностей).

### G3. Єдина система свят (4 тири, 1 компонент) — **M**
- **Конкурент:** Duolingo ABC — три рівні: іскра на тап, персонаж-танець після завдання, стікер + фанфари після уроку; Khan Kids — Kodi + предмет у колекцію.
- **Змінити:** один `Celebrate.show(context, tier: micro|round|daily|milestone, …)` за спекою §5.3; видалити `CelebrationOverlay`, `_CelebrationOverlay` у бульбашках, `_MilestoneDialog`; `CardRevealScreen` стає `daily`-тиром із **скінченним** конфеті (А2-12). Один фон-дім `DT.textPrimary` α0.35 (теплий, не `black54`/`0xCC`), одна велика кнопка 88dp, Done для батька 15sp, Bloom M «celebrating», praise-голос, `tada` → новий sfx.
- **Файли:** новий `widgets/celebrate.dart`; замінити виклики в `screens/cards_screen.dart` (`_showCelebration`), `widgets/game_celebration_overlay.dart` (стає обгорткою), `screens/bubble_pop_screen.dart`, `widgets/streak_milestone_overlay.dart`, `screens/card_reveal_screen.dart`, `widgets/confetti_burst.dart` (варіанти форм: кружки/зірочки/сердечка як дудли на картках).

### G4. Голосовий і звуковий шар — **M (контент)**
- **Конкурент:** усі топ-3 озвучують кожну дію: тап, правильно, «майже», перехід, поява персонажа.
- **Змінити:** (а) згенерувати `praise_{uk,en}_1..5.mp3`, `instr_{uk,en}_{guess,memory,bubbles,repeat,odd_one_out,opposites,coloring}.mp3` — без них 9 викликів у коді мовчать; додати `encourage_{uk,en}_1..3` («Майже!», «Спробуй ще!», «Ой, не ця») і `bloom_{hi,bye,yay1..3}`; (б) замінити синтезовані `pop/ding/tada` на дизайнерський набір: `tap`, `pop`, `flip`, `whoosh` (перехід), `ding` (правильно), `sparkle` (нагорода), `tada` (раунд), `fanfare` (milestone), `hmm` (промах, м'який, низький); (в) `AudioService.playSfx` з варіацією висоти через `setRelativePlaySpeed` (0.95–1.08) — щоб 20 pop-ів не звучали однаково.
- **Файли:** `tools/gen_praise_instructions.py`, `assets/audio_mp3/`, `assets/audio_sfx/`, `services/audio_service.dart` (`playPraise`, `playInstruction`, `playSfx`, новий `playEncourage`), `pubspec.yaml`.

### G5. Home hero → «Bloom запрошує» — **M**
- **Конкурент:** Khan Kids — home = один великий персонаж і одна велика картинка «сьогодні»; Lingokids — hero на 40 % екрана з ілюстрацією.
- **Змінити:** `DailyHeroCard` 150dp: ілюстрація на всю висоту ліворуч (≈45 % ширини, `BoxFit.cover`), Bloom S визирає з-за неї (стан `hint` — вказує на play), play 72dp `KidIcon.play` у кольорі акценту, бейдж 10sp → прибрати (голос Bloom каже «Картка дня!»), титул `DT.h1` Nunito. Кроки дня → три «камені» 72×72 з `KidIcon` без тексту (підпис 12sp лише при `MediaQuery.textScaler > 1.2` або в long-press). Виконаний крок — зелений камінь із галочкою + `sparkle` при переході стану. Використати `KidTap`.
- **Файли:** `widgets/daily_hero_card.dart`, `tabs/packs_tab.dart` (`_buildDailyHero`, `_showCardOfDayPopup` → тап = слово + bounce ілюстрації, шит на long-press, А1-9).

### G6. Спільний каркас ігор `KidGameScaffold` замість `AppBar` — **M**
- **Конкурент:** Sago Mini — жодного заголовка; лише велика кнопка «додому» і сцена; Duolingo ABC — X + смужка прогресу, все інше — сцена.
- **Змінити:** `KidGameScaffold(accent, progress, bloomState, child)` — back/close 72dp диск (як `_BackButton` у CardsScreen, але 72), «трубка» прогресу 10dp (з бульбашок), слот Bloom S праворуч унизу, фон `DT.bgWarm` + сцена-тінт `accentTint`; без текстового титулу (назва гри — голосом `instr_*`). Застосувати до Guess, Repeat, Opposite, OddOneOut, Articulation-player, Coloring, Memory (в межах його спеки).
- **Файли:** новий `widgets/kid_game_scaffold.dart`; `screens/guess_screen.dart`, `repeat_game_screen.dart`, `opposite_game_screen.dart`, `odd_one_out_screen.dart`, `articulation_screen.dart`, `coloring_screen.dart`, `memory_match_screen.dart`, `screens/quest_map_screen.dart` (`AppBar` → той самий back), `screens/kid_word_wall_screen.dart`, `screens/rewards_screen.dart`.

### G7. Типографіка: Nunito для всієї дитячої зони через тему — **S–M**
- **Конкурент:** один округлий шрифт скрізь (Duolingo — Feather/DIN Round; Khan Kids — власний округлий).
- **Змінити:** у `main.dart` `ThemeData.textTheme` на Nunito з `fontVariations` (через `DT.kidWeight`), `fontFamily: 'Roboto'` лишити лише в `ParentTheme` (обгортка `Theme(data: …)` для Paywall, ParentDashboard, Stats, ProfileSelector, ParentalGate, About). Прибрати inline `TextStyle(fontSize: …, fontWeight: bold)` у ~20 екранах на користь `DT.display/h1/h2/tileTitle/body/caption`. Пункт А1-28 позначений як виконаний лише частково — Nunito зараз лише у 7 місцях.
- **Файли:** `main.dart`, `utils/design_tokens.dart` (додати `DT.word` 32–72sp, `DT.praise` 52sp, `DT.kidButton` 20sp), усі екрани зі списку §3 з Roboto.

### G8. Колір: одна палітра, один зелений, kAccent — не дитячий — **S**
- **Конкурент:** 5–6 брендових кольорів, семантика стала (Duolingo: зелений = правильно, скрізь один).
- **Змінити:** у дитячій зоні замінити `kAccent` (#6C63FF індиго) на `DT.violet`/акцент паку; `kTeal`, `kSoundRed` — прибрати з дитячого UI (`QuizOption` слово, `SpeakerButton`); три зелених `#22C55E`, `#43A047`, `#4CAF50`, `#2E7D32` → один `DT.success` (перевизначити на `DT.mint`-темніший ≈ `#3FA85A`); фони ігр `#EAFFF5/#F8F0FF/#F0EEFF/#F5EEFF/#FAFAFF/#F7F2FF/#FAF8F5` → `DT.bgWarm` + `accentTint` сцени; `scaffoldBackgroundColor` `#FAF8F5` → `DT.bgWarm`. Червоне для помилки — заборонити в дитячій зоні (див. G10).
- **Файли:** `utils/constants.dart`, `utils/design_tokens.dart`, `main.dart`, `widgets/quiz_option.dart`, `widgets/speaker_button.dart`, `widgets/pack_grid_card.dart`, `screens/*_screen.dart` (`backgroundColor`), `widgets/daily_hero_card.dart` (`kAccent` в `_AllDoneRow`).

### G9. Прибрати текст з дитячих екранів (замінити іконка + голос + жест Bloom) — **S**
- **Конкурент:** Sago Mini — нуль тексту; Khan Kids — текст лише дублюється голосом і не є єдиним носієм.
- **Змінити:** видалити/сховати за `parentMode`: «Скажи: «Кіт»» (Repeat → великий `KidIcon.mic` + Bloom `listening`), «Натисни, щоб послухати», «торкнись», «Що протилежне?» (→ анімована стрілка ↔ між карткою і опціями), «Яка картка зайва?» (→ ❓ як `KidIcon` + голос), інструкція Coloring (→ Bloom + рука 2 с, А1-26), підзаголовки плиток ігр і «1–3 роки / 3+» (→ 11sp `textMuted` або в long-press), «Заверши 5 зупинок / Нумо сюди!» на мапі (→ Bloom стоїть на активній зупинці), snackbar на заблокованій грі (→ Bloom `hint` + `instr_locked` голос + shake), `_TodayPlanIntroHint` (→ голос Bloom один раз).
- **Файли:** `screens/repeat_game_screen.dart`, `opposite_game_screen.dart`, `odd_one_out_screen.dart`, `coloring_screen.dart`, `tabs/games_tab.dart`, `widgets/quest_journey_map.dart`, `tabs/packs_tab.dart`.

### G10. Безпечна помилка: без червоного і ❌, з підказкою після другого промаху — **S–M**
- **Конкурент:** Duolingo ABC — на помилку персонаж нахиляє голову, варіант м'яко «здувається», правильний починає світитися; ніколи червоний хрест.
- **Змінити:** спільний `MissFeedback`: light хаптик + `hmm` sfx + shake 6dp/300ms + опція fade до 0.6 на 800ms; після 2-го промаху в раунді — правильна опція «дихає» 1.06/900ms ×2 (hint), Bloom `hint` дивиться на неї; після 3-го — Bloom вказує, голос «Ось!»; `encourage_*` голос на кожний промах (варіації). Видалити `#E53935`/`#FFEBEE`/❌/✅ з `OddOneOut`, `Opposite`; `QuizOption` isWrong → без червоного. SRS-якість фіксувати окремо (А2-04) — уже частково є `lastAnswerQuality`.
- **Файли:** новий `widgets/miss_feedback.dart` (або в `utils/shake_animation_mixin.dart`), `screens/odd_one_out_screen.dart`, `opposite_game_screen.dart`, `widgets/quiz_option.dart`, `screens/guess_screen.dart`, `screens/repeat_game_screen.dart`.

### G11. Переходи: спільний елемент і одна крива — **M**
- **Конкурент:** Khan Kids — плитка «виростає» в екран; Sago Mini — сцена «в'їжджає», кнопка назад повертає туди ж.
- **Змінити:** `Hero(tag: pack.id)` навколо `CardImage` у `PackGridCard` → обкладинка в `CardsScreen` (перша картка/хедер); `_gameRoute` для всіх пушів з дитячої зони (зараз `MaterialPageRoute` у `_onPackTap`, quest stops, hero) з єдиною кривою `Curves.easeOutCubic` 320ms / reverse 220ms, scale 0.94→1 + fade; кнопка back — та ж анімація у зворотному напрямку; `IndexedStack` табів — легкий fade 180ms. Entrance-stagger 40ms/елемент для гриду паків, плиток ігр, опцій вікторини (з `DT.enterMs`).
- **Файли:** `tabs/packs_tab.dart`, `widgets/pack_grid_card.dart`, `screens/cards_screen.dart`, `tabs/games_tab.dart` (`_gameRoute` → `utils/kid_route.dart`), `screens/quest_map_screen.dart`, `screens/home_screen.dart`, `screens/guess_screen.dart`.

### G12. 100 % `KidTap` і всі таргети ≥72dp — **S**
- **Конкурент:** усі — кожна кнопка відповідає звуком і рухом; таргети 72–96dp.
- **Змінити:** обгорнути `KidTap`/`KidTap.feedback`: hero і `_TaskButton` (лише хаптик), `_TreasureBoxBanner`, `TreasureCard` (нічого), `SpeakerButton` (нічого), `StreakChip`, `ProfileAvatarChip` (нічого), `_JourneyStop` (без sfx), `_OptionTile`/`_CardChip` (без press-scale), `_TileWidget` Memory (у спеці), `QuizOption` (haptic на down), `_LearnedTile`, кнопки `CardRevealScreen`, кнопки всіх свят, `_ExerciseCard`, `_PackPickerSheet` плитки. Розміри: hero play 38→72, `_TaskButton` 54→72, `SpeakerButton` 56→72, `_BackButton` 64→72, back у 9 екранах 48→72 (через G6), X у `CardReveal` 48→72 і від краю ≥40dp, `_JourneyStop` 76×62→80×80, `_CategoryChip` 56→64, `PackGridCard` 2 колонки на `width < kMediumScreen` (А1-12), `_HintThumb` 44→56.
- **Файли:** перелічені віджети; `tabs/packs_tab.dart` (`crossAxisCount`).

### G13. Мапа квесту як пригода з мандрівником — **M**
- **Конкурент:** Khan Kids «шлях» — персонаж стоїть на поточному вузлі і переходить до наступного після виконання; Duolingo — маскот сидить біля активного уроку.
- **Змінити:** Bloom S стоїть на активній зупинці (замість bob каменя), після виконання — анімований перехід стежкою 900ms до наступної + `sparkle`; зупинки → `KidIcon` ландмарки (вушко/дерево-з-картками/дзвіночок/зірка/мікрофон-квітка/скриня); скриня — намальована, закрита/відкрита; `_PackPickerSheet` → великі плитки 120dp з `CardImage(pack.cover)` замість емодзі + 11sp; одна тема дня (А2-25) — окремий трек, тут лише візуал. Хедер «Маленькі кроки до скарбу 2/5» → 5 намальованих слідів-лапок, що заповнюються.
- **Файли:** `widgets/quest_journey_map.dart`, `screens/quest_map_screen.dart` (`_PackPickerSheet`), `widgets/treasure_card.dart`.

### G14. Нагороди як стікер-альбом дитини — **M**
- **Конкурент:** Khan Kids — колекція іграшок/наліпок, кожну можна торкнутись і вона реагує; Duolingo ABC — стікери після уроку.
- **Змінити:** `RewardsScreen` → «Альбом»: намальовані стікери (milestone-бонуси замість `bonusEmoji`), неотримані — силует на папері (без 🔒/❓), отриманий — тап → bounce + звук; Bloom L тримає альбом у хедері; вхід з дитячої зони через скарбничку (обʼєднати з `KidWordWall`: вкладки «Слова» / «Наліпки» як два великі KidIcon-таби); `StatsScreen` — лише за гейтом (Share там без гейту). `RewardsScreen` доступний із `StatsScreen` → перенести кнопку в скарбничку.
- **Файли:** `screens/rewards_screen.dart`, `screens/kid_word_wall_screen.dart`, `providers/streak_provider.dart` (`Milestone.badge/bonusEmoji` → asset), `screens/stats_screen.dart`, `widgets/streak_chip.dart` (`onTap` → гейт або скарбничка).

### G15. Батьківська зона у тому ж всесвіті (Paywall, Dashboard, діалоги) — **S–M**
- **Конкурент:** Lingokids/Duolingo — пейвол з персонажем і дитиною на ілюстрації, benefit-іконки в стилі бренду; дашборд Khan Kids — ті ж іконки, що в дитячій зоні.
- **Змінити:** Paywall: банер → ілюстрація «Bloom + 3 картки-віяло» (webp 320×180) замість 🎉 48sp, benefit-іконки → `KidIcon` (cards/sound/new), зірки → намальовані; план-тайли лишити (працюють). Dashboard: `_StatCard` емодзі → `KidIcon`, `Icons.emoji_events_outlined` → стікер. Notif opt-in: 🔔 → Bloom з дзвіночком. Гейт: кейпад 64×56 → 72×64, лишити нейтральним. About: `CircleAvatar(Icons.auto_stories)` → логотип. Тексти лишити Roboto 15–16sp — це дорослі.
- **Файли:** `screens/paywall_screen.dart` (`_trialBanner`, `_benefit`, `_testimonial`), `screens/parent_dashboard_screen.dart` (`_StatCard`, achievements), `widgets/notification_opt_in_dialog.dart`, `widgets/parental_gate.dart`, `tabs/packs_tab.dart` (`_showAbout`).

**Порядок:** G7+G8 (фундамент, S) → G12 (S) → G4 (контент, паралельно) → G6+G9+G10 (ігри, M) → G3 (свята) → G2 (Bloom) → G5 → G1 (іконки — довгий трек ілюстратора, стартувати з дня 1) → G11 → G13 → G14 → G15. Після G1–G4 очікую 7/10; після повного списку — 8.5–9.

---

## 5. Бриф візуального напряму (для Flutter-dev + ілюстратора)

Назва напряму: **«Паперова іграшкова кімната»**. Усе — предмети, вирізані з теплого паперу і намальовані тією ж акварельно-олівцевою рукою, що й 471 картка. Сцена тепла (`DT.bgWarm`), предмети — насичені, з м'яким контуром і паперовим білим стікер-обідком (той, що вже є в `PlayfulNavigationBar`: `Border(color: Colors.white, width: 2)`).

### 5.1. Спека іконок (`KidIcon`)

| Параметр | Значення |
|---|---|
| Простір дизайну | 48×48, жива зона 40×40 (4dp поля), оптичний мінімум показу 28dp, рекомендовано 32/40/56 |
| Форма | заокруглені, «пухкі» силуети; радіус кутів ≥ 25 % розміру; жодних гострих кутів; композиція — один головний обʼєкт + максимум 1 дудл (зірочка/крапка) |
| Контур | 2.5dp у 48-просторі (≈5 %), колір `DT.textPrimary` α0.70, округлі кінці; **всередині** обʼєкта лінії 1.5dp α0.35 |
| Заливка | 2 тони одного акценту (base + `Color.lerp(base, white, .35)` для верхнього світла) + 1 контрастний деталь-колір; без градієнтів, без тіней у самому асеті (тінь дає контейнер: `DT.shadowSoft`) |
| Стікер-обідок | 1.5dp білий по зовнішньому силуету (як паперовий виріз) — лише для іконок на кольоровому/фото фоні (бейджі на плитках, зупинки мапи); на білому фоні — без |
| Палітра | лише `DT`: coral, sunBurst, mint, sky, violet, peach, pink + `textPrimary`; **семантика:** категорія Мовлення = violet, Звуки = peach, Світ = mint; ігри: Вгадай = sky, Пара = mint, Бульбашки = coral, Повтори = peach, Зайве = violet, Протилежності = pink; success = один `DT.success` (перевизначити ≈ `#3FA85A`); lock = sunBurst-замочок з посмішкою (не сірий); reward = sunBurst/peach |
| Стан | normal / pressed (контейнер 0.96, не сама іконка) / disabled — **не сірити**, лишати колір і додавати замочок-стікер у куті |
| Формат | webp @1x/2x/3x у `assets/images/icons/` (не в `images/webp/` — там картки, архітектурний тест) **або** `CustomPainter` як `_ToyIcon` для 10 керуючих іконок (back, close, speaker×2, play, shuffle, replay, home, check, lock) — вони мають бути ідеально різкими на всіх dpr |
| Іменування | `ic_pack_animals`, `ic_cat_speech`, `ic_game_guess`, `ic_task_listen`, `ic_stop_ear`, `ic_ctrl_back`, `ic_reward_chest_closed/open`, `ic_avatar_01..12` |

Список (≈45): паки 21 (звукові паки Р/Л/Ш/С/З/Ж/Ч/Щ/Ц — літера як обʼємний паперовий стікер у кольорі паку з обличчям-дудлом, щоб вони не були «шрифтом серед малюнків»); категорії 3; ігри 6 (+ артикуляція 1); кроки дня 3; зупинки 6; нагороди 4 (скриня закрита/відкрита, подарунок, кубок); серія 1 (вогник із очима); статуси 4; керування 10; аватари 12 (тваринки з карток у стилі «портрет-стікер»); системні 2 (хмаринка, черепашка).

### 5.2. Спека поведінки Bloom

Анатомія v2: очі **відкриті** за замовчуванням (крапки з бліком), ^^ — лише в `happy/celebrating`; вуха рухомі (окремі шари); одна лапа рухома; рот 3 форми (усмішка, «о», рівна). Розміри: XS 32 (бейдж на печатці), S 56 (компаньйон у кутку), M 96 (свята), L 160 (splash, magic moment). Правило місця: **ніколи над навчальним обʼєктом**; кут нижній-правий у грі, лівий верх — лише на splash/onboarding. Reduce-motion: статична поза кожного стану, без loop-ів.

| Стан | Тригер | Рух (loop / one-shot) | Тривалість | Звук |
|---|---|---|---|---|
| `idle` | за замовчуванням | дихання scale 1.0→1.02 4 с easeInOut (loop), blink кожні 3–6 с (random) 120ms, раз на 20 с — погляд у сторону цілі 400ms | loop | — |
| `listening` | `AudioService.isSpeaking == true` (слово/інструкція) | вуха піднімаються на 6°, голова нахил 4° до джерела, рот «о» на голосних не робимо (без lip-sync) — лише легкий bob 2px у ритмі 300ms | доки грає | — |
| `hint` | 2-й промах у раунді, або 8 с без дії на екрані з однією ціллю (hero, magic moment) | лапа піднімається і вказує в напрямку цілі (кут задається `hintDirection`), 2 кивки; повтор через 6 с | 900ms one-shot | `bloom_hmm` тихо (лише при промаху) |
| `happy` | правильна відповідь, тап по картці, виконаний крок | стрибок 8dp з squash 0.94/1.06, очі ^^ на 600ms, вуха підстрибують із затримкою 60ms | 600ms one-shot | `ding` (звук цілі), голос — ні (не перекривати слово) |
| `celebrating` | тир round/daily/milestone | подвійний стрибок + оберт вух, конфеті з-за спини, очі ^^, рот широкий | 1.4 с, потім `idle` з посмішкою | `praise_*` / `bloom_yay` |
| `encourage` | промах | голова нахил 8°, брови (дві дужки) на 500ms, потім кивок «спробуй»; **ніколи сум** | 700ms | `encourage_*` (варіації) |
| `sleepy` | 30 с без дотику на будь-якому екрані (окрім активного аудіо) | очі напівзаплющені, повільне дихання 6 с, раз на 10 с — «Zz» дудл; будь-який тап → `happy` | loop | — |
| `wave` | поява на екрані (splash, onboarding, свята), вихід з апки | помах лапою 3 рази | 900ms | `bloom_hi` / `bloom_bye` |

API для dev: `BloomMascot(size, controller: BloomController, hintDirection: Alignment?)`; `BloomController.set(BloomState)`, `pulse(BloomState)` (one-shot із поверненням до попереднього), автопідписка на `AudioService.isSpeaking` для `listening`. Реалізація — `CustomPainter` з `Listenable` (repaint на кожен кадр лише поки є активний контролер) або спрайт-лист webp 8 кадрів на стан (менше коду, більше асетів); обидва без нових залежностей.

### 5.3. Тири свят (`Celebrate`)

| Тир | Коли | Що бачить дитина | Звук / хаптик | Тривалість | Кнопки |
|---|---|---|---|---|---|
| **micro** | правильний тап, картка озвучена, пара знайдена, бульбашка лопнула | ціль scale 1.08→1.0 spring; 12 частинок (кружки/зірочки в кольорі акценту) з точки тапу; Bloom S `happy`; для рахункових ігр — `_PraiseFlash`-слово 52sp кожні 5 | `ding` (варіація висоти) + light | 600ms, без оверлею, не блокує тап | — |
| **round** | гра завершена, пак пройдено, малюнок проявлено | dim `DT.textPrimary` α0.35 (теплий); картка `DT.paper` 28r з ілюстрацією раунду (обкладинка паку / остання картка); Bloom M `celebrating`; конфеті 1.2 с **скінченне**; заголовок `DT.display` «Молодець, {Ім'я}!» (для батька) | `tada` + `praise_*` + medium | вхід 420ms easeOutBack; лишається до дії | «Ще раз» 88dp (KidIcon.replay, без тексту або 20sp Nunito), «Готово» 15sp для батька |
| **daily** | скриня квесту відкрита | сцена мапи затемнюється, скриня відкривається (2 кадри + spring), з неї вилітає картка (як `CardRevealScreen`, але без промінців-loop), Bloom L підстрибує; стікер «летить» у скарбничку (мікроанімація до кутової іконки) | `sparkle` → слово картки → `praise_*` + heavy | 2.5 с, потім кнопки | «До паку» 88dp, «Додому» 72dp |
| **milestone** | серія 3/7/14/30, перший пак, 10/50/100 слів | повний екран `DT.sunTint`; Bloom L у «костюмі» (капелюх/медаль — 4 асети), великий намальований стікер-нагорода 160dp обертається 1 раз; для батька — рядок `DT.h2` | `fanfare` + `bloom_yay` + heavy | 3 с | «Так тримати!» 88dp; Share — тільки після гейту |

Заборонено у всіх тирах: `black54`/`0xCC` фон, емодзі як герой, безкінечні loop-и, рахунок/зірки/час у дитячому тирі, червоне.

### 5.4. Спека руху

| Параметр | Значення | Де |
|---|---|---|
| Press | scale 0.96, 100ms `easeOut`; release — `Curves.easeOutBack` 220ms до 1.0 (`DT.pressScale/pressMs` оновити) | `KidTap` — єдине джерело |
| Тап-фідбек | хаптик light + `tap`/`pop` sfx з варіацією ±6 % висоти | `KidTap.feedback` |
| Entrance списків | stagger 40ms, кожен елемент 280ms `easeOutCubic`: opacity 0→1, translateY 12→0, scale 0.94→1; максимум 9 елементів анімовано, решта — миттєво | грид паків, плитки ігр, опції, мапа |
| Перехід екрана | 320ms вперед / 220ms назад, `easeOutCubic`; fade + scale 0.94→1; Hero-обкладинка 360ms `Curves.fastOutSlowIn` | `kid_route.dart` |
| Свято-вхід | 420ms `easeOutBack` scale 0.85→1 | `Celebrate` |
| Idle-запрошення | лише **один** елемент на екран: breath 1.0→1.03, 1600ms `easeInOut` reverse | hero на home, картка на magic moment, активна зупинка (замінити Bloom-ом) |
| Спалахи уваги | бурстами (2 цикли, пауза 30 с) — як `StreakChip` | seasonal shimmer, streak |
| Помилка | shake ±6dp 300ms `elasticIn`, opacity → 0.6 на 800ms | `MissFeedback` |
| Хаптики | light = тап/перегортання; medium = правильно/flip/long-press; heavy = раунд/milestone; selectionClick — лише батьківські чипи | скрізь |
| Бюджет | ≤2 одночасні анімації в кадрі; кожен loop через `TickerMode`/`disableAnimations`; RepaintBoundary на сцени | А2-12/13 |
| Reduce motion | усі тривалості 0, loop-и off, Bloom — статичні пози, конфеті — статичний «вибух» 1 кадр | `MediaQuery.disableAnimationsOf` |

### 5.5. Набір звуків (для `content`)

`tap` (м'який дерев'яний клік, 60ms), `pop` (бульбашка, 120ms, 3 варіанти), `flip` (папір, 180ms), `whoosh` (перехід, 240ms), `ding` (ксилофон одна нота, 300ms, 3 висоти), `sparkle` (дзвіночки, 500ms), `tada` (короткий акорд ксилофона, 800ms), `fanfare` (1.6 с), `hmm` (м'який низький «м-м», 300ms), `bloom_hi`, `bloom_bye`, `bloom_yay_1..3`, `praise_{uk,en}_1..5`, `encourage_{uk,en}_1..3`, `instr_{uk,en}_{7 ігр + locked}`. Усе — один голос/один тембр інструментів (ксилофон + укулеле + папір), гучність sfx 0.6 від голосу, голос не перекривати sfx (черга в `AudioService`).

---

## 6. Що НЕ чіпати (працює, тримає планку)

`PlayfulNavigationBar` (еталон іконок), `_LandscapePainter` мапи, `FlashCard` (слово/пульс/flip), `KidTap`, `_MagicCard`, `_PraiseFlash`, амбієнтні `showBubblePop`, `SwipeHint` у кольорі паку, `ContentDownloadView` (структура), гейт, sticky CTA пейволу, архітектура `CardImage`. Тести, які треба не зламати: `test/screens/memory_board_fit_test.dart` (центри `GestureDetector` у екрані), `test/widgets/playful_navigation_bar_test.dart`, `test/architecture/asset_access_test.dart` (нові іконки — не в `assets/images/webp/`).

## 7. Як перевіряти «9/10»

- Скріншот будь-якого дитячого екрана без тексту → сторонній дорослий каже «це та сама апка, що й картки» (один автор).
- На екрані завжди видно Bloom або його слід (окрім батьківської зони), і він реагує на перший же тап.
- Кожен тап дитини дає звук + рух + хаптик; кожна правильна дія — micro-свято; кожен раунд — round-свято з голосом.
- У дитячій зоні нуль Material-іконок і нуль емодзі (перевірка: `grep -n "Icons\." lib/screens lib/tabs lib/widgets` порожній для дитячих файлів; `grep -nP "[\x{1F300}-\x{1FAFF}]"` — теж).
- Усі дитячі таргети ≥72dp (додати `test/architecture/tap_target_test.dart`: обійти `KidTap` у widget-тестах ключових екранів і перевірити `size >= 72`).
- Промах ніколи не червоний; після 2-го промаху є підказка.
