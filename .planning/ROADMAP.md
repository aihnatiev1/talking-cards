# Roadmap — Milestone 2: Growth & Engagement

Phases execute sequentially. Each phase = one atomic, shippable feature.  
Start with: `/gsd:plan-phase 1` (or manually: read REQUIREMENTS.md Phase 1, implement, commit)

---

## Phase 1 — Memory Match Game
**Goal:** Ship a fully playable flip-card memory match game.

**Deliverables:**
- `lib/screens/memory_match_screen.dart` — new game screen
- `lib/screens/memory_match_result_screen.dart` — end-of-game stars + score
- `lib/providers/memory_match_provider.dart` — game state (flipped, matched, attempts, timer)
- `lib/models/memory_match_state.dart` — board state model
- HomeScreen: "Memory" button in game modes section
- CardsScreen: "Грати Memory" button at bottom
- DailyQuest: new `QuestTask.playMemoryMatch` task (replaces or adds to existing 5)
- Audio: play card's audioKey on flip (reuse SoLoud)

**Key files to touch:**
- `lib/screens/home_screen.dart` — add entry point
- `lib/screens/cards_screen.dart` — add entry point
- `lib/providers/daily_quest_provider.dart` — add new task type
- `lib/models/quest_task.dart` (or wherever QuestTask enum lives)

**Success criteria:**
- [ ] Can start a game from HomeScreen choosing any pack
- [ ] Cards flip with 3D animation, audio plays
- [ ] Matched pairs stay face-up, unmatched flip back after 1s
- [ ] Game ends, star rating shown (1–3 stars based on attempts)
- [ ] Completing a game marks the daily quest task done
- [ ] Works on iPhone SE (no overflow)

---

## Phase 2 — Multi-Profile Support
**Goal:** Up to 3 isolated child profiles, each with separate progress/streaks/quests.

**Deliverables:**
- `lib/models/profile_model.dart` — Profile data class
- `lib/providers/profile_provider.dart` — active profile, list, CRUD
- `lib/screens/profile_selector_screen.dart` — full-screen picker on first launch / when switching
- `lib/widgets/profile_avatar_chip.dart` — tappable chip in HomeScreen AppBar
- `lib/services/profile_storage_service.dart` — namespaced SharedPreferences wrapper
- Migration: existing data → `profile_default` on upgrade
- All 9 data providers updated to use namespaced keys

**Key files to touch:**
- `lib/screens/home_screen.dart` — avatar chip in AppBar
- All providers in `lib/providers/` — key namespacing
- `lib/main.dart` — ensure ProfileProvider initialized before other providers

**Success criteria:**
- [ ] Can create up to 3 profiles with name + emoji avatar
- [ ] Switching profiles updates all data (streak, quest, progress) instantly
- [ ] Deleting a profile removes all its data
- [ ] Fresh install: shows profile creation screen
- [ ] Upgrade from v1.0.x: existing data preserved as first profile
- [ ] Subscription/purchase state is NOT per-profile (global)

---

## Phase 3 — Lifetime IAP
**Goal:** Add one-time `lifetime_premium` purchase to PaywallScreen.

**Deliverables:**
- New SKU registered in App Store Connect: `lifetime_premium` (non-consumable)
- `lib/services/purchase_service.dart` — handle `lifetime_premium` product + entitlement
- `lib/screens/paywall_screen.dart` — add Lifetime option (third card, "Назавжди" label)
- Entitlement: `isPremium` = true if any active subscription OR lifetime purchase present
- Restore: existing flow covers non-consumable automatically
- Analytics: `purchase_lifetime_start`, `purchase_lifetime_success`

**Key files to touch:**
- `lib/services/purchase_service.dart`
- `lib/screens/paywall_screen.dart`

**Success criteria:**
- [ ] Lifetime option visible on PaywallScreen with price
- [ ] Tapping Lifetime → StoreKit purchase sheet
- [ ] After purchase: all packs unlocked, same as subscription
- [ ] Restore purchases: lifetime restored correctly
- [ ] Monthly/yearly unaffected
- [ ] PaywallScreen not broken on iPhone SE with 3 options

---

## Phase 4 — Spaced Repetition (SM-2)
**Goal:** Cards shown at scientifically optimal review intervals; SRS queue visible on HomeScreen.

**Deliverables:**
- `lib/models/srs_card_state.dart` — per-card SM-2 state
- `lib/services/sm2_service.dart` — pure SM-2 algorithm (ease factor, interval, next date)
- `lib/providers/srs_provider.dart` — SRS queue, per-profile, persisted
- `lib/screens/srs_review_screen.dart` — review session (cards due today, max 20)
- HomeScreen: "Повторити сьогодні: N" widget when queue non-empty
- QuizScreen: on answer, update SRS state for that card
- DailyQuest: new task `reviewSRSCards` (review 5 SRS-due cards)

