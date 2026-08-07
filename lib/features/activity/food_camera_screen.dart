import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:carbonsense/features/utils/mission_engine.dart';

class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key});

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  List<String> _ingredients = [];

  // Result variables from Gemini AI
  String? _foodName;
  String? _foodCategory; // 🌟 NEW: Separated category for cleaner UI
  double? _weightG;
  bool _isMeatless = false;
  double? _co2e;
  String? _factorId;

  // --- CAPTURE IMAGE FUNCTION ---
  Future<void> _getImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _foodName = null;
        _foodCategory = null;
        _isMeatless = false;
        _weightG = null;
        _co2e = null;
        _factorId = null;
      });

      _analyzeImageWithGemini();
    }
  }

  void _showMessageDialog(String title, String message, {bool isError = false, VoidCallback? onSecondaryAction, String? secondaryActionText}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = theme.primaryColor;
        final iconColor = isError ? Colors.redAccent : primaryColor;

        return Dialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isError ? Icons.warning_rounded : Icons.check_circle_outline_rounded, color: iconColor, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isError ? Colors.redAccent : primaryColor),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
                // 🌟 NEW: Optional secondary action for Manual Entry
                if (onSecondaryAction != null && secondaryActionText != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Match StadiumBorder
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        onSecondaryAction(); // Trigger routing
                      },
                      child: Text(
                        secondaryActionText,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: primaryColor),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --- SUPABASE EDGE FUNCTION BRIDGE ---
  Future<void> _analyzeImageWithGemini() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await Supabase.instance.client.functions.invoke('analyze-food-image', body: {'image': base64Image});

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('🧠 GEMINI RESPONSE: $data');

        // 👇 NEW: Check if the AI recognized the image as food
        final bool isFood = data['is_food'] ?? true; // Default to true if missing

        if (!isFood || data['food_name'] == 'Not Food') {
          // Reject the image and alert the user
          setState(() {
            _isAnalyzing = false;
            _selectedImage = null; // Clear the invalid image
          });

          if (mounted) {
            // Replaced SnackBar with Custom Dialog
            _showMessageDialog('Invalid Image', 'No food detected in this image. Please try again!', isError: true);
          }
          return; // Stop execution here
        }

        // 2. Inside _analyzeImageWithGemini(), update the setState block:
        setState(() {
          _foodName = data['food_name']?.toString() ?? 'Unknown Food';
          _foodCategory = data['db_category']?.toString() ?? '';
          _factorId = data['factor_id']?.toString();

          // Safely parse the ingredients array
          if (data['ingredients'] != null) {
            _ingredients = List<String>.from(data['ingredients']);
          } else {
            _ingredients = [];
          }

          final bool aiIsMeatless = data['is_meatless'] ?? false;
          final bool categoryImpliesMeatless = _foodCategory!.toLowerCase().contains('plant-based') || _foodCategory!.toLowerCase().contains('gulay');

          _isMeatless = aiIsMeatless || categoryImpliesMeatless;
          _weightG = double.tryParse(data['weight_g']?.toString() ?? '0');
          _co2e = double.tryParse(data['estimated_co2e']?.toString() ?? '0');
          _isAnalyzing = false;
        });
      } else {
        throw Exception("Server responded with code ${response.status}");
      }
    } catch (e) {
      debugPrint('❌ Vision AI Error: $e');
      setState(() {
        _isAnalyzing = false;
        _selectedImage = null;
      });

      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        // Check for common Gemini quota/rate limit errors (429)
        if (errorStr.contains('quota') || errorStr.contains('429') || errorStr.contains('exhausted')) {
          _showMessageDialog(
            'AI Quota Reached',
            'Our AI is taking a quick breather due to high demand. You can still log your meal manually!',
            isError: true,
            secondaryActionText: 'Log Meal Manually',
            onSecondaryAction: () => context.push('/activity/manual-food'), // Assuming you use go_router
          );
        } else {
          _showMessageDialog('Analysis Failed', 'AI analysis failed: $e', isError: true);
        }
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

      // 3. Inside _saveFoodLog(), update the Supabase insert call:
      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id': _factorId,
        'input_value': double.parse(_weightG!.toStringAsFixed(2)),
        'total_co2e': double.parse(_co2e!.toStringAsFixed(4)),
        'ingredients': _ingredients, // 👇 NEW: Send the array to Supabase
      });

      // 🚀 Run the Mission Engine silently
      final completedMissions = await MissionEngine.evaluateTelemetry(userId: user.id, category: 'Diet', activityName: _foodName!, isMeatless: _isMeatless);

      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSuccessDialog(completedMissions);
      }
    } catch (e) {
      debugPrint('❌ DB Save Error: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save meal log: $e')));
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20.0, offset: Offset(0.0, 10.0))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.restaurant_menu_rounded, color: Colors.orange.shade600, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Meal Logged!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your $_foodName (${_weightG?.toStringAsFixed(0)}g) has been added to your climate journal.\n\nTracking your dietary footprint is one of the most impactful ways to lower your daily emissions. Keep eating mindfully!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
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
                      // Close the current "Meal Logged!" dialog
                      Navigator.of(context, rootNavigator: true).pop();

                      // 🚀 CHECK: Did they complete missions?
                      if (completedMissions.isNotEmpty) {
                        _showMissionUnlockedPopup(completedMissions);
                      } else {
                        // Original routing back
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) context.pop();
                        });
                      }
                    },
                    child: const Text(
                      'Back to Activity Log',
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 56),
              SizedBox(height: 12),
              Text("Quest Completed!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Your meal automatically unlocked:",
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
                      const Icon(Icons.check_circle, color: Colors.green, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(mission, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  if (mounted) context.pop();
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

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text('Food Carbon Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // TOP: Clean Image Preview or Placeholder
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover),
                              )
                            : _buildScannerPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // BOTTOM: Dynamic Content
                    if (_isAnalyzing) ...[
                      const CircularProgressIndicator(color: AppTheme.primaryColor),
                      const SizedBox(height: 12),
                      const Text("CarbonSense is analyzing ingredients and portion size...", style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                    ] else if (_foodName != null) ...[
                      _buildResultsCard(),
                    ] else ...[
                      // 🌟 NEW: Separated Instructions aligned with Bill Scanner design
                      _buildPhotoInstructions(),
                      const SizedBox(height: 20),
                      _buildCaptureButtons(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 600;

        final iconSize = isSmallScreen ? 42.0 : 56.0;
        final padding = isSmallScreen ? 18.0 : 24.0;
        final titleSize = isSmallScreen ? 18.0 : 20.0;
        final subtitleSize = isSmallScreen ? 13.0 : 14.0;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.lunch_dining_rounded, size: iconSize, color: Colors.orange.shade400),
              ),
              SizedBox(height: isSmallScreen ? 18 : 24),
              Text(
                'Ready to Scan',
                style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload or capture your meal below',
                style: TextStyle(fontSize: subtitleSize, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 Themed Photo Instructions + Visual Aid
  Widget _buildPhotoInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.center_focus_strong, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                "Photo Best Practices",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- 📸 VISUAL AID ---
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              // Use a photo of a plate taken from directly above
              child: Image.asset(
                'assets/images/food_sample_guide.png',
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    alignment: Alignment.center,
                    child: Text(
                      "[ Top-Down Food Sample Here ]",
                      style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.6), fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- THE CHECKLIST ---
          _buildInstructionRow(icon: Icons.camera_alt_outlined, color: AppTheme.primaryColor, text: 'Take a direct top-down photo to help the AI estimate portion sizes.'),
          const SizedBox(height: 10),
          _buildInstructionRow(icon: Icons.fullscreen_exit, color: Colors.orange.shade700, text: 'Ensure the entire plate or bowl is visible within the frame.'),
          const SizedBox(height: 10),
          _buildInstructionRow(icon: Icons.lightbulb_outline, color: Colors.amber.shade600, text: 'Use good lighting so all ingredients can be accurately identified.'),
        ],
      ),
    );
  }

  // Helper widget
  Widget _buildInstructionRow({required IconData icon, required Color color, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
      ],
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _getImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
            label: const Text(
              'Take Photo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _getImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
            label: const Text(
              'Gallery',
              style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
          ),
          // 🌟 UPGRADED: Display the database category distinctly as a subtitle
          if (_foodCategory != null && _foodCategory!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _foodCategory!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('${_weightG?.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text('Estimated Weight', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              Column(
                children: [
                  Text(
                    '+${_co2e?.toStringAsFixed(2)} kg',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.redAccent),
                  ),
                  const Text('CO₂e Footprint', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),

          // 👇 NEW: Display ingredients if any were found
          if (_ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Detected Ingredients",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _ingredients
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(item, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20), // Spacing before the Confirm button
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveFoodLog,
              child: const Text(
                'Confirm & Log Diet',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 🌟 NEW: The Retake Button
          TextButton.icon(
            onPressed: () => _getImage(ImageSource.camera),
            icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
            label: const Text("Not quite right? Retake photo", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
