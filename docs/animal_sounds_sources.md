# «Звуки тварин» / Animal Sounds — sources

Pack ids `animal_sounds` (UA, 25 cards) and `en_animal_sounds` (EN, 25 cards),
built by `tools/build_animal_sounds_pack.py` (it lists every animal, its
recording and the cut used).

**Illustrations** — generated in Adobe Firefly (Gemini 3.0 / 3.1), square PNG →
900² webp, `assets/images/webp/ph_<animal>.webp`.

**Real recordings** — each card clip is the narrator's word, a pause, then the
recording below.

| Animals | Source | Licence |
|---|---|---|
| cat, dog, cow, horse, pig, sheep, goat, donkey, hen, rooster, bird, crow, owl, wolf, bee, lion, tiger, monkey, snake | mixkit.co/free-sound-effects/animals (ids in the script) | Mixkit Sound Effects Free License — commercial use in apps, no attribution |
| duck, frog, bear, elephant, deer (elk), bunny, dolphin, whale, crocodile (alligator bellow) | Wikimedia Commons (file names in the script) | CC0 / public domain |

Mixkit licence: https://mixkit.co/license/#sfxFree

**Narrator** — existing card voice, cut at the word end. Four UA words the
narrator never recorded (ОВЕЧКА, КОЗЕНЯТКО, ОСЛИК, ВОРОНА) use the macOS
«Lesya» voice as a stand-in: record them with the card voice, drop the mp3
into `assets/audio_mp3/`, replace the `('tts', …)` tuple in the script with the
clip name and re-run.
