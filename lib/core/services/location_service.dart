import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Service specialized in handling GPS permissions and real-time location.
class LocationService {
  
  /// Checks and requests necessary location permissions.
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check location permission using geolocator
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return false;
    }

    return true;
  }

  /// General location stream — no foreground notification (for map/clients).
  Stream<Position> get locationStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).handleError((e) => print('[Location] Stream error: $e'));
  }

  /// Gets the current position once.
  Future<Position?> getCurrentLocation() async {
    try {
      // First, ensure permissions are granted
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      // We use 'high' or 'best' for publishing. Best can sometimes be slow.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // High is usually faster and very precise
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      print('LocationService: Error getting current location: $e');
      try {
        // Fallback to last known position if current fails
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}
