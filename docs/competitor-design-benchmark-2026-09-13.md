# Бенчмарк дизайну топових дитячих освітніх апок (1–5 років)

_Дата: 2026-09-13. Мета: дати Flutter-команді Картки-розмовлялки конкретну планку «що таке преміум-відчуття» у дитячій апці і список речей, які відрізняють 9/10 від 4/10._

## 0. Як читати цей документ

- **Обсяг.** 13 апок: Duolingo ABC (+ дизайн-система основного Duolingo), Khan Academy Kids, Lingokids, Speech Blubs, Endless Alphabet / Endless Reader (Originator), Sago Mini World, Toca Boca, Pok Pok Playroom, Papumba, Otsimo, Bini Games, Kids Academy, HOMER. Детально — топ‑8 (розділ 2), решта — коротко (розділ 3).
- **Джерела.** Пріоритет — первинні: офіційні блоги (blog.duolingo.com, rive.app/blog, Toca Boca Tech Blog, Otsimo dev blog, Apple Developer «Behind the Design»), інтерв'ю засновників, вакансії (стек), App Store, Common Sense Media. Усе, що не вдалося підтвердити первинним джерелом, позначено **[неперевірено]**. Не вигадуйте деталі там, де стоїть ця позначка — перевірте руками в апці.
- **Головний висновок наперед.** Преміум-відчуття — це не «більше конфеті». Це (а) один стиль ілюстрації без винятків, (б) живий персонаж із станами, (в) кожен тап відповідає трьома каналами одночасно (візуал + звук + гаптика) за <100 мс, (г) жодного стану «неправильно», (д) один очевидний «наступний крок» на головному екрані. Пункт 4 — ранжований список.

---

## 1. Duolingo як еталон дизайн-системи (те, що ABC успадковує)

Duolingo — найкраще задокументована дизайн-система у категорії, і Duolingo ABC збудований на тому самому візуальному ДНК, тому варто розібрати основну апку.

