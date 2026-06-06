import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';

class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key});

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  // Result variables from Gemini AI
  String? _foodName;
  double? _weightG;
  double? _co2e;

  String? _factorId; // 🌟 ADD THIS

  // --- CAPTURE IMAGE FUNCTION ---
  Future<void> _getImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80, // Compress slightly to optimize network upload speeds
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        // Clear previous results when a new photo is taken
        _foodName = null;
        _weightG = null;
        _co2e = null;
      });

      // Trigger the AI processing directly
      _analyzeImageWithGemini();
    }
  }

  // --- SUPABASE EDGE FUNCTION BRIDGE ---
  Future<void> _analyzeImageWithGemini() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // 1. Read image bytes and convert to base64 string
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Invoke secure Supabase Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'analyze-food-image',
        body: {'image': base64Image},
      );

      // 3. Parse the clean JSON structural response
      if (response.status == 200) {
        // 🌟 THE FIX: Supabase already parsed the JSON into a Map for us!
        // We just need to cast it safely.
        final data = response.data as Map<String, dynamic>;

        // 🌟 ADD THIS LINE to see exactly what Gemini returns in your terminal!
        debugPrint('🧠 GEMINI RESPONSE: $data');

        setState(() {
          // If Gemini appends the category, we can show it nicely in the UI
          final aiFoodName = data['food_name']?.toString() ?? 'Unknown Food';
          final aiCategory = data['db_category']?.toString() ?? '';

          // 🌟 THE FIX: Only show parentheses if a category was actually returned
          if (aiCategory.isNotEmpty) {
            _foodName = '$aiFoodName\n($aiCategory)';
          } else {
            _foodName = aiFoodName;
          }

          // 🌟 Capture the database UUID
          _factorId = data['factor_id']?.toString();
          _weightG = double.tryParse(data['weight_g']?.toString() ?? '0');
          _co2e = double.tryParse(data['estimated_co2e']?.toString() ?? '0');
          _isAnalyzing = false;
        });
      } else {
        throw Exception("Server responded with code ${response.status}");
      }
    } catch (e) {
      debugPrint('❌ Vision AI Error: $e');
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI analysis failed: $e')));
      }
    }
  }

  // --- SAVE TO DATABASE ---
  Future<void> _saveFoodLog() async {
    if (_foodName == null || _weightG == null || _co2e == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found.");

      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id':
            _factorId, // 🌟 THE FIX: Now perfectly linked to your Diet table!
        'input_value': double.parse(_weightG!.toStringAsFixed(2)),
        'total_co2e': double.parse(_co2e!.toStringAsFixed(4)),
      });

      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('❌ DB Save Error: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save meal log: $e')));
      }
    }
  }

  // --- CUSTOM SUCCESS DIALOG ---
  void _showSuccessDialog() {
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
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.primaryColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Meal Logged!",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your $_foodName (${_weightG?.toStringAsFixed(0)}g) has been added to your climate journal.\n\nTracking your dietary footprint is one of the most impactful ways to lower your daily emissions. Keep eating mindfully!",
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
                      // 1. Close the dialog first (using rootNavigator to be safe)
                      Navigator.of(context, rootNavigator: true).pop();

                      // 2. Close the Food Camera Screen
                      // Since we pushed this screen, popping it will naturally reveal
                      // the ActivityLogScreen that is sitting right behind it.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          // GoRouter's pop is the cleanest way to retreat
                          context.pop();
                        }
                      });
                    },
                    child: const Text(
                      'Back to Activity Log',
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

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text(
          'Food Carbon Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Image Preview Window Area
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fastfood_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Snap a picture of your meal to calculate footprint',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Conditional Loading or Results Display Pane
            if (_isAnalyzing) ...[
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 12),
              const Text(
                "Gemini Vision Engine analyzing plate composition...",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ] else if (_foodName != null) ...[
              _buildResultsCard(),
            ] else ...[
              _buildCaptureButtons(),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _getImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
            label: const Text(
              'Take Photo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _getImage(ImageSource.gallery),
            icon: const Icon(
              Icons.photo_library_rounded,
              color: AppTheme.primaryColor,
            ),
            label: const Text(
              'Gallery',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            _foodName!.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${_weightG?.toStringAsFixed(0)}g',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Estimated Weight',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              Column(
                children: [
                  Text(
                    '+${_co2e?.toStringAsFixed(2)} kg',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.redAccent,
                    ),
                  ),
                  const Text(
                    'CO₂e Footprint',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveFoodLog,
              child: const Text(
                'Confirm & Log Diet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
