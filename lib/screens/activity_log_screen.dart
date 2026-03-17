import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log Activity',
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
                    _buildCategoryButton(
                        context, Icons.directions_car, 'Transport'),
                    _buildCategoryButton(context, Icons.fastfood, 'Food'),
                    _buildCategoryButton(context, Icons.power, 'Energy'),
                    _buildCategoryButton(
                        context, Icons.shopping_cart, 'Shopping'),
                    _buildCategoryButton(context, Icons.delete, 'Waste'),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Recent Logs',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildRecentAction(context, 'Cycled to work', '1h ago'),
                _buildRecentAction(
                    context, 'Ate a vegetarian lunch', '3h ago'),
                _buildRecentAction(
                    context, 'Unplugged electronics', 'Yesterday'),
                _buildRecentAction(
                    context, 'Used a reusable water bottle', 'Yesterday'),
              ],
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
