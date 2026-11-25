# Опенсорс: механіки й пакети для дитячих ігор (2026-11-25)

**[V]** — перевірено з LICENSE / репозиторію / pub.dev; **[I]** — висновок дослідника.
Код можна брати лише з MIT/BSD/Apache. GPL/AGPL — тільки ідеї.

## A. Проєкти

| Проєкт | Ліцензія | Код? | Що взяти для 1–4 |
|---|---|---|---|
| [GCompris](https://github.com/gcompris/GCompris-qt) | AGPL-3/GPL-3 [V] | Ні, ідеї | `baby_mouse` (будь-який дотик дає ефект), `babymatch`/`babyshapes` (перетягни на силует), `explore_farm_animals` (тварина → звук → назва), `memory-sound` (пари за звуком) |
| [Feed the Monster JS](https://github.com/curiouslearning/FeedTheMonsterJS) | MIT, арт CC BY [V] | Так | Нагодуй персонажа правильним предметом, він росте; яйце → новий друг |
| [Antura](https://github.com/vgwb/Antura) | BSD-2, арт CC BY 4.0 [V] | Так (Unity) | Balloons, HideAndSeek, Egg (механіки [I]; вік 5+) |
| [Kitkit School](https://github.com/XPRIZE/GLEXP-Team-KitkitSchool) | Apache-2.0 [V] | Так (C++) | Tapping, AnimalPuzzle, WoodenPuzzles, FindTheMatch, EggQuiz [I] |
| [Sugarizer](https://github.com/llaske/sugarizer) | Apache-2.0 [V] | Так (JS) | Speak (обличчя, що говорить), TamTamMicro (дотик = звук) |
| [BabySmash](https://github.com/shanselman/babysmash) | MIT [V] | Так | Будь-який дотик — фігура + звук, помилитись неможливо |
| [Tux Paint](https://tuxpaint.org/features/) | GPL [I] | Ні, ідеї | Штампи, що кажуть свою назву; чарівні пензлі |
| Cboard / AsTeRICS Grid | GPL-3 / AGPL-3 [V] | Ні, ідеї | Торкнись символу → звучить; стрічка з 2–3 символів |
| [Rhubarb Lip Sync](https://github.com/DanielSWolf/rhubarb-lip-sync) | MIT [V] | Так (офлайн-інструмент) | 6–9 форм рота з mp3 — ліпсинк Блума |

## B. Топ-10 ідей, яких у нас немає

1. Звуки тварин: торкнись — почуй, потім «хто це сказав?».
2. Нагодуй Блума: він просить «яблуко», дитина тягне картку йому в рот.
3. Сортер силуетів: перетягни картинку на її тінь, слово звучить при влучанні.
4. Дошка вільного дотику для 1-річних: кожен дотик — картинка + слово, без помилок.
5. Голос робить дію: гучність надуває кульку чи задуває свічки (`flutter_recorder`).
6. Хованки: «Де котик?» → торкнись → «Ось він!».
7. Яйце, з якого вилуплюється друг після кількох названих слів.
8. Наліпки, що кажуть своє слово, коли їх клеїш.
9. Блум рухає ротом під озвучку (Rhubarb, попередній розрахунок).
10. Пари за звуком (для 3–4).

## C. Пакети Flutter (pub.dev [V])

| Пакет | Ліцензія | Вердикт |
|---|---|---|
| flutter_recorder (2.0.8, 2026-11) | Apache-2.0 | Брати: автор flutter_soloud; гучність, FFT, тиша, PCM |
| rive / lottie | MIT | Для маскота |
| flame, forge2d | MIT / BSD-3 | Лише якщо потрібна фізика |
| flutter_confetti, newton_particles | MIT | Годяться |
| vad (Silero) | MIT | Можливе покращення детектора голосу |
| pitch_detector_dart | BSD-3 | Застарілий, але робочий |
| scratcher, tracing_game, flutter_jigsaw_puzzle | MIT | Покинуті — лише читати |
| whisper_flutter_new | GPL-3 | Не брати |

## D. Розпізнавання мовлення на пристрої

- Реально вже зараз, офлайн: початок голосу, тривалість, гучність, тиша, FFT → «голос робить дію», плескання по складах, гучно/тихо, дмухання.
- Розпізнавання слів у 1–4 роки нереалістичне [I]: даних про точність до 5 років не знайдено. Ніколи не ставити успіх у залежність від розпізнавання.
- Vosk: українські моделі 73–343 МБ, iOS-обгортки слабкі. sherpa-onnx: ключові слова лише EN/ZH. whisper.cpp: 75+ МБ, повільно на старих планшетах.

## Асети

- ARASAAC: CC BY-NC-SA, комерційне використання виключене — **у платну апку не можна**.
- Kenney CC0 — лише UI-звуки. Freesound — ліцензія на кожен файл, фільтрувати CC0 вручну.
- OpenMoji / Mulberry: CC BY-SA 4.0; Fluent Emoji: MIT.
