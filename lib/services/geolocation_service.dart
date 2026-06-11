import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Result of a geolocation validation attempt.
class LocationValidationResult {
  final bool success;
  final String? errorMessage;
  final double? latitude;
  final double? longitude;
  final double? distanceFromOffice; // in meters

  const LocationValidationResult({
    required this.success,
    this.errorMessage,
    this.latitude,
    this.longitude,
    this.distanceFromOffice,
  });
}

/// Handles GPS location capture and geofence validation.
class GeolocationService {
  static const double _earthRadius = 6371000; // meters

  /// Requests location permission and returns the current position.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS is disabled. Please enable location services to check in.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission denied. Cannot verify your position.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable it in app settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }

  /// Validates that the user is within [allowedRadiusMeters] of the office.
  Future<LocationValidationResult> validateLocation({
    required double officeLat,
    required double officeLng,
    required double allowedRadiusMeters,
  }) async {
    try {
      final position = await getCurrentPosition();

      final distance = _haversineDistance(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      if (distance > allowedRadiusMeters) {
        return LocationValidationResult(
          success: false,
          errorMessage:
              'You are ${distance.toStringAsFixed(0)}m away from the office '
              '(max allowed: ${allowedRadiusMeters.toStringAsFixed(0)}m). '
              'Please check in from the workplace.',
          latitude: position.latitude,
          longitude: position.longitude,
          distanceFromOffice: distance,
        );
      }

      return LocationValidationResult(
        success: true,
        latitude: position.latitude,
        longitude: position.longitude,
        distanceFromOffice: distance,
      );
    } catch (e) {
      return LocationValidationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Returns distance in meters between two GPS coordinates (Haversine).
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
