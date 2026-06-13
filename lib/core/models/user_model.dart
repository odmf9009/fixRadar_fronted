class UserModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String profileImageUrl;
  final int points;
  final int totalXp;
  final int level;
  final int postsCount;
  final int foundCount;
  final int confirmationsCount;
  final int chatMessagesCount;
  final double totalImpactValue;
  final List<String> favorites;
  final List<String> redeemedRewards;
  final String? userType;
  final bool onboardingCompleted;
  final String role;
  final List<String> specialties;
  final double rating;
  final int reviewsCount;
  final int activeStreak;
  final double totalDistance;
  final int usersHelped;
  final String referralCode;
  final String? referredBy;
  final int referralCount;
  final int successfulReferrals;
  final int pendingReferrals;
  final int referralXpEarned;
  final bool isOnline;
  final bool notificationsEnabled;
  final String presenceStatus;
  final DateTime? lastSeen;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationUpdate;
  final String? companyName;
  final int yearsOfExperience;
  final int completedJobsCount;
  final String? avgResponseTime;
  final double satisfactionPercentage;
  final String bio;
  final String city;
  final double serviceRadius;
  final bool idVerified;
  final bool phoneVerified;
  final bool emailVerified;
  final bool licenseVerified;
  final bool insuranceVerified;
  final List<String> badges;
  final bool freeQuote;
  final bool emergencyService;
  final String? workHours;
  final bool weekendAvailability;
  final String? phoneNumber;

  UserModel({
    required this.id,
    required this.name,
    this.username = '',
    required this.email,
    this.profileImageUrl = '',
    this.userType,
    this.onboardingCompleted = false,
    this.role = 'client',
    this.specialties = const [],
    this.rating = 5.0,
    this.reviewsCount = 0,
    this.points = 0,
    this.totalXp = 0,
    this.level = 1,
    this.postsCount = 0,
    this.foundCount = 0,
    this.confirmationsCount = 0,
    this.chatMessagesCount = 0,
    this.totalImpactValue = 0.0,
    this.favorites = const [],
    this.redeemedRewards = const [],
    this.activeStreak = 0,
    this.totalDistance = 0.0,
    this.usersHelped = 0,
    this.referralCode = '',
    this.referredBy,
    this.referralCount = 0,
    this.successfulReferrals = 0,
    this.pendingReferrals = 0,
    this.referralXpEarned = 0,
    this.isOnline = false,
    this.notificationsEnabled = true,
    this.presenceStatus = 'offline',
    this.lastSeen,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.companyName,
    this.yearsOfExperience = 0,
    this.completedJobsCount = 0,
    this.avgResponseTime = 'N/A',
    this.satisfactionPercentage = 100.0,
    this.bio = '',
    this.city = '',
    this.serviceRadius = 20.0,
    this.idVerified = false,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.licenseVerified = false,
    this.insuranceVerified = false,
    this.badges = const [],
    this.freeQuote = true,
    this.emergencyService = false,
    this.workHours = '9:00 AM - 6:00 PM',
    this.weekendAvailability = false,
    this.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'] ?? '';
    return UserModel(
      id: id,
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? '',
      userType: json['userType'],
      onboardingCompleted: json['onboardingCompleted'] ?? false,
      role: json['role'] ?? json['userType'] ?? 'client',
      specialties: List<String>.from(json['specialties'] ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewsCount: json['reviewsCount'] ?? 0,
      points: json['points'] ?? 0,
      totalXp: json['totalXp'] ?? json['points'] ?? 0,
      level: json['level'] ?? 1,
      postsCount: json['postsCount'] ?? 0,
      foundCount: json['foundCount'] ?? 0,
      confirmationsCount: json['confirmationsCount'] ?? 0,
      chatMessagesCount: json['chatMessagesCount'] ?? 0,
      totalImpactValue: (json['totalImpactValue'] as num?)?.toDouble() ?? 0.0,
      favorites: List<String>.from(json['favorites'] ?? []),
      redeemedRewards: List<String>.from(json['redeemedRewards'] ?? []),
      activeStreak: json['activeStreak'] ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
      usersHelped: json['usersHelped'] ?? 0,
      referralCode: json['referralCode'] ?? '',
      referredBy: json['referredBy'],
      referralCount: json['referralCount'] ?? 0,
      successfulReferrals: json['successfulReferrals'] ?? 0,
      pendingReferrals: json['pendingReferrals'] ?? 0,
      referralXpEarned: json['referralXpEarned'] ?? 0,
      isOnline: json['isOnline'] ?? false,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      presenceStatus: json['presenceStatus'] ?? 'offline',
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen']) : null,
      latitude: json['location']?['coordinates'] != null
          ? (json['location']['coordinates'][1] as num?)?.toDouble()
          : (json['latitude'] as num?)?.toDouble(),
      longitude: json['location']?['coordinates'] != null
          ? (json['location']['coordinates'][0] as num?)?.toDouble()
          : (json['longitude'] as num?)?.toDouble(),
      lastLocationUpdate: json['lastLocationUpdate'] != null
          ? DateTime.tryParse(json['lastLocationUpdate'])
          : null,
      companyName: json['companyName'],
      yearsOfExperience: json['yearsOfExperience'] ?? 0,
      completedJobsCount: json['completedJobsCount'] ?? 0,
      avgResponseTime: json['avgResponseTime'] ?? 'N/A',
      satisfactionPercentage: (json['satisfactionPercentage'] as num?)?.toDouble() ?? 100.0,
      bio: json['bio'] ?? '',
      city: json['city'] ?? '',
      serviceRadius: (json['serviceRadius'] as num?)?.toDouble() ?? 20.0,
      idVerified: json['idVerified'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      emailVerified: json['emailVerified'] ?? false,
      licenseVerified: json['licenseVerified'] ?? false,
      insuranceVerified: json['insuranceVerified'] ?? false,
      badges: List<String>.from(json['badges'] ?? []),
      freeQuote: json['freeQuote'] ?? true,
      emergencyService: json['emergencyService'] ?? false,
      workHours: json['workHours'] ?? '9:00 AM - 6:00 PM',
      weekendAvailability: json['weekendAvailability'] ?? false,
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'email': email,
    'profileImageUrl': profileImageUrl,
    'userType': userType,
    'onboardingCompleted': onboardingCompleted,
    'role': role,
    'specialties': specialties,
    'rating': rating,
    'reviewsCount': reviewsCount,
    'points': points,
    'totalXp': totalXp,
    'level': level,
    'postsCount': postsCount,
    'isOnline': isOnline,
    'notificationsEnabled': notificationsEnabled,
    'presenceStatus': presenceStatus,
    'companyName': companyName,
    'yearsOfExperience': yearsOfExperience,
    'bio': bio,
    'city': city,
    'serviceRadius': serviceRadius,
    'specialties': specialties,
    'freeQuote': freeQuote,
    'emergencyService': emergencyService,
    'workHours': workHours,
    'weekendAvailability': weekendAvailability,
    'phoneNumber': phoneNumber,
  };

  String get displayName => username.isNotEmpty ? username : name;

  static int calculateLevel(int xp) {
    if (xp >= 10000) return 5;
    if (xp >= 5000) return 4;
    if (xp >= 2500) return 3;
    if (xp >= 1000) return 2;
    return 1;
  }

  String get levelTitle {
    final l = calculateLevel(totalXp);
    if (l <= 1) return 'Fixer Novato';
    if (l <= 2) return 'Técnico Jr.';
    if (l <= 3) return 'Especialista';
    if (l <= 4) return 'Maestro de Obras';
    return 'Ingeniero de la Casa';
  }

  double get levelProgress {
    if (totalXp >= 10000) return 1.0;
    if (totalXp >= 5000) return (totalXp - 5000) / 5000;
    if (totalXp >= 2500) return (totalXp - 2500) / 2500;
    if (totalXp >= 1000) return (totalXp - 1000) / 1500;
    return totalXp / 1000;
  }
}