**Key files to touch:**
- `lib/screens/home_screen.dart` — SRS queue widget
- `lib/screens/guess_screen.dart` — feed SRS quality after each answer
- `lib/providers/daily_quest_provider.dart` — new task

**Success criteria:**
- [ ] After first quiz session, SRS states created for answered cards
- [ ] Next day: due cards appear on HomeScreen counter
- [ ] SRS review session: shows only due cards, updates intervals on completion
- [ ] Wrong quiz answer: card interval resets to 1 day
- [ ] Correct first try: interval progresses per SM-2 formula
- [ ] SRS state namespaced per profile (Phase 2 prerequisite)

---

## Phase 5 — Speech Recognition (iOS)
**Goal:** Mic button on cards lets the child say the word; app validates pronunciation.

**Deliverables:**
- Add `speech_to_text` to `pubspec.yaml`
- `lib/services/speech_service.dart` — wraps speech_to_text, handles permissions, lifecycle
- `lib/widgets/speech_mic_button.dart` — animated mic with waveform listening indicator
- CardsScreen: mic button on front face of card (visible only when card is face-up)
- Validation: compare recognized text to `card.sound` (case-insensitive, trim)
- Feedback: ✅ correct animation / ❌ retry prompt (max 3 attempts)
- DailyQuest: new task `speakWords` (speak 3 words correctly per day)
- iOS Info.plist: `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`

**Key files to touch:**
- `lib/screens/cards_screen.dart` — add mic button
- `ios/Runner/Info.plist` — permissions
- `lib/providers/daily_quest_provider.dart` — new task

**Success criteria:**
- [ ] Mic button appears on card face when face-up
- [ ] Permission prompt shown on first use only
- [ ] Speaking correct word → green animation, quest counter increments
- [ ] Speaking wrong word → gentle retry (up to 3x), then show correct word
- [ ] Mic button hidden if speech recognition unavailable
- [ ] Works without internet (on-device recognition)

---

## Phase 6 — Seasonal Packs
**Goal:** 4 holiday-themed free packs that appear/disappear based on calendar date.

**Deliverables:**
- `assets/data/seasonal_packs.json` — all 4 packs × 15 cards = 60 cards (content + metadata)
- `assets/audio/seasonal/` — 60 audio files (`.mp3`)
- `lib/models/seasonal_pack_model.dart` (or extend PackModel with `activeFrom`/`activeTo` fields)
- `lib/providers/seasonal_packs_provider.dart` — filters packs by current date
- HomeScreen: seasonal packs shown above or between regular packs when active
- Special shimmer border on seasonal pack card
- Notification: push on first active day of each seasonal pack
- `lib/services/notification_service.dart` — schedule seasonal notifications at install time

**Key files to touch:**
- `lib/screens/home_screen.dart` — render seasonal section
- `lib/services/notification_service.dart` — seasonal push scheduling
- `pubspec.yaml` — register new asset paths

**Success criteria:**
- [ ] Christmas pack visible Dec 1 – Jan 15, invisible otherwise
- [ ] Easter pack visible Apr 1 – May 15
- [ ] Summer pack visible Jun 15 – Aug 31
- [ ] Autumn pack visible Oct 1 – Nov 15
- [ ] Packs accessible without subscription
- [ ] Shimmer border visible on seasonal pack cards
- [ ] Push notification fires on first day of each season

---

## Phase 7 — Parent Dashboard
**Goal:** PIN-protected parent area with per-profile learning analytics.

**Deliverables:**
- `lib/screens/parent_dashboard_screen.dart` — tabbed dashboard
- `lib/screens/parent_pin_screen.dart` — PIN setup + entry
- `lib/widgets/parent/weekly_chart_widget.dart` — 7-day bar chart
- `lib/widgets/parent/pack_progress_list.dart` — pack progress bars
- `lib/widgets/parent/weak_words_list.dart` — top 10 mistake cards
- `lib/providers/parent_auth_provider.dart` — PIN state (set/check/reset)
- Settings screen: long-press gear (2s) → PIN prompt → dashboard
- PIN storage: SharedPreferences `parent_pin` key (plain 4-digit string)

**Key files to touch:**
- `lib/screens/settings_screen.dart` (or wherever settings gear lives)
- `lib/providers/quiz_provider.dart` — expose mistake counts

