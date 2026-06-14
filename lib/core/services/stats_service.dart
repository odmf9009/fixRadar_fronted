// Migrated: stubbed — no backend stats endpoint yet
import 'dart:async';
import '../models/community_stats_model.dart';

class StatsService {
  Stream<CommunityStats> getCommunityStatsStream() {
    final controller = StreamController<CommunityStats>();
    controller.add(CommunityStats(
      activeObjects: 0,
      totalCollected: 0,
      activeUsers30d: 0,
      objectsToday: 0,
      categoryDistribution: {},
      hottestAreas: [],
      environmentalImpact: EnvironmentalImpact.calculate(0),
    ));
    return controller.stream;
  }
}
