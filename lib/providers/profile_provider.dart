import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_model.dart';
import '../services/profile_service.dart';
import 'bonus_cards_provider.dart';
import 'daily_quest_provider.dart';
import 'daily_stats_provider.dart';
import 'favorites_provider.dart';
import 'packs_provider.dart';
import 'review_provider.dart';
import 'srs_provider.dart';
import 'streak_provider.dart';
import 'weak_words_provider.dart';

// ─────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────

class ProfileState {
  final List<ProfileModel> profiles;
  final String activeId;

  const ProfileState({required this.profiles, required this.activeId});

  ProfileModel? get active =>
      profiles.where((p) => p.id == activeId).firstOrNull;

  ProfileState copyWith({List<ProfileModel>? profiles, String? activeId}) =>
      ProfileState(
        profiles: profiles ?? this.profiles,
        activeId: activeId ?? this.activeId,
      );
}

// ─────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref _ref;

  ProfileNotifier(this._ref, List<ProfileModel> initialProfiles)
      : super(ProfileState(
          profiles: initialProfiles,
          activeId: ProfileService.activeId,
        ));

  /// Switch active profile and reload all data providers.
  Future<void> switchProfile(String id) async {
    if (id == state.activeId) return;
    await ProfileService.setActive(id);
    state = state.copyWith(activeId: id);
    _invalidateDataProviders();
  }

  /// Add a new profile (max 3).
  Future<void> addProfile(String name, String avatarEmoji,
      {String language = 'uk', int level = 2}) async {
    final updated =
        await ProfileService.addProfile(name, avatarEmoji, language: language, level: level);
    state = state.copyWith(profiles: updated);
  }

  /// Rename / change avatar of a profile.
  Future<void> updateProfile(
      String id, String name, String avatarEmoji) async {
    final updated = await ProfileService.updateProfile(id, name, avatarEmoji);
    state = state.copyWith(profiles: updated);
  }

  /// Change the learning language for a profile.
  /// [packsProvider] auto-reloads via [languageProvider] dependency.
  Future<void> setLanguage(String profileId, String language) async {
    final updated = await ProfileService.setLanguage(profileId, language);
    state = state.copyWith(profiles: updated);
  }

  /// Change the age/difficulty level (1-4) for a profile.
  Future<void> setLevel(String profileId, int level) async {
    final updated = await ProfileService.setLevel(profileId, level);
    state = state.copyWith(profiles: updated);
  }

  /// Delete a profile. Switches to first remaining if active was deleted.
  Future<void> deleteProfile(String id) async {
    final updated = await ProfileService.deleteProfile(id);
    final newActiveId = ProfileService.activeId; // may have changed
    state = state.copyWith(profiles: updated, activeId: newActiveId);
    if (newActiveId != id) _invalidateDataProviders();
  }

  /// Force-reload all data providers with current profile prefix.
  void _invalidateDataProviders() {
    _ref.invalidate(completedPacksProvider);
    _ref.invalidate(packProgressProvider);
    _ref.invalidate(bonusCardsProvider);
    _ref.invalidate(reviewProvider);
    _ref.invalidate(dailyQuestProvider);
    _ref.invalidate(streakProvider);
    _ref.invalidate(favoritesProvider);
    _ref.invalidate(dailyStatsProvider);
    _ref.invalidate(srsProvider);
    _ref.invalidate(weakWordsProvider);
  }
}

// ─────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────

/// Initialized in main() via ProviderScope override after ProfileService.init().
/// Use [profileProvider] everywhere in the widget tree.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  // Fallback: if not overridden, use whatever ProfileService loaded at init.
  return ProfileNotifier(ref, [
    ProfileModel(
      id: ProfileService.activeId,
      name: 'Малюк',
      avatarEmoji: '👶',
      createdAt: DateTime.now(),
    )
  ]);
});
