import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class LogActivityScreen extends StatelessWidget {
  const LogActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Activity'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a Category',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildCategoryButton(context, Icons.directions_car, 'Transport'),
                        _buildCategoryButton(context, Icons.fastfood, 'Food'),
                        _buildCategoryButton(context, Icons.power, 'Energy'),
                        _buildCategoryButton(context, Icons.shopping_cart, 'Shopping'),
                        _buildCategoryButton(context, Icons.delete, 'Waste'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Recent Actions',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildRecentAction(context, 'Rode the bus today', '1h ago'),
                    _buildRecentAction(context, 'Used a reusable cup', '5h ago'),
                    _buildRecentAction(context, 'Bought local groceries', 'Yesterday'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, IconData icon, String label) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRecentAction(BuildContext context, String title, String timestamp) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title),
        trailing: Text(timestamp, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