**Success criteria:**
- [ ] Long-press settings gear → PIN setup on first access
- [ ] Correct PIN → dashboard opens
- [ ] Dashboard shows: active days, words seen, streak, pack progress
- [ ] Weekly chart: 7 bars matching DailyStatsProvider data
- [ ] Weak words: cards sorted by quiz mistake count descending
- [ ] Profile switcher within parent area (view any child's stats)
- [ ] Back button exits to app without re-entering PIN
- [ ] PIN reset flow works

---

## Dependency Map

```
Phase 1 (Memory Match)     — standalone
Phase 2 (Multi-profile)    — standalone (but: all later phases benefit from it)
Phase 3 (Lifetime IAP)     — standalone
Phase 4 (SRS)              — benefits from Phase 2 (namespaced storage)
Phase 5 (Speech)           — standalone
Phase 6 (Seasonal Packs)   — standalone
Phase 7 (Parent Dashboard) — requires Phase 2 (multi-profile) + Phase 4 (SRS tab)
```

Phases 1–3 are fully independent. Phases 4–7 are buildable in order but assume Phase 2 is done.

---

## Phase 8 — English Market (Language per Profile)
**Goal:** Add English as a learnable language. Each profile can choose Ukrainian or English. English content uses existing card images + `soundEn` field — no audio for now.

**Deliverables:**
- `assets/data/en_cards.json` ✅ **done** — 209 English cards across 7 packs (Animals, Home & Family, Feelings, Transport, Food & Fruits, Colors & Shapes, Body Parts), reusing existing images
- `lib/providers/language_provider.dart` — per-profile language setting ('uk' / 'en'), persisted in SharedPreferences with profile prefix
- `lib/providers/packs_provider.dart` — updated to load `uk_cards.json` or `en_cards.json` based on active language
- `lib/screens/profile_selector_screen.dart` — language chip in profile create/edit dialog
- `lib/widgets/profile_avatar_chip.dart` — show flag emoji alongside avatar when language ≠ 'uk'
- App Store metadata — add English locale in App Store Connect (en-US): title "Talking Cards", subtitle, description, screenshots

**Language switching UX:**
- Profile create/edit dialog: "Яку мову вчимо?" → 🇺🇦 Українська | 🇬🇧 English
- When language switches: invalidate `packsProvider` → reloads with correct JSON
- Cards display `sound` (EN) — the `soundEn` value is already in `sound` field of en_cards.json
- No audio mic button in EN mode until English audio is recorded (hide `SpeechMicButton` when language = 'en')

**Key files to touch:**
- `lib/providers/packs_provider.dart` — `ref.watch(languageProvider)` to pick JSON file
- `lib/providers/profile_provider.dart` — add `languageProvider` to invalidation list
- `lib/screens/profile_selector_screen.dart` — add language selector to `_ProfileEditDialog`
- `lib/screens/cards_screen.dart` — hide mic button when `language == 'en'`

**Success criteria:**
- [ ] New profile can choose 🇬🇧 English during creation
- [ ] Switching profile to EN: packs grid shows 7 English packs with images
- [ ] Cards show English word (e.g. "CAT"), image visible, no audio button
- [ ] Switching back to Ukrainian profile: Ukrainian packs reload instantly
- [ ] Existing Ukrainian users unaffected (default language = 'uk')
- [ ] App Store page has English metadata

**Future: EN audio**
When English audio is recorded:
- Add audio files to `assets/audio_mp3/` with `en_` prefix
- Add `audio` field to `en_cards.json` entries
- `AudioService` already handles them — no code changes needed

---

## Phase 9 — Games Block + Content Reorganization

**Goal:** Move games out of the pack grid into a dedicated "Games" section. Add Sorting game. Add age/level selector to profiles.

### Step 1: Games Section in HomeScreen
- Remove Quiz + Memory from the pack grid
- Add a `_GamesSection` widget above the pack grid with:
  - 🎧 Guess the word (quiz)
  - 🧠 Find the pair (memory)
  - 🗂️ Sort it! (new — drag/drop category sorting)
- Visual: horizontal scroll row or 2×N grid of game cards

### Step 2: Pack grid cleanup
- Without quiz/memory tiles, the pack grid is cleaner
- Favorites virtual pack stays
- Review virtual pack stays
- Add "Phrases" to the grid properly (it was added to uk_cards.json)

### Step 3: Sort game (new)
- Show 6-8 cards mixed from 2 categories (e.g. Animals + Food)
- Two drop zones at bottom (category icons)
- Drag card to correct category
- Counts as quest task: completes `reviewOldCard`

### Step 4: Age/level in profile (future)
- Add `level: 1-4` to ProfileModel
- Level 1 (1-2y): audio + emoji only, no text
- Level 2 (2-3y): audio + image + word
- Level 3 (3-4y): full card + quiz
- Level 4 (4-5y): sentences + harder quiz

**Success criteria:**
- [ ] Games section visible above pack grid
- [ ] Quiz + Memory removed from grid (no more ⬛ holes)
- [ ] Sort game playable with 2 categories
- [ ] Profile shows level selector (optional for Phase 9)
