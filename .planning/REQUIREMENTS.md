# Requirements — Milestone 2: Growth & Engagement

---

## Phase 1 — Memory Match Game

### Goal
Add a second mini-game to complement the existing quiz. Children flip cards to find matching pairs, reinforcing word recognition through repetition.

### Functional Requirements
- **Entry point:** New "Memory" button on HomeScreen (alongside existing quiz), accessible from any pack's CardsScreen
- **Game setup:** Player selects a pack; game picks N random cards from that pack (N = 6 pairs = 12 cards by default; hard mode = 8 pairs)
- **Gameplay:**
  - Cards displayed face-down in a grid (4×3 or 4×4)
  - Tap card → flip face-up, play audio (emoji + word shown)
  - Tap second card → if match: both stay face-up, celebration; if no match: both flip back after 1s
  - Game ends when all pairs matched
- **Scoring:** Time elapsed + number of attempts; show stars (1–3) based on attempts
- **Reward:** Completing a round counts as a daily quest task (new task type: `playMemoryMatch`)
- **Difficulty:** Use only cards the child has already seen (from packProgress) for accuracy; fallback to any cards if fewer than N seen

### Non-functional Requirements
- Flip animation: 3D card flip (Transform perspective)
- Audio: play card sound on flip (reuse existing SoLoud player)
- Haptics: light on flip, medium on match, heavy on game complete
- Grid must fit on iPhone SE screen without scrolling

### Out of Scope
- Multiplayer / competing with another player
- Leaderboards
- Cross-pack mixing (for Phase 1)

---

## Phase 2 — Multi-Profile Support

### Goal
Allow up to 3 child profiles per device, each with fully isolated progress, streaks, quest state, and favorites.

### Functional Requirements
- **Profile model:** `{ id: uuid, name: String, avatarEmoji: String, createdAt: DateTime }`
- **Max profiles:** 3
- **Profile switcher:** Available from HomeScreen (avatar chip in top bar) and Settings
- **Profile creation:** Name input + emoji avatar picker (grid of 20 kid-friendly emojis)
- **Profile deletion:** Swipe-to-delete in profile list, with confirmation dialog; cannot delete last profile
- **Data isolation:** All SharedPreferences keys namespaced with `profile_{id}_` prefix
- **Migration:** Existing data (no profile) treated as `profile_default` on first launch after update
- **Active profile:** Stored separately (not namespaced); survives app restart
- **Affected providers:** PackProgress, Favorites, DailyStats, Streak, BonusCards, DailyQuest, CompletedPacks, Quiz, Review
- **Not affected:** Purchase state (subscription applies to whole device), Remote Config, Theme

### Non-functional Requirements
- Profile switch must complete in <300ms (no loading screen)
- Profile names: 1–20 characters
- Avatar emoji: fixed set of 20 options (no custom emoji input)
- All profile data deleted on profile deletion (no recovery)

### Out of Scope
- Cloud sync / cross-device profiles
- Parental PIN to prevent accidental profile switch
- Per-profile subscription/IAP

---

## Phase 3 — Lifetime IAP

### Goal
Add a one-time purchase option ("Lifetime Premium") alongside the existing monthly/yearly subscriptions.

### Functional Requirements
- **New SKU:** `lifetime_premium` (non-consumable, one-time purchase)
- **Price:** Set in App Store Connect ($14.99 suggested)
- **Paywall UI:** Add "Lifetime" as third option on PaywallScreen, visually distinct (e.g. "Назавжди" badge, highlighted border)
- **Entitlement logic:** `lifetime_premium` purchase → `isPremium = true` permanently (same as active subscription)
- **Restore:** Existing `restorePurchases()` flow handles lifetime automatically (non-consumable restores on reinstall)
- **Priority:** If both lifetime and subscription active, lifetime takes precedence (no expiry check needed)
- **Receipt validation:** Same as current — rely on StoreKit / Google Play receipt; no server-side validation added
- **Analytics:** Track `purchase_lifetime_start`, `purchase_lifetime_success` events

