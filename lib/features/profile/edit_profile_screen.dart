import 'dart:typed_data'; // 👈 We use this instead of dart:io for Web!
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String? _energySource;
  String? _currentAvatarUrl; 
  
  // 👇 Web-Safe Variables for the new image
  Uint8List? _avatarBytes;
  String? _avatarExtension;

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _energyOptions = ['Standard Grid', '100% Renewable (Solar)', 'Mixed (Grid + Solar)'];

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

      final lifestyleData = await Supabase.instance.client
          .from('lifestyle_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _nameController.text = profileData?['display_name'] ?? '';
          _locationController.text = profileData?['location'] ?? '';
          _targetController.text = profileData?['monthly_co2_target']?.toString() ?? '';
          _currentAvatarUrl = profileData?['avatar_url']; 
          
          if (_energyOptions.contains(lifestyleData?['home_energy_source'])) {
            _energySource = lifestyleData?['home_energy_source'];
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

  // 👇 Web-Safe Image Picker
  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    
    if (image != null) {
      // Read the image as raw bytes so it works on Web and Mobile
      final bytes = await image.readAsBytes();
      
      setState(() {
        _avatarBytes = bytes;
        // Try to get the extension, default to jpg
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

      // 👇 Web-Safe Supabase Upload using uploadBinary
      if (_avatarBytes != null) {
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$_avatarExtension';
        
        await Supabase.instance.client.storage.from('avatars').uploadBinary(
          fileName, 
          _avatarBytes!,
          fileOptions: const FileOptions(upsert: true),
        );
        
        finalAvatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('user_profiles').update({
        'display_name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'monthly_co2_target': double.tryParse(_targetController.text.trim()) ?? 150.0,
        'avatar_url': finalAvatarUrl, 
      }).eq('user_id', userId);

      try {
        await Supabase.instance.client.from('lifestyle_profiles')
            .update({'home_energy_source': _energySource})
            .eq('user_id', userId);
      } catch (_) {
        await Supabase.instance.client.from('lifestyle_profiles')
            .insert({'user_id': userId, 'home_energy_source': _energySource});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppTheme.primaryColor),
        );
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

  void _showOptionsOverlay(String title, List<String> options, String? currentValue, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: options.map((option) {
                    final isSelected = option == currentValue;
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(bottomSheetContext); 
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade50,
                          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2)),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                // 👇 Uses MemoryImage instead of FileImage for Web Support
                                backgroundImage: _avatarBytes != null 
                                  ? MemoryImage(_avatarBytes!) as ImageProvider
                                  : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) : null),
                                child: (_avatarBytes == null && _currentAvatarUrl == null) 
                                  ? const Icon(Icons.person, size: 50, color: AppTheme.primaryColor) 
                                  : null,
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

                    const Text("Identity", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      children: [
                        _buildModernTextField(controller: _nameController, label: 'Display Name', icon: Icons.person_outline, validator: (value) => value!.isEmpty ? 'Name is required' : null),
                        const SizedBox(height: 16),
                        _buildModernTextField(controller: _locationController, label: 'Location', icon: Icons.location_on_outlined),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const Text("Carbon Goals", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      children: [
                        _buildModernTextField(controller: _targetController, label: 'Monthly Target (kg CO₂e)', icon: Icons.eco_outlined, isNumber: true),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    const Text("Lifestyle Configuration", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      children: [
                        _buildCustomSelector(label: 'Home Energy Source', value: _energySource, options: _energyOptions, onSelected: (val) => setState(() => _energySource = val)),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 20),
                              SizedBox(width: 12),
                              Expanded(child: Text('Diet and Commute badges are locked. They are updated dynamically by the CarbonSense AI based on your activity logs.', style: TextStyle(color: Colors.black87, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    
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
                            : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildModernTextField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
      ),
    );
  }

  Widget _buildCustomSelector({required String label, required String? value, required List<String> options, required Function(String) onSelected}) {
    return InkWell(
      onTap: () => _showOptionsOverlay(label, options, value, onSelected),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.electrical_services_outlined, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value ?? 'Tap to select...', style: TextStyle(color: value == null ? Colors.grey.shade400 : Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}