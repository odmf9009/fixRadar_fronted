// Migrated: stubbed — no backend rewards endpoint yet
import 'dart:async';
import '../models/reward_model.dart';

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
    return currentLevel * 500;
  }
}
