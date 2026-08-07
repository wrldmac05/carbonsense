import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart'; // 🌟 ADD THIS

class LocationTracker {
  // 1. Existing function for a single location check (Keep this)
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

  static Stream<Position> getContinuousLocationStream() {
    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation, // 🌟 MAXIMUM ACCURACY
      distanceFilter: 5, // 🌟 Re-add a tiny filter: Only update if moved > 5 meters
      intervalDuration: const Duration(seconds: 3), // Faster check
      forceLocationManager: true,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "CarbonSense is tracking your commute...",
        notificationTitle: "Active Trip",
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  // 3. Existing Math Function (Keep this)
  static double calculateDistanceInKm(Position startPosition, Position endPosition) {
    final distanceInMeters = Geolocator.distanceBetween(startPosition.latitude, startPosition.longitude, endPosition.latitude, endPosition.longitude);
    return distanceInMeters / 1000;
  }
}
