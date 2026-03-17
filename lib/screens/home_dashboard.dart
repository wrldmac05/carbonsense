
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    // Daily Progress
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/daily-tasks'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Eco-Progress',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: 0.70,
                                    strokeWidth: 12,
                                    backgroundColor: Colors.grey[300],
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryColor),
                                  ),
                                  Center(
                                    child: Text(
                                      '70%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionIconButton(
                            context, Icons.water_drop, 'Water'),
                        _buildActionIconButton(
                            context, Icons.lightbulb, 'Energy'),
                        _buildActionIconButton(
                            context, Icons.directions_bike, 'Travel'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Footprint Score
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/score-history'),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Your Footprint Score: 85/100',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconButton(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.primaryColor,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: () {},
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppTheme.primaryColor)),
      ],
    );
  }
}
