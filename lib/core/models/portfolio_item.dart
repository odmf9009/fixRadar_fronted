// Migrated: no Firestore dependency

class PortfolioItem {
  final String id;
  final String technicianId;
  final String title;
  final String description;
  final DateTime date;
  final String category;
  final List<String> imageUrls;
  final List<String> thumbnailUrls;
  final String? location;
  final DateTime? createdAt;

  PortfolioItem({
    required this.id,
    required this.technicianId,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    this.imageUrls = const [],
    this.thumbnailUrls = const [],
    this.location,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'technicianId': technicianId,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'category': category,
      'imageUrls': imageUrls,
      'thumbnailUrls': thumbnailUrls,
      'location': location,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : FieldValue.serverTimestamp(),
    };
  }

  factory PortfolioItem.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = DateTime.tryParse(map['date'] ?? '') ?? DateTime.now();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return PortfolioItem(
      id: id,
      technicianId: map['technicianId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: parsedDate,
      category: map['category'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      thumbnailUrls: List<String>.from(map['thumbnailUrls'] ?? []),
      location: map['location'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? ''),
    );
  }
}
