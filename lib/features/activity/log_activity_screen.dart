import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:carbonsense/features/utils/location_tracker.dart';
import 'package:go_router/go_router.dart';
import 'package:carbonsense/features/utils/mission_engine.dart';
import 'package:geocoding/geocoding.dart';

class VehicleData {
  final String id;
  final double factor;
  VehicleData({required this.id, required this.factor});
}

class LogActivityScreen extends StatefulWidget {
  final String? category;
  const LogActivityScreen({super.key, this.category});

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- STATE VARIABLES ---
  bool _isTracking = false;
  bool _isGettingLocation = false;
  bool _isSavingLog = false;
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;

  // Results & Live Metrics State
  double _distanceKm = 0.0;
  double _co2Emissions = 0.0;
  double _currentSpeedKmH = 0.0;

  Position? _startPosition;
  String _startAddress = "Unknown";
  String _endAddress = "Unknown";

  // Stopwatch & Animation State
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;
  late AnimationController _bounceController;

  // Supabase Database State
  bool _isLoadingFactors = true;
  String? _selectedVehicle;
  Map<String, VehicleData> _vehicleEmissionFactors = {};

  // Notifications State
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bounceController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _setupNotifications();
    _fetchEmissionFactors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopwatchTimer?.cancel();
    _bounceController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  // --- DATABASE HELPERS ---
  Future<void> _fetchEmissionFactors() async {
    try {
      final response = await Supabase.instance.client.from('emission_factors').select('factor_id, activity_name, co2_per_unit').eq('category', 'Transport');

      final Map<String, VehicleData> fetchedFactors = {};

      for (var item in response) {
        final name = item['activity_name'].toString();
        final id = item['factor_id'].toString();
        final factor = double.tryParse(item['co2_per_unit'].toString()) ?? 0.0;
        fetchedFactors[name] = VehicleData(id: id, factor: factor);
      }

      if (mounted) {
        setState(() {
          _vehicleEmissionFactors = fetchedFactors;
          if (_vehicleEmissionFactors.isNotEmpty) {
            _selectedVehicle = _vehicleEmissionFactors.keys.first;
          }
          _isLoadingFactors = false;
        });
      }
    } catch (e) {
      debugPrint('❌ DB Error: $e');
      if (mounted) {
        setState(() => _isLoadingFactors = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load live emission factors.')));
      }
    }
  }

  Future<void> _saveTripToDatabase() async {
    if (_selectedVehicle == null || _distanceKm <= 0) return;

    setState(() => _isSavingLog = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found.");

      final targetVehicleData = _vehicleEmissionFactors[_selectedVehicle!];
      if (targetVehicleData == null) throw Exception("Invalid vehicle factor tracking identity.");

      if (_startPosition != null && _lastPosition != null) {
        try {
          String buildAddress(Placemark p) {
            final parts = [p.street, p.subLocality, p.locality];
            final cleanParts = parts.where((e) => e != null && e.isNotEmpty && e != 'Unnamed Road').toList();
            return cleanParts.isNotEmpty ? cleanParts.join(', ') : 'Local Area';
          }

          List<Placemark> startMarks = await placemarkFromCoordinates(_startPosition!.latitude, _startPosition!.longitude);
          if (startMarks.isNotEmpty) _startAddress = buildAddress(startMarks.first);

          List<Placemark> endMarks = await placemarkFromCoordinates(_lastPosition!.latitude, _lastPosition!.longitude);
          if (endMarks.isNotEmpty) _endAddress = buildAddress(endMarks.first);
        } catch (e) {
          debugPrint('❌ Geocoding error: $e');
        }
      }

      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id': targetVehicleData.id,
        'input_value': double.parse(_distanceKm.toStringAsFixed(2)),
        'total_co2e': double.parse(_co2Emissions.toStringAsFixed(4)),
        'start_location': _startAddress,
        'end_location': _endAddress,
      });

      final completedMissions = await MissionEngine.evaluateTelemetry(userId: user.id, category: 'Commute', activityName: _selectedVehicle!);

      if (!mounted) return;
      setState(() => _isSavingLog = false);
      _showSuccessDialog(completedMissions);
    } catch (e) {
      debugPrint('❌ Insertion Error: $e');
      if (!mounted) return;
      setState(() => _isSavingLog = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record log to database: $e')));
    }
  }

