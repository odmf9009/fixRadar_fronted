enum MessageType { text, image, location }

class ChatMessage {
  final String id;
  final String requestId;
  final String? quoteId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final MessageType type;
  final DateTime createdAt;
  final List<String> readBy;

  const ChatMessage({
    required this.id,
    required this.requestId,
    this.quoteId,
    required this.senderId,
    required this.senderName,
    this.text = '',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.type = MessageType.text,
    required this.createdAt,
    this.readBy = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      requestId: json['requestId'] ?? '',
      quoteId: json['quoteId'],
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Usuario',
      text: json['text'] ?? '',
      imageUrl: json['imageUrl'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      readBy: List<String>.from(json['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'imageUrl': imageUrl,
    'latitude': latitude,
    'longitude': longitude,
    'type': type.name,
    'senderName': senderName,
  };
}
