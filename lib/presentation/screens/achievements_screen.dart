import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/user_model.dart';
import '../../core/models/achievement_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/language_service.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final FirestoreService firestoreService = FirestoreService();
    final AchievementService achievementService = AchievementService();

    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              tr('logros'),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: StreamBuilder<UserModel?>(
            stream: firestoreService.getUserStream(currentUserId),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = userSnapshot.data;
              if (user == null) {
                return const Center(child: Text('Error al cargar perfil'));
              }

              return StreamBuilder<List<AchievementModel>>(
                stream: achievementService.getUserAchievements(currentUserId),
                builder: (context, achSnapshot) {
                  final userAchievements = achSnapshot.data ?? baseAchievements;

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: userAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = userAchievements[index];
                      return _buildAchievementCard(achievement);
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAchievementCard(AchievementModel achievement) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: achievement.isUnlocked ? const Color(0xFFFF8A00).withOpacity(0.4) : Colors.grey[100]!,
          width: achievement.isUnlocked ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: achievement.isUnlocked ? Colors.black : Colors.grey[100],
            child: Icon(
              achievement.icon,
              color: achievement.isUnlocked ? Colors.white : Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(achievement.titleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: achievement.isUnlocked ? Colors.black : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              tr(achievement.descriptionKey),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: achievement.isUnlocked ? Colors.black54 : Colors.grey[400],
              ),
            ),
          ),
          if (!achievement.isUnlocked) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: achievement.progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
