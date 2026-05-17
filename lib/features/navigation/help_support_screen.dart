import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // Function to open the website
  Future<void> _launchWebsite(BuildContext context) async {
    // Replace this with your actual Vercel/Firebase web hosting link later!
    final Uri url = Uri.parse('https://carbonsense-web.vercel.app'); 
    
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web portal is currently under maintenance.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How can we help?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "Find answers to common questions or access the full CarbonSense ecosystem.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),

            // --- 1. WEB PORTAL REDIRECT CARD ---
            InkWell(
              onTap: () => _launchWebsite(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.laptop_mac, color: Colors.white, size: 40),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CarbonSense Web", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
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
            const Text("Frequently Asked Questions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 16),
            _buildFaqCard(
              "How does the AI Eco-Coach work?",
              "Our Gemini-powered AI analyzes your daily and monthly logged activities. It generates personalized insights and actionable tips to help you reduce your specific carbon footprint.",
            ),
            _buildFaqCard(
              "Why can't I edit my Diet or Commute badges?",
              "These badges are locked because they are generated dynamically. As you log your daily meals and travel, the system automatically calculates and updates your lifestyle profile to reflect your actual habits.",
            ),
            _buildFaqCard(
              "How is my net footprint calculated?",
              "Your net footprint is your Total Emissions (from logged activities like driving or electricity use) minus your Total Savings (from completing smart eco-tasks).",
            ),
            const SizedBox(height: 32),

            // --- 3. CONTACT SUPPORT ---
            const Text("Still need help?", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                ),
                title: const Text("Email Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text("support@carbonsense.ph"),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening email client...')));
                },
              ),
            ),
            const SizedBox(height: 48),

            // --- 4. CREDITS FOOTER ---
            Center(
              child: Column(
                children: [
                  const Icon(Icons.eco, color: Colors.grey, size: 24),
                  const SizedBox(height: 8),
                  Text("CarbonSense v1.0.0", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("A capstone initiative developed at\nNational University Dasmariñas.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqCard(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent), // Removes the ugly default lines
        child: ExpansionTile(
          iconColor: AppTheme.primaryColor,
          collapsedIconColor: Colors.grey,
          title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text(answer, style: TextStyle(color: Colors.grey.shade600, height: 1.5, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}