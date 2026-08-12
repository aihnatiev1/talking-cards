# Spanish (es-419) — Activation Checklist

Staged Spanish content. NOT active yet — `es_cards.json` and
`notifications_es.json` deliberately live here (not in `assets/`) because
`test/content/audio_integrity_test.dart` would fail without the 279 Spanish
mp3 files. `assets/l10n/ui_es.json` IS already live (safe: pure text asset,
covered by the source-scan completeness contract).

## What is staged here

| File | Destination when activating |
|---|---|
| `es_cards.json` | `assets/data/es_cards.json` |
| `notifications_es.json` | `assets/l10n/notifications_es.json` |
| `locales_entry.json` | append object to `assets/l10n/locales.json` |
| `es_voiceover_script.md` | input for TTS generation (stays out of assets) |

Already live: `assets/l10n/ui_es.json` (256 keys — full coverage of
`test/fixtures/l10n_strings.json`; plural keys use `{one, other}` maps per
es CLDR rules, supported by `lib/l10n/plural_rules.dart`).

## Content summary

- 11 packs, 279 cards (all base packs; NO sound_* / phoneme packs — those are
  language-specific, es v1 ships without them, hence `articulation: false`).
- IDs: `en_a01` → `es_a01`; audio keys: `en_cat` → `es_cat`; `image` unchanged
  (illustrations are shared across languages).
- `transcription` field dropped (EN IPA does not apply to Spanish).
- TTS-safe: no onomatopoeia in card sentences; notification texts DO use
  animal sounds (MIAU, GUAU…) — fine, they are read, never synthesized.

## Activation steps (in order)

1. **Generate audio** from `es_voiceover_script.md` via ElevenLabs
   (needs API key; pick a warm neutral-LatAm voice). One mp3 per card:
   word + 0.5–1.0 s pause + sentence, named exactly as the card's `audio`
   key (`es_cat.mp3`, …) → `assets/audio_mp3/`. 279 files expected.
2. Add word-cut timestamps for the new clips to
   `assets/data/audio_word_lengths.json` (needed by `playWordOnly`).
3. Move `es_cards.json` → `assets/data/es_cards.json` and wire pack loading
   for locale `es` (flutter-dev: wherever `en_cards.json` is loaded per
   locale).
4. Move `notifications_es.json` → `assets/l10n/notifications_es.json`.
5. Append `locales_entry.json` content to `assets/l10n/locales.json`.
6. `flutter test test/` — `audio_integrity_test` now validates the es deck;
   all 279 audio keys must resolve.
7. Store metadata: add `es-MX` (App Store) / `es-419` (Play) fastlane
   metadata — publisher agent.

## Decisions needing owner approval

### 1. Flag emoji — proposal: 🌎 (globe showing the Americas)
Neutral LatAm Spanish has no single country. 🇲🇽 would read as
"Mexico-only" to Colombian/Argentine/US-Hispanic parents; 🇪🇸 signals
Castilian Spanish, which this is NOT (no vosotros, LatAm vocabulary:
carro, jugo, papa, durazno, cachetes). 🌎 (Americas-facing globe) is the
convention several kids' apps use for es-419. `locales_entry.json` ships
with 🌎; swap if you prefer a country flag.

### 2. Brand / appTitle — default: "FirstWords Cards"
Options:
- **"FirstWords Cards"** (current default in `locales_entry.json`) — one
  global EN brand, matches App Store listing name, zero extra trademark and
  ASO work.
- **"Mis Primeras Palabras"** — fully localized, warmer for parents, better
  Spanish ASO keywords, but fragments the brand and needs its own store
  listing treatment.
- Hybrid: keep brand, localized subtitle in the store listing
  ("FirstWords Cards — mis primeras palabras").
Recommendation: hybrid; keep the entry as-is.

### 3. Vocabulary picks flagged for native-speaker review
Regional variance — best-guess neutral choices, please have an es-419
native confirm:
- `es_t17` SCOOTER (patín del diablo MX / monopatín Cono Sur) — kept the
  loanword "scooter"
- `es_fd02` PLÁTANO (banana/banano/guineo elsewhere)
- `es_fd16` TARTA for "pie" (pay MX / kuchen CL)
- `es_c10` CAFÉ for brown (marrón in Cono Sur)
- `es_adj05` ÁSPERO for "bumpy" (no clean one-word LatAm equivalent)
- `es_b23` CACHETES (mejillas is more formal/universal)
- `es_fd20` PANQUEQUE (hotcake MX)
- UI: "el intruso" for "Odd one out"; "quiz" kept as loanword; "Peque" as
  default child name ("Kiddo").
- Gender defaults are masculine-generic (enojado, cansado, "Nombre del
  niño") — standard for kids' apps, but flagging it.

### 4. Notification deck deviations (intentional, not translation drift)
EN daily items about the syllable game and R/L/SH/S phoneme packs were
replaced with generic word/animal/opposites prompts because es v1 ships
with `syllableGame: false` and `articulation: false` — a push must not
advertise a feature the locale doesn't have. Same deck size (31/7/4/1).
