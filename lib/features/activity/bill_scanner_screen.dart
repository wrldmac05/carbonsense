import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  // Use XFile and Uint8List for full cross-platform compatibility (Web, iOS, Android)
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  // Result variables from Gemini AI
  double? _kwhUsed;
  double? _co2e;
  String? _factorId;

  // --- CAPTURE IMAGE FUNCTION ---
  Future<void> _getImage(ImageSource source) async {
    if (_isAnalyzing) return;

    // Constrain resolution to keep payloads small and avoid memory spikes
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024, maxHeight: 1024);

    if (pickedFile != null && mounted) {
      final bytes = await pickedFile.readAsBytes();

      setState(() {
        _selectedImage = pickedFile;
        _imageBytes = bytes;
        _kwhUsed = null;
        _co2e = null;
        _factorId = null;
      });

      _analyzeImageWithGemini();
    }
  }

  void _showMessageDialog(String title, String message, {bool isError = false, VoidCallback? onSecondaryAction, String? secondaryActionText}) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
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
                    onPressed: () => Navigator.of(dialogContext).pop(),
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
                        Navigator.of(dialogContext).pop();
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
    if (_imageBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // Offload Base64 encoding to background isolate on mobile/desktop; synchronous on Web
      final base64Image = kIsWeb ? base64Encode(_imageBytes!) : await compute(base64Encode, _imageBytes!);

      final response = await Supabase.instance.client.functions.invoke('analyze-bill-image', body: {'image': base64Image});

      if (!mounted) return;

      if (response.status == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        debugPrint('⚡ GEMINI BILL RESPONSE: $data');

        final bool isValidBill = data['is_valid_bill'] == true;

        if (!isValidBill) {
          setState(() {
            _isAnalyzing = false;
            _selectedImage = null;
            _imageBytes = null;
          });

          _showMessageDialog('Invalid Image', 'No electricity bill detected in this image. Please try again!', isError: true);
          return;
        }

        // Sanitization & bounds clamping: realistic monthly residential limits (0 to 50,000 kWh)
        final parsedKwh = double.tryParse(data['kwh_used']?.toString() ?? '0') ?? 0.0;
        final parsedCo2e = double.tryParse(data['estimated_co2e']?.toString() ?? '0') ?? 0.0;
        final rawFactorId = data['factor_id']?.toString().trim();

        final validKwh = parsedKwh.clamp(0.0, 50000.0);
        final validCo2e = parsedCo2e.clamp(0.0, 100000.0);
        final safeFactorId = (rawFactorId != null && rawFactorId.length <= 64) ? rawFactorId : null;

        setState(() {
          _factorId = safeFactorId;
          _kwhUsed = validKwh;
          _co2e = validCo2e;
          _isAnalyzing = false;
        });
      } else {
        throw Exception("Server responded with code ${response.status}");
      }
    } catch (e) {
      debugPrint('❌ Vision AI Error: $e');
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _selectedImage = null;
        _imageBytes = null;
      });

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
        // Generic failure message avoids leaking API routes or stack traces
        _showMessageDialog('Analysis Failed', 'Failed to process your electricity bill. Please ensure clear lighting and retake the photo.', isError: true);
      }
    }
  }

  // --- SAVE TO DATABASE ---
  Future<void> _saveEnergyLog() async {
    if (_kwhUsed == null || _co2e == null || _factorId == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("No authenticated user found.");

      final safeKwh = double.parse(_kwhUsed!.clamp(0.0, 50000.0).toStringAsFixed(2));
      final safeCo2e = double.parse(_co2e!.clamp(0.0, 100000.0).toStringAsFixed(4));

      await Supabase.instance.client.from('activity_logs').insert({'user_id': user.id, 'factor_id': _factorId, 'input_value': safeKwh, 'total_co2e': safeCo2e});

      if (!mounted) return;

      setState(() => _isAnalyzing = false);
      _showSuccessDialog();
    } catch (e) {
      debugPrint('❌ DB Save Error: $e');
      if (!mounted) return;

      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save energy log. Please try again.')));
    }
  }

  // --- CUSTOM SUCCESS DIALOG ---
  void _showSuccessDialog() {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black54;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20.0, offset: Offset(0.0, 10.0))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(color: isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.electric_bolt, color: isDark ? Colors.amber[300] : Colors.amber.shade600, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  "Bill Scanned!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  "We extracted ${_kwhUsed?.toStringAsFixed(1)} kWh from your utility bill.\n\nTracking your monthly grid electricity is the first step toward finding ways to lower your energy consumption.",
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
                      Navigator.of(dialogContext).pop();
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

  Future<bool> _showExitConfirmationDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(
            'Analysis in Progress',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Gemini AI is currently analyzing your electricity bill. Leaving this page now will cancel the process. Are you sure you want to exit?',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Exit & Cancel', style: TextStyle(color: Colors.white)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: !_isAnalyzing,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _showExitConfirmationDialog();

        if (shouldPop && context.mounted) {
          setState(() => _isAnalyzing = false);

          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            context.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(
            'Electricity Bill Scanner',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
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
                        // TOP: Image Preview or Visual Aid (Cross-platform Image.memory)
                        SizedBox(
                          height: constraints.maxHeight * 0.40,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade300, width: 2),
                            ),
                            child: _imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                                  )
                                : _buildScannerPlaceholder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // BOTTOM: Dynamic Content
                        if (_isAnalyzing) ...[
                          const CircularProgressIndicator(color: AppTheme.primaryColor),
                          const SizedBox(height: 12),
                          Text(
                            "CarbonSense is reading the document...",
                            style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
                          ),
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
      ),
    );
  }

  Widget _buildScannerPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black54;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.document_scanner_outlined, size: 56, color: isDark ? Colors.white : AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Scan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text('Upload or capture your bill below', style: TextStyle(fontSize: 14, color: subtitleColor)),
        ],
      ),
    );
  }

  Widget _buildPrivacyInstructions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Text(
                "Privacy First Guidelines",
                style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/images/bill_sample_highlight.png',
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.4),
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
          _buildInstructionRow(icon: Icons.zoom_in, color: AppTheme.primaryColor, text: 'Zoom in ONLY on the "Actual Consumption" or "Total kWh" number.'),
          const SizedBox(height: 10),
          _buildInstructionRow(icon: Icons.visibility_off, color: Colors.redAccent, text: 'Do NOT capture your name, address, or account numbers.'),
          const SizedBox(height: 10),
          _buildInstructionRow(icon: Icons.lightbulb_outline, color: isDark ? Colors.amber[300]! : Colors.amber.shade600, text: 'Ensure the number is well-lit and readable.'),
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
            onPressed: _isAnalyzing ? null : () => _getImage(ImageSource.camera),
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
            onPressed: _isAnalyzing ? null : () => _getImage(ImageSource.gallery),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            "GRID ELECTRICITY",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${_kwhUsed?.toStringAsFixed(1)} kWh',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  Text('Extracted Usage', style: TextStyle(fontSize: 12, color: subtitleColor)),
                ],
              ),
              Container(width: 1, height: 30, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
              Column(
                children: [
                  Text(
                    '+${_co2e?.toStringAsFixed(2)} kg',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.redAccent),
                  ),
                  Text('CO₂e Footprint', style: TextStyle(fontSize: 12, color: subtitleColor)),
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
              onPressed: _isAnalyzing ? null : _saveEnergyLog,
              child: const Text(
                'Confirm & Log Energy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isAnalyzing ? null : () => _getImage(ImageSource.camera),
            icon: Icon(Icons.refresh, size: 16, color: subtitleColor),
            label: Text("Incorrect reading? Retake photo", style: TextStyle(color: subtitleColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
