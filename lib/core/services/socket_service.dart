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
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (isConnected) return;

    String? token;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      token = await firebaseUser.getIdToken();
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('backend_jwt');
    }

    if (token == null) return;

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

    _socket!.onConnect((_) => print('[Socket] Connected'));
    _socket!.onDisconnect((_) => print('[Socket] Disconnected'));
    _socket!.onConnectError((e) => print('[Socket] Error: $e'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void on(String event, SocketEventHandler handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
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
}
