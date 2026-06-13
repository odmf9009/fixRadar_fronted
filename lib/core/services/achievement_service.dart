// Migrated: uses API service instead of Firestore
import '../models/achievement_model.dart';
import '../models/user_model.dart';

class AchievementService {
  final FirebaseFirestore _db = /* MongoDB via ApiService */;
  
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  /// Fetches achievements for a specific user, merging base definitions with user progress
  Stream<List<AchievementModel>> getUserAchievements(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('achievements')
        .snapshots()
        .map((snapshot) {
          final List<AchievementModel> results = [];

          for (var baseAch in baseAchievements) {
            // Find progress in Firestore, considering possible legacy IDs
            final doc = snapshot.docs.cast<QueryDocumentSnapshot?>().firstWhere(
              (d) {
                if (d?.id == baseAch.id) return true;
                // Legacy Mapping
                if (baseAch.id == 'post_1' && d?.id == 'first_post') return true;
                if (baseAch.id == 'find_1' && d?.id == 'first_pickup') return true;
                if (baseAch.id == 'conf_5' && d?.id == 'confirm_5') return true;
                if (baseAch.id == 'msg_10' && d?.id == 'chat_social') return true;
                return false;
              }, 
              orElse: () => null
            );

            if (doc != null) {
              results.add(AchievementModel.fromMap(
                baseAch.id, // Always use the NEW ID for consistent UI
                doc.data() as Map<String, dynamic>,
                titleKey: baseAch.titleKey,
                descriptionKey: baseAch.descriptionKey,
                icon: baseAch.icon,
              ));
            } else {
              results.add(baseAch);
            }
          }
          return results;
        });
  }

  /// Check and update achievements based on user actions
  Future<void> checkAchievements(UserModel user) async {
    final batch = _db.batch();
    bool hasChanges = false;

    for (var achievement in baseAchievements) {
      double progress = 0.0;
      
      if (achievement.id.startsWith('post_')) {
        progress = (user.postsCount / achievement.targetValue).clamp(0.0, 1.0);
      } else if (achievement.id.startsWith('find_')) {
        progress = (user.foundCount / achievement.targetValue).clamp(0.0, 1.0);
      } else if (achievement.id.startsWith('conf_')) {
        progress = (user.confirmationsCount / achievement.targetValue).clamp(0.0, 1.0);
      } else if (achievement.id.startsWith('msg_')) {
        progress = (user.chatMessagesCount / achievement.targetValue).clamp(0.0, 1.0);
      } else if (achievement.id.startsWith('level_')) {
        progress = (user.level / achievement.targetValue).clamp(0.0, 1.0);
      } else if (achievement.id.startsWith('impact_')) {
        progress = (user.totalImpactValue / achievement.targetValue).clamp(0.0, 1.0);
      }

      if (progress > 0) {
        _updateProgress(batch, user.id, achievement.id, progress);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await batch.commit();
    }
  }

  void _updateProgress(WriteBatch batch, String userId, String achId, double progress) {
    final ref = _db.collection('users').doc(userId).collection('achievements').doc(achId);
    batch.set(ref, {
      'progress': progress,
      'isUnlocked': progress >= 1.0,
      if (progress >= 1.0) 'unlockedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
