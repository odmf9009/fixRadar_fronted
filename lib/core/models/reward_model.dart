// Migrated: no Firestore dependency

class RewardItem {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int xpRequired;
  final bool isRedeemed;

  RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpRequired,
    this.isRedeemed = false,
  });
}

class XPTransaction {
  final String id;
  final String title;
  final int xpAmount;
  final DateTime date;

  XPTransaction({
    required this.id,
    required this.title,
    required this.xpAmount,
    required this.date,
  });

  factory XPTransaction.fromMap(String id, Map<String, dynamic> map) {
    return XPTransaction(
      id: id,
      title: map['title'] ?? '',
      xpAmount: map['xpAmount'] ?? 0,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'xpAmount': xpAmount,
      'date': date.toIso8601String(),
    };
  }
}