### Non-functional Requirements
- PaywallScreen layout must not break on iPhone SE (smallest supported screen)
- No changes to subscription billing logic
- Lifetime option must be clearly labeled as one-time, not recurring

### Out of Scope
- Family Sharing support (Phase 3 scope only: single device)
- RevenueCat integration (staying with in_app_purchase)
- Price A/B testing

---

## Phase 4 — Spaced Repetition (SM-2)

### Goal
Replace the current naive "reviewed 3+ days ago" with a proper SM-2 spaced repetition algorithm so children see cards at scientifically optimal intervals.

### Functional Requirements
- **Algorithm:** SM-2 (standard: ease factor 2.5, interval progression 1→6→n*EF days)
- **Per-card state:** `{ cardId, easeFactor: double, interval: int (days), repetitions: int, nextReviewDate: DateTime, lastQuality: int }`
- **Quality input:** After each card in quiz or swiper, player implicitly rates it:
  - Answered correctly on first try in quiz → quality 5
  - Answered correctly after seeing → quality 4
  - Wrong answer → quality 2 (reset interval)
  - Never seen → not in SRS queue yet
- **SRS queue:** Cards due today or overdue, shown on HomeScreen as "Повторити сьогодні: N карток"
- **Review session:** New screen or mode in CardsScreen — shows only SRS-due cards, in SM-2 order
- **Daily quest integration:** New task: `reviewSRSCards` (review at least 5 SRS-due cards)
- **Persistence:** SRS state stored in SharedPreferences, namespaced per profile

### Non-functional Requirements
- SRS state must not affect existing quiz flow (opt-in mode)
- SRS queue calculation done at app startup (not real-time)
- Max SRS session: 20 cards (prevent fatigue)

### Out of Scope
- Custom ease factor input by parent
- Sync SRS state to cloud
- SRS analytics beyond existing card_view events

---

## Phase 5 — Speech Recognition

### Goal
Add a "Say it!" interaction mode where the child speaks the word aloud and the app validates pronunciation.

### Functional Requirements
- **Platform:** iOS only (Phase 5); Android in future milestone
- **Library:** `speech_to_text` Flutter package (wraps SFSpeechRecognizer)
- **Permission:** Request microphone + speech recognition permission on first use (not at startup)
- **Interaction:**
  - On CardScreen, new mic button appears when card is face-up
  - Tap mic → listening indicator (animated waveform)
  - Child says the word → app compares with card's `sound` field (case-insensitive, trimmed)
  - Correct: celebration animation + haptic
  - Incorrect: gentle retry prompt (max 3 attempts, then show correct word)
- **Language:** Ukrainian (`uk-UA`)
- **Timeout:** Auto-stop listening after 3 seconds of silence
- **Fallback:** If speech recognition unavailable (no permission, API error) → hide mic button silently
- **Daily quest integration:** New task: `speakWords` (say 3 words correctly)
- **Analytics:** Track `speech_attempt`, `speech_correct`, `speech_incorrect`

