import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/daily_quest_provider.dart';
import '../providers/packs_provider.dart';
import '../providers/streak_provider.dart';

class EngageService {
  EngageService._();
  static final instance = EngageService._();

  static const _channel = MethodChannel('com.talkingcards.app/engage');
  static const _keyLastPackId = 'engage_last_pack_id';
  static const _keyLastPackTitle = 'engage_last_pack_title';

  /// Returns the deep link URI if the app was opened from one, then clears it.
  /// Returns null on non-Android platforms.
  Future<String?> getInitialLink() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } catch (_) {
      return null;
    }
  }

  /// Save the last opened pack so it can be shown in Engage continuation cluster.
  Future<void> saveLastPack(String packId, String packTitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastPackId, packId);
    await prefs.setString(_keyLastPackTitle, packTitle);
  }

  /// Publish current app state to Google Play Engage SDK (You tab).
  /// Only runs on Android; silently no-ops elsewhere.
  Future<void> publish(WidgetRef ref) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPackId = prefs.getString(_keyLastPackId);
    final lastPackTitle = prefs.getString(_keyLastPackTitle);

    final streak = ref.read(streakProvider).currentStreak;
    final quest = ref.read(dailyQuestProvider);

    final packsAsync = ref.read(packsProvider);
    final allPacks = packsAsync.valueOrNull ?? [];

    // Recommend unlocked packs the user hasn't recently visited
    final recommended = allPacks
        .where((p) => !p.isLocked && p.id != lastPackId)
        .take(3)
        .map((p) => {'id': p.id, 'title': p.title})
        .toList();

    try {
      await _channel.invokeMethod('publishContent', {
        'lastPackId': lastPackId,
        'lastPackTitle': lastPackTitle,
        'recommendedPacks': recommended,
        'questDone': quest.doneCount,
        'questTotal': quest.totalCount,
        'streak': streak,
      });
    } catch (_) {
      // Engage SDK not available on this device — silently ignore
    }
  }

  /// Called at app startup: publishes from stored prefs without needing a ref.
  Future<void> publishFromPrefs() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPackId = prefs.getString(_keyLastPackId);
    final lastPackTitle = prefs.getString(_keyLastPackTitle);

    try {
      await _channel.invokeMethod('publishContent', {
        'lastPackId': lastPackId,
        'lastPackTitle': lastPackTitle,
        'recommendedPacks': <Map<String, String>>[],
        'questDone': 0,
        'questTotal': 5,
        'streak': 0,
      });
    } catch (_) {
      // Engage SDK not available — silently ignore
    }
  }
}
