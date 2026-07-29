import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:carbonsense/features/utils/location_tracker.dart';
import 'package:go_router/go_router.dart';
import 'package:carbonsense/features/utils/mission_engine.dart';
import 'package:geocoding/geocoding.dart'; // 🌟 NEW IMPORT

// Helper class to store both the factor value and its UUID from the database
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

class _LogActivityScreenState extends State<LogActivityScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- STATE VARIABLES ---

  // Tracking State
  bool _isTracking = false;
  bool _isGettingLocation = false;
  bool _isSavingLog = false;
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;

  // Results State
  double _distanceKm = 0.0;
  double _co2Emissions = 0.0;

  // 🌟 NEW: Track the specific start and end points
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
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // --- LIFECYCLE ---

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

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

  // --- SUPABASE DATA RETRIEVAL ---

  Future<void> _fetchEmissionFactors() async {
    try {
      final response = await Supabase.instance.client
          .from('emission_factors')
          .select('factor_id, activity_name, co2_per_unit')
          .eq('category', 'Transport');

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load live emission factors.'),
          ),
        );
      }
    }
  }

  // --- SUPABASE DATA INSERTION ---

  Future<void> _saveTripToDatabase() async {
    if (_selectedVehicle == null || _distanceKm <= 0) return;

    setState(() => _isSavingLog = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found.");

      final targetVehicleData = _vehicleEmissionFactors[_selectedVehicle!];
      if (targetVehicleData == null)
        throw Exception("Invalid vehicle factor tracking identity.");

      debugPrint("===== SAVE TRIP =====");
      debugPrint("_startPosition = $_startPosition");
      debugPrint("_lastPosition = $_lastPosition");

      // 🌟 NEW: Reverse Geocode Point A and Point B with High Granularity
      if (_startPosition != null && _lastPosition != null) {
        try {
          // Helper function to build a precise, street-level address
          String buildAddress(Placemark p) {
            // Prioritize finer details: Street -> Barangay (subLocality) -> City (locality)
            final parts = [
              p.street, // e.g., "Aguinaldo Highway" or local street
              p.subLocality, // e.g., Barangay name (crucial for local Philippine tracking)
              p.locality, // e.g., "Imus"
            ];

            // Filter out nulls, empty values, or generic placeholders
            final cleanParts = parts
                .where((e) => e != null && e.isNotEmpty && e != 'Unnamed Road')
                .toList();

            // Fallback if everything is empty
            return cleanParts.isNotEmpty ? cleanParts.join(', ') : 'Local Area';
          }

          // Get Point A
          List<Placemark> startMarks = await placemarkFromCoordinates(
            _startPosition!.latitude,
            _startPosition!.longitude,
          );
          if (startMarks.isNotEmpty) {
            _startAddress = buildAddress(startMarks.first);
          }

          // Get Point B
          List<Placemark> endMarks = await placemarkFromCoordinates(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
          );
          if (endMarks.isNotEmpty) {
            _endAddress = buildAddress(endMarks.first);
          }

          debugPrint('📍 Precise Route: $_startAddress TO $_endAddress');
        } catch (e) {
          debugPrint('❌ Geocoding error: $e');
        }
      }

      debugPrint("Saving:");
      debugPrint("Start=$_startAddress");
      debugPrint("End=$_endAddress");

      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id': targetVehicleData.id,
        'input_value': double.parse(_distanceKm.toStringAsFixed(2)),
        'total_co2e': double.parse(_co2Emissions.toStringAsFixed(4)),
        'start_location': _startAddress, // Point A
        'end_location': _endAddress, // Point B
      });

      // 🚀 Run the Mission Engine silently
      final completedMissions = await MissionEngine.evaluateTelemetry(
        userId: user.id,
        category: 'Commute',
        activityName: _selectedVehicle!,
      );

      if (mounted) {
        setState(() => _isSavingLog = false);
        // Pass the results to the dialog!
        _showSuccessDialog(completedMissions);
      }
    } catch (e) {
      debugPrint('❌ Insertion Error: $e');
      if (mounted) {
        setState(() => _isSavingLog = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record log to database: $e')),
        );
      }
    }
  }

  // --- CUSTOM SUCCESS DIALOG ---

  void _showSuccessDialog(List<String> completedMissions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppTheme.primaryColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Awesome Journey!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You successfully tracked and logged your travel distance of ${_distanceKm.toStringAsFixed(2)} km.\n\nEvery trip you audit builds a clearer picture of your environmental legacy. Keep up the clean commuting habits!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // Close the current "Awesome Journey" dialog
                      Navigator.of(context, rootNavigator: true).pop();

                      // 🚀 CHECK: Did they complete missions?
                      if (completedMissions.isNotEmpty) {
                        _showMissionUnlockedPopup(completedMissions);
                      } else {
                        // Original routing back to dashboard
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Column(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 56),
              SizedBox(height: 12),
              Text(
                "Quest Completed!",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Your activity automatically unlocked:",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...missions.map(
                (mission) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mission,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(); // Close Quest dialog
                // Navigate back to dashboard safely
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- NOTIFICATIONS ENGINE ---

  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
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
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'carbonsense_tracking_channel',
          'Active Tracking Reminders',
          channelDescription:
              'Reminds you when a trip is actively being recorded.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      0,
      'Trip Tracking in Progress 📍',
      'CarbonSense is calculating your ${_selectedVehicle ?? 'commute'} distance.',
      platformDetails,
    );
  }

  // --- TIMER & MATH LOGIC ---

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

  // 🌟 NEW: Cleanly reset the trip state if discarded
  void _resetTrip() {
    setState(() {
      _distanceKm = 0.0;
      _co2Emissions = 0.0;
      _elapsedSeconds = 0;

      _startPosition = null;
      _lastPosition = null;

      _startAddress = "Unknown";
      _endAddress = "Unknown";
    });
  }

  // --- TRACKING ENGINE ---

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      // 🛑 END THE TRIP
      _stopTimer();
      _bounceController.stop();

      if (_positionStream != null) {
        await _positionStream!.cancel();
        _positionStream = null;
      }

      setState(() {
        _isTracking = false;

        // Safety catch: If they didn't move at all, just reset.
        if (_distanceKm < 0.01) {
          _resetTrip();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Trip ended. No distance was recorded."),
            ),
          );
        }
      });
    } else {
      // 🟢 START THE TRIP
      setState(() {
        _isGettingLocation = true;
        _distanceKm = 0.0;
        _co2Emissions = 0.0;
      });

      try {
        final initialPos = await LocationTracker.getCurrentLocation();

        if (initialPos != null) {
          setState(() {
            _lastPosition = initialPos;
            _startPosition = initialPos; // 🌟 NEW: Save Point A
            _isTracking = true;
            _isGettingLocation = false;
          });

          _startTimer();
          _bounceController.repeat(reverse: true);

          _positionStream = LocationTracker.getContinuousLocationStream()
              .listen((Position currentPosition) {
                if (currentPosition.accuracy > 25.0) {
                  debugPrint('⚠️ Ignored: Bad GPS Signal');
                  return;
                }

                if (_lastPosition != null) {
                  final addedDistance = LocationTracker.calculateDistanceInKm(
                    _lastPosition!,
                    currentPosition,
                  );

                  if (addedDistance > 0.2) {
                    debugPrint('⚠️ Ignored: Speed teleportation detected');
                    _lastPosition = currentPosition;
                    return;
                  }

                  if (addedDistance < 0.01) return;

                  if (mounted) {
                    setState(() {
                      _distanceKm += addedDistance;

                      final targetData =
                          _vehicleEmissionFactors[_selectedVehicle!];
                      final factor = targetData?.factor ?? 0.0;

                      _co2Emissions = _distanceKm * factor;
                      _lastPosition = currentPosition;
                    });
                  }
                }
              });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGettingLocation = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    // 🌟 State check to clean up the UI
    final bool hasFinishedTrip = !_isTracking && _distanceKm > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Commute Tracker',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildVehicleSelector(),

                      const Spacer(),

                      _buildAnimatedVehicleIcon(),
                      const SizedBox(height: 12),

                      Text(
                        _isTracking || hasFinishedTrip
                            ? _formatDuration(_elapsedSeconds)
                            : '00:00',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: _isTracking
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_isTracking)
                        _buildGpsActiveBadge()
                      else if (hasFinishedTrip)
                        const Text(
                          'Trip Completed',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const Text(
                          'Ready to depart',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                      const Spacer(),

                      if (!_isTracking && _distanceKm == 0) ...[
                        _buildTrackingTips(),
                        const SizedBox(height: 24),
                      ],

                      if (hasFinishedTrip)
                        _buildResultsCard()
                      else
                        _buildHeroButton(),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 🌟 NEW: GPS Active Live Badge
  Widget _buildGpsActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'GPS Active',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 Compact Tracking Instructions
  Widget _buildTrackingTips() {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18), // Slightly smaller
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
            blurRadius: 8, // Reduced
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.satellite_alt_outlined,
                color: AppTheme.primaryColor,
                size: 20, // Reduced from 22
              ),
              SizedBox(width: 6),
              Text(
                "Tracking Best Practices",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontSize: 15, // Reduced from 16
                ),
              ),
            ],
          ),

          const SizedBox(height: 12), // Reduced from 16

          _buildInstructionRow(
            icon: Icons.play_circle_outline,
            color: AppTheme.primaryColor,
            text: 'Tap START exactly when your vehicle begins moving.',
          ),

          const SizedBox(height: 8), // Reduced from 10

          _buildInstructionRow(
            icon: Icons.screen_lock_portrait_outlined,
            color: Colors.blue,
            text:
                'You can lock your screen while CarbonSense continues tracking your trip.',
          ),

          const SizedBox(height: 8),

          _buildInstructionRow(
            icon: Icons.stop_circle_outlined,
            color: Colors.redAccent,
            text:
                'Tap END TRIP immediately upon arrival for accurate carbon calculations.',
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGET FOR INSTRUCTION ROWS ---
  Widget _buildInstructionRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedVehicleIcon() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        final double bounceOffset = -15 * _bounceController.value;
        return Transform.translate(
          offset: Offset(0, bounceOffset),
          child: Icon(
            _getIconForVehicle(_selectedVehicle ?? ''),
            size: 56,
            color: _isTracking || (_distanceKm > 0)
                ? AppTheme.primaryColor
                : Colors.grey.shade300,
          ),
        );
      },
    );
  }

  Widget _buildVehicleSelector() {
    if (_isLoadingFactors) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_vehicleEmissionFactors.isEmpty) {
      return const Text(
        "No vehicles found in database.",
        style: TextStyle(color: Colors.red),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Transport Mode",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicle,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppTheme.primaryColor,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              onChanged: _isTracking
                  ? null
                  : (String? newValue) {
                      if (newValue != null)
                        setState(() => _selectedVehicle = newValue);
                    },
              items: _vehicleEmissionFactors.keys.map<DropdownMenuItem<String>>(
                (String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(
                          _getIconForVehicle(value),
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
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
        height: 140, // Reduced from 180
        width: 140, // Reduced from 180
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isTracking ? Colors.redAccent : AppTheme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: (_isTracking ? Colors.redAccent : AppTheme.primaryColor)
                  .withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isGettingLocation
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isTracking
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48, // Reduced from 64 to fit the new button size
                    ),
                    Text(
                      _isTracking ? 'END TRIP' : 'START',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Reduced from 18
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            "TRIP SUMMARY",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(
                Icons.route,
                _distanceKm.toStringAsFixed(2),
                'Kilometers',
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _buildStatMetric(
                Icons.co2,
                '+${_co2Emissions.toStringAsFixed(2)}',
                'kg CO₂e',
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSavingLog ? null : _saveTripToDatabase,
              child: _isSavingLog
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Confirm & Log Route',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // 🌟 UPGRADED: The Discard/Reset button (Mirrors the Retake button on scanners)
          TextButton.icon(
            onPressed: _isSavingLog ? null : _resetTrip,
            icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
            label: const Text(
              "Discard trip & reset",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(
    IconData icon,
    String value,
    String label, {
    Color color = Colors.black87,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  IconData _getIconForVehicle(String vehicle) {
    final lower = vehicle.toLowerCase();
    if (lower.contains('walk') || lower.contains('bicycle'))
      return Icons.directions_walk;
    if (lower.contains('train') ||
        lower.contains('mrt') ||
        lower.contains('lrt'))
      return Icons.train;
    if (lower.contains('jeepney')) return Icons.directions_bus_filled_outlined;
    if (lower.contains('bus')) return Icons.directions_bus;
    if (lower.contains('motorcycle') || lower.contains('tricycle'))
      return Icons.two_wheeler;
    if (lower.contains('car')) return Icons.directions_car;
    return Icons.commute;
  }
}
