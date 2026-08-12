import 'dart:convert';
import 'dart:typed_data';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  // Web-Safe Variables for the new image
  Uint8List? _avatarBytes;
  String? _avatarExtension;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDetectingGps = false;

  // Lockout State Variables
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

      final profileData = await Supabase.instance.client.from('user_profiles').select().eq('user_id', userId).maybeSingle();

      if (mounted) {
        setState(() {
          _nameController.text = profileData?['display_name'] ?? '';
          _locationController.text = profileData?['location'] ?? '';
          _targetController.text = profileData?['monthly_co2_target']?.toString() ?? '';
          _currentAvatarUrl = profileData?['avatar_url'];

          // Check 30-day lockout status
          if (profileData?['target_updated_at'] != null) {
            final lastUpdate = DateTime.parse(profileData!['target_updated_at']);
            final daysPassed = DateTime.now().toUtc().difference(lastUpdate).inDays;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // --- GPS LOCATION HANDLER ---
  Future<void> _detectLocationViaGps() async {
    setState(() => _isDetectingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Reverse geocoding using OpenStreetMap Nominatim API
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10');

      final response = await http.get(url, headers: {'User-Agent': 'CarbonSenseApp'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['address'] != null) {
          final address = data['address'];
          final city = address['city'] ?? address['municipality'] ?? address['town'] ?? address['village'] ?? '';
          final province = address['state'] ?? address['region'] ?? '';

          setState(() {
            _locationController.text = (city.isNotEmpty && province.isNotEmpty) ? '$city, $province' : (data['display_name'] ?? 'Unknown Location');
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location successfully detected via GPS!'), backgroundColor: AppTheme.primaryColor));
          }
        } else {
          throw 'Unable to parse address from coordinates.';
        }
      } else {
        throw 'Failed to connect to geocoding service.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  void _showUnlockConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('Manual Override', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: Text(
          'Manually updating your monthly goal will reset your 30-day adaptive cycle timer. The system will start evaluating your progress from today.\n\nAre you sure you want to proceed?',
          style: TextStyle(height: 1.4, color: isDark ? Colors.grey[300] : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _isTargetLocked = false;
              });
            },
            child: const Text('Unlock Goal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarExtension = image.name.contains('.') ? image.name.split('.').last : 'jpg';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? finalAvatarUrl = _currentAvatarUrl;

      if (_avatarBytes != null) {
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$_avatarExtension';

        await Supabase.instance.client.storage.from('avatars').uploadBinary(fileName, _avatarBytes!, fileOptions: const FileOptions(upsert: true));

        finalAvatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      }

      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'display_name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
            'monthly_co2_target': double.tryParse(_targetController.text.trim()) ?? 150.0,
            'target_updated_at': DateTime.now().toUtc().toIso8601String(),
            'avatar_url': finalAvatarUrl,
          })
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppTheme.primaryColor));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
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
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: isDark ? Colors.grey[800] : AppTheme.primaryColor.withOpacity(0.1),
                                backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) as ImageProvider : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) : null),
                                child: (_avatarBytes == null && _currentAvatarUrl == null) ? Icon(Icons.person, size: 50, color: isDark ? Colors.white : AppTheme.primaryColor) : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      "Identity",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
                    ),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      children: [
                        _buildModernTextField(
                          controller: _nameController,
                          label: 'Display Name',
                          icon: Icons.person_outline,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')), FilteringTextInputFormatter.deny(RegExp(r'  '))],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            if (!RegExp(r'^[a-zA-Z]+( [a-zA-Z]+)*$').hasMatch(value)) {
                              return 'Only letters and single spaces allowed';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Location Section Header & GPS Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 18, color: isDark ? Colors.white : AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Location',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                              ),
                              onPressed: _isDetectingGps ? null : _detectLocationViaGps,
                              icon: _isDetectingGps
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.my_location, size: 16, color: Colors.white),
                              label: Text(
                                _isDetectingGps ? 'Detecting...' : 'Detect via GPS',
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Read-Only Location Field
                        _buildModernTextField(
                          controller: _locationController,
                          label: 'Current Location',
                          hint: 'Click "Detect via GPS" above...',
                          icon: Icons.map_outlined,
                          readOnly: true, // Prevents typing custom strings
                          fillColor: isDark ? Colors.teal.withOpacity(0.12) : const Color(0xFFE6FFFA), // Soft teal indicator
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Location verification is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Text(
                      "Monthly Carbon Goals",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
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
                                icon: const Icon(Icons.lock_outline, color: Colors.orange),
                                onPressed: _showUnlockConfirmationDialog,
                              ),
                            ],
                          ],
                        ),
                        if (_isTargetLocked) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Goal locked for $_daysRemaining more days (Auto-adjusts monthly). Tap lock to override.',
                                    style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: isDark ? Colors.white : AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Set a monthly carbon emission goal that you would like to achieve. CarbonSense tracks your total emissions throughout the month and compares them with this goal, helping you monitor your progress and build more sustainable habits over time. You can update this goal whenever your lifestyle or sustainability goals change.',
                                  style: TextStyle(fontSize: 13, height: 1.6, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[300] : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          elevation: 4,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text(
                                'Save Changes',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.grey[800]! : AppTheme.primaryColor.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    bool enabled = true,
    bool readOnly = false,
    String? hint,
    Color? fillColor,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: validator,
      inputFormatters: inputFormatters,
      style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? textColor : (isDark ? Colors.grey[600] : Colors.grey)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey.shade400),
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: isDark ? Colors.white : AppTheme.primaryColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor ?? (isDark ? Colors.grey[900] : Colors.grey.shade50),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }
}
