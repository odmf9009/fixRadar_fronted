// Compatibility facade: same interface as the original FirestoreService
// but uses MongoDB REST API + Socket.io instead of Firestore.
import 'dart:async';
import '../models/service_request.dart';
import '../models/quote_model.dart';
import '../models/user_model.dart';
import '../models/chat_message_model.dart';
import '../models/alert_model.dart';
import '../models/review_model.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'upload_service.dart';

class FirestoreService {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  // ─── SERVICE REQUESTS ─────────────────────────────────────────────────────

  Future<String> createServiceRequest(ServiceRequest request) async {
    final response = await _api.post('/service-requests', data: {
      'title': request.title,
      'description': request.description,
      'category': request.category,
      'imageUrls': request.imageUrls,
      'thumbnailUrls': request.thumbnailUrls,
      'latitude': request.latitude,
      'longitude': request.longitude,
      'address': request.address,
      'urgency': request.urgency.name,
      'minBudget': request.minBudget,
      'maxBudget': request.maxBudget,
      'targetTechnicianId': request.targetTechnicianId,
    });
    return response.data['_id'] ?? response.data['id'];
  }

  // Returns a stream backed by Socket.io — emits updated list on each change
  Stream<List<ServiceRequest>> getNearbyServiceRequests({
    double? latitude,
    double? longitude,
    String? userId,
  }) {
    final controller = StreamController<List<ServiceRequest>>();

    Future<void> fetchAndEmit() async {
      try {
        final response = await _api.get('/service-requests/nearby', params: {
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'radius': 30,
        });
        final list = (response.data as List)
            .map((e) => ServiceRequest.fromJson(e))
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetchAndEmit();

    // Listen for new requests via Socket.io
    _socket.on('request:created', (_) => fetchAndEmit());
    _socket.on('request:status', (_) => fetchAndEmit());

    controller.onCancel = () {
      _socket.off('request:created');
      _socket.off('request:status');
    };

    return controller.stream;
  }

  Stream<ServiceRequest?> getServiceRequestStream(String id) {
    final controller = StreamController<ServiceRequest?>();

    Future<void> fetchAndEmit() async {
      try {
        final response = await _api.get('/service-requests/$id');
        if (!controller.isClosed) {
          controller.add(ServiceRequest.fromJson(response.data));
        }
      } catch (_) {
        if (!controller.isClosed) controller.add(null);
      }
    }

    fetchAndEmit();
    _socket.joinRequest(id);
    _socket.on('request:status', (data) {
      if (data['requestId'] == id) fetchAndEmit();
    });
    _socket.on('request:assigned', (data) {
      if (data['_id'] == id || data['id'] == id) {
        if (!controller.isClosed) controller.add(ServiceRequest.fromJson(data));
      }
    });

    controller.onCancel = () {
      _socket.leaveRequest(id);
      _socket.off('request:status');
      _socket.off('request:assigned');
    };

    return controller.stream;
  }

  Future<ServiceRequest?> getServiceRequestById(String id) async {
    try {
      final response = await _api.get('/service-requests/$id');
      return ServiceRequest.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<ServiceRequest?> getObjectById(String id) => getServiceRequestById(id);

  Stream<List<ServiceRequest>> getClientRequests(String clientId) {
    final controller = StreamController<List<ServiceRequest>>();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/service-requests/my');
        final list = (response.data as List)
            .map((e) => ServiceRequest.fromJson(e))
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();
    _socket.on('request:status', (_) => fetch());
    _socket.on('request:created', (_) => fetch());
    _socket.on('request:cancelled', (_) => fetch());

    controller.onCancel = () {
      _socket.off('request:status');
      _socket.off('request:created');
      _socket.off('request:cancelled');
    };

    return controller.stream;
  }

  Future<void> updateRequestStatus(String requestId, ServiceRequestStatus status) async {
    await _api.put('/service-requests/$requestId/status', data: {'status': status.name});
  }

  Future<void> cancelServiceRequest(String requestId) async {
    await _api.put('/service-requests/$requestId/cancel');
  }

  Future<void> deleteServiceRequest(String requestId) async {
    await _api.delete('/service-requests/$requestId');
  }

  // ─── USERS ────────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    try {
      final response = await _api.get('/users/$uid');
      return UserModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    await _api.put('/users/me', data: user.toJson());
  }

  Stream<UserModel?> getUserStream(String uid) {
    final controller = StreamController<UserModel?>();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/users/$uid');
        if (!controller.isClosed) {
          controller.add(UserModel.fromJson(response.data));
        }
      } catch (_) {
        if (!controller.isClosed) controller.add(null);
      }
    }

    fetch();
    return controller.stream;
  }

  Future<List<UserModel>> getNearbyTechnicians({
    required double latitude,
    required double longitude,
    double radiusKm = 20,
    String? specialty,
  }) async {
    final response = await _api.get('/users/nearby-technicians', params: {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radiusKm,
      if (specialty != null) 'specialty': specialty,
    });
    return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> getTopTechnicians() async {
    final response = await _api.get('/users/top-technicians');
    return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Stream<List<UserModel>> getTopTechniciansStream() {
    final controller = StreamController<List<UserModel>>();
    _api.get('/users/top-technicians').then((response) {
      final list = (response.data as List).map((e) => UserModel.fromJson(e)).toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((e) {
      if (!controller.isClosed) controller.addError(e);
    });
    return controller.stream;
  }

  // ─── QUOTES ───────────────────────────────────────────────────────────────

  Future<Quote> createQuote(Quote quote) async {
    final response = await _api.post('/quotes', data: quote.toJson());
    return Quote.fromJson(response.data);
  }

  Stream<List<Quote>> getQuotesForRequest(String requestId) {
    final controller = StreamController<List<Quote>>();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/quotes/request/$requestId');
        final list = (response.data as List).map((e) => Quote.fromJson(e)).toList();
        if (!controller.isClosed) controller.add(list);
      } catch (_) {
        if (!controller.isClosed) controller.add([]);
      }
    }

    fetch();
    _socket.on('quote:new', (data) {
      if (data['quote']?['requestId'] == requestId) fetch();
    });
    _socket.on('quote:accepted', (_) => fetch());
    _socket.on('quote:rejected', (_) => fetch());

    controller.onCancel = () {
      _socket.off('quote:new');
      _socket.off('quote:accepted');
      _socket.off('quote:rejected');
    };

    return controller.stream;
  }

  Future<void> acceptQuote(String quoteId) async {
    await _api.put('/quotes/$quoteId/accept');
  }

  Future<void> rejectQuote(String quoteId) async {
    await _api.put('/quotes/$quoteId/reject');
  }

  // ─── CHAT ─────────────────────────────────────────────────────────────────

  Stream<List<ChatMessage>> getChatMessages(String requestId) {
    final controller = StreamController<List<ChatMessage>>.broadcast();
    final messages = <ChatMessage>[];

    _api.get('/chat/$requestId/messages').then((response) {
      messages.addAll((response.data as List).map((e) => ChatMessage.fromJson(e)));
      if (!controller.isClosed) controller.add(List.from(messages));
    });

    _socket.joinRoom(requestId);
    _socket.on('chat:message', (data) {
      if (data['requestId'] == requestId) {
        messages.add(ChatMessage.fromJson(data));
        if (!controller.isClosed) controller.add(List.from(messages));
      }
    });

    controller.onCancel = () {
      _socket.leaveRoom(requestId);
      _socket.off('chat:message');
    };

    return controller.stream;
  }

  Future<void> sendChatMessage(String requestId, ChatMessage message) async {
    _socket.sendChatMessage(
      requestId: requestId,
      text: message.text,
      senderName: message.senderName,
      imageUrl: message.imageUrl,
      latitude: message.latitude,
      longitude: message.longitude,
      type: message.type.name,
    );
  }

  // ─── ALERTS ───────────────────────────────────────────────────────────────

  Future<void> saveUserAlert(String userId, AlertModel alert) async {
    // Alerts are server-generated. This is a no-op on the client side.
  }

  Stream<List<AlertModel>> getUserAlerts(String userId) {
    final controller = StreamController<List<AlertModel>>();
    final alerts = <AlertModel>[];

    _api.get('/alerts').then((response) {
      alerts.addAll((response.data as List).map((e) => AlertModel.fromJson(e)));
      if (!controller.isClosed) controller.add(List.from(alerts));
    });

    _socket.on('alert:new', (data) {
      alerts.insert(0, AlertModel.fromJson(data));
      if (!controller.isClosed) controller.add(List.from(alerts));
    });

    controller.onCancel = () {
      _socket.off('alert:new');
    };

    return controller.stream;
  }

  // ─── REVIEWS ──────────────────────────────────────────────────────────────

  Future<void> createReview(ReviewModel review) async {
    await _api.post('/reviews', data: {
      'requestId': review.requestId,
      'rating': review.rating,
      'comment': review.comment,
    });
  }

  Future<List<ReviewModel>> getTechnicianReviews(String technicianId) async {
    final response = await _api.get('/reviews/technician/$technicianId');
    return (response.data as List).map((e) => ReviewModel.fromJson(e)).toList();
  }

  // ─── PORTFOLIO ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTechnicianPortfolio(String technicianId) async {
    final response = await _api.get('/users/$technicianId/portfolio');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> addPortfolioItem(String technicianId, Map<String, dynamic> item) async {
    await _api.post('/users/me/portfolio', data: item);
  }

  Future<void> deletePortfolioItem(String technicianId, String itemId) async {
    await _api.delete('/users/me/portfolio/$itemId');
  }

  // ─── UPLOAD (delegates to Firebase Storage) ───────────────────────────────

  final UploadService _uploadService = UploadService();

  Future<List<String>> uploadServiceImages(
    List<dynamic> files,
    String requestId,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await _uploadService.uploadServiceImage(file, requestId);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
