import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

class LocationTracker {
  // 1. Existing function for a single location check
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permission denied.');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Permission permanently denied.');

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // 2. Cross-platform continuous location stream
  static Stream<Position> getContinuousLocationStream() {
    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 3),
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "CarbonSense is tracking your commute...",
          notificationTitle: "Active Trip",
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true, // Displays the blue bar/pill on iOS
      );
    } else {
      // Fallback for Windows desktop or testing environments
      locationSettings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  // 3. Distance Math
  static double calculateDistanceInKm(Position startPosition, Position endPosition) {
    final distanceInMeters = Geolocator.distanceBetween(startPosition.latitude, startPosition.longitude, endPosition.latitude, endPosition.longitude);
    return distanceInMeters / 1000;
  }
}
