enum QuoteStatus {
  pending,
  accepted,
  rejected,
  counter_offer_sent,
  final_rejected,
  cancelled,
  completed,
}

class Quote {
  final String id;
  final String requestId;
  final String clientId;
  final String technicianId;
  final String technicianName;
  final String? technicianPhotoUrl;
  final double technicianRating;
  final double? price;
  final double minPrice;
  final double maxPrice;
  final String message;
  final String? estimatedTime;
  final DateTime createdAt;
  final QuoteStatus status;
  final DateTime? statusUpdatedAt;

  bool get isAccepted => status == QuoteStatus.accepted;
  bool get isRejected => status == QuoteStatus.rejected || status == QuoteStatus.final_rejected;

  const Quote({
    required this.id,
    required this.requestId,
    required this.clientId,
    required this.technicianId,
    required this.technicianName,
    this.technicianPhotoUrl,
    required this.technicianRating,
    this.price,
    required this.minPrice,
    required this.maxPrice,
    required this.message,
    this.estimatedTime,
    required this.createdAt,
    this.status = QuoteStatus.pending,
    this.statusUpdatedAt,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    double min = (json['minPrice'] as num?)?.toDouble() ?? 0.0;
    double max = (json['maxPrice'] as num?)?.toDouble() ?? 0.0;
    double p = (json['price'] as num?)?.toDouble() ?? 0.0;
    if (min == 0.0 && max == 0.0 && p > 0.0) {
      min = p;
      max = p;
    }

    QuoteStatus mappedStatus = QuoteStatus.pending;
    if (json['status'] != null) {
      try {
        mappedStatus = QuoteStatus.values.byName(json['status']);
      } catch (_) {}
    }

    return Quote(
      id: json['_id'] ?? json['id'] ?? '',
      requestId: json['requestId'] ?? '',
      clientId: json['clientId'] ?? '',
      technicianId: json['technicianId'] ?? '',
      technicianName: json['technicianName'] ?? 'Técnico',
      technicianPhotoUrl: json['technicianPhotoUrl'],
      technicianRating: (json['technicianRating'] as num?)?.toDouble() ?? 5.0,
      price: p,
      minPrice: min,
      maxPrice: max,
      message: json['message'] ?? '',
      estimatedTime: json['estimatedTime'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      status: mappedStatus,
      statusUpdatedAt: json['statusUpdatedAt'] != null
          ? DateTime.tryParse(json['statusUpdatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'message': message,
    'estimatedTime': estimatedTime,
  };
}
