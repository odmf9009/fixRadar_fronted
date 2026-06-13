import '../models/alert_model.dart';
import 'api_service.dart';
import 'socket_service.dart';

class AlertService {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  Future<List<AlertModel>> getMyAlerts() async {
    final response = await _api.get('/alerts');
    return (response.data as List).map((e) => AlertModel.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get('/alerts/unread-count');
    return response.data['count'] ?? 0;
  }

  Future<void> markRead(String alertId) async {
    await _api.put('/alerts/$alertId/read');
  }

  Future<void> markAllRead() async {
    await _api.put('/alerts/read-all');
  }

  void listenToNewAlerts(void Function(AlertModel) onAlert) {
    _socket.on('alert:new', (data) {
      onAlert(AlertModel.fromJson(data));
    });
  }

  void stopListening() {
    _socket.off('alert:new');
  }
}
