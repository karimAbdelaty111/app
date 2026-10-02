import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Reason why a location request did not return a position.
enum LocationOutcome {
  /// A position was read successfully.
  success,

  /// Location services are switched off on the device.
  serviceDisabled,

  /// The user did not grant the location permission.
  permissionDenied,

  /// The user denied the location permission permanently, it can only be
  /// changed in the app settings.
  permissionDeniedForever,

  /// Something went wrong while reading the position.
  failed,
}

/// A position read from the device.
class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.name,
  });

  final double latitude;
  final double longitude;

  /// Accuracy of the position in meters, `null` when the platform did not
  /// report one.
  final double? accuracy;

  /// Readable name of the position, for example `Cairo, Egypt`.
  ///
  /// It is `null` when the address could not be resolved, [label] then falls
  /// back to the coordinates.
  final String? name;

  /// Short human readable representation used in the user interface.
  String get label => formatLocationLabel(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    name: name,
  );
}

/// Result of [LocationService.getCurrentLocation].
class LocationResult {
  const LocationResult._({
    required this.outcome,
    this.location,
    this.errorMessage,
  });

  const LocationResult.success(DeviceLocation location)
    : this._(outcome: LocationOutcome.success, location: location);

  const LocationResult.serviceDisabled()
    : this._(outcome: LocationOutcome.serviceDisabled);

  const LocationResult.permissionDenied()
    : this._(outcome: LocationOutcome.permissionDenied);

  const LocationResult.permissionDeniedForever()
    : this._(outcome: LocationOutcome.permissionDeniedForever);

  const LocationResult.failed(String message)
    : this._(outcome: LocationOutcome.failed, errorMessage: message);

  final LocationOutcome outcome;

  /// The position, only set when [outcome] is [LocationOutcome.success].
  final DeviceLocation? location;

  /// Message describing [LocationOutcome.failed].
  final String? errorMessage;

  bool get isSuccess => outcome == LocationOutcome.success;
}

/// Formats a position for the user interface, for example
/// `Cairo, Egypt` or, when the name is unknown, `51.50735, -0.12776 (±8 m)`.
String formatLocationLabel({
  required double latitude,
  required double longitude,
  double? accuracy,
  String? name,
}) {
  final readableName = _cleanName(name);
  if (readableName != null) {
    return readableName;
  }
  final coordinates = '${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)}';
  if (accuracy == null || accuracy <= 0) {
    return coordinates;
  }
  return '$coordinates (±${accuracy.round()} m)';
}

/// Returns the name without empty parts, or `null` when nothing is left.
String? _cleanName(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Builds a short place name such as `Cairo, Egypt` from a platform placemark.
///
/// Only the parts that are useful for a note are kept, so the result stays
/// short enough for the user interface.
String? _describePlacemark(Placemark place) {
  final parts = <String>[
    if (_cleanName(place.locality) != null) place.locality!,
    if (_cleanName(place.administrativeArea) != null &&
        place.administrativeArea != place.locality)
      place.administrativeArea!,
    if (_cleanName(place.country) != null && place.country != place.locality)
      place.country!,
  ];
  return parts.isEmpty ? _cleanName(place.name) : parts.join(', ');
}

/// Reads the current position of the device.
///
/// The class only talks to the platform, it does not show any dialog, so the
/// permission and service problems can be handled by the caller.
class LocationService {
  const LocationService();

  /// Reverse geocoding is done through this helper, the `geocoding` package
  /// exposes it as an object instead of a plain function.
  static final Geocoding _geocoding = Geocoding();

  /// Requests the permission if needed and returns the current position.
  ///
  /// The returned [LocationResult] tells the caller which of the possible
  /// problems occurred, nothing is thrown to the user interface.
  Future<LocationResult> getCurrentLocation({
    // A medium accuracy is accurate enough for a note and does not force the
    // GPS to search for a fix for a long time.
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeLimit = const Duration(seconds: 15),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.serviceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.permissionDenied();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.permissionDeniedForever();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
      return LocationResult.success(
        DeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          name: await readPlaceName(
            position.latitude,
            position.longitude,
          ),
        ),
      );
    } on TimeoutException {
      return const LocationResult.failed(
        'It took too long to read your position, please try again.',
      );
    } on LocationServiceDisabledException {
      return const LocationResult.serviceDisabled();
    } catch (error) {
      debugPrint('LocationService: could not read the position - $error');
      return const LocationResult.failed(
        'Your position could not be read, please try again.',
      );
    }
  }

  /// Turns coordinates into a readable name such as `Cairo, Egypt`.
  ///
  /// Reverse geocoding is a nice to have, so it never throws: when the lookup
  /// fails or is too slow `null` is returned and the caller keeps the plain
  /// coordinates.
  @visibleForTesting
  static Future<String?> readPlaceName(
    double latitude,
    double longitude, {
    Duration timeLimit = const Duration(seconds: 6),
  }) async {
    try {
      final places = await _geocoding
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(timeLimit);
      if (places.isEmpty) {
        return null;
      }
      return _describePlacemark(places.first);
    } on TimeoutException {
      debugPrint('LocationService: the place name lookup timed out');
      return null;
    } catch (error) {
      debugPrint('LocationService: could not read the place name - $error');
      return null;
    }
  }

  /// Opens the system page where location services can be switched on.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens the app settings page where the location permission can be
  /// granted.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
