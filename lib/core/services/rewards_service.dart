// Migrated: uses API service instead of Firestore
import '../models/reward_model.dart';

class RewardsService {
  final FirebaseFirestore _db = /* MongoDB via ApiService */;

  Stream<List<XPTransaction>> getXPHistory(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('xp_history')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => XPTransaction.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addXPTransaction(String userId, String title, int amount) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('xp_history')
        .add({
      'title': title,
      'xpAmount': amount,
      'date': DateTime.now().toIso8601String(),
    });
  }

  List<RewardItem> getAvailableRewards() {
    return [
      RewardItem(
        id: 'premium_7d',
        title: '7 Días Acceso Premium',
        description: 'Desbloquea todas las funciones avanzadas por una semana.',
        icon: '👑',
        xpRequired: 1000,
      ),
      RewardItem(
        id: 'adv_alerts',
        title: 'Alertas Avanzadas',
        description: 'Recibe notificaciones prioritarias de objetos valiosos.',
        icon: '🔔',
        xpRequired: 500,
      ),
      RewardItem(
        id: 'radius_ext',
        title: 'Radio de Búsqueda Extendido',
        description: 'Aumenta tu radar hasta 20 millas adicionales.',
        icon: '📍',
        xpRequired: 750,
      ),
      RewardItem(
        id: 'hot_zones',
        title: 'Acceso a Zonas Calientes',
        description: 'Visualiza áreas de alta actividad en tiempo real.',
        icon: '🔥',
        xpRequired: 1200,
      ),
      RewardItem(
        id: 'profile_badge',
        title: 'Insignia de Perfil Exclusiva',
        description: 'Muestra tu estatus de Cazador Élite a la comunidad.',
        icon: '🏅',
        xpRequired: 2000,
      ),
    ];
  }

  static String getLevelTitle(int level) {
    if (level <= 1) return 'Buscador Novato';
    if (level <= 5) return 'Explorador';
    if (level <= 10) return 'Cazador de Curb';
    if (level <= 20) return 'Héroe de la Comunidad';
    return 'Reciclador Élite';
  }

  static int getXPForNextLevel(int currentLevel) {
    // Each level requires 500 more XP than the previous one
    return currentLevel * 500;
  }
}
