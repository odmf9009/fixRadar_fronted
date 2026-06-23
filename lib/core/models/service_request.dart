enum ServiceRequestStatus {
  open,
  assigned,
  inProgress,
  finishedByTechnician,
  completed,
  cancelled,
}

enum UrgencyLevel {
  low,
  medium,
  high,
}

class ServiceRequest {
  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> imageUrls;
  final List<String> thumbnailUrls;
  final double latitude;
  final double longitude;
  final String address;
  final ServiceRequestStatus status;
  final UrgencyLevel urgency;
  final String clientId;
  final String clientName;
  final String? clientPhotoUrl;
  final String? technicianId;
  final String? technicianName;
  final String? technicianPhotoUrl;
  final String? acceptedQuoteId;
  final DateTime? assignedAt;
  final double? budget;
  final double? minBudget;
  final double? maxBudget;
  final String? completionPhotoUrl;
  final List<String> completionPhotoUrls;
  final DateTime? completedAt;
  final double? reviewRating;
  final String? reviewComment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int responsesCount;
  final List<String> interestedTechnicians;
  final bool isChatEnabled;
  final DateTime? lastMessageAt;
  final String? lastMessageBy;
  final String? lastMessageText;
  final Map<String, dynamic> chatLastReadBy;
  final String? targetTechnicianId;

  const ServiceRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrls,
    this.thumbnailUrls = const [],
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    required this.urgency,
    required this.clientId,
    required this.clientName,
    this.clientPhotoUrl,
    this.technicianId,
    this.technicianName,
    this.technicianPhotoUrl,
    this.acceptedQuoteId,
    this.assignedAt,
    this.budget,
    this.minBudget,
    this.maxBudget,
    this.completionPhotoUrl,
    this.completionPhotoUrls = const [],
    this.completedAt,
    this.reviewRating,
    this.reviewComment,
    required this.createdAt,
    required this.updatedAt,
    this.responsesCount = 0,
    this.interestedTechnicians = const [],
    this.isChatEnabled = true,
    this.lastMessageAt,
    this.lastMessageBy,
    this.lastMessageText,
    this.chatLastReadBy = const {},
    this.targetTechnicianId,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    final coords = json['location']?['coordinates'];
    final double lat = coords != null
        ? (coords[1] as num).toDouble()
        : (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final double lng = coords != null
        ? (coords[0] as num).toDouble()
        : (json['longitude'] as num?)?.toDouble() ?? 0.0;

    return ServiceRequest(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Otros',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      thumbnailUrls: List<String>.from(json['thumbnailUrls'] ?? []),
      latitude: lat,
      longitude: lng,
      address: json['address'] ?? '',
      status: ServiceRequestStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'open'),
        orElse: () => ServiceRequestStatus.open,
      ),
      urgency: UrgencyLevel.values.firstWhere(
        (e) => e.name == (json['urgency'] ?? 'medium'),
        orElse: () => UrgencyLevel.medium,
      ),
      clientId: json['clientId'] ?? '',
      clientName: json['clientName'] ?? 'Cliente',
      clientPhotoUrl: json['clientPhotoUrl'],
      technicianId: json['technicianId'],
      technicianName: json['technicianName'],
      technicianPhotoUrl: json['technicianPhotoUrl'],
      acceptedQuoteId: json['acceptedQuoteId'],
      assignedAt: json['assignedAt'] != null ? DateTime.tryParse(json['assignedAt']) : null,
      budget: (json['budget'] as num?)?.toDouble(),
      minBudget: (json['minBudget'] as num?)?.toDouble(),
      maxBudget: (json['maxBudget'] as num?)?.toDouble(),
      completionPhotoUrl: json['completionPhotoUrl'],
      completionPhotoUrls: List<String>.from(json['completionPhotoUrls'] ?? []),
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      reviewRating: (json['reviewRating'] as num?)?.toDouble(),
      reviewComment: json['reviewComment'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      responsesCount: json['responsesCount'] ?? 0,
      interestedTechnicians: List<String>.from(json['interestedTechnicians'] ?? []),
      isChatEnabled: json['isChatEnabled'] ?? true,
      lastMessageAt: json['lastMessageAt'] != null ? DateTime.tryParse(json['lastMessageAt']) : null,
      lastMessageBy: json['lastMessageBy'],
      lastMessageText: json['lastMessageText'],
      chatLastReadBy: Map<String, dynamic>.from(json['chatLastReadBy'] ?? {}),
      targetTechnicianId: json['targetTechnicianId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'imageUrls': imageUrls,
    'thumbnailUrls': thumbnailUrls,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'status': status.name,
    'urgency': urgency.name,
    'clientId': clientId,
    'clientName': clientName,
    'minBudget': minBudget,
    'maxBudget': maxBudget,
    'targetTechnicianId': targetTechnicianId,
  };

  ServiceRequest copyWith({
    String? id,
    ServiceRequestStatus? status,
    String? technicianId,
    String? technicianName,
    String? technicianPhotoUrl,
    String? acceptedQuoteId,
    DateTime? assignedAt,
    String? completionPhotoUrl,
    List<String>? completionPhotoUrls,
    DateTime? completedAt,
    double? reviewRating,
    String? reviewComment,
    DateTime? updatedAt,
    int? responsesCount,
    List<String>? interestedTechnicians,
    DateTime? lastMessageAt,
    String? lastMessageBy,
    String? lastMessageText,
    Map<String, dynamic>? chatLastReadBy,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      title: title,
      description: description,
      category: category,
      imageUrls: imageUrls,
      thumbnailUrls: thumbnailUrls,
      latitude: latitude,
      longitude: longitude,
      address: address,
      status: status ?? this.status,
      urgency: urgency,
      clientId: clientId,
      clientName: clientName,
      clientPhotoUrl: clientPhotoUrl,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      technicianPhotoUrl: technicianPhotoUrl ?? this.technicianPhotoUrl,
      acceptedQuoteId: acceptedQuoteId ?? this.acceptedQuoteId,
      assignedAt: assignedAt ?? this.assignedAt,
      budget: budget,
      minBudget: minBudget,
      maxBudget: maxBudget,
      completionPhotoUrl: completionPhotoUrl ?? this.completionPhotoUrl,
      completionPhotoUrls: completionPhotoUrls ?? this.completionPhotoUrls,
      completedAt: completedAt ?? this.completedAt,
      reviewRating: reviewRating ?? this.reviewRating,
      reviewComment: reviewComment ?? this.reviewComment,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      responsesCount: responsesCount ?? this.responsesCount,
      interestedTechnicians: interestedTechnicians ?? this.interestedTechnicians,
      isChatEnabled: isChatEnabled,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageBy: lastMessageBy ?? this.lastMessageBy,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      chatLastReadBy: chatLastReadBy ?? this.chatLastReadBy,
      targetTechnicianId: targetTechnicianId,
    );
  }
}
