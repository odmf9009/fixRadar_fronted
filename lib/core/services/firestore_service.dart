// Compatibility facade: same interface as the original FirestoreService
// but uses MongoDB REST API + Socket.io instead of Firestore.
import 'dart:async';
import 'dart:io';
import '../models/service_request.dart';
import '../models/quote_model.dart';
import '../models/user_model.dart';
import '../models/chat_message_model.dart';
import '../models/alert_model.dart';
import '../models/review_model.dart';
import '../models/portfolio_item.dart';
import '../models/activity_model.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'upload_service.dart';

class FirestoreService {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  // Singleton broadcast streams to share data and minimize API requests
  static final Map<String, StreamController<UserModel?>> _userStreamControllers = {};
  static final Map<String, UserModel?> _cachedUserValues = {};
  static final Map<String, StreamController<List<ServiceRequest>>> _requestStreamControllers = {};
  static final Map<String, List<ServiceRequest>> _cachedRequestValues = {};

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
    double radius = 30,
    String? userId,
  }) {
    final controller = StreamController<List<ServiceRequest>>.broadcast();

    Future<void> fetchAndEmit() async {
      // If we don't have location, we can't fetch nearby requests from the backend
      // because the backend requires latitude and longitude for the $near query.
      if (latitude == null || longitude == null) {
        if (!controller.isClosed) controller.add([]);
        return;
      }

      try {
        final response = await _api.get('/service-requests/nearby', params: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        });
        final list = (response.data as List)
            .map((e) => ServiceRequest.fromJson(e))
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (_) {}
    }

    void onUpdate(_) => fetchAndEmit();

    fetchAndEmit();

    // Listen for new requests via Socket.io
    _socket.on('request:created', onUpdate);
    _socket.on('request:status', onUpdate);
    _socket.on('request:deleted', onUpdate);

    controller.onCancel = () {
      _socket.off('request:created', onUpdate);
      _socket.off('request:status', onUpdate);
      _socket.off('request:deleted', onUpdate);
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  Stream<List<ServiceRequest>> getClientRequests(String clientId) {
    // If the stream controller already exists and is open, trigger a refresh and return it.
    if (_requestStreamControllers.containsKey(clientId)) {
      final existing = _requestStreamControllers[clientId]!;
      if (!existing.isClosed) {
        // Trigger an asynchronous fetch to update the stream
        _fetchClientRequests(clientId);
        return existing.stream;
      }
    }

    final controller = StreamController<List<ServiceRequest>>.broadcast();
    _requestStreamControllers[clientId] = controller;

    _fetchClientRequests(clientId);

    // Named handlers to allow surgical removal
    void onUpdate(_) => _fetchClientRequests(clientId);

    _socket.on('request:status', onUpdate);
    _socket.on('request:created', onUpdate);
    _socket.on('request:cancelled', onUpdate);
    _socket.on('request:deleted', onUpdate);

    controller.onCancel = () {
      _socket.off('request:status', onUpdate);
      _socket.off('request:created', onUpdate);
      _socket.off('request:cancelled', onUpdate);
      _socket.off('request:deleted', onUpdate);
      _requestStreamControllers.remove(clientId);
      _cachedRequestValues.remove(clientId);
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  Future<void> _fetchClientRequests(String clientId) async {
    final controller = _requestStreamControllers[clientId];
    if (controller == null || controller.isClosed) return;

    try {
      final response = await _api.get('/service-requests/my');
      final list = (response.data as List)
          .map((e) => ServiceRequest.fromJson(e))
          .toList();
      _cachedRequestValues[clientId] = list;
      if (!controller.isClosed) controller.add(list);
    } catch (_) {
      // If we have cached values, we can at least show those
      if (_cachedRequestValues.containsKey(clientId)) {
        if (!controller.isClosed) controller.add(_cachedRequestValues[clientId]!);
      }
    }
  }

  Stream<ServiceRequest?> getServiceRequestStream(String id) {
    final controller = StreamController<ServiceRequest?>.broadcast();

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

    void onStatus(data) {
      if (data['requestId'] == id) fetchAndEmit();
    }
    void onAssigned(data) {
      if (data['_id'] == id || data['id'] == id) {
        if (!controller.isClosed) controller.add(ServiceRequest.fromJson(data));
      }
    }

    fetchAndEmit();
    _socket.joinRequest(id);
    _socket.on('request:status', onStatus);
    _socket.on('request:assigned', onAssigned);

    controller.onCancel = () {
      _socket.leaveRequest(id);
      _socket.off('request:status', onStatus);
      _socket.off('request:assigned', onAssigned);
      if (!controller.isClosed) controller.close();
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
    // Reuse existing broadcast stream — all callers share ONE polling loop
    final existing = _userStreamControllers[uid];
    if (existing != null && !existing.isClosed) {
      // Emit last known value immediately so late subscribers get data right away
      final cached = _cachedUserValues[uid];
      if (cached != null) {
        Future.microtask(() {
          if (!existing.isClosed) existing.add(cached);
        });
      }
      return existing.stream;
    }

    late StreamController<UserModel?> controller;
    controller = StreamController<UserModel?>.broadcast(
      onCancel: () {
        _userStreamControllers.remove(uid);
        _cachedUserValues.remove(uid);
        if (!controller.isClosed) controller.close();
      },
    );
    _userStreamControllers[uid] = controller;
    _pollUser(uid, controller);
    return controller.stream;
  }

  void _pollUser(String uid, StreamController<UserModel?> controller) async {
    while (!controller.isClosed) {
      try {
        final response = await _api.get('/users/$uid');
        if (!controller.isClosed) {
          final user = UserModel.fromJson(response.data);
          _cachedUserValues[uid] = user;
          controller.add(user);
        }
      } catch (_) {
        // On error (including 429), keep last known value — do NOT emit null
        // This prevents the UI from reverting to a loading/error state on blips
      }
      if (!controller.isClosed) {
        // Increased from 30s to 60s since sockets handle real-time updates
        await Future.delayed(const Duration(seconds: 60));
      }
    }
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
    final controller = StreamController<List<UserModel>>.broadcast();
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
    final controller = StreamController<List<Quote>>.broadcast();

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

  // acceptQuote can be called as acceptQuote(quoteId) or acceptQuote(requestId, quote)
  Future<void> acceptQuote(String requestIdOrQuoteId, [Quote? quote]) async {
    final String quoteId = quote?.id ?? requestIdOrQuoteId;
    await _api.put('/quotes/$quoteId/accept');
  }

  // rejectQuote can be called as rejectQuote(quoteId) or rejectQuote(requestId, quoteId)
  Future<void> rejectQuote(String requestIdOrQuoteId, [String? quoteId]) async {
    final String id = quoteId ?? requestIdOrQuoteId;
    await _api.put('/quotes/$id/reject');
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
    final controller = StreamController<List<AlertModel>>.broadcast();
    final alerts = <AlertModel>[];

    Future<void> fetch() async {
      try {
        final response = await _api.get('/alerts');
        final list = (response.data as List).map((e) => AlertModel.fromJson(e)).toList();
        alerts.clear();
        alerts.addAll(list);
        if (!controller.isClosed) controller.add(List.from(alerts));
      } catch (_) {}
    }

    void onNewAlert(data) {
      alerts.insert(0, AlertModel.fromJson(data));
      if (!controller.isClosed) controller.add(List.from(alerts));
    }

    void onCleared(_) {
      alerts.clear();
      if (!controller.isClosed) controller.add(List.from(alerts));
    }

    fetch();
    _socket.on('alert:new', onNewAlert);
    _socket.on('alerts:cleared', onCleared);

    controller.onCancel = () {
      _socket.off('alert:new', onNewAlert);
      _socket.off('alerts:cleared', onCleared);
      if (!controller.isClosed) controller.close();
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
    try {
      final response = await _api.get('/reviews/technician/$technicianId');
      return (response.data as List).map((e) => ReviewModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<ReviewModel>> getTechnicianReviewsStream(String technicianId) {
    final controller = StreamController<List<ReviewModel>>.broadcast();
    getTechnicianReviews(technicianId).then((list) {
      if (!controller.isClosed) controller.add(list);
    }).catchError((_) {
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }

  // ─── PORTFOLIO ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTechnicianPortfolio(String technicianId) async {
    final response = await _api.get('/users/$technicianId/portfolio');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // addPortfolioItem is defined below with overloaded signature

  Future<void> deletePortfolioItem(String technicianIdOrItemId, [String? itemId]) async {
    final String id = itemId ?? technicianIdOrItemId;
    await _api.delete('/users/me/portfolio/$id');
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

  // ─── USER PRESENCE / LOCATION ─────────────────────────────────────────────

  Future<void> updateUserOnlineStatus(String uid, bool isOnline, {double? lat, double? lng}) async {
    try {
      final data = <String, dynamic>{'isOnline': isOnline};
      if (lat != null) data['latitude'] = lat;
      if (lng != null) data['longitude'] = lng;
      await _api.put('/users/me', data: data);
    } catch (_) {}
  }

  Future<void> updateUserLocation(String uid, double lat, double lng) async {
    try {
      await _api.put('/users/me', data: {'latitude': lat, 'longitude': lng});
    } catch (_) {}
  }

  Future<void> updateUserRadius(String userId, double radius) async {
    try {
      await _api.put('/users/me', data: {'serviceRadius': radius});
    } catch (_) {}
  }

  // ─── USER PROFILE MUTATIONS ───────────────────────────────────────────────

  Future<void> updateUserAlias(String userId, String alias) async {
    await _api.put('/users/me', data: {'username': alias});
  }

  Future<void> updateUserRole(String userId, String role, {List<String>? specialties}) async {
    await _api.put('/users/me', data: {
      'userType': role,
      'role': role,
      'onboardingCompleted': true,
      if (specialties != null) 'specialties': specialties,
    });
  }

  Future<void> updateUserProfileImage(String userId, String imageUrl) async {
    await _api.put('/users/me', data: {'profileImageUrl': imageUrl});
  }

  Future<void> updateNotificationsStatus(String userId, bool enabled) async {
    await _api.put('/users/me', data: {'notificationsEnabled': enabled});
  }

  Future<void> deleteUserAccount(String userId) async {
    try {
      await _api.delete('/users/me');
    } catch (_) {}
  }

  Future<void> toggleFavoriteTechnician(String userId, String technicianId, [bool? isFavorite]) async {
    try {
      if (isFavorite == true) {
        await _api.delete('/users/me/favorites/$technicianId');
      } else {
        await _api.post('/users/me/favorites', data: {'technicianId': technicianId});
      }
    } catch (_) {}
  }

  // ─── TECHNICIANS ──────────────────────────────────────────────────────────

  /// Returns a stream of all technicians, optionally filtered by location
  Stream<List<UserModel>> getTechnicians({double? latitude, double? longitude, double? radius}) {
    final controller = StreamController<List<UserModel>>.broadcast();
    
    final params = <String, dynamic>{};
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (radius != null) params['radius'] = radius;

    _api.get('/users/nearby-technicians', params: params).then((response) {
      final list = (response.data as List).map((e) => UserModel.fromJson(e)).toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((e) {
      print('FirestoreService: Error fetching technicians: $e');
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }

  /// Returns a stream of top-rated technicians
  Stream<List<UserModel>> getTopRatedTechnicians({int? limit}) {
    final controller = StreamController<List<UserModel>>.broadcast();
    _api.get('/users/top-technicians', params: limit != null ? {'limit': limit} : null).then((response) {
      final list = (response.data as List).map((e) => UserModel.fromJson(e)).toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((e) {
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }

  /// Returns nearby technicians filtered by location (online only)
  Stream<List<UserModel>> getNearbyTechniciansStream({
    required double latitude,
    required double longitude,
    double radius = 50,
  }) {
    final controller = StreamController<List<UserModel>>.broadcast();
    _api.get('/users/nearby-technicians', params: {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    }).then((response) {
      final list = (response.data as List).map((e) => UserModel.fromJson(e)).toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((e) {
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }

  /// Updates the current user's online/offline status.
  /// Also toggles notificationsEnabled so manual offline blocks push.
  Future<UserModel?> updateOnlineStatus({required bool isOnline}) async {
    final response = await _api.put('/users/me', data: {
      'isOnline': isOnline,
      'presenceStatus': isOnline ? 'online' : 'offline',
      'notificationsEnabled': isOnline,
    });
    return UserModel.fromJson(response.data);
  }

  /// Returns a stream of active technicians (used for map markers)
  Stream<List<UserModel>> getActiveHunters() {
    final controller = StreamController<List<UserModel>>.broadcast();
    _api.get('/users/nearby-technicians').then((response) {
      final list = (response.data as List)
          .map((e) => UserModel.fromJson(e))
          .where((u) => u.isOnline)
          .toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((e) {
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }

  Stream<List<UserModel>> getTopUsers({int limit = 20, String? sortBy}) {
    final controller = StreamController<List<UserModel>>.broadcast();
    _api.get('/users/top-technicians', params: {
      'limit': limit,
      if (sortBy != null) 'sortBy': sortBy,
    }).then((response) {
      final list = (response.data as List).map((e) => UserModel.fromJson(e)).toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((_) {
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }

  // ─── QUOTES (EXTRA) ───────────────────────────────────────────────────────

  Future<Quote?> getQuoteByTechnician(String requestId, String technicianId) async {
    try {
      final response = await _api.get('/quotes/request/$requestId');
      final list = (response.data as List).map((e) => Quote.fromJson(e)).toList();
      return list.cast<Quote?>().firstWhere(
        (q) => q?.technicianId == technicianId,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Quote?> getQuoteById(String quoteId) async {
    try {
      final response = await _api.get('/quotes/$quoteId');
      return Quote.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Stream<List<Quote>> getQuotesForTechnician(String technicianId) {
    final controller = StreamController<List<Quote>>.broadcast();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/quotes/technician/$technicianId');
        final list = (response.data as List).map((e) => Quote.fromJson(e)).toList();
        if (!controller.isClosed) controller.add(list);
      } catch (_) {
        if (!controller.isClosed) controller.add([]);
      }
    }

    fetch();
    _socket.on('quote:new', (_) => fetch());
    _socket.on('quote:accepted', (_) => fetch());
    _socket.on('quote:rejected', (_) => fetch());
    _socket.on('quote:status', (_) => fetch());
    _socket.on('request:cancelled', (_) => fetch());

    controller.onCancel = () {
      _socket.off('quote:new');
      _socket.off('quote:accepted');
      _socket.off('quote:rejected');
      _socket.off('quote:status');
      _socket.off('request:cancelled');
    };

    return controller.stream;
  }

  Stream<List<Quote>> getQuotesForClient(String clientId) {
    final controller = StreamController<List<Quote>>.broadcast();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/quotes/client');
        final list = (response.data as List).map((e) => Quote.fromJson(e)).toList();
        if (!controller.isClosed) controller.add(list);
      } catch (_) {
        if (!controller.isClosed) controller.add([]);
      }
    }

    void onQuoteEvent(_) => fetch();

    fetch();
    _socket.on('quote:new', onQuoteEvent);
    _socket.on('quote:accepted', onQuoteEvent);
    _socket.on('quote:rejected', onQuoteEvent);
    _socket.on('quote:status', onQuoteEvent);
    _socket.on('request:cancelled', onQuoteEvent);

    controller.onCancel = () {
      _socket.off('quote:new', onQuoteEvent);
      _socket.off('quote:accepted', onQuoteEvent);
      _socket.off('quote:rejected', onQuoteEvent);
      _socket.off('quote:status', onQuoteEvent);
      _socket.off('request:cancelled', onQuoteEvent);
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  Future<void> sendQuote(Quote quote) async {
    await _api.post('/quotes', data: quote.toJson());
  }

  Future<void> sendCounterOffer(String quoteId, dynamic minPriceOrData, [double? maxPrice, String? message, dynamic extra]) async {
    final Map<String, dynamic> data;
    if (minPriceOrData is Map<String, dynamic>) {
      data = minPriceOrData;
    } else {
      data = {
        'minPrice': minPriceOrData,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (message != null) 'message': message,
      };
    }
    await _api.put('/quotes/$quoteId/counter-offer', data: data);
  }

  Future<void> withdrawQuote(String requestIdOrQuoteId, [String? technicianId]) async {
    try {
      // Called as withdrawQuote(quoteId) or withdrawQuote(requestId, technicianId)
      await _api.put('/quotes/$requestIdOrQuoteId/withdraw');
    } catch (_) {}
  }

  // ─── SERVICE REQUEST EXTRAS ───────────────────────────────────────────────

  Stream<List<ServiceRequest>> getDirectRequestsForTechnician(String technicianId) {
    final controller = StreamController<List<ServiceRequest>>.broadcast();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/service-requests/available');
        final list = (response.data as List)
            .map((e) => ServiceRequest.fromJson(e))
            .where((r) => r.targetTechnicianId == technicianId)
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (_) {
        if (!controller.isClosed) controller.add([]);
      }
    }

    fetch();
    _socket.on('request:created', (_) => fetch());
    _socket.on('request:status', (_) => fetch());
    _socket.on('request:deleted', (_) => fetch());

    controller.onCancel = () {
      _socket.off('request:created');
      _socket.off('request:status');
      _socket.off('request:deleted');
    };

    return controller.stream;
  }

  Stream<List<ServiceRequest>> getTechnicianHistory(String technicianId) {
    final controller = StreamController<List<ServiceRequest>>.broadcast();

    Future<void> fetch() async {
      try {
        final response = await _api.get('/service-requests/technician-history');
        final list = (response.data as List)
            .map((e) => ServiceRequest.fromJson(e))
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (_) {
        if (!controller.isClosed) controller.add([]);
      }
    }

    void onUpdate(_) => fetch();

    fetch();
    _socket.on('request:status', onUpdate);
    _socket.on('request:assigned', onUpdate);
    _socket.on('request:created', onUpdate);
    _socket.on('quote:accepted', onUpdate);
    _socket.on('quote:status', onUpdate);

    controller.onCancel = () {
      _socket.off('request:status', onUpdate);
      _socket.off('request:assigned', onUpdate);
      _socket.off('request:created', onUpdate);
      _socket.off('quote:accepted', onUpdate);
      _socket.off('quote:status', onUpdate);
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  Future<void> hideServiceRequest(String userId, String requestId) async {
    try {
      await _api.post('/service-requests/$requestId/hide');
    } catch (_) {}
  }

  Future<void> cancelAssignment(String requestId) async {
    await _api.put('/service-requests/$requestId/cancel-assignment');
  }

  Future<void> finishWorkByTechnician(String requestId) async {
    try {
      await _api.put('/service-requests/$requestId/finish');
    } catch (_) {}
  }

  Future<void> completeService(String requestId, [String? photoUrl]) async {
    try {
      await _api.put('/service-requests/$requestId/complete', data: {
        if (photoUrl != null) 'completionPhotoUrl': photoUrl,
      });
    } catch (_) {}
  }

  // ─── REVIEWS ──────────────────────────────────────────────────────────────

  Future<void> submitReview(dynamic reviewOrRequestId, [String? technicianId, double? rating, String? comment]) async {
    if (reviewOrRequestId is ReviewModel) {
      await createReview(reviewOrRequestId);
    } else {
      // Called as submitReview(requestId, technicianId, rating, comment)
      final review = ReviewModel(
        id: '',
        requestId: reviewOrRequestId as String,
        technicianId: technicianId ?? '',
        clientId: '',
        clientName: '',
        rating: rating ?? 5.0,
        comment: comment ?? '',
        createdAt: DateTime.now(),
      );
      await createReview(review);
    }
  }

  // ─── PORTFOLIO (typed) ────────────────────────────────────────────────────

  Stream<List<PortfolioItem>> getPortfolio(String technicianId) {
    final controller = StreamController<List<PortfolioItem>>.broadcast();

    _api.get('/users/$technicianId/portfolio').then((response) {
      final list = (response.data as List)
          .map((e) => PortfolioItem.fromMap(e['_id'] ?? '', e as Map<String, dynamic>))
          .toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((_) {
      if (!controller.isClosed) controller.add([]);
    });

    return controller.stream;
  }

  // Override addPortfolioItem to accept 1 arg (PortfolioItem) as well
  Future<void> addPortfolioItem(dynamic technicianIdOrItem, [Map<String, dynamic>? item]) async {
    if (technicianIdOrItem is PortfolioItem) {
      await _api.post('/users/me/portfolio', data: technicianIdOrItem.toMap());
    } else {
      final String technicianId = technicianIdOrItem as String;
      await _api.post('/users/me/portfolio', data: item ?? {});
    }
  }

  Future<void> updatePortfolioItem(dynamic technicianIdOrItem, [PortfolioItem? item]) async {
    if (technicianIdOrItem is PortfolioItem) {
      await _api.put('/users/me/portfolio/${technicianIdOrItem.id}', data: technicianIdOrItem.toMap());
    } else {
      await _api.put('/users/me/portfolio/${item!.id}', data: item.toMap());
    }
  }

  // ─── CHAT EXTRAS ──────────────────────────────────────────────────────────

  Future<void> updateChatLastRead(String requestId, String userId) async {
    try {
      await _api.put('/chat/$requestId/read', data: {'userId': userId});
    } catch (_) {}
  }

  // ─── REWARDS ──────────────────────────────────────────────────────────────

  Future<bool> redeemReward(String userId, String rewardId, [int? xpRequired, String? rewardTitle]) async {
    try {
      await _api.post('/rewards/redeem', data: {
        'userId': userId,
        'rewardId': rewardId,
        if (xpRequired != null) 'xpRequired': xpRequired,
        if (rewardTitle != null) 'rewardTitle': rewardTitle,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── UPLOAD HELPERS ───────────────────────────────────────────────────────

  Future<String?> uploadObjectImage(File file) async {
    return await _uploadService.uploadServiceImage(file, 'object_${DateTime.now().millisecondsSinceEpoch}');
  }

  // ─── ALERTS EXTRAS ────────────────────────────────────────────────────────

  Future<void> markAlertAsRead(String userId, String alertId) async {
    try {
      await _api.put('/alerts/$alertId/read');
    } catch (_) {}
  }

  Future<void> clearAllUserAlerts(String userId) async {
    try {
      await _api.delete('/alerts/clear-all');
    } catch (_) {}
  }

  // ─── MISC STUBS ───────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> getGlobalStats() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _api.get('/stats/global').then((response) {
      if (!controller.isClosed) {
        controller.add(Map<String, dynamic>.from(response.data));
      }
    }).catchError((_) {
      if (!controller.isClosed) controller.add({});
    });
    return controller.stream;
  }

  Stream<List<ActivityModel>> getUserActivities(String userId) {
    final controller = StreamController<List<ActivityModel>>.broadcast();
    controller.add([]);
    return controller.stream;
  }

  Stream<List<UserModel>> getAllUsers() {
    final controller = StreamController<List<UserModel>>.broadcast();
    _api.get('/users/all').then((response) {
      final list = (response.data as List).map((e) => UserModel.fromJson(e)).toList();
      if (!controller.isClosed) controller.add(list);
    }).catchError((_) {
      if (!controller.isClosed) controller.add([]);
    });
    return controller.stream;
  }
}
