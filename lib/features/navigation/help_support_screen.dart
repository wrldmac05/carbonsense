import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // Function to open the website
  Future<void> _launchWebsite(BuildContext context) async {
    final Uri url = Uri.parse('https://carbon-sense-web.vercel.app/');

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web portal is currently under maintenance.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FFF9);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "How can we help?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: textColor),
            ),
            const SizedBox(height: 8),
            Text("Find answers to common questions or access the full CarbonSense ecosystem.", style: TextStyle(fontSize: 15, color: subtitleColor, height: 1.5)),
            const SizedBox(height: 32),

            // --- 1. WEB PORTAL REDIRECT CARD ---
            InkWell(
              onTap: () => _launchWebsite(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.laptop_mac, color: Colors.white, size: 40),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CarbonSense Web",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          SizedBox(height: 4),
                          Text("Access the full dashboard on your desktop browser.", style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- 2. FAQ SECTION ---
            Text(
              "Frequently Asked Questions",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 16),
            _buildFaqCard(
              context,
              "How does the AI Eco-Coach work?",
              "Our Gemini-powered AI analyzes your daily and monthly logged activities. It generates personalized insights and actionable tips to help you reduce your specific carbon footprint.",
            ),
            _buildFaqCard(
              context,
              "Why can't I edit my Diet or Commute badges?",
              "These badges are locked because they are generated dynamically. As you log your daily meals and travel, the system automatically calculates and updates your lifestyle profile to reflect your actual habits.",
            ),
            _buildFaqCard(
              context,
              "How is my net footprint calculated?",
              "Your net footprint is your Total Emissions (from logged activities like driving or electricity use) minus your Total Savings (from completing smart eco-tasks).",
            ),
            const SizedBox(height: 32),

            // --- 3. CONTACT SUPPORT ---
            Text(
              "Still need help?",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                ),
                title: Text(
                  "Email Support",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                ),
                subtitle: Text("ph.carbonsense@gmail.com", style: TextStyle(color: subtitleColor)),
                onTap: () async {
                  final Uri emailUri = Uri(scheme: 'mailto', path: 'ph.carbonsense@gmail.com', queryParameters: {'subject': 'Support Request - CarbonSense'});

                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email client.')));
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 48),

            // --- 4. CREDITS FOOTER ---
            Center(
              child: Column(
                children: [
                  Icon(Icons.eco, color: isDark ? Colors.grey[600] : Colors.grey, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    "CarbonSense v1.0.0",
                    style: TextStyle(color: subtitleColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "A capstone initiative developed at\nNational University Dasmariñas.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey.shade500, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqCard(BuildContext context, String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final answerColor = isDark ? Colors.grey[400] : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppTheme.primaryColor,
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
          title: Text(
            question,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text(answer, style: TextStyle(color: answerColor, height: 1.5, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
