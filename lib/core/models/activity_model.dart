// Migrated: no Firestore dependency
import 'package:flutter/material.dart';

enum ActivityType {
  publish,
  serviceCompleted,
  confirm,
  onMyWayToService,
  photoUpdate,
  achievement,
  levelUp,
  rankingEntry,
  communityAppreciation,
  serviceCompletedByOther,
  pointsRedeemed
}

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final int points;
  final ActivityType type;
  final DateTime createdAt;
  final String? requestId;
  final Map<String, dynamic> metadata;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    this.points = 0,
    required this.type,
    required this.createdAt,
    this.requestId,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'points': points,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'requestId': requestId,
      'metadata': metadata,
    };
  }

  factory ActivityModel.fromMap(String id, Map<String, dynamic> map) {
    return ActivityModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      points: map['points'] ?? 0,
      type: ActivityType.values.byName(map['type'] ?? 'publish'),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      requestId: map['requestId'] ?? map['objectId'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  IconData get icon {
    switch (type) {
      case ActivityType.publish: return Icons.add_task;
      case ActivityType.serviceCompleted: return Icons.check_circle;
      case ActivityType.confirm: return Icons.verified;
      case ActivityType.onMyWayToService: return Icons.directions_car;
      case ActivityType.photoUpdate: return Icons.refresh;
      case ActivityType.achievement: return Icons.emoji_events;
      case ActivityType.levelUp: return Icons.trending_up;
      case ActivityType.rankingEntry: return Icons.leaderboard;
      case ActivityType.communityAppreciation: return Icons.favorite;
      case ActivityType.serviceCompletedByOther: return Icons.volunteer_activism;
      case ActivityType.pointsRedeemed: return Icons.card_giftcard;
    }
  }

  Color get color {
    switch (type) {
      case ActivityType.publish: return Colors.orange;
      case ActivityType.serviceCompleted: return Colors.green;
      case ActivityType.confirm: return Colors.blue;
      case ActivityType.onMyWayToService: return Colors.indigo;
      case ActivityType.photoUpdate: return Colors.cyan;
      case ActivityType.achievement: return Colors.amber;
      case ActivityType.levelUp: return Colors.purple;
      case ActivityType.rankingEntry: return Colors.deepPurple;
      case ActivityType.communityAppreciation: return Colors.red;
      case ActivityType.serviceCompletedByOther: return Colors.teal;
      case ActivityType.pointsRedeemed: return Colors.pink;
    }
  }
}
