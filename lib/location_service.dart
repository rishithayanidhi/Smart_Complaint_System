import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Represents full location + address metadata
class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'city': city,
    'state': state,
    'country': country,
    'postalCode': postalCode,
    'accuracy': accuracy,
  };

  @override
  String toString() =>
      '$address (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
}

/// Main location utility (optimized for production)
class LocationService {
  static const String _logTag = '📍[LocationService]';

  // ----------------------------------------------------------
  // ✅ Permission & Service Checks
  // ----------------------------------------------------------

  static Future<bool> _checkLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      debugPrint('$_logTag: Location services are disabled');
    }
    return enabled;
  }

  static Future<bool> _checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('$_logTag: Permission permanently denied.');
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ----------------------------------------------------------
  // ✅ Core Location Acquisition
  // ----------------------------------------------------------

  static Future<Position?> _tryGetPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int timeoutSec = 10,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: 25,
          timeLimit: Duration(seconds: timeoutSec),
        ),
      );
    } catch (e) {
      debugPrint('$_logTag: Error getting position: $e');
      return null;
    }
  }

  static Future<Position?> _fallbackLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('$_logTag: No last known position available: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // ✅ Reverse Geocoding
  // ----------------------------------------------------------

  static Future<String> _getAddressFromCoordinates(
    double lat,
    double lon,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = [
          p.name,
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        return address.isNotEmpty ? address : 'Unnamed Location';
      }
    } catch (e) {
      debugPrint('$_logTag: Geocoding failed: $e');
    }
    return 'Lat: ${lat.toStringAsFixed(5)}, Lon: ${lon.toStringAsFixed(5)}';
  }

  // ----------------------------------------------------------
  // ✅ Public Interface: get current location with address
  // ----------------------------------------------------------

  static Future<LocationData?> getCurrentLocationWithAddress({
    bool highAccuracy = false,
    bool includeAddress = true,
  }) async {
    try {
      if (!await _checkLocationServiceEnabled()) {
        debugPrint('$_logTag: Service disabled.');
        return null;
      }

      if (!await _checkAndRequestPermission()) {
        debugPrint('$_logTag: Permission denied.');
        return null;
      }

      Position? position = await _tryGetPosition(
        accuracy: highAccuracy
            ? LocationAccuracy.best
            : LocationAccuracy.medium,
      );

      position ??= await _fallbackLastKnownPosition();

      if (position == null) {
        debugPrint('$_logTag: Could not retrieve any position.');
        return null;
      }

      String address = includeAddress
          ? await _getAddressFromCoordinates(
              position.latitude,
              position.longitude,
            )
          : 'Coordinates only';

      final placemarks = includeAddress
          ? await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            )
          : <Placemark>[];

      final p = placemarks.isNotEmpty ? placemarks.first : null;

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        city: p?.locality,
        state: p?.administrativeArea,
        country: p?.country,
        postalCode: p?.postalCode,
        accuracy: position.accuracy,
      );
    } catch (e) {
      debugPrint('$_logTag: Exception: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // ✅ Utility Helpers
  // ----------------------------------------------------------

  static Future<String> getQuickLocationString() async {
    final loc = await getCurrentLocationWithAddress(
      highAccuracy: false,
      includeAddress: false,
    );
    return loc != null
        ? 'Lat: ${loc.latitude.toStringAsFixed(3)}, Lon: ${loc.longitude.toStringAsFixed(3)}'
        : 'Location unavailable';
  }

  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('$_logTag: Error opening location settings: $e');
    }
  }

  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('$_logTag: Error opening app settings: $e');
    }
  }

  static Future<bool> isPermissionGranted() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }
}
