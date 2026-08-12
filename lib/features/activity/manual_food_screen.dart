import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:carbonsense/features/utils/mission_engine.dart';

class ManualFoodLogScreen extends StatefulWidget {
  const ManualFoodLogScreen({super.key});

  @override
  State<ManualFoodLogScreen> createState() => _ManualFoodLogScreenState();
}

class _ManualFoodLogScreenState extends State<ManualFoodLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ingredientController = TextEditingController();

  bool _isSaving = false;
  List<String> _ingredients = [];
  Map<String, dynamic>? _selectedCategory;

  // Database emission factors
  final List<Map<String, dynamic>> _foodCategories = [
    {"name": "Plant-based / Gulay Meal", "factor_id": "32bd37ee-f879-4c69-b769-b762c506ed65", "co2_per_unit": 0.8000, "is_meatless": true, "icon": Icons.eco_rounded, "color": Colors.green},
    {"name": "Pescatarian Meal (Fish & Rice)", "factor_id": "31c0f8ec-7b07-416a-8ce1-5212647e6dac", "co2_per_unit": 1.6000, "is_meatless": false, "icon": Icons.phishing_rounded, "color": Colors.blue},
    {
      "name": "Standard Filipino (Pork/Chicken & Rice)",
      "factor_id": "ba3a3e12-29b8-4c06-b9f8-4756609c538d",
      "co2_per_unit": 2.5000,
      "is_meatless": false,
      "icon": Icons.set_meal_rounded,
      "color": Colors.orange,
    },
    {
      "name": "Heavy Beef Meal (Bulalo/Steak)",
      "factor_id": "81c7fcff-6015-4922-a4e9-258d53be33b1",
      "co2_per_unit": 6.5000,
      "is_meatless": false,
      "icon": Icons.restaurant_rounded,
      "color": Colors.redAccent,
    },
  ];

  // --- STRICT VALIDATION: Add Ingredient ---
  void _addIngredient() {
    final text = _ingredientController.text.trim().toLowerCase();

    if (text.isEmpty) return;

    if (_ingredients.length >= 15) {
      _showErrorSnackBar("Maximum of 15 ingredients allowed.");
      return;
    }

    if (text.length < 2 || text.length > 30) {
      _showErrorSnackBar("Ingredient must be between 2 and 30 characters.");
      return;
    }

    // Troll prevention
    final validChars = RegExp(r'^[a-z\s\-]+$');
    if (!validChars.hasMatch(text)) {
      _showErrorSnackBar("Please use only letters for ingredients.");
      return;
    }

    if (_ingredients.contains(text)) {
      _showErrorSnackBar("Ingredient already added.");
      return;
    }

    setState(() {
      _ingredients.add(text);
      _ingredientController.clear();
    });
  }

  void _removeIngredient(String item) {
    setState(() {
      _ingredients.remove(item);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  void _setPresetWeight(int weight) {
    setState(() {
      _weightController.text = weight.toString();
    });
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _submitManualLog() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showErrorSnackBar("Please select a meal category.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      final weightG = double.parse(_weightController.text);
      final baseCo2 = _selectedCategory!['co2_per_unit'] as double;
      final totalCo2e = (weightG / 500.0) * baseCo2;
      final foodName = _foodNameController.text.trim();

      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user.id,
        'factor_id': _selectedCategory!['factor_id'],
        'food_name': foodName,
        'input_value': double.parse(weightG.toStringAsFixed(2)),
        'total_co2e': double.parse(totalCo2e.toStringAsFixed(4)),
        'ingredients': _ingredients,
      });

      final completedMissions = await MissionEngine.evaluateTelemetry(userId: user.id, category: 'Diet', activityName: _selectedCategory!['name'], isMeatless: _selectedCategory!['is_meatless']);

      if (mounted) {
        setState(() => _isSaving = false);

        if (completedMissions.isNotEmpty) {
          _showMissionUnlockedPopup(completedMissions, () {
            _showSuccessDialog(foodName, weightG);
          });
        } else {
          _showSuccessDialog(foodName, weightG);
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar("Failed to save: $e");
    }
  }

  // --- DIALOGS ---
  void _showSuccessDialog(String foodName, double weight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black54;

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
                  decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.restaurant_menu_rounded, color: isDark ? Colors.orange[300] : Colors.orange.shade600, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  "Meal Logged!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your $foodName (${weight.toStringAsFixed(0)}g) has been added to your climate journal.\n\nTracking your dietary footprint is one of the most impactful ways to lower your daily emissions. Keep eating mindfully!",
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

  void _showMissionUnlockedPopup(List<String> missions, VoidCallback onClosed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                "Your meal automatically unlocked:",
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
                Navigator.of(context, rootNavigator: true).pop();
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

  // --- MODERNIZED UI BUILDERS ---

  void _showCategoryBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Select Meal Type",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              ..._foodCategories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (cat['color'] as Color).withOpacity(0.15),
                    child: Icon(cat['icon'] as IconData, color: cat['color'] as Color),
                  ),
                  title: Text(
                    cat['name'] as String,
                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: textColor),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    Navigator.pop(context);
                  },
                );
              }),
              const SafeArea(child: SizedBox(height: 8)),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black54;

    return Scaffold(
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
                  "Log Your Meal",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                ),
                const SizedBox(height: 8),
                Text("Fill in the details below to accurately track your carbon footprint.", style: TextStyle(color: subtitleColor, fontSize: 14)),
                const SizedBox(height: 32),

                // 1. FOOD NAME CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Food Name",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _foodNameController,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                        decoration: InputDecoration(
                          hintText: "e.g., Spinach and Cheese Pizza",
                          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey.shade400, fontWeight: FontWeight.normal),
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the food name';
                          }
                          if (value.trim().length < 2) {
                            return 'Food name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. MEAL CATEGORY CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What type of meal is it?",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _showCategoryBottomSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedCategory == null ? (isDark ? Colors.grey[800]! : Colors.grey.shade300) : AppTheme.primaryColor),
                          ),
                          child: Row(
                            children: [
                              Icon(_selectedCategory == null ? Icons.restaurant_menu : _selectedCategory!['icon'], color: _selectedCategory == null ? Colors.grey : _selectedCategory!['color']),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedCategory == null ? "Tap to select meal type" : _selectedCategory!['name'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedCategory == null ? (isDark ? Colors.grey[400] : Colors.grey.shade600) : textColor,
                                    fontWeight: _selectedCategory == null ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. PORTION SIZE CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Portion Size",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),

                      // Quick Selectors
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildWeightChip("Snack", 250), _buildWeightChip("Standard", 500), _buildWeightChip("Large", 750)]),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                        decoration: InputDecoration(
                          labelText: "Or enter custom portion",
                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54),
                          suffixText: "grams",
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
                          if (value == null || value.isEmpty) return 'Required';
                          final num? weight = double.tryParse(value);
                          if (weight == null) return 'Must be a valid number';
                          if (weight < 10) return 'Weight must be at least 10g';
                          if (weight > 3000) return 'Exceeds limit (Max: 3000g)';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. INGREDIENTS CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.kitchen_rounded, size: 20, color: isDark ? Colors.white : AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            "Main Ingredients",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Optional. Helps CarbonSense tailor your insights.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ingredientController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: "e.g., spinach",
                                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey.shade400),
                                filled: true,
                                fillColor: isDark ? Colors.grey[900] : Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
                                ),
                              ),
                              onFieldSubmitted: (_) => _addIngredient(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _addIngredient,
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      if (_ingredients.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _ingredients.map((item) {
                            return InputChip(
                              label: Text(
                                item,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
                              ),
                              deleteIcon: Icon(Icons.cancel, size: 18, color: isDark ? Colors.grey[400] : Colors.black54),
                              onDeleted: () => _removeIngredient(item),
                              backgroundColor: isDark ? AppTheme.primaryColor.withOpacity(0.25) : AppTheme.primaryColor.withOpacity(0.1),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            );
                          }).toList(),
                        ),
                      ],
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
    );
  }

  // Helper widget for weight presets
  Widget _buildWeightChip(String label, int weight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _setPresetWeight(weight),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.black54, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              "${weight}g",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _weightController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }
}
