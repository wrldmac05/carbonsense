import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  // Result variables from Gemini AI
  double? _kwhUsed;
  double? _co2e;
  String? _factorId;

  // --- CAPTURE IMAGE FUNCTION ---
  Future<void> _getImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _kwhUsed = null;
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
                if (onSecondaryAction != null && secondaryActionText != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSecondaryAction();
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

      final response = await Supabase.instance.client.functions.invoke('analyze-bill-image', body: {'image': base64Image});

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('⚡ GEMINI BILL RESPONSE: $data');

        // 👇 NEW: Check if the AI recognized the image as an electricity bill
        final bool isValidBill = data['is_valid_bill'] ?? true;

        if (!isValidBill) {
          // Reject the image and alert the user
          setState(() {
            _isAnalyzing = false;
            _selectedImage = null; // Clear the invalid image
          });

          if (mounted) {
            // Replaced SnackBar with Custom Dialog
            _showMessageDialog('Invalid Image', 'No electricity bill detected in this image. Please try again!', isError: true);
          }
          return; // Stop execution here
        }

        // Proceed normally if it IS a bill
        setState(() {
          _factorId = data['factor_id']?.toString();
          _kwhUsed = double.tryParse(data['kwh_used']?.toString() ?? '0');
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
        if (errorStr.contains('quota') || errorStr.contains('429') || errorStr.contains('exhausted')) {
          _showMessageDialog(
            'AI Quota Reached',
            'Our AI is taking a quick breather due to high demand. You can still log your bill manually!',
            isError: true,
            secondaryActionText: 'Enter Data Manually',
            onSecondaryAction: () => context.push('/activity/manual-bill'),
          );
        } else {
          _showMessageDialog('Analysis Failed', 'Failed to read bill: $e', isError: true);
        }
      }
    }
  }

  // --- SAVE TO DATABASE ---
  Future<void> _saveEnergyLog() async {
    if (_kwhUsed == null || _co2e == null || _factorId == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found.");

      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id': _factorId,
        'input_value': double.parse(_kwhUsed!.toStringAsFixed(2)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save energy log: $e')));
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
                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.electric_bolt, color: Colors.amber.shade600, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Bill Scanned!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  "We extracted ${_kwhUsed?.toStringAsFixed(1)} kWh from your utility bill.\n\nTracking your monthly grid electricity is the first step toward finding ways to lower your energy consumption.",
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
                      Navigator.of(context, rootNavigator: true).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) context.pop();
                      });
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

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text('Electricity Bill Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // TOP: Image Preview or Visual Aid
                      SizedBox(
                        height: constraints.maxHeight * 0.40,
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
                        const Text("CarbonSense is reading the document...", style: TextStyle(fontWeight: FontWeight.w500)),
                      ] else if (_kwhUsed != null) ...[
                        _buildResultsCard(),
                      ] else ...[
                        _buildPrivacyInstructions(),
                        const SizedBox(height: 20),
                        _buildCaptureButtons(),
                      ],
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

  // 🌟 Cleaned up Scanner Placeholder
  Widget _buildScannerPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 56, // Increased size since it's the main focal point now
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ready to Scan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text('Upload or capture your bill below', style: TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );
  }

  // 🌟 Themed Privacy Instructions + Visual Aid
  Widget _buildPrivacyInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // Matches the app's clean aesthetic
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)), // Same border as your results card
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Privacy First Guidelines",
                style: TextStyle(
                  fontWeight: FontWeight.w900, // Matches your results card typography
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- 📸 VISUAL AID INSIDE THE CARD ---
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/images/bill_sample_highlight.png',
                height: 100, // Kept slightly compact so it doesn't push buttons off-screen
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.4), // Slightly lower
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    alignment: Alignment.center,
                    child: Text(
                      "[ Cropped Visual Guide Here ]",
                      style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.6), fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- THE CHECKLIST ---
          _buildInstructionRow(icon: Icons.zoom_in, color: AppTheme.primaryColor, text: 'Zoom in ONLY on the "Actual Consumption" or "Total kWh" number.'),
          const SizedBox(height: 10),
          _buildInstructionRow(icon: Icons.visibility_off, color: Colors.redAccent, text: 'Do NOT capture your name, address, or account numbers.'),
          const SizedBox(height: 10),
          _buildInstructionRow(icon: Icons.lightbulb_outline, color: Colors.amber.shade600, text: 'Ensure the number is well-lit and readable.'),
        ],
      ),
    );
  }

  // Helper widget remains unchanged
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
              'Scan Bill',
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
          const Text(
            "GRID ELECTRICITY",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('${_kwhUsed?.toStringAsFixed(1)} kWh', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text('Extracted Usage', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveEnergyLog,
              child: const Text(
                'Confirm & Log Energy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 🌟 NEW: The Retake Button
          TextButton.icon(
            onPressed: () => _getImage(ImageSource.camera),
            icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
            label: const Text("Incorrect reading? Retake photo", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
