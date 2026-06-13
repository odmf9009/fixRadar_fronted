import '../models/user_model.dart';
import 'api_service.dart';

class UserService {
  final ApiService _api = ApiService();

  Future<UserModel> getMe() async {
    final response = await _api.get('/users/me');
    return UserModel.fromJson(response.data);
  }

  Future<UserModel> updateMe(Map<String, dynamic> fields) async {
    final response = await _api.put('/users/me', data: fields);
    return UserModel.fromJson(response.data);
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    await _api.put('/users/me/location', data: {'latitude': latitude, 'longitude': longitude});
  }

  Future<UserModel> getPublicProfile(String userId) async {
    final response = await _api.get('/users/$userId');
    return UserModel.fromJson(response.data);
  }

  Future<List<UserModel>> getNearbyTechnicians({
    required double latitude,
    required double longitude,
    double radius = 20,
    String? specialty,
  }) async {
    final response = await _api.get('/users/nearby-technicians', params: {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      if (specialty != null) 'specialty': specialty,
    });
    return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> getTopTechnicians() async {
    final response = await _api.get('/users/top-technicians');
    return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<UserModel>> getFavoriteTechnicians() async {
    final response = await _api.get('/users/me/favorites');
    return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
  }

  Future<List<String>> toggleFavorite(String technicianId) async {
    final response = await _api.post('/users/me/favorites', data: {'technicianId': technicianId});
    return List<String>.from(response.data['favorites']);
  }

  Future<List<Map<String, dynamic>>> getPortfolio(String technicianId) async {
    final response = await _api.get('/users/$technicianId/portfolio');
    return List<Map<String, dynamic>>.from(response.data);
  }
}
