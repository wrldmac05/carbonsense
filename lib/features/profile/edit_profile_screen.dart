import 'dart:typed_data'; // 👈 We use this instead of dart:io for Web!
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 NEW: For input formatters
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart'; // 👈 NEW: For GPS
import 'package:geocoding/geocoding.dart'; // 👈 NEW: For Reverse Geocoding

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _targetController = TextEditingController();

  String? _currentAvatarUrl;

  // 👇 Web-Safe Variables for the new image
  Uint8List? _avatarBytes;
  String? _avatarExtension;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFetchingLocation = false; // 👈 NEW: Tracks GPS loading state

  // 🚀 NEW: Lockout State Variables
  bool _isTargetLocked = true;
  int _daysRemaining = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final profileData = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _nameController.text = profileData?['display_name'] ?? '';
          _locationController.text = profileData?['location'] ?? '';
          _targetController.text =
              profileData?['monthly_co2_target']?.toString() ?? '';
          _currentAvatarUrl = profileData?['avatar_url'];

          // 🚀 CHECK 30-DAY LOCKOUT STATUS
          if (profileData?['target_updated_at'] != null) {
            final lastUpdate = DateTime.parse(
              profileData!['target_updated_at'],
            );
            final daysPassed = DateTime.now()
                .toUtc()
                .difference(lastUpdate)
                .inDays;

            if (daysPassed < 30) {
              _isTargetLocked = true;
              _daysRemaining = 30 - daysPassed;
            } else {
              _isTargetLocked = false;
            }
          } else {
            _isTargetLocked = false;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // 🚀 OVERRIDE CONFIRMATION DIALOG
  void _showUnlockConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Manual Override'),
          ],
        ),
        content: const Text(
          'Manually updating your monthly goal will reset your 30-day adaptive cycle timer. The system will start evaluating your progress from today.\n\nAre you sure you want to proceed?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _isTargetLocked = false; // 🔓 UNLOCK THE FIELD
              });
            },
            child: const Text(
              'Unlock Goal',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 Web-Safe Image Picker
  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();

      setState(() {
        _avatarBytes = bytes;
        _avatarExtension = image.name.contains('.')
            ? image.name.split('.').last
            : 'jpg';
      });
    }
  }

  Future<void> _getUserLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      // 1. Check if the physical GPS is turned on
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please turn on your GPS location services.'),
            ),
          );
        }
        return;
      }

      // 2. Check current app permissions
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. If denied, trigger the OS permission pop-up
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission was denied.')),
            );
          }
          return;
        }
      }

      // 4. If permanently denied, prompt them to open settings
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Location permissions are permanently denied. Please open your phone settings to grant permission.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openAppSettings(); // 👈 Takes them straight to settings
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 5. Fetch the location (with timeout fallback for emulators)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint("Timeout getting current position, using last known: $e");
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not fetch location. Please try again.'),
            ),
          );
        }
        return;
      }

      // 6. Convert coordinates to a readable address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        String city = place.locality?.isNotEmpty == true
            ? place.locality!
            : (place.subAdministrativeArea ?? 'Unknown City');

        setState(() {
          _locationController.text = '$city, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? finalAvatarUrl = _currentAvatarUrl;

      if (_avatarBytes != null) {
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}.$_avatarExtension';

        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              _avatarBytes!,
              fileOptions: const FileOptions(upsert: true),
            );

        finalAvatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'display_name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
            'monthly_co2_target':
                double.tryParse(_targetController.text.trim()) ?? 150.0,
            'target_updated_at': DateTime.now().toUtc().toIso8601String(),
            'avatar_url': finalAvatarUrl,
          })
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppTheme.primaryColor
                                    .withOpacity(0.1),
                                backgroundImage: _avatarBytes != null
                                    ? MemoryImage(_avatarBytes!)
                                          as ImageProvider
                                    : (_currentAvatarUrl != null
                                          ? NetworkImage(_currentAvatarUrl!)
                                          : null),
                                child:
                                    (_avatarBytes == null &&
                                        _currentAvatarUrl == null)
                                    ? const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: AppTheme.primaryColor,
                                      )
                                    : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      "Identity",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      children: [
                        _buildModernTextField(
                          controller: _nameController,
                          label: 'Display Name',
                          icon: Icons.person_outline,
                          // 👈 NEW: Formatters enforce rules during typing
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z ]'),
                            ),
                            FilteringTextInputFormatter.deny(RegExp(r'  ')),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            // 👈 NEW: Final regex check for valid format
                            if (!RegExp(
                              r'^[a-zA-Z]+( [a-zA-Z]+)*$',
                            ).hasMatch(value)) {
                              return 'Only letters and single spaces allowed';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _locationController,
                          label: 'Location',
                          icon: Icons.location_on_outlined,
                          // 👈 NEW: GPS Button added to the suffix
                          suffixIcon: _isFetchingLocation
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.my_location),
                                  color: AppTheme.primaryColor,
                                  onPressed: _getUserLocation,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      "Monthly Carbon Goals",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildModernTextField(
                                controller: _targetController,
                                label: 'Monthly Carbon Goal (kg CO₂e)',
                                hint: 'e.g. 400 kg CO₂e',
                                icon: Icons.eco_outlined,
                                isNumber: true,
                                enabled: !_isTargetLocked,
                              ),
                            ),
                            if (_isTargetLocked) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Override & Edit Goal',
                                icon: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.orange,
                                ),
                                onPressed: _showUnlockConfirmationDialog,
                              ),
                            ],
                          ],
                        ),
                        if (_isTargetLocked) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Goal locked for $_daysRemaining more days (Auto-adjusts monthly). Tap lock to override.',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Set a monthly carbon emission goal that you would like to achieve. CarbonSense tracks your total emissions throughout the month and compares them with this goal, helping you monitor your progress and build more sustainable habits over time. You can update this goal whenever your lifestyle or sustainability goals change.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          elevation: 4,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // 👈 NEW: Added inputFormatters and suffixIcon parameters here
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    bool enabled = true,
    String? hint,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: validator,
      inputFormatters: inputFormatters, // 👈 Hooked up here
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        suffixIcon: suffixIcon, // 👈 Hooked up here
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }
}
