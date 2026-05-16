import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';
// 🌟 NEW: Import the universal help guide component
import 'package:carbonsense/widgets/quick_start_guide_dialog.dart';

class LogActivityScreen extends StatefulWidget {
  final String category;
  const LogActivityScreen({super.key, required this.category});

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchCategoryActivities();
  }

  Future<void> _fetchCategoryActivities() async {
    try {
      final data = await Supabase.instance.client
          .from('emission_factors')
          .select()
          .eq('category', widget.category)
          .order('activity_name', ascending: true);

      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activities: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIconForActivity(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('car')) return Icons.directions_car;
    if (lower.contains('motorcycle')) return Icons.two_wheeler;
    if (lower.contains('tricycle')) return Icons.electric_rickshaw;
    if (lower.contains('jeepney')) return Icons.airport_shuttle;
    if (lower.contains('bus')) return Icons.directions_bus;
    if (lower.contains('mrt') || lower.contains('lrt')) return Icons.train;
    if (lower.contains('bicycle') || lower.contains('walk')) return Icons.directions_bike;
    if (lower.contains('beef') || lower.contains('meal')) return Icons.restaurant;
    if (lower.contains('electricity') || lower.contains('grid')) return Icons.electrical_services;
    if (lower.contains('lpg') || lower.contains('gas')) return Icons.local_fire_department;
    if (lower.contains('water')) return Icons.water_drop;
    if (lower.contains('waste')) return Icons.delete_outline;
    return Icons.eco;
  }

  String _getImpactFact(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('car') || lower.contains('motorcycle')) return "Vehicle emissions are a leading cause of urban air pollution. Every km tracked is a step toward awareness.";
    if (lower.contains('bus') || lower.contains('mrt') || lower.contains('lrt') || lower.contains('jeepney')) return "Awesome choice! Shared transit produces significantly less greenhouse gas emissions per passenger.";
    if (lower.contains('walk') || lower.contains('bike') || lower.contains('bicycle')) return "Zero emissions! Active transport is the ultimate hack for a carbon-neutral lifestyle.";
    if (lower.contains('beef') || lower.contains('meat')) return "Livestock accounts for ~14.5% of global greenhouse gases. Small diet shifts make a massive impact over time.";
    if (lower.contains('electricity')) return "Turning off unused appliances can reduce your home's energy footprint by up to 10% annually.";
    return "Every activity logged helps CarbonSense's AI build a more accurate mitigation profile just for you.";
  }

  void _openModernLoggingSheet(Map<String, dynamic> activity) {
    final TextEditingController inputController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    
    final double co2PerUnit = (activity['co2_per_unit'] as num).toDouble();
    double livePreviewCo2e = 0.0;
    final impactFact = _getImpactFact(activity['activity_name']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(innerContext).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.category.toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(sheetContext),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                  child: Icon(Icons.close, size: 18, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_getIconForActivity(activity['activity_name']), size: 48, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            activity['activity_name'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 8),

                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blueGrey.shade100),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    impactFact,
                                    style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, height: 1.4, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          Text('Enter amount in ${activity['unit']}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: inputController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.black87),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            onChanged: (value) {
                              final parsed = double.tryParse(value) ?? 0.0;
                              setSheetState(() => livePreviewCo2e = parsed * co2PerUnit);
                            },
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(color: Colors.grey.shade300),
                              border: InputBorder.none,
                              errorStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter a value';
                              final numValue = double.tryParse(value);
                              if (numValue == null || numValue <= 0) return 'Must be greater than 0';
                              if (numValue > 10000) return 'Value exceeds limit';
                              return null;
                            },
                          ),
                          
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            decoration: BoxDecoration(
                              color: livePreviewCo2e > 0 ? AppTheme.primaryColor : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: livePreviewCo2e > 0 ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Estimated Footprint:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: livePreviewCo2e > 0 ? Colors.white70 : Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  '${livePreviewCo2e.toStringAsFixed(2)} kg CO₂',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: livePreviewCo2e > 0 ? Colors.white : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                  : const Text('Confirm Activity Log', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setSheetState(() => isSubmitting = true);

                                      try {
                                        final userId = Supabase.instance.client.auth.currentUser?.id;
                                        if (userId == null) throw Exception("User is not logged in!");

                                        final inputValue = double.parse(inputController.text.trim());
                                        final calculatedCo2e = inputValue * co2PerUnit;
                                        final factorId = activity['factor_id'] ?? activity['id'];

                                        await Supabase.instance.client.from('activity_logs').insert({
                                          'user_id': userId,
                                          'factor_id': factorId,
                                          'input_value': inputValue,
                                          'total_co2e': calculatedCo2e,
                                        });

                                        if (mounted) {
                                          Navigator.pop(sheetContext); 
                                          Navigator.pop(context); 
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.auto_awesome, color: Colors.white),
                                                  const SizedBox(width: 12),
                                                  Text('Awesome! Logged ${calculatedCo2e.toStringAsFixed(2)} kg CO₂e.'),
                                                ],
                                              ),
                                              backgroundColor: Colors.black87,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              margin: const EdgeInsets.all(16),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernActivityTile(Map<String, dynamic> activity) {
    final co2PerUnit = (activity['co2_per_unit'] as num).toDouble();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openModernLoggingSheet(activity),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_getIconForActivity(activity['activity_name']), color: AppTheme.primaryColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['activity_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${co2PerUnit.toStringAsFixed(2)} kg CO₂e / ${activity['unit']}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.add, color: AppTheme.primaryColor, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        // 🌟 NEW: Added the anytime-accessible Quick Start Guide button here as well!
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.primaryColor),
            tooltip: 'Quick Start Guide',
            onPressed: () => showQuickStartGuideDialog(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: -1.0),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select an activity below to calculate your footprint.',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _activities.isEmpty
                      ? Center(child: Text('No activities found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
                          itemCount: _activities.length,
                          itemBuilder: (context, index) {
                            return _buildModernActivityTile(_activities[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}