  // --- NOTIFICATIONS & LIFECYCLE ---
  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isTracking && state == AppLifecycleState.paused) {
      _showBackgroundReminderNotification();
    }
  }

  Future<void> _showBackgroundReminderNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'carbonsense_tracking_channel',
      'Active Tracking Reminders',
      channelDescription: 'Reminds you when a trip is actively being recorded.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(0, 'Trip Tracking in Progress 📍', 'CarbonSense is calculating your ${_selectedVehicle ?? 'commute'} distance.', platformDetails);
  }

  // --- TIMER & TRACKING LOGIC ---
  void _startTimer() {
    _elapsedSeconds = 0;
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _stopwatchTimer?.cancel();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _resetTrip() {
    setState(() {
      _distanceKm = 0.0;
      _co2Emissions = 0.0;
      _elapsedSeconds = 0;
      _currentSpeedKmH = 0.0;
      _startPosition = null;
      _lastPosition = null;
      _startAddress = "Unknown";
      _endAddress = "Unknown";
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _stopTimer();
      _bounceController.stop();

      if (_positionStream != null) {
        await _positionStream!.cancel();
        _positionStream = null;
      }

      setState(() {
        _isTracking = false;
        _currentSpeedKmH = 0.0;
        if (_distanceKm < 0.01) {
          _resetTrip();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip ended. No distance recorded.")));
        }
      });
    } else {
      setState(() {
        _isGettingLocation = true;
        _distanceKm = 0.0;
        _co2Emissions = 0.0;
        _currentSpeedKmH = 0.0;
      });

      try {
        final initialPos = await LocationTracker.getCurrentLocation();

        if (initialPos != null) {
          setState(() {
            _lastPosition = initialPos;
            _startPosition = initialPos;
            _isTracking = true;
            _isGettingLocation = false;
          });

          _startTimer();
          _bounceController.repeat(reverse: true);

          _positionStream = LocationTracker.getContinuousLocationStream().listen((Position currentPosition) {
            if (currentPosition.accuracy > 25.0) return;

            if (_lastPosition != null) {
              final addedDistance = LocationTracker.calculateDistanceInKm(_lastPosition!, currentPosition);

              if (addedDistance > 0.2) {
                _lastPosition = currentPosition;
                return;
              }

              if (addedDistance < 0.005) return;

              if (mounted) {
                setState(() {
                  _distanceKm += addedDistance;

                  final targetData = _vehicleEmissionFactors[_selectedVehicle!];
                  final factor = targetData?.factor ?? 0.0;
                  _co2Emissions = _distanceKm * factor;

                  if (currentPosition.speed >= 0) {
                    _currentSpeedKmH = currentPosition.speed * 3.6;
                  }

                  _lastPosition = currentPosition;
                });
              }
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(
            'Ongoing Travel Tracking',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'You have an active tracking session in progress. Leaving this page will stop and discard your current trip. Are you sure you want to exit?',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit & Stop', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    return shouldExit ?? false;
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    final bool hasFinishedTrip = !_isTracking && _distanceKm > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final textColor = isDark ? Colors.white : Colors.black87;
    final stopwatchInactiveColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey;

    // 🌟 Primary dynamic accent: White in dark mode, Green in light mode
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    return PopScope(
      canPop: !_isTracking,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _showExitConfirmationDialog();

        if (shouldPop && context.mounted) {
          if (_isTracking) {
            _stopTimer();
            _bounceController.stop();
            _positionStream?.cancel();
            _positionStream = null;
          }

          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            GoRouter.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            'Commute Tracker',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 24, top: 16, right: 24, bottom: 120),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 136 > 0 ? constraints.maxHeight - 136 : 0),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // 1. Selector Widget
                        _buildVehicleSelector(),

                        const Spacer(),

                        // 2. Main Visual Metrics Hub
                        _buildAnimatedVehicleIcon(),
                        const SizedBox(height: 12),
                        Text(
                          _isTracking || hasFinishedTrip ? _formatDuration(_elapsedSeconds) : '00:00',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            color: _isTracking ? primaryAccentColor : stopwatchInactiveColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isTracking)
                          _buildGpsActiveBadge()
                        else if (hasFinishedTrip)
                          Text(
                            'Trip Completed',
                            style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w600),
                          )
                        else
                          Text(
                            'Ready to depart',
                            style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w600),
                          ),

                        const Spacer(),

                        // 3. LIVE METRICS DASHBOARD / TIPS / SUMMARY
                        if (_isTracking) _buildLiveMetricsDashboard() else if (!_isTracking && _distanceKm == 0) _buildTrackingTips() else if (hasFinishedTrip) _buildResultsCard(),

                        const Spacer(),

                        // 4. ACTION BUTTONS AT BOTTOM
                        if (!_isTracking && !hasFinishedTrip) _buildHeroButton() else if (_isTracking) _buildActiveTripControls(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLiveMetricsDashboard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryAccentColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLiveMetricItem(icon: Icons.route_rounded, value: _distanceKm.toStringAsFixed(2), unit: 'km', label: 'Distance', color: primaryAccentColor),
          Container(height: 36, width: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
          _buildLiveMetricItem(icon: Icons.speed_rounded, value: _currentSpeedKmH.toStringAsFixed(0), unit: 'km/h', label: 'Speed', color: Colors.blueAccent),
          Container(height: 36, width: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
          _buildLiveMetricItem(icon: Icons.co2_rounded, value: _co2Emissions.toStringAsFixed(2), unit: 'kg', label: 'Est. CO₂e', color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildLiveMetricItem({required IconData icon, required String value, required String unit, required String label, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTripControls() {
    return Column(
      children: [
        GestureDetector(
          onTap: _toggleTracking,
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  'END TRIP & REVIEW',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            _toggleTracking();
            _resetTrip();
          },
          child: const Text(
            "Cancel & Discard Trip",
            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsActiveBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🌟 White badge accents for dark mode, Green for light mode
    final badgeColor = isDark ? Colors.white : Colors.green;
    final badgeBg = isDark ? Colors.white.withOpacity(0.1) : Colors.green.shade50;
    final badgeBorder = isDark ? Colors.white.withOpacity(0.3) : Colors.green.shade200;
    final badgeText = isDark ? Colors.white : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'GPS Live Tracking',
            style: TextStyle(color: badgeText, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryAccentColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.satellite_alt_outlined, color: primaryAccentColor, size: 20),
              const SizedBox(width: 6),
              Text(
                "Tracking Best Practices",
                style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionRow(icon: Icons.play_circle_outline, color: primaryAccentColor, text: 'Tap START exactly when your vehicle begins moving.'),
          const SizedBox(height: 8),
          _buildInstructionRow(icon: Icons.screen_lock_portrait_outlined, color: Colors.blue, text: 'You can lock your screen while CarbonSense continues tracking your trip.'),
          const SizedBox(height: 8),
          _buildInstructionRow(icon: Icons.stop_circle_outlined, color: Colors.redAccent, text: 'Tap END TRIP immediately upon arrival for accurate carbon calculations.'),
        ],
      ),
    );
  }

  Widget _buildInstructionRow({required IconData icon, required Color color, required String text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedVehicleIcon() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        final double bounceOffset = -15 * _bounceController.value;
        return Transform.translate(
          offset: Offset(0, bounceOffset),
          child: Icon(_getIconForVehicle(_selectedVehicle ?? ''), size: 56, color: _isTracking || (_distanceKm > 0) ? primaryAccentColor : (isDark ? Colors.grey[700] : Colors.grey.shade300)),
        );
      },
    );
  }

  Widget _buildVehicleSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    // Trip completed and summary is showing
    final bool hasFinishedTrip = !_isTracking && _distanceKm > 0;

    // Lock selector during tracking, summary review, or active saving
    final bool isReadOnly = _isTracking || hasFinishedTrip || _isSavingLog;

    if (_isLoadingFactors) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
        ),
        child: const Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_vehicleEmissionFactors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              "No vehicle factors found in database.",
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header & Status Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TRANSPORT MODE",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            if (isReadOnly)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 12, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                    Text(
                      _isTracking
                          ? "LOCKED DURING TRIP"
                          : hasFinishedTrip
                          ? "LOCKED FOR REVIEW"
                          : "LOCKED",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orangeAccent, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Dropdown Box Container
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isReadOnly ? 0.65 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isReadOnly ? (isDark ? Colors.grey[900] : Colors.grey.shade100) : cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isReadOnly ? (isDark ? Colors.grey[800]! : Colors.grey.shade300) : primaryAccentColor.withOpacity(0.35), width: 1.5),
              boxShadow: isReadOnly ? [] : [BoxShadow(color: primaryAccentColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedVehicle,
                dropdownColor: cardBg,
                isExpanded: true,
                // Lock icon displayed when interactive mode is disabled
                icon: isReadOnly
                    ? Icon(Icons.lock_outline_rounded, color: isDark ? Colors.grey[500] : Colors.grey[400], size: 20)
                    : Icon(Icons.keyboard_arrow_down_rounded, color: primaryAccentColor, size: 24),
                // Strictly null when read-only to prevent opening the dropdown menu
                onChanged: isReadOnly
                    ? null
                    : (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedVehicle = newValue);
                        }
                      },
                items: _vehicleEmissionFactors.keys.map<DropdownMenuItem<String>>((String vehicleName) {
                  final vehicleData = _vehicleEmissionFactors[vehicleName];
                  final double factor = vehicleData?.factor ?? 0.0;

                  return DropdownMenuItem<String>(
                    value: vehicleName,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: primaryAccentColor.withOpacity(isDark ? 0.15 : 0.08), borderRadius: BorderRadius.circular(10)),
                          child: Icon(_getIconForVehicle(vehicleName), color: primaryAccentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicleName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Text(
                                '${factor.toStringAsFixed(3)} kg CO₂e / km',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroButton() {
    return GestureDetector(
      onTap: _isGettingLocation ? null : _toggleTracking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 140,
        width: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor,
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 30, spreadRadius: 10, offset: const Offset(0, 10))],
        ),
        child: Center(
          child: _isGettingLocation
              ? const CircularProgressIndicator(color: Colors.white)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    Text(
                      'START',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey;
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryAccentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            "TRIP SUMMARY",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: subtitleColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(Icons.route, _distanceKm.toStringAsFixed(2), 'Kilometers'),
              Container(width: 1, height: 40, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
              _buildStatMetric(Icons.co2, '+${_co2Emissions.toStringAsFixed(2)}', 'kg CO₂e', color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSavingLog ? null : _saveTripToDatabase,
              child: _isSavingLog
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Confirm & Log Route',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isSavingLog ? null : _resetTrip,
            icon: Icon(Icons.refresh, size: 16, color: subtitleColor),
            label: Text("Discard trip & reset", style: TextStyle(color: subtitleColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(IconData icon, String value, String label, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = color ?? (isDark ? Colors.white : Colors.black87);
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey;

    return Column(
      children: [
        Icon(icon, color: isDark ? Colors.grey[600] : Colors.grey.shade400, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: valueColor),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: subtitleColor)),
      ],
    );
  }

  void _showSuccessDialog(List<String> completedMissions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black54;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dialogBg,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20.0, offset: Offset(0.0, 10.0))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  "Awesome Journey!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  "You successfully tracked and logged your travel distance of ${_distanceKm.toStringAsFixed(2)} km.\n\nEvery trip you audit builds a clearer picture of your environmental legacy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      if (completedMissions.isNotEmpty) {
                        _showMissionUnlockedPopup(completedMissions);
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            if (Navigator.canPop(context)) {
                              Navigator.of(context).pop();
                            } else {
                              GoRouter.of(context).pop();
                            }
                          }
                        });
                      }
                    },
                    child: const Text(
                      'Back to Dashboard',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMissionUnlockedPopup(List<String> missions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: dialogBg,
          title: Column(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 56),
              const SizedBox(height: 12),
              Text(
                "Quest Completed!",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Your activity automatically unlocked:",
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...missions.map(
                (mission) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mission,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    } else {
                      GoRouter.of(context).pop();
                    }
                  }
                });
              },
              child: const Text(
                "Awesome",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconForVehicle(String vehicle) {
    final lower = vehicle.toLowerCase();
    if (lower.contains('walk') || lower.contains('bicycle')) return Icons.directions_walk;
    if (lower.contains('train') || lower.contains('mrt') || lower.contains('lrt')) return Icons.train;
    if (lower.contains('jeepney')) return Icons.directions_bus_filled_outlined;
    if (lower.contains('bus')) return Icons.directions_bus;
    if (lower.contains('motorcycle') || lower.contains('tricycle')) return Icons.two_wheeler;
    if (lower.contains('car')) return Icons.directions_car;
    return Icons.commute;
  }
}
