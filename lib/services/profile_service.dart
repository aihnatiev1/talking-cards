import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/profile_model.dart';

/// Manages the active profile ID and persists it across app launches.
///
/// Call [ProfileService.init()] in main() before runApp() so that all
/// providers use the correct prefix from the very first build.
class ProfileService {
  ProfileService._();

  static const _defaultId = 'default';
  static const _keyActiveId = 'active_profile_id';
  static const _keyProfiles = 'app_profiles';

  static String _activeId = _defaultId;

  /// SharedPreferences key prefix for the active profile.
  ///
  /// Returns empty string for the 'default' profile so that data written
  /// before multi-profile existed (v1.0.x) is automatically accessible
  /// without any migration.
  static String get prefix =>
      _activeId == _defaultId ? '' : '${_activeId}_';

  static String get activeId => _activeId;

  /// Load active profile ID from storage. Creates the default profile if
  /// this is the first launch.
  static Future<List<ProfileModel>> init() async {
    final prefs = await SharedPreferences.getInstance();
    _activeId = prefs.getString(_keyActiveId) ?? _defaultId;

    final raw = prefs.getStringList(_keyProfiles) ?? [];
    List<ProfileModel> profiles =
        raw.map(ProfileModel.fromJsonString).toList();

    if (profiles.isEmpty) {
      final defaultProfile = ProfileModel(
        id: _defaultId,
        name: 'Малюк',
        avatarEmoji: '👶',
        createdAt: DateTime.now(),
      );
      profiles = [defaultProfile];
      await _saveProfiles(prefs, profiles);
    }

    // Ensure active ID still refers to an existing profile
    if (!profiles.any((p) => p.id == _activeId)) {
      _activeId = profiles.first.id;
      await prefs.setString(_keyActiveId, _activeId);
    }

    return profiles;
  }

  /// Switch the active profile (updates static field + persists).
  static Future<void> setActive(String id) async {
    _activeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveId, id);
  }

  /// Add a new profile (max 3 total).
  static Future<List<ProfileModel>> addProfile(
      String name, String avatarEmoji, {String language = 'uk'}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadProfiles(prefs);
    if (existing.length >= 3) return existing;
    final newProfile = ProfileModel(
      id: const Uuid().v4(),
      name: name,
      avatarEmoji: avatarEmoji,
      createdAt: DateTime.now(),
      language: language,
    );
    final updated = [...existing, newProfile];
    await _saveProfiles(prefs, updated);
    return updated;
  }

  /// Update a profile's name / avatar.
  static Future<List<ProfileModel>> updateProfile(
      String id, String name, String avatarEmoji) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadProfiles(prefs);
    final updated = existing
        .map((p) => p.id == id ? p.copyWith(name: name, avatarEmoji: avatarEmoji) : p)
        .toList();
    await _saveProfiles(prefs, updated);
    return updated;
  }

  /// Change the learning language ('uk' or 'en') for a profile.
  static Future<List<ProfileModel>> setLanguage(
      String id, String language) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadProfiles(prefs);
    final updated = existing
        .map((p) => p.id == id ? p.copyWith(language: language) : p)
        .toList();
    await _saveProfiles(prefs, updated);
    return updated;
  }

  /// Delete a profile and all of its namespaced data.
  /// Cannot delete the last remaining profile.
  static Future<List<ProfileModel>> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadProfiles(prefs);
    if (existing.length <= 1) return existing; // refuse to delete last

    // Wipe all namespaced keys for this profile
    if (id != _defaultId) {
      final profilePrefix = '${id}_';
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(profilePrefix)) await prefs.remove(key);
      }
    }

    final updated = existing.where((p) => p.id != id).toList();
    await _saveProfiles(prefs, updated);

    // If we deleted the active profile, switch to the first remaining
    if (_activeId == id) {
      await setActive(updated.first.id);
    }

    return updated;
  }

  static Future<List<ProfileModel>> _loadProfiles(SharedPreferences prefs) {
    final raw = prefs.getStringList(_keyProfiles) ?? [];
    return Future.value(raw.map(ProfileModel.fromJsonString).toList());
  }

  static Future<void> _saveProfiles(
      SharedPreferences prefs, List<ProfileModel> profiles) async {
    await prefs.setStringList(
        _keyProfiles, profiles.map((p) => p.toJsonString()).toList());
  }
}
