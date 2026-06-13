enum AlertType { nearby, directQuote, system }

class AlertModel {
  final String id;
  final String requestId;
  final String requestTitle;
  final String requestImageUrl;
  final String address;
  final double distance;
  final DateTime createdAt;
  final AlertType type;
  bool isRead;

  AlertModel({
    required this.id,
    required this.requestId,
    required this.requestTitle,
    required this.requestImageUrl,
    required this.address,
    required this.distance,
    required this.createdAt,
    this.type = AlertType.nearby,
    this.isRead = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['_id'] ?? json['id'] ?? '',
      requestId: json['requestId'] ?? '',
      requestTitle: json['requestTitle'] ?? 'Servicio detectado',
      requestImageUrl: json['requestImageUrl'] ?? '',
      address: json['address'] ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      type: AlertType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'nearby'),
        orElse: () => AlertType.nearby,
      ),
      isRead: json['isRead'] ?? false,
    );
  }
}
