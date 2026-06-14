import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_request.dart';
import 'firestore_service.dart';
import 'upload_service.dart';

class SyncService {
  final FirestoreService _firestoreService = FirestoreService();
  final UploadService _uploadService = UploadService();
  static const String _offlineQueueKey = 'offline_requests_queue';

  Future<void> queueRequestOffline(ServiceRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
    queue.add(jsonEncode(request.toJson()));
    await prefs.setStringList(_offlineQueueKey, queue);
  }

  Future<void> syncPendingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
    if (queue.isEmpty) return;

    print('SyncService: Iniciando sincronización de ${queue.length} pedidos...');

    List<String> remainingQueue = List.from(queue);
    
    for (String item in queue) {
      try {
        final Map<String, dynamic> data = jsonDecode(item);
        
        // 1. Upload local images
        List<String> localPaths = List<String>.from(data['imageUrls'] ?? []);
        List<String> remoteUrls = [];
        
        for (String path in localPaths) {
          if (path.startsWith('http')) {
            remoteUrls.add(path);
          } else {
            final File file = File(path);
            if (await file.exists()) {
              final String url = await _uploadService.uploadObjectImage(file);
              remoteUrls.add(url);
            }
          }
        }
        
        // 2. Create the real request
        data['imageUrls'] = remoteUrls;
        final ServiceRequest request = ServiceRequest.fromJson(data);
        
        await _firestoreService.createServiceRequest(request);
        
        remainingQueue.remove(item);
        print('SyncService: Pedido sincronizado OK');
      } catch (e) {
        print('SyncService: Error al sincronizar: $e');
      }
    }

    await prefs.setStringList(_offlineQueueKey, remainingQueue);
  }

  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_offlineQueueKey) ?? []).length;
  }
}
