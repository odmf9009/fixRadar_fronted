class FilterModel {
  final double distance;
  final double alertDistance;
  final String category;
  final String status;
  final String timeRange;
  final String searchQuery;

  FilterModel({
    this.distance = 10.0,
    this.alertDistance = 5.0,
    this.category = 'Todos',
    this.status = 'available',
    this.timeRange = 'all',
    this.searchQuery = '',
  });

  FilterModel copyWith({
    double? distance,
    double? alertDistance,
    String? category,
    String? status,
    String? timeRange,
    String? searchQuery,
  }) {
    return FilterModel(
      distance: distance ?? this.distance,
      alertDistance: alertDistance ?? this.alertDistance,
      category: category ?? this.category,
      status: status ?? this.status,
      timeRange: timeRange ?? this.timeRange,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
