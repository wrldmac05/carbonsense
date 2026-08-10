import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FFF9),
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
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
                    'CarbonSense Privacy Policy',
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
              'CarbonSense is an AI-driven recommendation system originally developed as a capstone project by students of National University Dasmariñas (NU Dasmariñas). The system is designed to help users understand, monitor, and mitigate their personal carbon footprint based on self-reported activities and AI-assisted analysis.\n\n'
              'This Privacy Policy explains how CarbonSense collects, uses, stores, processes, shares, and protects information when you use our mobile application, website, and related services.\n\n'
              'By creating an account or using CarbonSense, you acknowledge the data practices described in this Privacy Policy.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Sections
            _buildSectionTitle('1. Information We Collect'),
            _buildSectionBody('Depending on how you use CarbonSense, we may collect the following information.'),

            _buildSubSectionTitle('1.1 Account and Profile Information'),
            _buildSectionBody(
              'When you create or use a CarbonSense account, we may collect:\n'
              '• Full name;\n'
              '• Email address;\n'
              '• Profile picture;\n'
              '• Account credentials, including securely managed authentication information;\n'
              '• Account creation and account-related information; and\n'
              '• Other information you voluntarily provide through your profile.',
            ),

            _buildSubSectionTitle('1.2 Activity and Carbon Footprint Information'),
            _buildSectionBody(
              'To provide carbon-footprint tracking and recommendations, we may collect information about activities that you manually enter or submit through AI-assisted features, including:\n'
              '• Daily activities;\n'
              '• Transportation habits;\n'
              '• Food and dietary information;\n'
              '• Food consumption activities;\n'
              '• Electricity usage;\n'
              '• Electricity bill information voluntarily submitted for analysis;\n'
              '• Carbon-footprint activity logs;\n'
              '• Weekly mission progress and completion;\n'
              '• Estimated carbon-footprint results; and\n'
              '• Other activity information necessary to generate estimates, summaries, and recommendations.\n\n'
              'CarbonSense primarily relies on self-reported information. The accuracy of estimates may depend on the completeness and accuracy of the information provided by users.',
            ),

            _buildSubSectionTitle('1.3 Images and Documents Submitted for AI Analysis'),
            _buildSectionBody(
              'When you use AI-assisted features, you may voluntarily submit images or documents, such as:\n'
              '• Images of food; and\n'
              '• Electricity bills or similar documents containing electricity consumption information.\n\n'
              'These submissions may be processed to provide features such as food identification, ingredient detection, estimated food weight, emission-factor categorization, electricity consumption estimation, carbon-footprint calculation, summaries, and recommendations.\n'
              'Please avoid submitting unnecessary sensitive or confidential information.',
            ),

            _buildSubSectionTitle('1.4 Location and GPS Data'),
            _buildSectionBody(
              'CarbonSense may collect location-related information, including GPS or geographical data, when you permit access through your device.\n'
              'Location information may be used for:\n'
              '• Research and future studies;\n'
              '• Improving carbon-footprint estimation;\n'
              '• Improving AI-driven recommendations;\n'
              '• Understanding activity patterns;\n'
              '• System development and improvement; and\n'
              '• Supporting future location-based or research-related features.\n\n'
              'You may be able to control location permissions through your device settings. However, disabling location access may affect the availability or accuracy of certain current or future CarbonSense features.',
            ),

            _buildSubSectionTitle('1.5 Device and Technical Information'),
            _buildSectionBody(
              'We may automatically or indirectly collect limited technical information necessary to operate and secure the system, such as:\n'
              '• Device or application information;\n'
              '• Operating system information;\n'
              '• Notification-related identifiers;\n'
              '• IP address or network-related information;\n'
              '• Application activity related to system operation;\n'
              '• Error and diagnostic information; and\n'
              '• Security-related logs.\n\n'
              'The exact information collected may depend on the technologies and third-party services used by CarbonSense.',
            ),

            _buildSectionTitle('2. How We Collect Information'),
            _buildSectionBody(
              'We may collect information in the following ways:\n'
              '• Directly from information you enter during account registration;\n'
              '• From activities you manually log through CarbonSense;\n'
              '• From images or documents you voluntarily submit for AI-assisted analysis;\n'
              '• From location permissions granted through your device;\n'
              '• From your interactions with the application\'s features;\n'
              '• From system-generated activity and calculation results; and\n'
              '• From third-party services that provide necessary infrastructure, notifications, authentication, AI processing, or other system functionality.',
            ),

            _buildSectionTitle('3. How We Use Your Information'),
            _buildSectionBody(
              'We may use collected information to:\n'
              '• Create and manage your account;\n'
              '• Authenticate your identity and maintain account security;\n'
              '• Calculate and estimate your carbon footprint;\n'
              '• Analyze submitted food images;\n'
              '• Analyze electricity bills and electricity consumption;\n'
              '• Generate activity summaries;\n'
              '• Generate daily, weekly, monthly, and other carbon-footprint summaries;\n'
              '• Generate AI-driven recommendations;\n'
              '• Track and validate weekly missions;\n'
              '• Apply eligible mission-related carbon-footprint adjustments;\n'
              '• Provide notifications;\n'
              '• Operate and maintain the mobile application and website;\n'
              '• Monitor system performance and security;\n'
              '• Improve system features and user experience;\n'
              '• Improve carbon-footprint estimation methods;\n'
              '• Evaluate and improve AI-assisted features;\n'
              '• Conduct academic and research-related analysis;\n'
              '• Develop future features;\n'
              '• Generate aggregated or de-identified statistics; and\n'
              '• Comply with applicable legal, academic, or institutional requirements.',
            ),

            _buildSectionTitle('4. AI Processing and Google Gemini'),
            _buildSectionBody(
              'CarbonSense uses Google\'s Gemini AI through an API to support certain AI-assisted features.\n'
              'Depending on the feature you use, information may be processed to:\n'
              '• Analyze food images;\n'
              '• Identify or describe food;\n'
              '• Detect possible ingredients;\n'
              '• Estimate food weight;\n'
              '• Identify relevant emission-factor categories;\n'
              '• Estimate carbon-footprint values;\n'
              '• Analyze electricity bills;\n'
              '• Estimate electricity consumption;\n'
              '• Generate personal summaries;\n'
              '• Generate monthly summaries;\n'
              '• Generate aggregated dashboard summaries; and\n'
              '• Generate administrative summaries based on available system data.\n\n'
              'AI-generated results are estimates and may be incomplete, inaccurate, or incorrect.\n'
              'Information submitted to an AI-assisted feature may be processed through the applicable AI service to provide the requested functionality. CarbonSense does not guarantee that AI-generated results are scientifically exact or error-free.\n'
              'We may also use appropriately processed system data to evaluate and improve the accuracy and performance of CarbonSense and its AI-assisted features.',
            ),

            _buildSectionTitle('5. Carbon Footprint Calculations'),
            _buildSectionBody(
              'CarbonSense provides estimated carbon-footprint results based on user-provided information, AI-assisted analysis, applicable emission factors, and system assumptions.\n'
              'Results may vary depending on:\n'
              '• The accuracy of self-reported activities;\n'
              '• The completeness of submitted information;\n'
              '• The quality of submitted images or documents;\n'
              '• AI interpretation;\n'
              '• Estimated food weight or ingredients;\n'
              '• Activity categorization;\n'
              '• Electricity consumption data;\n'
              '• Available emission factors; and\n'
              '• Changes to calculation methods.\n\n'
              'CarbonSense results should be understood as estimates and are not guaranteed measurements of actual emissions.',
            ),

            _buildSectionTitle('6. Firebase Cloud Messaging'),
            _buildSectionBody(
              'CarbonSense may use Firebase Cloud Messaging (FCM) to send notifications to your device.\n'
              'Notifications may include information related to:\n'
              '• Weekly missions;\n'
              '• Activity reminders;\n'
              '• Carbon-footprint tracking;\n'
              '• Account-related information;\n'
              '• System updates; and\n'
              '• Other CarbonSense features.\n\n'
              'To provide notifications, FCM may process technical information or identifiers associated with your device or application.\n'
              'You may manage or disable notifications through your device settings, subject to the features and capabilities of your device and operating system.',
            ),

            _buildSectionTitle('7. Vercel and Website Infrastructure'),
            _buildSectionBody(
              'The CarbonSense website may use Vercel for website hosting, deployment, delivery, and related infrastructure services.\n'
              'When you access the CarbonSense website, Vercel or related infrastructure may process certain technical information necessary to deliver and secure the website, such as network, device, browser, request, and log information.\n'
              'The processing of such information may also be subject to the applicable privacy practices of Vercel and other infrastructure providers used by CarbonSense.',
            ),

            _buildSectionTitle('8. How We Share or Disclose Information'),
            _buildSectionBody(
              'CarbonSense does not sell your personal information.\nWe may share or disclose information only when reasonably necessary for purposes described in this Privacy Policy, including with:',
            ),

            _buildSubSectionTitle('8.1 Service Providers'),
            _buildSectionBody(
              'Third-party providers that help us operate CarbonSense, including services related to:\n'
              '• AI processing;\n'
              '• Notifications;\n'
              '• Website hosting and deployment;\n'
              '• Database or backend infrastructure;\n'
              '• Authentication;\n'
              '• Cloud storage; and\n'
              '• System security and maintenance.',
            ),

            _buildSubSectionTitle('8.2 Academic and Research Purposes'),
            _buildSectionBody(
              'Because CarbonSense was developed as a capstone and may continue to support academic or future research, appropriately processed information may be used for:\n'
              '• Research;\n'
              '• System evaluation;\n'
              '• Improving carbon-footprint models;\n'
              '• Improving AI-assisted features;\n'
              '• Academic presentations or studies; and\n'
              '• Future system development.\n\n'
              'Whenever reasonably possible and appropriate for the purpose, research information should be anonymized, de-identified, or aggregated before being used or presented.',
            ),

            _buildSubSectionTitle('8.3 Legal or Security Reasons'),
            _buildSectionBody(
              'We may disclose information when reasonably necessary to:\n'
              '• Comply with applicable laws or lawful requests;\n'
              '• Protect the security and integrity of CarbonSense;\n'
              '• Investigate suspected fraud or misuse;\n'
              '• Protect the rights and safety of users or others; or\n'
              '• Enforce our Terms of Use.',
            ),

            _buildSectionTitle('9. Aggregated and De-Identified Information'),
            _buildSectionBody(
              'We may create aggregated, anonymized, or de-identified information from data collected through CarbonSense.\n'
              'This information may be used to:\n'
              '• Analyze general carbon-footprint patterns;\n'
              '• Generate global dashboard statistics;\n'
              '• Support academic research;\n'
              '• Evaluate system performance;\n'
              '• Improve calculation methods;\n'
              '• Improve AI-driven recommendations; and\n'
              '• Support future studies.\n\n'
              'Where information has been properly anonymized or de-identified so that it is no longer reasonably linked to an identifiable individual, it may be retained and used for research and system improvement purposes.',
            ),

            _buildSectionTitle('10. Account Deletion and Archived Research Data'),
            _buildSectionBody(
              'Users may delete their CarbonSense accounts through available account deletion features or procedures.\n'
              'When an account is deleted:\n'
              '• The account will no longer be available for normal user access;\n'
              '• The account may be removed from active system use;\n'
              '• Certain associated information may be archived rather than immediately and permanently erased; and\n'
              '• Archived information may be retained for legitimate research, academic, system improvement, security, integrity, and future study purposes.\n\n'
              'Where reasonably possible, archived data intended for long-term research or system improvement should be anonymized, de-identified, or separated from direct identifiers.\n'
              'Deletion of an account does not necessarily mean that all information is immediately and permanently erased, particularly where information must be retained for legitimate academic, research, security, integrity, legal, or operational purposes.\n'
              'We will handle deletion and retention requests in accordance with applicable law and our legitimate system, academic, and research requirements.',
            ),

            _buildSectionTitle('11. Data Retention'),
            _buildSectionBody(
              'We retain information for as long as reasonably necessary to:\n'
              '• Provide and operate CarbonSense;\n'
              '• Maintain your account;\n'
              '• Calculate and maintain relevant activity history;\n'
              '• Support research and academic purposes;\n'
              '• Improve the accuracy and functionality of the system;\n'
              '• Protect system security and integrity;\n'
              '• Comply with applicable legal or institutional requirements; and\n'
              '• Resolve technical, security, or operational issues.\n\n'
              'Active account information may be retained while your account remains active.\n'
              'After account deletion, certain information may be retained in archived, anonymized, de-identified, aggregated, or otherwise appropriately processed form for research, academic, system improvement, or legitimate operational purposes.\n'
              'The specific retention period may vary depending on the type of information and the purpose for which it is retained.',
            ),

            _buildSectionTitle('12. Data Security'),
            _buildSectionBody(
              'We take reasonable technical and organizational measures to help protect information against unauthorized access, alteration, disclosure, loss, or misuse.\n'
              'However, no method of electronic transmission, cloud storage, or internet-based service is completely secure. Therefore, while we take reasonable steps to protect information, we cannot guarantee absolute security.\n'
              'Users are responsible for maintaining the confidentiality of their passwords and taking reasonable precautions to protect their accounts and devices.',
            ),

            _buildSectionTitle('13. Children\'s Privacy'),
            _buildSectionBody(
              'CarbonSense is intended for users who are at least 12 years old.\n'
              'We do not intentionally design the system for children below this minimum age.\n'
              'If we become aware that information has been collected from a user below the minimum age in a manner that does not comply with applicable legal requirements, we may take appropriate steps to restrict, delete, or otherwise manage the account and information.\n'
              'Where parental or guardian consent is required under applicable law, a parent or legal guardian should provide the necessary consent before a minor uses CarbonSense.',
            ),

            _buildSectionTitle('14. Your Choices and Controls'),
            _buildSectionBody(
              'Depending on the available features and applicable law, you may be able to:\n'
              '• Access and update certain account information;\n'
              '• Change profile information;\n'
              '• Control device permissions, including location access;\n'
              '• Enable or disable notifications;\n'
              '• Request account deletion;\n'
              '• Contact us regarding questions or concerns about your information; and\n'
              '• Exercise other rights available under applicable privacy laws.\n\n'
              'Some information may be necessary for certain CarbonSense features. Restricting access to such information may limit the functionality or accuracy of the system.',
            ),

            _buildSectionTitle('15. Third-Party Services'),
            _buildSectionBody(
              'CarbonSense may use third-party services, including:\n'
              '• Google Gemini for AI-assisted features;\n'
              '• Firebase Cloud Messaging for notifications;\n'
              '• Vercel for website hosting and deployment; and\n'
              '• Other technology providers necessary for authentication, databases, cloud infrastructure, storage, security, or system operation.\n\n'
              'These third parties may process information according to their own applicable privacy practices and contractual arrangements.\n'
              'We encourage users to review the privacy policies of relevant third-party services where appropriate.',
            ),

            _buildSectionTitle('16. International Data Processing'),
            _buildSectionBody(
              'Some of the third-party services used by CarbonSense may process or store information using infrastructure located outside the Philippines.\n'
              'By using CarbonSense, you understand that information may be processed in locations where our service providers operate, subject to applicable privacy and data protection requirements.\n'
              'We will take reasonable steps to ensure that international processing is handled in a manner consistent with applicable laws and appropriate data protection requirements.',
            ),

            _buildSectionTitle('17. Philippine Privacy Law'),
            _buildSectionBody(
              'CarbonSense is intended to operate in accordance with applicable privacy and data protection requirements in the Philippines, including the Data Privacy Act of 2012 (Republic Act No. 10173) and other applicable rules and regulations.\n'
              'Nothing in this Privacy Policy is intended to limit rights that users may have under applicable data protection laws.\n'
              'If you believe that your personal information has been handled improperly or if you have concerns regarding your privacy, you may contact us using the information provided below.',
            ),

            _buildSectionTitle('18. Changes to This Privacy Policy'),
            _buildSectionBody(
              'We may update this Privacy Policy as CarbonSense develops, introduces new features, changes its data practices, or becomes publicly available.\n'
              'When significant changes are made, we may provide notice through the application, website, email, or another appropriate method.\n'
              'The "Last Updated" date at the beginning of this Privacy Policy will indicate when it was most recently revised.',
            ),

            _buildSectionTitle('19. Contact Us'),
            _buildSectionBody(
              'If you have questions, concerns, requests, or feedback regarding this Privacy Policy or your personal information, please contact us at:\n'
              'ph.carbonsense@gmail.com\n\n'
              'By using CarbonSense, you acknowledge that you have read and understood this Privacy Policy and agree to the collection, use, processing, and retention of information as described in this Policy, subject to applicable law.',
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

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade800));
  }
}
