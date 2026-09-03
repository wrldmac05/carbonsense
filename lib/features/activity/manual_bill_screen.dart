import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:carbonsense/features/utils/mission_engine.dart';

class ManualBillScreen extends StatefulWidget {
  const ManualBillScreen({super.key});

  @override
  State<ManualBillScreen> createState() => _ManualBillScreenState();
}

class _ManualBillScreenState extends State<ManualBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kwhController = TextEditingController();

  bool _isSaving = false;

  // Fallback defaults; preferably populated dynamically from Supabase
  final String _factorId = "184fdcea-17b3-4370-8dd6-ed33612015c6";
  final String _activityName = "Grid Electricity (Luzon/Visayas)";
  final double _co2PerUnit = 0.7120;

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _submitManualLog() async {
    // Guard against duplicate concurrent taps
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      // Normalize and sanitize numeric inputs
      final sanitizedInput = _kwhController.text.trim().replaceAll(',', '.');
      final rawKwh = double.tryParse(sanitizedInput);
      if (rawKwh == null || rawKwh <= 0) {
        throw const FormatException("Invalid numeric input");
      }

      // Bound values to realistic residential limits
      final safeKwh = double.parse(rawKwh.clamp(0.01, 20000.0).toStringAsFixed(2));
      final safeCo2e = double.parse((safeKwh * _co2PerUnit).clamp(0.0, 50000.0).toStringAsFixed(4));

      await Supabase.instance.client.from('activity_logs').insert({'user_id': user.id, 'factor_id': _factorId, 'input_value': safeKwh, 'total_co2e': safeCo2e});

      // Trigger Mission Engine
      final completedMissions = await MissionEngine.evaluateTelemetry(userId: user.id, category: 'Energy', activityName: _activityName, isMeatless: false);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (completedMissions.isNotEmpty) {
        _showMissionUnlockedPopup(completedMissions, () {
          if (mounted) _showSuccessDialog(safeKwh);
        });
      } else {
        _showSuccessDialog(safeKwh);
      }
    } catch (e) {
      debugPrint('Manual Log DB Error: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);

      // Avoid leaking raw exception stack/schema details to the UI
      _showErrorSnackBar("Unable to save energy log. Please verify your connection and try again.");
    }
  }

  // --- DIALOGS ---
  void _showSuccessDialog(double kwh) {
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
                  "Bill Logged!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your electricity usage (${kwh.toStringAsFixed(1)} kWh) has been safely added to your journal.\n\nTracking your monthly grid electricity is the first step toward finding ways to lower your energy consumption.",
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

  void _showMissionUnlockedPopup(List<String> missions, VoidCallback onClosed) {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: dialogBg,
          title: Column(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 56),
              const SizedBox(height: 12),
              Text(
                "Quest Completed!",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Your energy log automatically unlocked:",
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13),
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
                        child: Text(
                          mission,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onClosed();
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

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  // --- MODERNIZED UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black54;
    final primaryAccentColor = isDark ? Colors.white : AppTheme.primaryColor;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(
            'Manual Entry',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Log Electricity",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Text("Enter your total consumption to track your home energy footprint.", style: TextStyle(color: subtitleColor, fontSize: 14)),
                  const SizedBox(height: 32),

                  // 1. SOURCE CARD
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Energy Source",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.power, color: primaryAccentColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _activityName,
                                  style: TextStyle(fontSize: 15, color: primaryAccentColor, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Icon(Icons.check_circle, color: primaryAccentColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. CONSUMPTION CARD
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Consumption",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Text("Found on your monthly utility bill.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _kwhController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          enabled: !_isSaving,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                          decoration: InputDecoration(
                            labelText: "Enter usage",
                            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
                            suffixText: "kWh",
                            suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.black54),
                            filled: true,
                            fillColor: isDark ? Colors.grey[900] : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Required';
                            final sanitized = value.trim().replaceAll(',', '.');
                            final num? kwh = double.tryParse(sanitized);
                            if (kwh == null) return 'Must be a valid number';
                            if (kwh <= 0) return 'Must be greater than 0';
                            if (kwh > 20000) return 'Exceeds standard residential limits';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- SUBMIT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      onPressed: _isSaving ? null : _submitManualLog,
                      child: _isSaving
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text(
                              'Save Manual Log',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _kwhController.dispose();
    super.dispose();
  }
}
