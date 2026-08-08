import 'package:flutter/material.dart';
import 'package:carbonsense/theme/app_theme.dart';

// 🌟 REUSABLE CAROUSEL QUICK START GUIDE DIALOG
void showQuickStartGuideDialog(
  BuildContext context, {
  bool isOnboarding = false, // When true, forces the user to complete all slides before exiting
  VoidCallback? onComplete,
}) {
  showDialog(
    context: context,
    barrierDismissible: !isOnboarding, // 🔒 Cannot tap outside to close if onboarding
    builder: (BuildContext dialogContext) {
      // 🔒 Prevent closing via Android hardware back button / gestural navigation
      return PopScope(
        canPop: !isOnboarding,
        child: QuickStartCarouselDialog(isOnboarding: isOnboarding, onComplete: onComplete),
      );
    },
  );
}

class QuickStartCarouselDialog extends StatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onComplete;

  const QuickStartCarouselDialog({super.key, this.isOnboarding = false, this.onComplete});

  @override
  State<QuickStartCarouselDialog> createState() => _QuickStartCarouselDialogState();
}

class _QuickStartCarouselDialogState extends State<QuickStartCarouselDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 📝 EASY-TO-UNDERSTAND SLIDE DATA
  final List<Map<String, dynamic>> _pages = [
    {
      "icon": Icons.co2_rounded,
      "color": Colors.teal.shade600,
      "badge": "THE BASICS",
      "title": "What is a Carbon Footprint?",
      "subtitle": "Your daily environmental footprint",
      "description":
          "Just like walking on sand leaves footprints, your daily choices—like turning on lights, commuting, or eating meals—leave an invisible trace of carbon gases in the air. That total trace is your carbon footprint!",
    },
    {
      "icon": Icons.public_rounded,
      "color": Colors.amber.shade800,
      "badge": "WHY IT MATTERS",
      "title": "Why Does It Matter?",
      "subtitle": "Small actions, big planetary impact",
      "description":
          "When too much carbon builds up in the air, it traps heat like a heavy blanket around the Earth. This causes extreme weather, rising heat, and loss of nature. Lowering our emissions keeps our planet healthy!",
    },
    {
      "icon": Icons.pie_chart_outline_rounded,
      "color": Colors.blue.shade600,
      "badge": "YOUR ASSISTANT",
      "title": "Understand Your Impact",
      "subtitle": "Track energy, transport, and meals effortlessly",
      "description":
          "CarbonSense takes away the guesswork. Easily log your everyday habits, and our system automatically calculates your total footprint so you can clearly see where your emissions come from.",
    },
    {
      "icon": Icons.auto_awesome_rounded,
      "color": AppTheme.primaryColor,
      "badge": "SMART ACTION",
      "title": "Take Action with AI",
      "subtitle": "Personalized habits that make a difference",
      "description":
          "You don't need to change your whole life overnight! CarbonSense uses AI to deliver small, tailored weekly missions that make shrinking your carbon footprint easy, fun, and rewarding.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    bool isLastPage = _currentPage == _pages.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
        child: Column(
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text("Quick Start Guide", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ],
                ),
                // 🔒 HIDE CLOSE BUTTON IF ONBOARDING
                if (!widget.isOnboarding)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const Divider(height: 20),

            // PageView Carousel Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final Color themeColor = page["color"];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hero Icon Banner
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(color: themeColor.withOpacity(0.12), shape: BoxShape.circle),
                          child: Icon(page["icon"], size: 44, color: themeColor),
                        ),
                        const SizedBox(height: 16),

                        // Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: themeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            page["badge"],
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: themeColor, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Slide Title & Subtitle
                        Text(
                          page["title"],
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          page["subtitle"],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Plain Language Body Text
                        Text(
                          page["description"],
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.45),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Page Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: _currentPage == index ? AppTheme.primaryColor : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Navigation Controls
            Row(
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    },
                    child: const Text(
                      "Back",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (!widget.isOnboarding)
                  // 🔒 HIDE SKIP BUTTON IF ONBOARDING
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Skip", style: TextStyle(color: Colors.grey)),
                  )
                else
                  const SizedBox.shrink(), // Keeps spacing aligned
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (isLastPage) {
                      Navigator.pop(context);
                      if (widget.onComplete != null) widget.onComplete!();
                    } else {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    }
                  },
                  child: Text(
                    isLastPage ? "Let's Get Started!" : "Next",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
