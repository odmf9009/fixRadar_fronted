enum AlertType { nearby, directQuote, quoteReceived, message, system }

class AlertModel {
  final String id;
  final String requestId;
  final String? quoteId;
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
    this.quoteId,
    required this.requestTitle,
    required this.requestImageUrl,
    required this.address,
    required this.distance,
    required this.createdAt,
    this.type = AlertType.nearby,
    this.isRead = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final rawQuoteId = json['quoteId'];
    return AlertModel(
      id: json['_id'] ?? json['id'] ?? '',
      requestId: json['requestId'] ?? '',
      quoteId: (rawQuoteId == null || rawQuoteId == '') ? null : rawQuoteId.toString(),
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
