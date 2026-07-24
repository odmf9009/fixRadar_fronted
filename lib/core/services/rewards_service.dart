// Migrated: stubbed — no backend rewards endpoint yet
import 'dart:async';
import '../models/reward_model.dart';
import 'language_service.dart';

class RewardsService {
  /// Returns XP history — stubbed (empty stream)
  Stream<List<XPTransaction>> getXPHistory(String userId) {
    final controller = StreamController<List<XPTransaction>>();
    controller.add([]);
    return controller.stream;
  }

  /// Add XP transaction — stubbed (no-op)
  Future<void> addXPTransaction(String userId, String title, int amount) async {
    // No backend endpoint yet — no-op
  }

  List<RewardItem> getAvailableRewards() {
    return [
      RewardItem(
        id: 'premium_7d',
        title: tr('reward_premium_title'),
        description: tr('reward_premium_desc'),
        icon: '👑',
        xpRequired: 1000,
      ),
      RewardItem(
        id: 'adv_alerts',
        title: tr('reward_alerts_title'),
        description: tr('reward_alerts_desc'),
        icon: '🔔',
        xpRequired: 500,
      ),
      RewardItem(
        id: 'radius_ext',
        title: tr('reward_radius_title'),
        description: tr('reward_radius_desc'),
        icon: '📍',
        xpRequired: 750,
      ),
      RewardItem(
        id: 'hot_zones',
        title: tr('reward_hotzones_title'),
        description: tr('reward_hotzones_desc'),
        icon: '🔥',
        xpRequired: 1200,
      ),
      RewardItem(
        id: 'profile_badge',
        title: tr('reward_badge_title'),
        description: tr('reward_badge_desc'),
        icon: '🏅',
        xpRequired: 2000,
      ),
    ];
  }

  static String getLevelTitle(int level) {
    if (level <= 1) return tr('level_service_1');
    if (level <= 5) return tr('level_service_2');
    if (level <= 10) return tr('level_service_3');
    if (level <= 20) return tr('level_service_4');
    return tr('level_service_5');
  }

  static int getXPForNextLevel(int currentLevel) {
    return currentLevel * 500;
  }
}