### Non-functional Requirements
- Mic button must not appear on locked cards
- Speech recognition runs on-device (no audio sent to server per Apple's default behavior)
- Works offline for previously cached language models (iOS downloads on first permission grant)

### Out of Scope
- Android support (Phase 5 only)
- Pronunciation scoring (phoneme-level accuracy)
- Recording playback
- Parent review of speech sessions

---

## Phase 6 — Seasonal Packs

### Goal
Add time-limited packs that appear automatically around Ukrainian holidays. Free for all users — acquisition tool for new downloads.

### Functional Requirements
- **Packs (4 total):**
  - 🎄 Новий рік / Різдво (Dec 1 – Jan 15): 15 cards (ялинка, подарунок, сніг, дід мороз, зірка, ...)
  - 🐣 Великдень / Весна (Apr 1 – May 15): 15 cards (яйце, кошик, квіти, сонце, пташка, ...)
  - ☀️ Літо (Jun 15 – Aug 31): 15 cards (море, пляж, морозиво, кавун, сонце, ...)
  - 🎃 Осінь / Геловін (Oct 1 – Nov 15): 15 cards (гарбуз, листя, яблуко, їжак, ...)
- **Visibility:** Pack appears in HomeScreen grid only during its active date window
- **Access:** Free for ALL users (no paywall)
- **UI:** Seasonal pack card has special shimmer/glow border to stand out
- **Notification:** Push notification sent on first day of each season ("🎄 З'явився новорічний пак!")
- **Content:** Cards follow existing CardModel format; audio files needed for all 60 cards
- **Date check:** At app startup + midnight reset

### Non-functional Requirements
- Date comparison uses device local time (Ukrainian timezone not enforced)
- Seasonal packs do not count toward "8 packs" in marketing copy
- Seasonal pack cards excluded from SRS (Phase 4) to avoid orphan states after pack disappears

### Out of Scope
- User-controlled "keep seasonal pack after season ends"
- Multiple seasonal events per season
- In-app seasonal animations (just the pack card shimmer)

---

## Phase 7 — Parent Dashboard

### Goal
Give parents a dedicated, PIN-protected area to view their child's learning progress across all profiles.

### Functional Requirements
- **Entry:** Long-press on settings gear icon for 2 seconds → PIN prompt (first time: set PIN)
- **PIN:** 4-digit numeric PIN; stored in SharedPreferences (not Keychain for now)
- **PIN reset:** "Забули PIN?" → shows onboarding date + device model as verification, then resets
- **Dashboard screens:**
  1. **Overview:** Select profile → summary card (days active, words seen, packs completed, current streak)
  2. **Weekly chart:** 7-day bar chart of cards viewed per day (reuse DailyStatsProvider data)
  3. **Pack progress:** List of all packs with progress bars (seen/total cards)
  4. **Weak words:** Top 10 cards with most wrong quiz answers (from QuizProvider mistake log)
  5. **SRS queue:** How many cards due for review today per pack (available after Phase 4)
- **Navigation:** Bottom tab bar within parent area (Overview / Weekly / Packs / Weak words)
- **Exit:** Back button or swipe down dismisses parent area

### Non-functional Requirements
- Parent area never auto-opens (always requires PIN after app restart)
- PIN input UI is adult-oriented (not kid-friendly large buttons)
- No analytics tracked for parent dashboard actions (privacy)
- SRS tab hidden if Phase 4 not yet shipped (graceful degradation)

### Out of Scope
- Email/push weekly report (future milestone)
- Export data to CSV
- Remote access / web dashboard
- Per-session time tracking

---

## Phase 8 — English Market

### Goal
Allow each profile to learn in English (or Ukrainian). English content uses existing card images with English labels from the `soundEn` field — no audio recording needed to ship.

### Functional Requirements
- **Language setting:** per profile, two options: `'uk'` (Ukrainian, default) and `'en'` (English)
- **Persistence:** key `'${ProfileService.prefix}lang'` in SharedPreferences
- **Content:** `assets/data/en_cards.json` — 209 cards / 7 packs (Animals, Home & Family, Feelings, Transport, Food & Fruits, Colors & Shapes, Body Parts)
- **Pack loading:** `packsProvider` watches `languageProvider` and loads the matching JSON file
- **Profile UI:**
  - Profile create/edit dialog: "Яку мову вчимо?" row with 🇺🇦 / 🇬🇧 toggle chips
  - Profile avatar chip in HomeScreen: show flag emoji (`🇺🇦` / `🇬🇧`) next to avatar when multiple languages in use
- **Language switch:** switching profile OR changing language in profile → `ref.invalidate(packsProvider)` → packs reload
- **Speech mic button:** hidden when `language == 'en'` (no EN audio available yet)

### Non-functional Requirements
- Default language for ALL existing profiles = 'uk' (no data migration needed)
- Language change takes effect immediately without app restart
- English cards use `sound` field (which contains EN word in en_cards.json) — no special rendering needed

### Out of Scope
- English audio recording (Phase 9+)
- More than 2 languages
- Mixed-language packs (showing both UA and EN in the same session)
