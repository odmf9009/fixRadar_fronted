import '../models/chat_message_model.dart';
import 'api_service.dart';
import 'socket_service.dart';

class ChatService {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  Future<List<ChatMessage>> getMessages(String requestId, {String? before, int limit = 50}) async {
    final response = await _api.get('/chat/$requestId/messages', params: {
      if (before != null) 'before': before,
      'limit': limit,
    });
    return (response.data as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  void joinChat(String requestId) {
    _socket.joinRoom(requestId);
  }

  void leaveChat(String requestId) {
    _socket.leaveRoom(requestId);
  }

  void sendMessage({
    required String requestId,
    required String text,
    required String senderName,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String type = 'text',
  }) {
    _socket.sendChatMessage(
      requestId: requestId,
      text: text,
      senderName: senderName,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      type: type,
    );
  }

  void listenToMessages(String requestId, void Function(ChatMessage) onMessage) {
    _socket.on('chat:message', (data) {
      if (data['requestId'] == requestId) {
        onMessage(ChatMessage.fromJson(data));
      }
    });
  }

  void stopListening() {
    _socket.off('chat:message');
  }

  void markRead(String requestId) {
    _socket.markChatRead(requestId);
  }
}
