import '../models/service_request.dart';
import '../models/quote_model.dart';
import 'api_service.dart';

class ServiceRequestService {
  final ApiService _api = ApiService();

  Future<List<ServiceRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radius = 30,
    String? category,
    String? urgency,
  }) async {
    final response = await _api.get('/service-requests/nearby', params: {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      if (category != null) 'category': category,
      if (urgency != null) 'urgency': urgency,
    });
    return (response.data as List)
        .map((e) => ServiceRequest.fromJson(e))
        .toList();
  }

  Future<List<ServiceRequest>> getMyRequests() async {
    final response = await _api.get('/service-requests/my');
    return (response.data as List)
        .map((e) => ServiceRequest.fromJson(e))
        .toList();
  }

  Future<List<ServiceRequest>> getMyAssignedRequests() async {
    final response = await _api.get('/service-requests/assigned');
    return (response.data as List)
        .map((e) => ServiceRequest.fromJson(e))
        .toList();
  }

  Future<ServiceRequest> getById(String id) async {
    final response = await _api.get('/service-requests/$id');
    return ServiceRequest.fromJson(response.data);
  }

  Future<ServiceRequest> create({
    required String title,
    required String description,
    required String category,
    required double latitude,
    required double longitude,
    required String address,
    List<String> imageUrls = const [],
    List<String> thumbnailUrls = const [],
    String urgency = 'medium',
    double? minBudget,
    double? maxBudget,
    String? targetTechnicianId,
  }) async {
    final response = await _api.post('/service-requests', data: {
      'title': title,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'imageUrls': imageUrls,
      'thumbnailUrls': thumbnailUrls,
      'urgency': urgency,
      if (minBudget != null) 'minBudget': minBudget,
      if (maxBudget != null) 'maxBudget': maxBudget,
      if (targetTechnicianId != null) 'targetTechnicianId': targetTechnicianId,
    });
    return ServiceRequest.fromJson(response.data);
  }

  Future<void> updateStatus(String id, ServiceRequestStatus status) async {
    await _api.put('/service-requests/$id/status', data: {'status': status.name});
  }

  Future<void> cancel(String id) async {
    await _api.put('/service-requests/$id/cancel');
  }

  Future<void> delete(String id) async {
    await _api.delete('/service-requests/$id');
  }

  Future<List<Quote>> getQuotes(String requestId) async {
    final response = await _api.get('/quotes/request/$requestId');
    return (response.data as List).map((e) => Quote.fromJson(e)).toList();
  }

  Future<Quote> sendQuote({
    required String requestId,
    required double minPrice,
    required double maxPrice,
    required String message,
    String? estimatedTime,
  }) async {
    final response = await _api.post('/quotes', data: {
      'requestId': requestId,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'message': message,
      if (estimatedTime != null) 'estimatedTime': estimatedTime,
    });
    return Quote.fromJson(response.data);
  }

  Future<void> acceptQuote(String quoteId) async {
    await _api.put('/quotes/$quoteId/accept');
  }

  Future<void> rejectQuote(String quoteId, {String? reason}) async {
    await _api.put('/quotes/$quoteId/reject', data: {'reason': reason ?? ''});
  }
}
