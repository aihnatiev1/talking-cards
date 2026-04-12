# Talking Cards — Project Plan

## App

**Name:** Talking Cards (Картки-розмовлялки)  
**Platform:** iOS (primary), Android (secondary)  
**Audience:** Children ages 1–5, operated by parents  
**Purpose:** Ukrainian speech development through interactive sound cards  
**Model:** Freemium — 2 free packs, subscription (monthly/yearly) unlocks 6 more  
**Current version:** 1.0.4+13

## Tech Stack

- Flutter / Dart (SDK ^3.11.0)
- Riverpod 2 (state management)
- SharedPreferences (local persistence)
- flutter_soloud (audio playback)
- firebase_analytics + firebase_remote_config
- in_app_purchase (IAP)
- flutter_local_notifications
- home_widget (iOS/Android home widget)

## Current Feature Set (v1.0.4)

- 234 cards across 8 packs (2 free, 6 locked)
- Card swiper with audio playback
- Multiple-choice quiz (GuessScreen)
- Daily quest system (5 tasks, map UI, reward unlock)
- Streak milestones with badges
- Card of the Day (home widget + notification)
- Paywall (monthly + yearly subscription)
- Firebase analytics + remote config
- English card support (soundEn field)

---

## Milestone 2 — Growth & Engagement

**Goal:** Increase retention, add new game modes, expand monetization, lay groundwork for long-term engagement features.

**Decision log:**
- Multi-profile: local only (SharedPreferences per profile), no cloud sync
- Seasonal packs: free for all users (acquisition tool)
- Speech recognition: included (Phase 5)
- Order is fixed by priority: retention → monetization → learning science

**Phases:**

| # | Feature | Why now |
|---|---------|---------|
| 1 | Memory Match game | New game mode, highest retention impact, low complexity |
| 2 | Multi-profile support | #1 family pain point (siblings overwriting progress) |
| 3 | Lifetime IAP | Quick revenue hit, high conversion for kids apps |
| 4 | Spaced Repetition (SRS) | Learning efficacy, differentiator vs competitors |
| 5 | Speech Recognition | Premium feature, unique in Ukrainian kids space |
| 6 | Seasonal Packs | Acquisition tool, drives downloads around holidays |
| 7 | Parent Dashboard | Monetization support, justifies subscription to parents |
| 8 | English Market | Per-profile language (UA/EN), en_cards.json from existing data, App Store EN locale |
