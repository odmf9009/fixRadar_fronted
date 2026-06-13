class CommunityStats {
  final int activeObjects;
  final int totalCollected;
  final int activeUsers30d;
  final int objectsToday;
  final Map<String, double> categoryDistribution; // Category: Percentage
  final List<AreaActivity> hottestAreas;
  final EnvironmentalImpact environmentalImpact;

  CommunityStats({
    required this.activeObjects,
    required this.totalCollected,
    required this.activeUsers30d,
    required this.objectsToday,
    required this.categoryDistribution,
    required this.hottestAreas,
    required this.environmentalImpact,
  });
}

class AreaActivity {
  final String name;
  final int objectCount;
  final double latitude;
  final double longitude;

  AreaActivity({
    required this.name,
    required this.objectCount,
    required this.latitude,
    required this.longitude,
  });
}

class EnvironmentalImpact {
  final int objectsRecovered;
  final double estimatedWeightKg;
  final double co2SavedKg;

  EnvironmentalImpact({
    required this.objectsRecovered,
    required this.estimatedWeightKg,
    required this.co2SavedKg,
  });

  factory EnvironmentalImpact.calculate(int totalCollected) {
    // Averages: 15kg per object, 1.2kg CO2 saved per kg of recycled material
    const double avgWeight = 15.0; 
    const double co2PerKg = 1.2;
    
    return EnvironmentalImpact(
      objectsRecovered: totalCollected,
      estimatedWeightKg: totalCollected * avgWeight,
      co2SavedKg: (totalCollected * avgWeight) * co2PerKg,
    );
  }
}
