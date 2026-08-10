import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text(
          'Terms of Use',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'CarbonSense Terms of Use',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Last Updated: August 10, 2026',
                    style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preamble
            const Text(
              'Welcome to CarbonSense: An AI-Driven Recommendation System for Personal Carbon Footprint Mitigation Based on Self-Reported Activities ("CarbonSense," "we," "us," or "our").\n\n'
              'CarbonSense is an AI-driven system developed as a capstone project by students of National University Dasmariñas (NU Dasmariñas). The system is designed to help users understand, monitor, and mitigate their personal carbon footprint based on their self-reported activities and AI-assisted activity analysis.\n\n'
              'By creating an account, accessing, or using CarbonSense, you agree to these Terms of Use. If you do not agree with these Terms, please do not use the system.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Sections
            _buildSectionTitle('1. Acceptance of Terms'),
            _buildSectionBody(
              'By accessing or using CarbonSense, you confirm that you have read, understood, and agreed to be bound by these Terms of Use.\n'
              'We may update or modify these Terms from time to time as CarbonSense is developed, improved, or made available to a wider audience. Continued use of the system after changes are posted constitutes acceptance of the updated Terms.',
            ),

            _buildSectionTitle('2. About CarbonSense'),
            _buildSectionBody(
              'CarbonSense is an AI-driven recommendation system that helps users estimate and better understand their personal carbon footprint.\n'
              'The system may allow users to:\n'
              '• Log daily activities manually through forms;\n'
              '• Use AI-assisted analysis to identify and process certain activities;\n'
              '• Analyze food images to estimate food items, ingredients, categories, estimated weight, and associated carbon footprint;\n'
              '• Analyze electricity bills to estimate electricity consumption and related carbon emissions;\n'
              '• Record transportation habits and activities;\n'
              '• Record food and dietary activities;\n'
              '• Track electricity usage;\n'
              '• View summaries of their carbon footprint;\n'
              '• Receive general, daily, weekly, monthly, and other activity-based summaries;\n'
              '• Participate in weekly carbon-footprint mitigation missions; and\n'
              '• Receive AI-driven recommendations based on available activity data.\n\n'
              'CarbonSense may also include administrative dashboards and global or aggregated summaries for system monitoring, research, and analysis purposes.',
            ),

            _buildSectionTitle('3. Eligibility'),
            _buildSectionBody(
              'CarbonSense is intended for users who are at least 12 years old.\n'
              'By using CarbonSense, you confirm that you meet this minimum age requirement.\n'
              'If you are below the age required to independently provide consent under applicable laws, you should use the system only with appropriate permission or supervision from a parent or legal guardian where required.',
            ),

            _buildSectionTitle('4. Account Registration and Security'),
            _buildSectionBody(
              'To access certain features of CarbonSense, you may be required to create an account using your email address and password.\n'
              'You agree to:\n'
              '• Provide accurate and truthful information;\n'
              '• Keep your account credentials confidential;\n'
              '• Not share your password with unauthorized individuals;\n'
              '• Notify us of any suspected unauthorized access to your account; and\n'
              '• Take reasonable steps to protect your account and device.\n\n'
              'You are responsible for activities performed through your account unless the activity resulted from unauthorized access that was not caused by your negligence.\n'
              'CarbonSense currently does not support third-party or social media sign-in services.',
            ),

            _buildSectionTitle('5. Information and Activities Submitted by Users'),
            _buildSectionBody(
              'CarbonSense may collect and process information necessary for its operation, including:\n'
              '• Full name;\n'
              '• Email address;\n'
              '• Profile picture;\n'
              '• Location information;\n'
              '• GPS or geographical data;\n'
              '• Daily activities;\n'
              '• Transportation habits;\n'
              '• Food and dietary information;\n'
              '• Electricity usage;\n'
              '• Images voluntarily submitted for AI analysis;\n'
              '• Electricity bills voluntarily submitted for AI analysis; and\n'
              '• Other information necessary to calculate, estimate, summarize, or improve carbon-footprint-related features.\n\n'
              'Users are responsible for ensuring that the information and activities they submit are accurate to the best of their knowledge.\n'
              'Because CarbonSense relies partly on self-reported activities, inaccurate, incomplete, or misleading information may affect the accuracy of carbon footprint calculations, summaries, recommendations, and other results.',
            ),

            _buildSectionTitle('6. AI-Assisted Features'),
            _buildSectionBody(
              'CarbonSense uses Google\'s Gemini AI through an API to support certain system features.\n'
              'Depending on the feature used, the AI may assist in:\n'
              '• Identifying food from submitted images;\n'
              '• Detecting or describing ingredients;\n'
              '• Estimating the weight of food;\n'
              '• Identifying relevant emission-factor categories;\n'
              '• Estimating the carbon footprint associated with analyzed food;\n'
              '• Analyzing electricity bills and estimating electricity consumption;\n'
              '• Calculating estimated emissions based on electricity consumption and applicable emission factors;\n'
              '• Generating personal activity summaries;\n'
              '• Generating monthly summaries;\n'
              '• Generating aggregated summaries for the system dashboard; and\n'
              '• Assisting administrators with daily, weekly, and monthly summaries.\n\n'
              'By using AI-assisted features, you understand that information submitted to those features may be processed as necessary to provide the requested functionality and operate the CarbonSense system.',
            ),

            _buildSectionTitle('7. Carbon Footprint Estimates and AI Disclaimer'),
            _buildSectionBody(
              'CarbonSense provides estimates, not exact or guaranteed measurements of carbon emissions.\n'
              'Carbon footprint results may depend on several factors, including:\n'
              '• The accuracy of user-submitted information;\n'
              '• The quality and clarity of submitted images or documents;\n'
              '• Estimated food weight and ingredients;\n'
              '• Activity classifications;\n'
              '• Available emission factors;\n'
              '• Assumptions used by the system; and\n'
              '• The limitations of AI-assisted analysis.\n\n'
              'Although CarbonSense uses emission factors and information based on legitimate and credible sources where applicable, results should still be understood as estimates.\n'
              'AI-generated results, recommendations, summaries, and analyses may occasionally be incomplete, inaccurate, or incorrect.\n'
              'CarbonSense should not be considered a substitute for professional environmental, scientific, legal, financial, or other expert advice.\n'
              'We may use collected and appropriately processed data to evaluate and improve the accuracy and performance of the AI-driven features and the CarbonSense system.',
            ),

            _buildSectionTitle('8. Location and GPS Data'),
            _buildSectionBody(
              'CarbonSense may collect location or GPS-related information for research, future development, system improvement, and other features supported by the application.\n'
              'Location data may be used to study activity patterns, improve carbon-footprint estimation methods, improve recommendations, and support future research and development.\n'
              'Users should review the CarbonSense Privacy Policy for additional information regarding how location and other personal data are collected, used, retained, and protected.',
            ),

            _buildSectionTitle('9. Weekly Missions'),
            _buildSectionBody(
              'CarbonSense may provide weekly missions designed to encourage users to reduce or mitigate their estimated carbon footprint.\n'
              'System administrators may create, modify, replace, or remove missions when necessary.\n'
              'Upon successful completion of an eligible mission, the system may apply a corresponding reduction to the user\'s total estimated carbon footprint for the applicable month, according to the rules and calculations defined by the mission.\n'
              'These mission-related reductions are:\n'
              '• System-generated calculations or adjustments;\n'
              '• Intended to represent estimated mitigation or achievement within CarbonSense;\n'
              '• Not monetary rewards;\n'
              '• Not exchangeable for cash or real-world compensation; and\n'
              '• Subject to validation and system rules.\n\n'
              'Users must not attempt to manipulate, falsify, exploit, or bypass mission requirements.\n'
              'CarbonSense may modify, reverse, remove, or deny mission-related adjustments if fraudulent, misleading, or manipulated activity is detected.',
            ),

            _buildSectionTitle('10. Acceptable Use'),
            _buildSectionBody(
              'When using CarbonSense, you agree not to:\n'
              '• Provide deliberately false or misleading activity information;\n'
              '• Manipulate activity logs, missions, calculations, or carbon footprint results;\n'
              '• Create or use multiple accounts for the purpose of abusing system features;\n'
              '• Attempt to gain unauthorized access to the system, accounts, databases, or administrative features;\n'
              '• Interfere with the security, stability, or normal operation of CarbonSense;\n'
              '• Introduce malicious code, viruses, or harmful software;\n'
              '• Reverse engineer, exploit, or abuse the system except where permitted by applicable law;\n'
              '• Use the system for illegal, fraudulent, or harmful purposes; or\n'
              '• Use CarbonSense in any manner that may damage, disrupt, or compromise its data, services, or users.\n\n'
              'We may investigate suspected misuse and take appropriate action, including account suspension or termination.',
            ),

            _buildSectionTitle('11. Account Suspension and Termination'),
            _buildSectionBody(
              'We reserve the right to suspend, restrict, or terminate an account when we reasonably believe that a user has:\n'
              '• Violated these Terms of Use;\n'
              '• Submitted fraudulent or intentionally misleading information;\n'
              '• Manipulated system features or calculations;\n'
              '• Attempted unauthorized access;\n'
              '• Compromised or threatened system or data security; or\n'
              '• Used CarbonSense for unlawful or harmful purposes.\n\n'
              'Where appropriate and reasonably possible, we may provide notice before or after taking action against an account.',
            ),

            _buildSectionTitle('12. Account Deletion and Data Retention'),
            _buildSectionBody(
              'Users may request or initiate deletion of their CarbonSense account through available system features or procedures.\n'
              'When an account is deleted, the account may be removed from normal active use and archived rather than immediately and permanently erased.\n'
              'Certain information associated with deleted accounts may be retained for purposes including:\n'
              '• Research;\n'
              '• System evaluation;\n'
              '• Improvement of CarbonSense;\n'
              '• Future studies;\n'
              '• Improving the accuracy of AI-assisted features;\n'
              '• Maintaining system integrity; and\n'
              '• Other legitimate academic, research, or operational purposes.\n\n'
              'Where appropriate, retained data should be anonymized, aggregated, or de-identified to reduce the connection between retained information and an identifiable individual.\n'
              'The specific handling, retention, protection, and possible deletion of personal data will be further explained in the CarbonSense Privacy Policy.',
            ),

            _buildSectionTitle('13. Research and System Improvement'),
            _buildSectionBody(
              'CarbonSense was originally developed as a capstone project for National University Dasmariñas and may continue to be improved after the completion of the academic project.\n'
              'The system may use appropriately processed user data, activity patterns, aggregated information, and system results for:\n'
              '• Academic research;\n'
              '• System testing and evaluation;\n'
              '• Improving carbon footprint calculations;\n'
              '• Improving AI-assisted analysis;\n'
              '• Improving recommendations;\n'
              '• Developing future features; and\n'
              '• Supporting studies related to personal carbon footprint mitigation.\n\n'
              'Any future research use of personal information should be handled in accordance with applicable laws, institutional requirements, and the CarbonSense Privacy Policy.',
            ),

            _buildSectionTitle('14. Intellectual Property'),
            _buildSectionBody(
              'The CarbonSense name, system design, software, interface, content, features, branding, and other materials associated with the system are owned by or used with authorization by the CarbonSense development team, unless otherwise stated.\n'
              'Users may not copy, reproduce, distribute, modify, sell, or commercially exploit CarbonSense or its materials without prior authorization, except as permitted by applicable law.\n'
              'Users retain responsibility for the content and information they voluntarily submit to the system. By submitting information necessary to operate CarbonSense, users grant us permission to process that information solely as necessary to provide, maintain, improve, research, and operate the system, subject to applicable privacy requirements.',
            ),

            _buildSectionTitle('15. Third-Party Services'),
            _buildSectionBody(
              'CarbonSense may rely on third-party technologies and services to provide certain functionality, including:\n'
              '• Google\'s Gemini AI;\n'
              '• Firebase Cloud Messaging for notifications; and\n'
              '• Vercel and other infrastructure or hosting technologies.\n\n'
              'Third-party services may have their own terms, privacy policies, and data-handling practices.\n'
              'CarbonSense is not responsible for the independent actions, policies, availability, or practices of third-party service providers, except where responsibility cannot be excluded under applicable law.',
            ),

            _buildSectionTitle('16. Availability and Changes to the System'),
            _buildSectionBody(
              'CarbonSense is an evolving system originally developed as a capstone project.\n'
              'We may:\n'
              '• Add, modify, or remove features;\n'
              '• Update calculations or emission factors;\n'
              '• Improve or replace AI models;\n'
              '• Modify missions;\n'
              '• Change system interfaces;\n'
              '• Temporarily suspend access for maintenance; or\n'
              '• Discontinue certain features or the system where necessary.\n\n'
              'We do not guarantee that CarbonSense will always be available without interruption, errors, or technical limitations.',
            ),

            _buildSectionTitle('17. Disclaimer of Warranties'),
            _buildSectionBody(
              'CarbonSense is provided on an "as is" and "as available" basis to the extent permitted by applicable law.\n'
              'We do not guarantee that:\n'
              '• Carbon footprint estimates will always be exact;\n'
              '• AI-generated results will always be accurate;\n'
              '• The system will always be available;\n'
              '• The system will be completely free from errors; or\n'
              '• Every feature will operate without interruption.\n\n'
              'We will make reasonable efforts to maintain and improve the system, but users acknowledge that CarbonSense, particularly as an evolving academic and research-based project, may contain limitations or inaccuracies.',
            ),

            _buildSectionTitle('18. Limitation of Liability'),
            _buildSectionBody(
              'To the extent permitted by applicable law, CarbonSense and its developers will not be liable for losses, damages, or decisions resulting solely from:\n'
              '• Reliance on estimated carbon footprint calculations;\n'
              '• Inaccurate or incomplete AI-generated results;\n'
              '• Incorrect or incomplete information submitted by users;\n'
              '• Temporary system unavailability;\n'
              '• Technical failures beyond reasonable control; or\n'
              '• Changes to system features or calculations.\n\n'
              'Nothing in these Terms is intended to exclude liability where such exclusion is prohibited by applicable law.',
            ),

            _buildSectionTitle('19. Privacy'),
            _buildSectionBody(
              'Your use of CarbonSense is also subject to our Privacy Policy, which will explain how personal information, activity data, location data, and other collected information are handled.\n'
              'By using CarbonSense, you acknowledge that certain information is necessary for providing and improving the system\'s features.',
            ),

            _buildSectionTitle('20. Governing Law'),
            _buildSectionBody(
              'These Terms of Use shall be governed by and interpreted in accordance with the laws of the Republic of the Philippines, subject to applicable laws and regulations.\n'
              'Where appropriate, disputes related to the use of CarbonSense shall be handled through applicable legal or regulatory processes in the Philippines.',
            ),

            _buildSectionTitle('21. Changes to These Terms'),
            _buildSectionBody(
              'We may revise these Terms of Use as CarbonSense develops or as legal, technical, research, or operational requirements change.\n'
              'When significant changes are made, we may provide notice through the application, website, email, or another appropriate method.\n'
              'The "Last Updated" date at the beginning of these Terms will indicate the most recent revision.',
            ),

            _buildSectionTitle('22. Contact Us'),
            _buildSectionBody(
              'If you have questions, concerns, or requests regarding these Terms of Use or the CarbonSense system, you may contact us at:\n'
              'ph.carbonsense@gmail.com\n\n'
              'By creating an account or continuing to use CarbonSense, you acknowledge that you have read and agreed to these Terms of Use.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade800));
  }
}
