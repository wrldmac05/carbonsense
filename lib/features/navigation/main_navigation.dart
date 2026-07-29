import 'dart:ui';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:carbonsense/widgets/custom_drawer.dart';
import 'package:carbonsense/widgets/quick_start_guide_dialog.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF9FFF9), // Match your app background
      // 1. The Drawer lives here now
      drawer: const CustomDrawer(),

      // 2. The AppBar lives here now
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              'CarbonSense',
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.primaryColor),
            tooltip: 'Quick Start Guide',
            onPressed: () => showQuickStartGuideDialog(context),
          ),
          const SizedBox(width: 12),
        ],
      ),

      body: navigationShell,

      // We use a SafeArea to ensure it doesn't collide with the iOS home indicator
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.list_alt,
                      label: 'Activity',
                      isSelected: navigationShell.currentIndex == 0,
                      onTap: () => _goTo(0),
                    ),
                    _NavItem(
                      icon: Icons.home,
                      label: 'Home',
                      isSelected: navigationShell.currentIndex == 1,
                      onTap: () => _goTo(1),
                    ),
                    _NavItem(
                      icon: Icons.analytics,
                      label: 'Analytics',
                      isSelected: navigationShell.currentIndex == 2,
                      onTap: () => _goTo(2),
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

  void _goTo(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            // ClipRect and AnimatedSize work together to smoothly reveal the text
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors
                                .white, // Assumes your primary color is dark/vibrant
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
