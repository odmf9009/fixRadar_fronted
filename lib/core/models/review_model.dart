class ReviewModel {
  final String id;
  final String requestId;
  final String technicianId;
  final String clientId;
  final String clientName;
  final String? clientPhotoUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.requestId,
    required this.technicianId,
    required this.clientId,
    required this.clientName,
    this.clientPhotoUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['_id'] ?? json['id'] ?? '',
      requestId: json['requestId'] ?? '',
      technicianId: json['technicianId'] ?? '',
      clientId: json['clientId'] ?? '',
      clientName: json['clientName'] ?? 'Cliente',
      clientPhotoUrl: json['clientPhotoUrl'],
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
