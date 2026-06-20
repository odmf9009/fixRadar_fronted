import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

typedef SocketEventHandler = void Function(dynamic data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _connectedToken;
  bool get isConnected => _socket?.connected ?? false;

  // Registry so handlers survive socket reconnects
  final Map<String, List<SocketEventHandler>> _registry = {};

  Future<void> connect() async {
    String? token;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      token = await firebaseUser.getIdToken();
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('backend_jwt');
    }

    if (token == null) return;

    // Already connected with the same token — nothing to do.
    if (isConnected && _connectedToken == token) return;

    // Different token (e.g. re-login after session expiry) — reconnect.
    if (_socket != null) {
      _socket?.disconnect();
      _socket = null;
    }

    _connectedToken = token;
    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setAuth({'token': token})
          .build(),
    );

    // Re-register all persisted handlers on the new socket instance
    _registry.forEach((event, handlers) {
      for (final h in handlers) {
        _socket!.on(event, h);
      }
    });

    _socket!.onConnect((_) => print('[Socket] Connected'));
    _socket!.onDisconnect((_) => print('[Socket] Disconnected'));
    _socket!.onConnectError((e) => print('[Socket] Error: $e'));
  }

  // Temporary disconnect (radar off). Registry is preserved so handlers
  // survive when connect() is called again.
  void disconnect() {
    _connectedToken = null;
    _socket?.disconnect();
    _socket = null;
  }

  // Full reset on logout. Clears registry so stale handlers don't carry over.
  void reset() {
    _connectedToken = null;
    _registry.clear();
    _socket?.disconnect();
    _socket = null;
  }

  void on(String event, SocketEventHandler handler) {
    _registry.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  void off(String event, [SocketEventHandler? handler]) {
    if (handler != null) {
      _registry[event]?.remove(handler);
      _socket?.off(event, handler);
    } else {
      _registry.remove(event);
      _socket?.off(event);
    }
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void joinRoom(String room) => emit('chat:join', room);
  void leaveRoom(String room) => emit('chat:leave', room);
  void joinRequest(String requestId) => emit('request:join', requestId);
  void leaveRequest(String requestId) => emit('request:leave', requestId);

  void sendChatMessage({
    required String requestId,
    required String text,
    required String senderName,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String type = 'text',
  }) {
    emit('chat:message', {
      'requestId': requestId,
      'text': text,
      'senderName': senderName,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
    });
  }

  void updateLocation(double latitude, double longitude) {
    emit('location:update', {'latitude': latitude, 'longitude': longitude});
  }

  void markChatRead(String requestId) {
    emit('chat:read', {'requestId': requestId});
  }

  void joinQuoteRoom(String quoteId) => emit('chat:join', 'quote:$quoteId');
  void leaveQuoteRoom(String quoteId) => emit('chat:leave', 'quote:$quoteId');

  void sendQuoteChatMessage({
    required String quoteId,
    required String text,
    required String senderName,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String type = 'text',
  }) {
    emit('chat:message', {
      'quoteId': quoteId,
      'text': text,
      'senderName': senderName,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
    });
  }
}
