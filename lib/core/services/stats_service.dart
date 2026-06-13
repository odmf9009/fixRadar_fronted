// Migrated: uses API service instead of Firestore
import '../models/community_stats_model.dart';

class StatsService {
  final FirebaseFirestore _db = /* MongoDB via ApiService */;

  Stream<CommunityStats> getCommunityStatsStream() {
    return _db.collection('metadata').doc('global_stats').snapshots().map((doc) {
      final data = doc.data() ?? {};
      
      return CommunityStats(
        activeObjects: data['totalRequests'] ?? 0,
        totalCollected: data['totalJobsCompleted'] ?? 0,
        activeUsers30d: data['totalUsers'] ?? 0,
        objectsToday: 0, // Placeholder
        categoryDistribution: {},
        hottestAreas: [],
        environmentalImpact: EnvironmentalImpact.calculate(data['totalJobsCompleted'] ?? 0),
      );
    });
  }
}