### 1.1 Ілюстрація і форма
- Усі ілюстрації будуються з **трьох базових форм: заокруглений прямокутник, коло, заокруглений трикутник; гострі кути — off-brand**. Голова і тіло персонажа — 1–2 базові форми, п'ять канонічних стилів очей; емоція передається розміром зіниці, бліком і повіками. (Витяг з Duolingo Illustration Guidelines: https://www.scribd.com/document/583545694/Duolingo-Illustration-Guidelines ; хаб дизайну: https://blog.duolingo.com/hub/design/)
- Палітра — плоска, насичена, з чіткими семантичними ролями: Feather Green `#58CC02` (успіх/CTA), Blue `#1CB0F6` (інформація/прогрес), Red `#FF4B4B` (серця/помилки), Orange `#FF9600` (streak), Yellow `#FFC800` (XP/нагороди), Purple `#CE82FF` (ліги/преміум). (https://blakecrosley.com/guides/design/duolingo)
- Типографіка: кастомний Feather Bold (Johnson Banks + Fontsmith, 2019) для дисплейних написів, DIN Next Rounded для UI. (https://www.monotype.com/studio/portfolio/duolingo ; https://www.creativebloq.com/news/feather-bold)
- Кнопки — «3D»: 4 px суцільна нижня межа темнішого тону, радіус 16 px; при натисканні межа зникає і кнопка «сідає» на 4 px вниз, при відпусканні пружинить назад. (https://blakecrosley.com/guides/design/duolingo ; https://60fps.design/shots/duolingo-button-tactile-interaction)

### 1.2 Персонаж: Duo і World Characters
- Анімація — **Rive + State Machine**. Кожен із 10 World Characters має **20+ форм рота (візем)**; TTS → фонеми → віземи → стан у Rive. Окремі стани для поз і для рота зливаються в одній state machine, експортуються одним runtime-файлом. Idle: кивки, моргання, брови; реакції на результат уроку. Rive обрано за компактні файли і чистий хендоф аніматор → інженер. (https://blog.duolingo.com/world-character-visemes)
- Lily у Video Call: **8 анімацій голови × 8 анімацій тіла → 64+ варіантів «нейтрального» idle**, щоб персонаж не зациклювався; nested artboards (голова окремо від тіла), event-triggered expressions; **фінальний .riv < 1 МБ**. (https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life)
- Роль **creative technologist**: аніматор робить таймлайни, креативний технолог будує логіку state machine і документує inputs, потім передає інженеру. Принцип: «менше складності для інженера → анімація швидша». (https://rive.app/blog/creative-technologists-duolingo-s-solution-to-the-designer-to-developer-handoff)
- У 2024 Duolingo купив motion-студію Hobbes (12 аніматорів) саме для «animation design systems»; CDO Ryan Sims: «Design is a critical part of Duolingo's success, particularly our use of character illustration and animation». (https://www.tipranks.com/news/press-releases/duolingo-doubles-down-on-design-and-animation-with-acquisition-of-hobbes)
- Персонаж-віджет: Duo змінює вираз протягом дня залежно від того, чи зроблено урок; 25 додаткових ілюстрацій настроїв; половина користувачів із віджетом мають streak ≥ 6 місяців. (https://blog.duolingo.com/widget-feature/)

### 1.3 Святкування
- **Кінець уроку**: конфеті; за ідеальний урок Duo виїжджає знизу, голова роздувається, червоніє і «вибухає» грибом із іскрами; далі **три stat-картки в'їжджають зі stagger-затримкою, з тікером цифр і окремим звуком на кожну**. (https://60fps.design/shots/duolingo-lesson-complete-head-explode-animation)
- **Streak milestone**: Duo перетворюється на фенікса в полум'ї; звичайний день — просто тікер лічильника, milestone — унікальна анімація («як power-up у грі, Duo фізично змінюється»). Метафора птаха обрана, бо «вогонь» не всюди читається культурно. «Timing is everything in animation» — кілька грубих проходів по ритму до чистового. (https://blog.duolingo.com/streak-milestone-design-animation) Редизайн анімації фенікса дав **+1.7% до D7 retention** — одна анімація виявилась «несучою» для утримання. (https://duolingo.deconstructoroffun.com/mechanics/streaks)
- Іконка streak: idle-пульсація 2 с; коли streak під загрозою — 0.8 с і більша насиченість. (https://blakecrosley.com/guides/design/duolingo)
- 2025: «свіжі анімації для streak milestones, Friend Streaks і екранів кінця уроку», редизайн відкриття скрині «щоб відкривати було приємніше». (https://blog.duolingo.com/product-highlights/)

### 1.4 Фідбек і копі
- Правильно: зелена панель знизу з галочкою, «Great!», позитивний звук, slide-up 200 мс ease-out. Неправильно: червона панель із правильною відповіддю, **м'який** звук, прогрес-бар усе одно трохи росте («щоб не було відчуття, що застряг»), кнопка «GOT IT» замість «Wrong». (https://blakecrosley.com/guides/design/duolingo)
- Звук правильної відповіді — пара шістнадцятих F#→A# («мажорна» частина акорду, «перевернутий дверний дзвінок»). (https://www.losdoggies.com/archives/8816)
- Копі-принцип: «говори як тренер, а не як суддя», нагороджуй маленькі кроки. A/B: loss-framing («Не втрать 10‑денний streak!») переміг gain-framing («You're on fire!») — але це для дорослих; для дітей 1–4 актуальний лише позитивний бік. (https://maleesha-16.medium.com/designing-delight-how-duolingos-ux-writing-turns-language-learning-into-a-habit-dfd04d81e1c6 ; https://medium.com/@sidgore1998/how-a-duolingo-message-made-me-rethink-praise-in-ux-dc25b6221e9f)

### 1.5 Головний екран
- Перехід від «дерева навичок» до **лінійного шляху**: прибирає вибір «чи я правильно вчуся», один наступний вузол, пройдені — золоті, персонажі стоять уздовж шляху і підбадьорюють. (https://blog.duolingo.com/new-duolingo-home-screen-design)
- «Elevating craft» (редизайн табів): консистентність без мети шкодить; менше стилів типографіки; замість «контейнерів заради контейнерів» — цілеспрямований whitespace. «Good craft is what makes learning feel easy and enjoyable». (https://blog.duolingo.com/core-tabs-redesign/)

---

## 2. Топ‑8 апок — детально

### 2.1 Duolingo ABC (Learn to Read)

1. **Іконки/ілюстрація.** Плоска, «duolingo-стиль» (три базові форми, заокруглення), насичена палітра, кастомна ілюстрація без Material/емодзі. Іскри на правильну відповідь, літери «клацають» на місце. (https://blog.duolingo.com/a-good-read-building-duolingo-abc-for-android/ ; App Store: https://apps.apple.com/us/app/learn-to-read-duolingo-abc/id1440502568)
2. **Маскот.** Duo + «дитячі» версії касту (Bea, Eddy, Junior, Lily, Zari, Vikram) і мавпочки. Анімація — Rive/state machine (спільна інфраструктура з основним Duolingo). (https://blog.duolingo.com/world-character-visemes ; https://duolingoguides.com/all-duolingo-characters/)
3. **Святкування.** «Щедра доза іскор» на правильну дію; мотивація — візити маскота і візуальні нагороди, а не бали. (https://blog.duolingo.com/a-good-read-building-duolingo-abc-for-android/) Чи ідентичний звук «дзинь» основному Duolingo — **[неперевірено]**.
4. **Копі/голос.** Озвучка **складається з окремих кліпів**: «The letter team» + [літера] + [літера] + «says» + [фонема], синхронізована з пульсацією іконки через Kotlin coroutines (`async`/`awaitAll`). Це і є архітектура «lazy-VO з блоків», а не один записаний файл на речення. (https://blog.duolingo.com/a-good-read-building-duolingo-abc-for-android/)
5. **Мікровзаємодії.** Іконка пульсує в такт нарації; тап‑цілі: дослідження показало, що малі діти **тапають із мікро-драгом, і тап не реєструється** — рекомендація зараховувати «tap + small drag» як тап. (https://www.thegiantroom.com/blog/05/31/2023/report-duolingoabc-playtesting-session)
6. **Головний екран.** Строго лінійний шлях (127 юнітів), пропускати не можна навіть якщо дитина вже читає. Формула утримання з плейтестів: **«4–5 завдань → окремий екран із розвагою»**; ігри з наративом запам'ятовуються краще, гумор і «дурощі» — головний драйвер захвату. (https://www.commonsensemedia.org/app-reviews/duolingo-abc-learn-to-read ; https://www.thegiantroom.com/blog/05/31/2023/report-duolingoabc-playtesting-session)
7. **Онбординг/батьки.** Батько: політика → ім'я дитини → дозвіл на мікрофон → опційний email; потім віддає планшет дитині. Окремий parental gate — **[неперевірено]**. (https://www.commonsensemedia.org/app-reviews/duolingo-abc-learn-to-read)
8. **Звук.** Розпізнавання мовлення як частина вправ; модульна нарація (див. п. 4). Окремої публічної таксономії SFX немає.
9. **Тех.** Нативний Android (Kotlin, coroutines, мультимодульна архітектура), нативний iOS (Swift); анімація — Rive. Не Flutter/RN. (https://blog.duolingo.com/a-good-read-building-duolingo-abc-for-android/ ; https://rive.app/blog/creative-technologists-duolingo-s-solution-to-the-designer-to-developer-handoff)

### 2.2 Khan Academy Kids

1. **Іконки/ілюстрація.** Плоска, тепла, «м'яка» ілюстрація команди Duck Duck Moose (22 апки, 22 Parents' Choice Awards до злиття). (https://blog.khanacademy.org/khan-academy-adds-apps-for-young-children/ ; https://apps.apple.com/us/app/khan-academy-kids/id1378467217)
2. **Маскот.** П'ять тварин, кожна «відповідає» за домен: **Kodi (ведмедиця, головний гід: інструкції, підказки, підбадьорення)**, Ollo (слон — фоніка), Reya (панда — історії), Peck (колібрі — числа), Sandy (дінго — логіка). Ведмідь обраний за «сильний силует і великі читабельні риси»: може вказати, тримати предмет, слухати, реагувати **без слів**. Ті самі персонажі — герої книжок в апці. (https://khankids.zendesk.com/hc/en-us/articles/360049358751-Learn-more-about-the-characters-inside-Khan-Academy-Kids ; https://svgapp.ai/app-mascots/khan-academy-kids/ — вторинне джерело)
3. **Святкування.** Kodi підстрибує, піднімає лапи, усміхається + голосове «Yay!»/«That's right!». На помилку — жест «думає» (лапа до підборіддя) і анімована покрокова демонстрація правильного ходу. **[частково неперевірено — опис зібраний із вторинних джерел]**
4. **Копі/голос.** Лише підбадьорення; «Read to me» англійською та іспанською. (https://apps.apple.com/us/app/khan-academy-kids/id1378467217)
5. **Мікровзаємодії.** Публічно не задокументовано — **[неперевірено]**.
6. **Головний екран.** «Сторінка з великим будинком» + **одна велика зелена кнопка «Learning Path»**, що запускає автоматично підібраний урок із Kodi і відновлюється з того ж місця — дитина не приймає жодних навігаційних рішень. Бібліотека (книги/відео/creat/офлайн) — за окремою іконкою книги. (https://khankids.zendesk.com/hc/en-us/articles/360006764812-Parent-Guide-Using-Khan-Academy-Kids-at-Home ; https://khankids.zendesk.com/hc/en-us/articles/4403657703821-Find-books-and-lessons-in-the-Khan-Kids-Library)
7. **Батьківська зона.** Аватар → «For Parents» → секція **«Grown-Ups Only»**; там можна сховати таби Videos/Create і навіть іконку Home під час уроку, щоб дитина не вийшла. (https://khankids.zendesk.com/hc/en-us/articles/360047566151-How-do-I-access-parental-controls)
8. **Звук.** Веселий «ding» на правильно / м'який «bong» на неправильно — навмисно нейтральні до мови, не каральні. **[неперевірено первинним джерелом]**
9. **Тех.** Первинного підтвердження стеку немає — **[неперевірено]**.

### 2.3 Pok Pok Playroom (Apple Design Award 2021, «Delight and Fun»)

1. **Іконки/ілюстрація.** **Намальовано і анімовано вручну**, стартувало як скетчі на iPad. Палітра з іграшкового кораблика (червоний/жовтий/синій) формалізована у **рівно 11 кольорів + білий** як Sketch Color Variables. Художникам дозволено «трохи тремтіти» лініями — це навмисна hand-made неідеальність замість pixel-perfect. (https://developer.apple.com/news/?id=5bcex7xf ; https://www.sketch.com/blog/pok-pok/ ; https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom)
2. **Маскот.** Немає єдиного маскота; персонажі говорять безсловесним «gibberish» (озвучив саунд-дизайнер Matt Miller із дружиною), щоб апка була мовно-нейтральною. (https://developer.apple.com/news/?id=5bcex7xf ; https://www.commonsensemedia.org/app-reviews/pok-pok-playroom)
3. **Святкування — свідомо відсутні.** Креативна директорка Esther Huybreghts: **«There are no reward systems because it's open-ended. There's no flashing "congratulations" when you reach some goal»**. Нагорода — відкриття наступного шару складності в самому предметі (плазмова куля показує магнетизм глибше, коли дитина доростає). Три роки плейтестів; «kids are the smartest people in the room» — жодних туторіалів. (https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom ; https://developer.apple.com/news/?id=5bcex7xf)
4. **Копі/голос.** Немає тексту взагалі (багато користувачів не читають); підбадьорення — виключно дієгетичне (реакція предмета). (https://www.sketch.com/blog/pok-pok/)
5. **Мікровзаємодії.** «Тисячі анімацій»: перемикачі клацають, шестерні скрегочуть, краплі плюхають, дзвіночки дзвенять — **кожен елемент фізично реагує на дотик**; підтримка мультитачу двома руками. (https://developer.apple.com/news/?id=5bcex7xf ; https://www.sketch.com/blog/pok-pok/)
6. **Головний екран.** «Цифрова коробка іграшок» — полиця з іграшками без тексту і без меню. (https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom)
7. **Онбординг/батьки.** Онбордингу немає за задумом; підписка з безкоштовним пробним періодом. Деталі gate — **[неперевірено]**. (https://www.commonsensemedia.org/app-reviews/pok-pok-playroom)
8. **Звук — головний урок Pok Pok.** Засновники «поклялися», що батькам ніколи не доведеться вимикати звук у ресторані: **жодних зациклених джинглів і «вушних червів»**. Усе — справжній Foley (швабра, гриль, дерев'яні кубики, кухонні каструлі), розрахований на сотні повторів без втоми. Musical Blobs: колір ↔ нота (синій = C), коло = чиста синусоїда — «найпростіша форма → найпростіший звук», замість кліше «співаючих тварин». (https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom ; https://developer.apple.com/news/?id=5bcex7xf)
9. **Тех.** Дизайн — Sketch (Color Variables, Symbols, Libraries), релізи кожні 4–6 тижнів; рушій — **[неперевірено]**. (https://www.sketch.com/blog/pok-pok/)

### 2.4 Toca Boca (Toca Boca World / Toca Life)

1. **Іконки/ілюстрація.** Плоска заливка з легкою об'ємністю і **навмисною «рукотворністю»: «things shouldn't be too perfect, there is still dirt in the corners, and there is always a weird, quirky element»**. (https://motionographer.com/2016/04/27/the-design-process-behind-toca-bocas-infectious-apps/) Кольори UI синхронізовані Figma → Unity єдиною системою, власний SDF-конвертер спрайтів. (https://medium.com/toca-boca-tech-blog/coherent-ui-in-toca-boca-days-caacb7909614)
2. **Маскот.** Єдиного нема — ротація касту; персонажі реагують **невербально**: у Toca Kitchen «їхнє задоволення або огида — і є твоя нагорода». Голос — стилізований gibberish. (https://www.killscreen.com/secret-smart-kids-entertainment-give-them-toy-not-game/ ; https://soundeffects.fandom.com/wiki/Toca_life_animation/Sound_Effects_Used/Alphabetically)
3. **Святкування — свідомо відсутні.** «No rules, no levels, no winning or losing. Just play». Співзасновник Emil Overmar: змагання в дитинстві «блокувало решту досвіду»; натхнення — безцільна Little Computer People (1985). (https://www.killscreen.com/secret-smart-kids-entertainment-give-them-toy-not-game/ ; https://readwriterespond.com/2018/02/toca-boca/)
4. **Копі/голос.** Немає шару похвали/помилок — фідбек лише дієгетичний. (там само)
5. **Мікровзаємодії.** Публічно не описані на рівні тапів; інженерні пости — про рендеринг сотень анімованих інстансів. (https://medium.com/toca-boca-tech-blog/all?topic=unity)
6. **Головний екран.** Карта, яку можна панорамувати/зумити: ~90 локацій у 15 районах. (https://parental-control.flashget.com/toca-boca-world)
7. **Батьки.** Магазин за parental gate (утримання кнопки / рік народження); фріміум, без реклами. (там само)
8. **Звук.** Первинних матеріалів нема — **[неперевірено]**.
9. **Тех.** **Unity** з власним high-performance бекендом (BatchRendererGroup, Burst). (https://unity.com/blog/how-toca-boca-built-a-high-performance-scalable-rendering-backend)

### 2.5 Sago Mini World

1. **Іконки/ілюстрація.** Прості великі форми, мінімум тексту, ікон-навігація; власна команда ілюстраторів (Photoshop → Illustrator → Unity). (https://sagomini.com/article/meet-the-illustrator-a-q-and-a-with-village-artist-katherine-elliott/ ; https://sagomini.com/)
2. **Маскот.** Постійний каст тварин: Jinja (кішка), Jack (кролик), Harvey, Robin. (https://sagomini.com/characters/ ; https://sago-mini.fandom.com/wiki/Jinja)
3. **Святкування.** Відкрита гра «без інструкцій і правил»; конкретні секвенції — **[неперевірено]**.
4–5. **Копі, мікровзаємодії.** «Великі кольорові кнопки, чіткі візуальні підказки, мінімум тексту», drag-and-drop від 3 років. (https://sagomini.com/) Деталі — **[неперевірено]**.
6. **Головний екран.** Хаб «світів» (підписка об'єднує міні-апки). (https://www.commonsensemedia.org/app-reviews/sago-mini-apartment)
7–8. **[неперевірено]**
9. **Тех.** **Unity**, спільна «Core Tech» команда для всіх тайтлів (Sago Mini і Toca Boca — сестринські бренди Spin Master). (https://jobs.sagomini.com/apply/ekFd10IANQ/Unity-Game-Developer ; https://gamejobs.co/Engineering-Manager-Unity-App-Tools-at-Sago-Mini)

### 2.6 Endless Alphabet / Endless Reader (Originator)

1. **Іконки/ілюстрація.** М'які округлі мультяшні монстри; головний образ — монстр із літерами в роті; «lovable and irreverent cast». (https://joanganzcooneycenter.org/2017/05/15/the-app-fairy-interviews-originator/ ; https://www.educationalappstore.com/app/endless-alphabet)
2. **Маскот.** **Кожна літера — персонаж**: під час перетягування літера оживає (очі, рот, язик) і **безперервно вимовляє свою фонему, поки її тягнеш** — аудіо прив'язане до позиції пальця. Постійні монстри (Little Blue, Big Blue, Pistachio…). (https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/EndlessAlphabet ; https://originator.fandom.com/wiki/Endless_Monsters)
3. **Святкування.** Після складання слова — окрема анімація «Celebrate» (день народження: шапки, подарунки, торт із монстрами). **Жодних балів і валюти — «гра сама є нагородою»**. (https://originator-kids.fandom.com/wiki/Celebrate_(Endless_Alphabet) ; https://www.phonics.org/endless-alphabet-app-review/)
4. **Копі/голос.** Правильне розміщення — чітка назва літери; помилки структурно не існують: слово просто не складається. (https://www.phonics.org/endless-alphabet-app-review/)
5. **Мікровзаємодії.** Drag-to-match зі звуком під пальцем (див. 2). Літера, кинута не туди, повертається на місце **[неперевірено в деталях]**.
6–7. **[неперевірено]**
8. **Звук.** Спокійна фонова музика, «не відволікає»; критика фонетиків — зайвий schwa у фонемах. (https://www.phonics.org/endless-alphabet-app-review/)
9. **Тех.** **[неперевірено]**.

### 2.7 Lingokids

1. **Іконки/ілюстрація.** Кастомні плоскі мультяшні персонажі від Guillermo García-Carsí (автор Pocoyó); ребрендинг 2024 зробив п'ятьох персонажів «двигуном сторітелінгу» продукту й маркетингу. (https://www.learningcabinet.org/tool/lingokids/ ; https://lingokids.com/blog/posts/lingokids-new-brand-identity-kids-entertainment)
2. **Маскот.** Cowy (корова), Billy (курча), Lisa (кішка), Elliot (панда), Baby Bot — у відео-скетчах і пісеньках, не лише в UI. Пайплайн анімації — **[неперевірено]**. (https://lingokids.fandom.com/wiki/Billy ; https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn)
3–5. **Святкування, копі, мікровзаємодії.** Публічно не описані — **[неперевірено]**. Філософія «Playlearning: learning sticks when it's wrapped in fun». (https://apps.apple.com/us/app/lingokids-games-shows/id1002043426)
6. **Головний екран — антиприклад.** Одна велика сітка меню; Common Sense Media: **«lots of content and no guidance for kids in how to navigate through it»**. (https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn)
7. **Батьки.** Email → профіль дитини (ім'я, дата народження, рівень англійської), кілька профілів, таймер екранного часу, батьківська секція прогресу. (там само)
8. **Звук.** Пісні/шоу; таксономія SFX — **[неперевірено]**.
9. **Тех.** Історично native + **Unity** для ігор + Rails бекенд (StackShare); з 2021 вакансії **React Native**. (https://stackshare.io/companies/lingokids/stack ; https://lingokids.com/press/lingokids-is-looking-for-highly-qualified-talent-to-reinforce-its-international-growth)

### 2.8 Speech Blubs (найближчий до нашої задачі — розвиток мовлення)

1. **Іконки/ілюстрація.** Головний контент — **відео справжніх дітей** (video modelling), навколо — прості мультяшні іконки категорій, «consistent and predictable». (https://help.speechblubs.com/article/56-what-is-speech-blubs ; https://www.commonsensemedia.org/app-reviews/speech-blubs-language-therapy)
2. **Маскот.** Ротація тварин-гідів (лев, мавпа, жираф, пожежник); «моделлю» для наслідування є реальна дитина у відео. (https://www.educationalappstore.com/app/speech-blubs-language-therapy)
3. **Святкування — найкраще задокументована система нагород у вибірці.** (а) **AR-фільтр на обличчя**, що відповідає слову (сказав «monkey» — камера вмикається з вухами мавпи); (б) **стікер у стікербук** за кожне слово; (в) **хід у міні-грі** (balloon pop / star pop) кожні ~2 вправи; (г) випадковий «сюрприз-цукерка». (https://homeschooling4him.com/speech-blubs-review-speech-therapy-app-for-toddlers/ ; https://help.speechblubs.com/article/51-tips-tricks-for-using-speech-blubs)
4. **Копі/голос.** Явна ABA-філософія: **нагороджуємо спробу, а не правильність**; «просто дивись відео і роби як умієш, не хвилюючись про результат». (https://www.commonsensemedia.org/app-reviews/speech-blubs-language-therapy ; https://help.speechblubs.com/article/51-tips-tricks-for-using-speech-blubs)
5. **[неперевірено]**
6. **Головний екран.** 28 тематичних секцій, без карти. (https://apps.apple.com/us/app/speech-blubs-language-therapy/id1239522573)
7. **Батьки.** Анкета про мовні віхи → початкова оцінка → звіт; персоналізація головного екрану під інтереси; кілька профілів; нагадування у визначені дні/години; журнал використання. (https://www.commonsensemedia.org/app-reviews/speech-blubs-language-therapy)
8. **Звук.** Основний «звук» — голоси дітей (повільно/швидко), обґрунтування через дзеркальні нейрони. (https://help.speechblubs.com/article/56-what-is-speech-blubs)
9. **Тех.** **[неперевірено]**.

---

## 3. Решта апок — коротко

- **HOMER (Begin).** Після ребрендингу 2018 — новий стиль-гайд ілюстрацій, **кнопки й ілюстрації тестували безпосередньо на дітях**; використовує Lottie + нативну анімацію; архітектура — **плоска сітка категорій «за кілька тапів від головного меню»**, а не шлях. Єдиного маскота немає (претензії на «сову Ollie» не підтверджені). (https://gracekim-design.com/project/homer-rebrand ; http://www.hollydoodlestudio.com/homer-learn-grow ; https://apps.apple.com/us/app/homer-learn-grow/id601437586)
- **Otsimo (для дітей з аутизмом) — цінний контрприклад по кольору.** Власний дизайн-блог: **«intensive color usually distracts and gives anxiety»** — м'які, спокійні кольори, один плоский фон замість патернів, елемент має бути «great enough to be clickable and look clickable». Стани дотику: «touched / is touching / should not be touching / should touch next» із підсвіткою кола, пальцем-вказівником і вібрацією. Правильна відповідь — **оплески** (ABA «social praise»); помилок немає — є **prompting** до правильної відповіді. Мінус: інструкція звучить лише раз без повтору. (https://medium.com/otsimo/designing-ui-ux-for-children-with-autism-in-touch-devices-bdd4c7741586 ; https://childrenandmedia.org.au/app-reviews/apps/otsimo-special-education-aba ; https://www.commonsensemedia.org/app-reviews/otsimo-special-education-aac)
- **Papumba.** Плоска векторна система, теплі пастелі, каст Emma/Lio/David; **похвала перебільшена голосом** («you're a genius like Albert Einstein»), але фідбек на помилку «занадто тонкий для віку» і без підказок; головне меню з 4 пілярів + «Papumba Land» — рецензенти вважають його **перевантаженим** для наймолодших. Онбординг — вибір інтересів батьками. Стек — імовірно Unity (вакансії). (https://www.commonsensemedia.org/app-reviews/papumba-games-for-kids-2-7 ; https://dribbble.com/shots/9065817-Papumba-Academy-educational-app-for-kids ; https://www.papumba.com/)
- **Bini Games.** Яскраві насичені «світи», кожен зі своєю обгорткою; **«Live Letters» — літери з обличчями і характером**; 120+ спеціалістів, **Unity** для iOS/tvOS/Android. Деталі святкувань — **[неперевірено]**. (https://binibambini.com/products/bini-abc-games/ ; https://cy.linkedin.com/company/binicareer)
- **Kids Academy.** Маскот Eddie the Elephant; **зірки → магазин одягу для Eddie**, трофеї, колесо фортуни; але Common Sense Media: ігри «середньої якості», **«no feedback for helping kids understand what they may have done wrong»** — приклад, коли відсутність негативу є недоглядом, а не дизайном. (https://www.kidsacademy.mobi/storytime/announcing-new-feature-kids-academy-app/ ; https://www.commonsensemedia.org/app-reviews/kids-academy-talented-gifted)

---

## 4. Зведена таблиця

| Апка | Стиль ілюстрації | Маскот / анімація | Святкування | Помилка | Головний екран | Тех |
|---|---|---|---|---|---|---|
| Duolingo / ABC | плоский, 3 базові форми, без гострих кутів | Duo + каст; **Rive state machine**, 20+ візем, <1 МБ | конфеті + Duo-вибух + stagger stat-карток; milestone = унікальна анімація | м'який звук, прогрес усе одно росте, «Got it» | лінійний шлях, один наступний вузол | native + Rive |
| Khan Kids | плоский теплий | Kodi + 4 «предметні» тварини | Kodi стрибає + «Yay!» | жест «думаю» + демонстрація | будинок + одна велика зелена кнопка | ? |
| Pok Pok | ручний малюнок, 11 кольорів, навмисне тремтіння | немає; gibberish | **немає** («no flashing congratulations») | не існує | полиця іграшок без тексту | ? (Sketch) |
| Toca Boca | плоский із «брудом у кутах» | каст без головного; реакції дієгетичні | **немає** | не існує | карта 90 локацій | Unity |
| Sago Mini | прості великі форми | Jinja, Jack… | відкрита гра | не існує | хаб світів | Unity |
| Endless Alphabet | округлі монстри | **кожна літера — персонаж**, фонема під пальцем | «Celebrate»-сцена, без балів | слово просто не складається | категорії слів | ? |
| Lingokids | плоский Pocoyó-стиль | 5 персонажів у відео | ? | ? | **сітка без гайдансу (мінус)** | Unity/RN |
| Speech Blubs | відео дітей + прості іконки | тварини-гіди | **AR-фільтр + стікер + хід міні-гри** | нагорода за спробу | 28 секцій | ? |
| Otsimo | **спокійні кольори**, один фон | немає | оплески | prompting | сітка категорій | ? |

---

## 5. Синтез: 10 речей, які є в апці на 9/10 і немає в апці на 4/10

Ранжовано за впливом на відчуття якості. Для кожного пункту — що саме, доказ, і як це стосується нас.

### 1. Кожен тап відповідає трьома каналами одразу — і миттєво
**Що.** Візуальна реакція (squish/scale), звук і гаптика стартують на `pointerDown` (не на `onTap`), <100 мс; елемент фізично «просідає» і пружинить назад. У Pok Pok «тисячі анімацій» — кожна річ реагує на дотик; у Duolingo кнопка сідає на 4 px і spring-ом повертається; в Otsimo дотик підсвічується колом + вібрація. «Juice»: фідбек має бути читабельним, мультисенсорним і перебільшеним.
**Докази.** https://developer.apple.com/news/?id=5bcex7xf ; https://60fps.design/shots/duolingo-button-tactile-interaction ; https://medium.com/otsimo/designing-ui-ux-for-children-with-autism-in-touch-devices-bdd4c7741586 ; https://resprawn.medium.com/when-you-play-a-great-game-it-feels-good-d23761b6eccf
**Чому це #1.** Це єдина річ, яку дитина 1–2 років відчуває у 100% взаємодій. 4/10-апка має тап без звуку або зі затримкою 200–300 мс на `onTap` — і все виглядає «дешево», навіть із гарними картинками.
**Ми.** `KidTap`/`DT.pressMs = 140ms` є; перевірити, що реакція йде на `onTapDown`, що звук тапу (pop.wav) грає на кожен тап картки/плитки, а не тільки на «успіх», і що гаптика однакова на iOS/Android.

### 2. Жодного стану «неправильно»
**Що.** У 9/10 помилки структурно не існують: літера повертається на місце (Endless), персонаж «думає» і показує (Khan Kids), система підказує наступний крок (Otsimo prompting), нагорода дається за спробу (Speech Blubs), або взагалі немає win/lose (Toca, Pok Pok). У Duolingo навіть для дорослих: м'який звук, прогрес росте, кнопка «Got it». Kids Academy критикують саме за те, що «нема фідбеку, що робити далі» — тобто відсутність негативу без підказки — це також 4/10.
**Докази.** https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom ; https://childrenandmedia.org.au/app-reviews/apps/otsimo-special-education-aba ; https://help.speechblubs.com/article/51-tips-tricks-for-using-speech-blubs ; https://www.commonsensemedia.org/app-reviews/kids-academy-talented-gifted ; https://blakecrosley.com/guides/design/duolingo
**Ми.** Аудит усіх міні-ігор: на невірний вибір — не «х», не червоне, не «бзз», а: варіант м'яко «відскакує» (shake_animation_mixin), правильний варіант починає пульсувати/підсвічуватись через 1.5–2 с, голос повторює слово. Праведно повторювана інструкція (кнопка speaker) — Otsimo критикують за її відсутність.

### 3. Живий персонаж зі станами, а не статична картинка
**Що.** Маскот має idle (моргання, дихання, кивок — з варіативністю, щоб не зациклювався), реакцію на тап, «дивиться» на правильну відповідь, святкує, «думає» при помилці, вітає при вході. Duolingo: 8×8 варіантів idle, щоб не було відчуття циклу; Kodi обрана як ведмідь за читабельний силует і здатність показувати без слів.
**Докази.** https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life ; https://blog.duolingo.com/world-character-visemes ; https://khankids.zendesk.com/hc/en-us/articles/360049358751-Learn-more-about-the-characters-inside-Khan-Academy-Kids ; https://blog.duolingo.com/widget-feature/
**Ми.** `BloomMascot` — процедурний CustomPainter із двома емоціями (happy/waving) і bounce на тап. Це достойний фундамент, але 9/10 вимагає: постійний idle (моргання кожні 3–5 с із рандомом, легке «дихання» scale 1.0→1.02), мінімум 5 станів (idle, wave, cheer, think, sleepy), присутність на екрані карток (кутик) і в іграх, а не тільки на святкуванні. Технічно: або Rive (`rive` пакет, один .riv <1 МБ, state machine з inputs `emotion`, `tap`) — стандарт індустрії; або залишити CustomPainter, але додати idle-контролер. Lottie — гірший вибір для маскота (лінійне відтворення без state machine).

### 4. Один очевидний «наступний крок» без тексту
**Що.** Дитина 2–4 років не сканує сітку. Khan Kids: один великий будинок + одна велика зелена кнопка, яка сама вирішує, що далі, і продовжує з місця зупинки. Duolingo: лінійний шлях, один активний вузол, пройдені — золоті, персонажі стоять уздовж. Pok Pok: полиця іграшок. Антиприклади з рецензій: Lingokids («no guidance how to navigate»), Papumba («large activity menu may feel overwhelming»).
**Докази.** https://khankids.zendesk.com/hc/en-us/articles/360006764812-Parent-Guide-Using-Khan-Academy-Kids-at-Home ; https://blog.duolingo.com/new-duolingo-home-screen-design ; https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn ; https://www.commonsensemedia.org/app-reviews/papumba-games-for-kids-2-7
**Ми.** `DailyHeroCard` + `QuestJourneyMap` рухаються в цей бік. Критерій 9/10: на головному екрані рівно один елемент, який (а) найбільший, (б) пульсує/має персонажа, (в) один тап запускає активність без проміжних екранів. Сітка паків — другорядна, під ним.

### 5. Один стиль ілюстрації без винятків — і без Material-іконок/емодзі в дитячій зоні
**Що.** Duolingo: три базові форми, гострі кути off-brand, палітра з ролями. Pok Pok: 11 кольорів + білий, зафіксовані як змінні. Toca: рукотворні неідеальності — але **однакові** всюди. 4/10 видно одразу: іконки з Material поруч із мультяшною ілюстрацією, емодзі як іконки, три різні стилі картинок у сітці, гострі кути на кнопках.
**Докази.** https://www.scribd.com/document/583545694/Duolingo-Illustration-Guidelines ; https://www.sketch.com/blog/pok-pok/ ; https://motionographer.com/2016/04/27/the-design-process-behind-toca-bocas-infectious-apps/
**Ми.** `DT` палітра (coral/sunBurst/mint/sky/violet/peach/pink + тінти) — добра основа. Перевірити: (а) всі іконки ігор/табів — один сет (кастомний або один зовнішній набір із однією товщиною лінії), не `Icons.*` у дитячій зоні; (б) 471 картка — один стиль webp (якщо є «стильові викиди», їх видно у сітці); (в) радіуси уніфіковані (Duolingo — 16 px кнопки; у дітей можна більше).

### 6. Святкування — це секвенція з ритмом, а не одномоментний вибух конфеті
**Що.** Duolingo: конфеті → персонаж робить трюк → stat-картки в'їжджають stagger'ом з тікером цифр і окремим звуком на кожну → кнопка. Endless: окрема «Celebrate»-сцена з персонажами. Speech Blubs: нагорода **матеріальна і персональна** (стікер у книжку, AR-фільтр на своє обличчя, хід у міні-грі). Ключове: **звичайне і рідкісне святкування різні** — щоденний тікер vs унікальна анімація на milestone; одна така анімація дала +1.7% D7.
**Докази.** https://60fps.design/shots/duolingo-lesson-complete-head-explode-animation ; https://blog.duolingo.com/streak-milestone-design-animation ; https://duolingo.deconstructoroffun.com/mechanics/streaks ; https://homeschooling4him.com/speech-blubs-review-speech-therapy-app-for-toddlers/ ; https://originator-kids.fandom.com/wiki/Celebrate_(Endless_Alphabet)
**Ми.** `GameCelebrationOverlay` (маскот + конфеті + praise + одна велика кнопка) і `StreakMilestoneOverlay` є. Довести до 9/10: (а) stagger — маскот 0 мс, конфеті +100 мс, зірки/стікер +400 мс з окремим «дзинь» на кожну, кнопка +900 мс; (б) 3 рівні: правильний тап (0.3 с: іскри + pop), кінець гри (2–3 с: секвенція), milestone (унікальна анімація, яку дитина бачить рідко); (в) відчутна нагорода — стікер/наліпка, що лишається в колекції (`TreasureCard`/`RewardsScreen`).

### 7. Звук як система: таксономія SFX, голос під пальцем, і нічого, що батьки захочуть вимкнути
**Що.** Мінімальна таксономія 9/10: `tap` (короткий м'який pop, різна висота тону на різних елементах), `correct` (мажорний інтервал, як Duolingo F#→A#), `gentle-miss` (низький м'який «бум», не buzzer), `complete` (акорд/тада), `unlock`/`reward` (блиск), `transition` (свуш). Endless: фонема звучить **безперервно, поки тягнеш літеру**. Pok Pok: справжній Foley, «без зациклених джинглів — щоб не вимикали в ресторані»; висота ноти прив'язана до кольору. Otsimo: оплески як соціальна похвала.
**Докази.** https://www.losdoggies.com/archives/8816 ; https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/EndlessAlphabet ; https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom ; https://developer.apple.com/news/?id=5bcex7xf ; https://childrenandmedia.org.au/app-reviews/apps/otsimo-special-education-aba
**Ми.** `assets/audio_sfx` = pop/ding/tada (3 файли). Для 9/10 потрібно 8–12: додати `miss_soft`, `unlock_sparkle`, `swoosh`, `stagger_tick` (для тікерів), `applause_short`, 2–3 варіанти `pop` різної висоти (щоб не набридав). Не додавати фонові музичні лупи — Pok Pok доводить, що їх відсутність — плюс.

### 8. Голос говорить першим, часто, і його можна повторити
**Що.** Діти не читають: інструкція — голосом одразу при вході в екран; похвала — голосом (Khan Kids «Yay!», Papumba перебільшена похвала); нарація складається з блоків (Duolingo ABC: «The letter team» + літера + «says» + фонема). Otsimo критикують за інструкцію «один раз, швидко, без повтору». Sesame Workshop: текстова допомога для нечитачів не працює взагалі.
**Докази.** https://blog.duolingo.com/a-good-read-building-duolingo-abc-for-android/ ; https://www.commonsensemedia.org/app-reviews/otsimo-special-education-aac ; https://joanganzcooneycenter.org/wp-content/uploads/2020/02/SesameWorkshop-2012.pdf ; https://www.commonsensemedia.org/app-reviews/papumba-games-for-kids-2-7
**Ми.** praise_/instr_ кліпи заплановані (`tools/gen_praise_instructions.py`) — це прямий крок до 9/10. Правила: інструкція автоматично при відкритті гри; 6–8 варіантів похвали, що ротуються рандомно; 2–3 «м'які» фрази на промах («Спробуй ще!», «Майже!»); кнопка-спікер ≥72 dp на кожному ігровому екрані для повтору.

### 9. Батьківська зона — окремий світ із іншим тоном, за gate, і не «протікає» в дитячу
**Що.** Khan Kids: «Grown-Ups Only» за аватаром, можливість сховати таби і навіть Home під час уроку. Speech Blubs: анкета → оцінка → звіт, розклад нагадувань. Duolingo ABC: батько робить усе налаштування до того, як віддати планшет. Apple вимагає gate перед будь-яким лінком/покупкою.
**Докази.** https://khankids.zendesk.com/hc/en-us/articles/360047566151-How-do-I-access-parental-controls ; https://www.commonsensemedia.org/app-reviews/speech-blubs-language-therapy ; https://developer.apple.com/app-store/review/guidelines/
**Ми.** `showParentalGate()` і `ParentDashboardScreen` є. Планка 9/10: жодного тексту-для-батьків у дитячому екрані (ціни, «Преміум», «Налаштування» словами); один непомітний вхід (аватар/кут) → gate → зона з дорослою типографікою і спокійними кольорами; опція «замкнути в грі» (сховати навігацію).

### 10. Прощення дотику: 72 dp+, «tap + drag» = tap, нижній край вільний, мультитач не ламає
**Що.** Плейтести Duolingo ABC: діти тапають із мікро-драгом і тап не реєструється → зараховувати рух до N px як тап. Sesame Workshop: у landscape долоні лежать на нижньому краю — не ставити там цілі; NN/g: цілі для дітей 2×2 см проти 1×1 см для дорослих. Pok Pok: мультитач двома руками працює завжди.
**Докази.** https://www.thegiantroom.com/blog/05/31/2023/report-duolingoabc-playtesting-session ; https://joanganzcooneycenter.org/wp-content/uploads/2020/02/SesameWorkshop-2012.pdf ; https://www.nngroup.com/reports/children-on-the-web/ ; https://www.sketch.com/blog/pok-pok/
**Ми.** 72 dp правило є в CLAUDE.md. Додати: у `KidTap` — `GestureDetector` з `onTapDown` + tolerance (зараховувати як тап, якщо pointer up у межах ~24 px від down, навіть якщо Flutter класифікував як drag/pan); ігнорувати другий палець замість скидання стану; безпечна зона знизу в landscape.

### Бонус (не потрапило в топ‑10, але відрізняє 9/10)
- **Ритм сесії «4–5 завдань → розважальний екран»** (плейтести Duolingo ABC). https://www.thegiantroom.com/blog/05/31/2023/report-duolingoabc-playtesting-session
- **Наратив і гумор** підвищують запам'ятовування і рейтинг гри дітьми (там само).
- **Спокійна альтернатива кольору** для чутливих дітей (Otsimo) — опція «спокійний режим» у батьківській зоні. https://medium.com/otsimo/designing-ui-ux-for-children-with-autism-in-touch-devices-bdd4c7741586
- **Персонаж поза апкою** (віджет Duo з настроями; Kodi у YouTube) — утримання без пушів. https://blog.duolingo.com/widget-feature/

---

## 6. Технічні підказки для Flutter-команди

| Потреба | Що робить індустрія | Що взяти нам |
|---|---|---|
| Маскот зі станами | Rive state machine (Duolingo; .riv < 1 МБ; 8×8 idle-варіацій) | `rive` пакет: один artboard, inputs `emotion` (enum), `tap` (trigger), `talking` (bool). Або поки — `BloomMascot` + idle AnimationController із рандомним морганням. Гайд: https://dev.to/uianimation/how-to-implement-onboarding-mascots-in-flutter-with-rive-53mi ; Rive vs Lottie: https://tillitsdone.com/blogs/rive-vs-lottie--flutter-animations/ |
| Одноразові святкові анімації | Lottie/Rive для milestone; конфеті — партикли | Для унікальних milestone-анімацій — Rive/Lottie файл; для повсякденного — `ConfettiBurst` (CustomPainter) достатньо |
| Кнопка «3D» | 4 px нижня межа, просідання на 4 px, spring назад | `AnimatedContainer`/`Transform.translate` на `onTapDown`, `SpringSimulation` або `Curves.elasticOut` 180–220 мс на release |
| Stagger-святкування | Секвенція з окремими звуками | `flutter_animate` або власна `Interval` на одному контролері; кожна stat-картка — свій `AudioService.playSfx` |
| Звук під пальцем (drag) | Endless Alphabet | `flutter_soloud` вже дозволяє loop/pitch; при `onPanStart` — play word loop, `onPanEnd` — stop |
| Гаптика | Duolingo: тонка, не «бомбардування» | `HapticFeedback.lightImpact` на tapDown, `mediumImpact` на correct, `selectionClick` на stagger-тікери; для 1–4 років гаптика підсилює ритм, а не несе сенс (https://developer.android.com/develop/ui/views/haptics/haptics-principles) |
| Рушії конкурентів | Unity (Toca, Sago, Bini, Lingokids-ігри, ймовірно Papumba); native+Rive (Duolingo); Lottie+native (HOMER) | Flutter цілком достатньо: жодна з описаних технік не вимагає рушія; критично лише 60 fps на слабких пристроях (CustomPainter/RepaintBoundary, без offscreen-шейдерів) |

---

## 7. Швидкий чекліст самооцінки (для рев'ю нових екранів)

- [ ] Реакція на `pointerDown` <100 мс: squish + звук + гаптика
- [ ] Немає червоного/«х»/buzzer на промах; є підказка через 1.5–2 с
- [ ] Маскот присутній і має idle (моргання/дихання), а не стоїть статично
- [ ] На екрані один найбільший елемент = наступний крок
- [ ] Жодної `Icons.*`/емодзі поруч із кастомною ілюстрацією
- [ ] Святкування — секвенція зі stagger та окремими звуками; рідкісне ≠ щоденне
- [ ] Інструкція звучить автоматично; кнопка повтору ≥72 dp
- [ ] Текст лише за parental gate
- [ ] Тап із мікро-драгом зараховується; другий палець не ламає стан
- [ ] Немає фонового музичного лупу, який батьки захочуть вимкнути

---

## 8. Джерела (зведено)

**Duolingo (первинні):** https://blog.duolingo.com/world-character-visemes · https://blog.duolingo.com/new-duolingo-home-screen-design · https://blog.duolingo.com/streak-milestone-design-animation · https://blog.duolingo.com/core-tabs-redesign/ · https://blog.duolingo.com/widget-feature/ · https://blog.duolingo.com/product-highlights/ · https://blog.duolingo.com/a-good-read-building-duolingo-abc-for-android/ · https://blog.duolingo.com/hub/design/ · https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life · https://rive.app/blog/creative-technologists-duolingo-s-solution-to-the-designer-to-developer-handoff · https://www.tipranks.com/news/press-releases/duolingo-doubles-down-on-design-and-animation-with-acquisition-of-hobbes · https://www.monotype.com/studio/portfolio/duolingo
**Duolingo (вторинні/розбори):** https://blakecrosley.com/guides/design/duolingo · https://60fps.design/shots/duolingo-lesson-complete-head-explode-animation · https://60fps.design/shots/duolingo-button-tactile-interaction · https://duolingo.deconstructoroffun.com/mechanics/streaks · https://www.scribd.com/document/583545694/Duolingo-Illustration-Guidelines · https://www.losdoggies.com/archives/8816 · https://www.thegiantroom.com/blog/05/31/2023/report-duolingoabc-playtesting-session · https://dscout.com/case-studies/duolingo-case-study · https://www.commonsensemedia.org/app-reviews/duolingo-abc-learn-to-read
**Khan Academy Kids:** https://khankids.zendesk.com/hc/en-us/articles/360049358751-Learn-more-about-the-characters-inside-Khan-Academy-Kids · https://khankids.zendesk.com/hc/en-us/articles/360006764812-Parent-Guide-Using-Khan-Academy-Kids-at-Home · https://khankids.zendesk.com/hc/en-us/articles/360047566151-How-do-I-access-parental-controls · https://blog.khanacademy.org/khan-academy-adds-apps-for-young-children/ · https://svgapp.ai/app-mascots/khan-academy-kids/
**Pok Pok:** https://developer.apple.com/news/?id=5bcex7xf · https://www.sketch.com/blog/pok-pok/ · https://www.gamedeveloper.com/design/how-just-letting-kids-be-kids-drives-the-design-of-pok-pok-playroom · https://www.commonsensemedia.org/app-reviews/pok-pok-playroom
**Toca Boca / Sago Mini:** https://motionographer.com/2016/04/27/the-design-process-behind-toca-bocas-infectious-apps/ · https://www.killscreen.com/secret-smart-kids-entertainment-give-them-toy-not-game/ · https://medium.com/toca-boca-tech-blog/coherent-ui-in-toca-boca-days-caacb7909614 · https://unity.com/blog/how-toca-boca-built-a-high-performance-scalable-rendering-backend · https://sagomini.com/characters/ · https://jobs.sagomini.com/apply/ekFd10IANQ/Unity-Game-Developer
**Endless Alphabet:** https://joanganzcooneycenter.org/2017/05/15/the-app-fairy-interviews-originator/ · https://www.phonics.org/endless-alphabet-app-review/ · https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/EndlessAlphabet · https://originator-kids.fandom.com/wiki/Celebrate_(Endless_Alphabet)
**Lingokids / Speech Blubs / Otsimo / Kids Academy:** https://lingokids.com/blog/posts/lingokids-new-brand-identity-kids-entertainment · https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn · https://stackshare.io/companies/lingokids/stack · https://help.speechblubs.com/article/56-what-is-speech-blubs · https://help.speechblubs.com/article/51-tips-tricks-for-using-speech-blubs · https://www.commonsensemedia.org/app-reviews/speech-blubs-language-therapy · https://homeschooling4him.com/speech-blubs-review-speech-therapy-app-for-toddlers/ · https://medium.com/otsimo/designing-ui-ux-for-children-with-autism-in-touch-devices-bdd4c7741586 · https://childrenandmedia.org.au/app-reviews/apps/otsimo-special-education-aba · https://www.commonsensemedia.org/app-reviews/kids-academy-talented-gifted · https://www.kidsacademy.mobi/storytime/announcing-new-feature-kids-academy-app/
**HOMER / Papumba / Bini:** https://gracekim-design.com/project/homer-rebrand · http://www.hollydoodlestudio.com/homer-learn-grow · https://www.commonsensemedia.org/app-reviews/papumba-games-for-kids-2-7 · https://dribbble.com/shots/9065817-Papumba-Academy-educational-app-for-kids · https://binibambini.com/products/bini-abc-games/ · https://cy.linkedin.com/company/binicareer
**Гайдлайни та craft:** https://joanganzcooneycenter.org/wp-content/uploads/2020/02/SesameWorkshop-2012.pdf · https://www.nngroup.com/reports/children-on-the-web/ · https://developer.apple.com/app-store/review/guidelines/ · https://play.google.com/console/about/programs/teacherapproved/ · https://rosenfeldmedia.com/books/design-for-kids/ · https://resprawn.medium.com/when-you-play-a-great-game-it-feels-good-d23761b6eccf · https://tillitsdone.com/blogs/rive-vs-lottie--flutter-animations/ · https://dev.to/uianimation/how-to-implement-onboarding-mascots-in-flutter-with-rive-53mi · https://developer.android.com/develop/ui/views/haptics/haptics-principles
