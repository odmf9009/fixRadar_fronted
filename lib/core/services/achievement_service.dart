// Migrated: stubbed — no backend endpoint yet
import 'dart:async';
import '../models/achievement_model.dart';
import '../models/user_model.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  /// Returns a stream of achievements — stubbed (returns base definitions with no progress)
  Stream<List<AchievementModel>> getUserAchievements(String userId) {
    final controller = StreamController<List<AchievementModel>>();
    controller.add(List<AchievementModel>.from(baseAchievements));
    return controller.stream;
  }

  /// Check and update achievements — stubbed (no-op)
  Future<void> checkAchievements(UserModel user) async {
    // No backend endpoint yet — no-op
  }
}
