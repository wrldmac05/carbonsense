import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:carbonsense/theme/app_theme.dart'; 
import 'package:carbonsense/features/utils/location_tracker.dart';
import 'package:go_router/go_router.dart';

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

class _LogActivityScreenState extends State<LogActivityScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- STATE VARIABLES ---
  
  // Tracking State
  bool _isTracking = false;
  bool _isGettingLocation = false;
  bool _isSavingLog = false; // 🌟 NEW: Track database insertion state
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;
  
  // Results State
  double _distanceKm = 0.0;
  double _co2Emissions = 0.0;
  
  // Stopwatch & Animation State
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;
  late AnimationController _bounceController;

  // Supabase Database State
  bool _isLoadingFactors = true;
  String? _selectedVehicle;
  
  // 🌟 UPGRADED: Maps vehicle names to a data object containing the database UUID and the factor
  Map<String, VehicleData> _vehicleEmissionFactors = {};

  // Notifications State
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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
      // 🌟 Pull the factor_id UUID alongside name and factor values
      final response = await Supabase.instance.client
          .from('emission_factors')
          .select('factor_id, activity_name, co2_per_unit')
          .eq('category', 'Transport');

      final Map<String, VehicleData> fetchedFactors = {};
      
      for (var item in response) {
         final name = item['activity_name'].toString();
         final id = item['factor_id'].toString();
         final factor = double.tryParse(item['co2_per_unit'].toString()) ?? 0.0;
         
         // Store both values under the name key
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
          const SnackBar(content: Text('Failed to load live emission factors.')),
        );
      }
    }
  }

  // --- SUPABASE DATA INSERTION ---

  Future<void> _saveTripToDatabase() async {
    if (_selectedVehicle == null || _distanceKm <= 0) return;

    setState(() => _isSavingLog = true);

    try {
      // 1. Get the current user session ID
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found.");

      // 2. Retrieve the target factor data object
      final targetVehicleData = _vehicleEmissionFactors[_selectedVehicle!];
      if (targetVehicleData == null) throw Exception("Invalid vehicle factor tracking identity.");

      // 3. Insert the log directly matching your public.activity_logs schema
      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id': targetVehicleData.id,
        'input_value': double.parse(_distanceKm.toStringAsFixed(2)),
        'total_co2e': double.parse(_co2Emissions.toStringAsFixed(4)),
      });

      if (mounted) {
        setState(() {
          _isSavingLog = false;
        });
        
        // 🌟 4. Trigger our encouraging celebratory dialog!
        _showSuccessDialog();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to engage with the button to close it
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 20.0, offset: Offset(0.0, 10.0)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Wrap content tightly
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Awesome Journey!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  "You successfully tracked and logged your travel distance of ${_distanceKm.toStringAsFixed(2)} km.\n\nEvery trip you audit builds a clearer picture of your environmental legacy. Keep up the clean commuting habits!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  // 🌟 REMOVED height: 48 here
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16), // 🌟 ADDED natural padding instead
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
  // 1. Safely close the dialog using the root navigator
  Navigator.of(context, rootNavigator: true).pop();

  // 2. Wait for the dialog animation to finish
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      if (Navigator.canPop(context)) {
        // 🌟 GOLD STANDARD: If we got here normally, this will step back cleanly 
        // inside the shell, preserving your bottom navigation bar perfectly!
        Navigator.of(context).pop(); 
      } else {
        // 🌟 SAFETY FALLBACK: If history was cleared (e.g. Hot Restart), 
        // use pop instead of go to prevent snapping out of the shell layout structure.
        GoRouter.of(context).pop();
      }
    }
  });
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

  // --- NOTIFICATIONS ENGINE ---

  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
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
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

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
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
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
        _lastPosition = null; 
      });

    } else {
      // 🟢 START THE TRIP
      setState(() {
        _isGettingLocation = true;
        _distanceKm = 0.0; 
        _co2Emissions = 0.0;
        _lastPosition = null;
      });

      try {
        final initialPos = await LocationTracker.getCurrentLocation();
        
        if (initialPos != null) {
          setState(() {
            _lastPosition = initialPos;
            _isTracking = true;
            _isGettingLocation = false;
          });
          
          _startTimer();
          _bounceController.repeat(reverse: true);

          _positionStream = LocationTracker.getContinuousLocationStream().listen(
            (Position currentPosition) {
              
              if (currentPosition.accuracy > 25.0) {
                debugPrint('⚠️ Ignored: Bad GPS Signal');
                return; 
              }

              if (_lastPosition != null) {
                final addedDistance = LocationTracker.calculateDistanceInKm(_lastPosition!, currentPosition);
                
                if (addedDistance > 0.2) {
                  debugPrint('⚠️ Ignored: Speed teleportation detected');
                  _lastPosition = currentPosition; 
                  return;
                }

                if (addedDistance < 0.01) {
                  return;
                }
                
                if (mounted) {
                  setState(() {
                    _distanceKm += addedDistance; 
                    
                    // Retrieve structural data mapping safely
                    final targetData = _vehicleEmissionFactors[_selectedVehicle!];
                    final factor = targetData?.factor ?? 0.0;
                    
                    _co2Emissions = _distanceKm * factor;
                    _lastPosition = currentPosition; 
                  });
                }
              }
            },
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildVehicleSelector(),
              
              const Spacer(),

              _buildAnimatedVehicleIcon(),
              const SizedBox(height: 12),

              Text(
                _isTracking ? _formatDuration(_elapsedSeconds) : '00:00',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: _isTracking ? AppTheme.primaryColor : Colors.grey.shade300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isTracking ? 'Tracking active...' : 'Ready to depart',
                style: TextStyle(
                  fontSize: 16,
                  color: _isTracking ? AppTheme.primaryColor : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),
              _buildHeroButton(),
              const Spacer(),
              if (!_isTracking && _distanceKm > 0) _buildResultsCard(),
            ],
          ),
        ),
      ),
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
            color: _isTracking ? AppTheme.primaryColor : Colors.grey.shade300,
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
        child: const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_vehicleEmissionFactors.isEmpty) {
       return const Text("No vehicles found in database.", style: TextStyle(color: Colors.red));
    }

    return Container(
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
          )
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVehicle,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryColor),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          onChanged: _isTracking ? null : (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedVehicle = newValue);
            }
          },
          items: _vehicleEmissionFactors.keys.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Icon(_getIconForVehicle(value), color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeroButton() {
    return GestureDetector(
      onTap: _isGettingLocation ? null : _toggleTracking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 180,
        width: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isTracking ? Colors.redAccent : AppTheme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: (_isTracking ? Colors.redAccent : AppTheme.primaryColor).withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 10,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Center(
          child: _isGettingLocation
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                    Text(
                      _isTracking ? 'END TRIP' : 'START',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
          const Text("TRIP SUMMARY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(Icons.route, _distanceKm.toStringAsFixed(2), 'Kilometers'),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _buildStatMetric(Icons.co2, '+${_co2Emissions.toStringAsFixed(2)}', 'kg CO₂e', color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            // 🌟 REMOVED height: 48 here
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16), // 🌟 ADDED natural padding instead
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSavingLog ? null : _saveTripToDatabase,
              child: _isSavingLog 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatMetric(IconData icon, String value, String label, {Color color = Colors.black87}) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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