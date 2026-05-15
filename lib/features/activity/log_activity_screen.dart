import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';

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

  // 🧠 Smart Icon Mapper: Assigns a cool icon based on the database text!
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
    return Icons.eco; // Default fallback icon
  }

  // 🎈 The Floating Centered Pop-Up Dialog
  void _showCenteredInputDialog(Map<String, dynamic> activity) {
    final TextEditingController inputController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap cancel to close
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          // 🛠️ THE FIX: Renamed 'context' to 'innerContext' below!
          builder: (BuildContext innerContext, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
              contentPadding: const EdgeInsets.all(24),
              title: Column(
                children: [
                  Icon(
                    _getIconForActivity(activity['activity_name']),
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activity['activity_name'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter amount in ${activity['unit']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: inputController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        suffixText: activity['unit'],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a value';
                        if (double.tryParse(value) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actionsPadding: const EdgeInsets.only(bottom: 16),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            final userId = Supabase.instance.client.auth.currentUser!.id;
                            final inputValue = double.parse(inputController.text.trim());
                            final co2PerUnit = (activity['co2_per_unit'] as num).toDouble();
                            final calculatedCo2e = inputValue * co2PerUnit;

                            await Supabase.instance.client.from('activity_logs').insert({
                              'user_id': userId,
                              'factor_id': activity['factor_id'],
                              'input_value': inputValue,
                              'total_co2e': calculatedCo2e,
                            });

                            if (mounted) {
                              Navigator.pop(dialogContext); // Close Dialog
                              Navigator.pop(context); // Go back to Dashboard securely!
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Activity logged!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? const Center(child: Text('No activities found for this category.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 columns
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85, // Adjusts height of the cards
                  ),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return InkWell(
                      onTap: () => _showCenteredInputDialog(activity),
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                child: Icon(
                                  _getIconForActivity(activity['activity_name']),
                                  size: 32,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                activity['activity_name'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
