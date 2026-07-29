import 'package:carbonsense/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // 🌟 ADDED: Required for making text interactive
import 'package:go_router/go_router.dart';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;

  // 🌟 ADDED: Gesture Recognizers for the clickable text
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  // Place this variable inside your _RegisterScreenState class, right above initState
  final String _rawTermsContent = '''
TERMS AND CONDITIONS
Last updated: May 18, 2026

AGREEMENT TO OUR LEGAL TERMS
We are CarbonSense Corp. ("Company," "we," "us," "our"), a company registered in the Philippines at Imus, Cavite 4103. We operate the website http://www.carbonsense.com, the mobile application CarbonSense, as well as any other related products and services that refer or link to these legal terms (collectively, the "Services").

CarbonSense is a utility app used for tracking your carbon footprint through your daily activities to help save the environment and make a big impact on nature. CarbonSense also provides an AI-generated summary of your total carbon footprint emissions and offers alternatives to reduce your footprint emissions.

1. OUR SERVICES
The information provided when using the Services is not intended for distribution to or use by any person or entity in any jurisdiction or country where such distribution or use would be contrary to law or regulation.

2. INTELLECTUAL PROPERTY RIGHTS
We are the owner or the licensee of all intellectual property rights in our Services, including all source code, databases, functionality, software, website designs, audio, video, text, photographs, and graphics.

3. USER REPRESENTATIONS
By using the Services, you represent and warrant that all registration information you submit will be true, accurate, current, and complete, and that you have the legal capacity to comply with these terms.

4. USER REGISTRATION
You may be required to register to use the Services. You agree to keep your password confidential and will be responsible for all use of your account and password.

5. PURCHASES AND PAYMENT
You agree to provide current, complete, and accurate purchase and account information for all purchases made via the Services.

6. SOFTWARE
Any software provided in connection with our Services is provided "AS IS" without warranty of any kind, either express or implied.

7. PROHIBITED ACTIVITIES
You may not access or use the Services for any purpose other than that for which we make the Services available. Prohibited acts include systematic data scraping, fraud, or deliberately sabotaging the system's service.

8. USER GENERATED CONTRIBUTIONS
The Services do not currently offer users the ability to submit or publicize public user-generated content.

9. CONTRIBUTION LICENSE
You and the Services agree that we may access, store, process, and use any information and personal data that you provide following your settings choices.

10. MOBILE APPLICATION LICENSE
We grant you a revocable, non-exclusive, non-transferable, limited right to install and use the mobile app on wireless electronic devices owned or controlled by you.

11. SERVICES MANAGEMENT
We reserve the right, but not the obligation, to monitor the Services for violations of these Legal Terms and take appropriate legal action.

12. TERM AND TERMINATION
These Legal Terms shall remain in full force and effect while you use the Services. We reserve the right to terminate accounts at any time in our sole discretion.

13. MODIFICATIONS AND INTERRUPTIONS
We reserve the right to change, modify, or remove the contents of the Services at any time or for any reason at our sole discretion without notice.

14. GOVERNING LAW
These Legal Terms shall be governed by and defined following the laws of the Philippines.

15. DISPUTE RESOLUTION
Any dispute arising out of these terms shall be referred to and finally resolved by informal negotiations for 30 days, or binding arbitration seated in Manila, Philippines.

16. CORRECTIONS
There may be information on the Services that contains typographical errors, inaccuracies, or omissions. We reserve the right to correct them without notice.

17. DISCLAIMER
THE SERVICES ARE PROVIDED ON AN AS-IS AND AS-AVAILABLE BASIS. YOU AGREE THAT YOUR USE OF THE SERVICES WILL BE AT YOUR SOLE RISK.

18. LIMITATIONS OF LIABILITY
IN NO EVENT WILL WE OR OUR DIRECTORS, EMPLOYEES, OR AGENTS BE LIABLE TO YOU FOR ANY DIRECT, INDIRECT, CONSEQUENTIAL, OR PUNITIVE DAMAGES.

19. INDEMNIFICATION
You agree to defend, indemnify, and hold us harmless from and against any loss, damage, liability, or claim arising out of your misuse of the Services.

20. USER DATA
We will maintain certain data that you transmit to the Services for the purpose of managing the performance of the app. You are solely responsible for all data backup.

21. ELECTRONIC COMMUNICATIONS
Visiting the Services, sending us emails, and completing online forms constitute electronic communications. You consent to receive electronic communications.

22. MISCELLANEOUS
These Legal Terms constitute the entire agreement between you and us. If any part is unenforceable, it does not affect the remaining provisions.

23. CONTACT US
To resolve a complaint or receive further info, contact us at:
CarbonSense Corp.
Imus, Cavite 4103
Philippines
carbonsense@gmail.com
''';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);

    // 🌟 ADDED: Initialize the recognizers to open our custom dialogs
    _termsRecognizer = TapGestureRecognizer()..onTap = _showTermsDialog;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _showPrivacyDialog;
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 6;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
    });
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        fullName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (!_hasMinLength || !_hasUppercase || !_hasNumber) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please ensure your password meets all requirements.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: 'io.supabase.carbonsense://login',
      );

      if (mounted) {
        _showSuccessDialog(email);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${error.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();

    // 🌟 ADDED: Dispose recognizers to prevent memory leaks
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  // 🌟 UPGRADED: Replaces the small alert box with an elegant scrollable legal viewer sheet
  void _showTermsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Allows the sheet to take up the full target height
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          height:
              MediaQuery.of(context).size.height *
              0.85, // Takes up 85% of screen
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual handle line at the top
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Top Sticky Header Section
              const Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: AppTheme.primaryColor,
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Terms & Conditions",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Infinite Scroll Window for your text content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      _rawTermsContent,
                      style: TextStyle(
                        height: 1.6,
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Action Button Sticky Anchor
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    "I Accept & Understand",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 NEW: Data Privacy Act Educational Dialog
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.security, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Data Privacy Act of 2012",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              "Republic Act No. 10173\n\n"
              "The Data Privacy Act of the Philippines protects your fundamental human right to privacy. It ensures that your personal information is:\n\n"
              "• Collected only for specific and legitimate purposes.\n"
              "• Processed fairly, safely, and lawfully.\n"
              "• Secured against unauthorized access or breaches.\n\n"
              "At CarbonSense, we strictly adhere to this law. Your credentials, logs, and lifestyle data are encrypted securely on our backend and will never be sold or shared without your direct consent.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Close",
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper widget for the visual checklist
  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: AppTheme.primaryColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Almost There!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 12),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a verification link to\n'),
                      TextSpan(
                        text: email,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '.\n\nPlease confirm your email to activate your account and access the Eco-Coach dashboard.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/login');
                    },
                    child: const Text(
                      'Continue to Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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

  @override
  Widget build(BuildContext context) {
    // 🌟 Make sure to define this in your StatefulWidget's State class:
    // final _formKey = GlobalKey<FormState>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                // 🌟 Wrap the Column in a Form to enable validation
                child: Form(
                  key: _formKey, // 🌟 Assign the form key here
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.eco,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Create Account',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _fullNameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          hintText: 'Full Name',
                        ),
                        // 🌟 ADD THIS BLOCK:
                        inputFormatters: [
                          // 1. Only allow letters and spaces (rejects numbers/special chars)
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z ]'),
                          ),
                          // 2. Reject double spaces (two or more spaces in a row)
                          FilteringTextInputFormatter.deny(RegExp(r' {2,}')),
                          // 3. Reject a space as the very first character
                          FilteringTextInputFormatter.deny(RegExp(r'^ ')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          // You can still keep a basic validator to ensure they didn't just type one letter
                          if (value.trim().length < 2) {
                            return 'Name is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- EMAIL FIELD ---
                      TextFormField(
                        controller: _emailController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(hintText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          // Standard email format validation
                          final emailRegExp = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegExp.hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- PASSWORD FIELD ---
                      TextFormField(
                        controller: _passwordController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Password'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'Must contain at least 1 uppercase letter';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'Must contain at least 1 number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- CONFIRM PASSWORD FIELD ---
                      TextFormField(
                        controller: _confirmPasswordController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Confirm Password',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      _buildRequirement('At least 6 characters', _hasMinLength),
                      _buildRequirement(
                        'At least 1 uppercase letter',
                        _hasUppercase,
                      ),
                      _buildRequirement('At least 1 number', _hasNumber),
                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: 'By signing up, you agree to our ',
                              ),
                              TextSpan(
                                text: 'Terms and Conditions',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: '.\n\n'),
                              const TextSpan(
                                text:
                                    '🔒 Your data is secured and encrypted in compliance with the ',
                              ),
                              TextSpan(
                                text: 'Data Privacy Act',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          // 🌟 UPDATED: You can now validate the form before submitting
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    _register();
                                  }
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Register'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text(
                            'Already have an account? Login here',
                            style: TextStyle(color: AppTheme.primaryColor),
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
      ),
    );
  }
}
