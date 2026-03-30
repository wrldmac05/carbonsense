import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for text fields
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  final _targetController = TextEditingController();

  // Selector states (Only Energy remains!)
  String? _energySource;

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _energyOptions = [
    'Standard Grid', '100% Renewable (Solar)', 'Mixed (Grid + Solar)'
  ];

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
          _bioController.text = profileData?['bio'] ?? '';
          _targetController.text = profileData?['monthly_co2_target']?.toString() ?? '';
          
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 1. Update user_profiles table
      await Supabase.instance.client.from('user_profiles').update({
        'display_name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'monthly_co2_target': double.tryParse(_targetController.text.trim()) ?? 150.0,
      }).eq('user_id', userId);

      // 2. Safely update lifestyle_profiles (Energy Only)
      // We use a try-catch here just in case the AI trigger hasn't created their row yet!
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
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text(
                'Select $title',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: options.map((option) {
                  final isSelected = option == currentValue;
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(bottomSheetContext); 
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomSelector({required String label, required String? value, required List<String> options, required Function(String) onSelected}) {
    return InkWell(
      onTap: () => _showOptionsOverlay(label, options, value, onSelected),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
        ),
        child: Text(
          value ?? 'Tap to select...',
          style: TextStyle(
            color: value == null ? Colors.grey.shade600 : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4, 
                      decoration: const InputDecoration(
                        labelText: 'Bio', 
                        alignLabelWithHint: true,
                        hintText: 'Share your eco-journey...',
                        border: OutlineInputBorder()
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monthly CO2 Target (kg)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 32),
                    
                    const Text('Lifestyle Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Diet and Commute badges are now awarded automatically by the Smart AI based on your logged activities!',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildCustomSelector(
                      label: 'Home Energy Source',
                      value: _energySource,
                      options: _energyOptions,
                      onSelected: (val) => setState(() => _energySource = val),
                    ),
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}