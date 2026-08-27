class ReviewModel {
  final String id;
  final String requestId;
  final String technicianId;
  final String clientId;
  final String clientName;
  final String? clientPhotoUrl;
  final double rating;
  final String comment;
  final String category;
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
    this.category = '',
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
      category: json['category'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class CategoryRating {
  final String category;
  final double rating;
  final int count;

  const CategoryRating({required this.category, required this.rating, required this.count});

  factory CategoryRating.fromJson(Map<String, dynamic> json) {
    return CategoryRating(
      category: json['category'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
