// auth_screen.dart
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthState { splash, selection, login, register, forgotPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  AuthState _authState = AuthState.splash;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _authState = AuthState.selection;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToLogin() => setState(() => _authState = AuthState.login);
  void _goToRegister() => setState(() => _authState = AuthState.register);
  void _goToForgotPassword() => setState(() => _authState = AuthState.forgotPassword);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    final bool isSplash = _authState == AuthState.splash;

    double sheetHeight = 0;

    switch (_authState) {
      case AuthState.splash:
        sheetHeight = 0;
        break;
      case AuthState.selection:
        sheetHeight = size.height * 0.30;
        break;
      case AuthState.login:
        sheetHeight = isKeyboardOpen ? size.height * 0.85 : size.height * 0.60;
        break;
      case AuthState.register:
        sheetHeight = isKeyboardOpen ? size.height * 0.92 : size.height * 0.70;
        break;
      case AuthState.forgotPassword:
        sheetHeight = isKeyboardOpen ? size.height * 0.75 : size.height * 0.48;
        break;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. BACKGROUND
          Positioned.fill(child: Image.asset('assets/images/bg2.png', fit: BoxFit.cover)),

          // 2. DYNAMIC HEADERS
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            top: isSplash ? size.height * 0.25 : 0,
            left: 0,
            right: 0,
            height: isSplash ? size.height * 0.5 : (size.height - sheetHeight),
            child: SafeArea(
              bottom: false,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: _getTopHeader()),
              ),
            ),
          ),

          // 3. BOTTOM SHEET
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            bottom: isSplash ? -sheetHeight : 0,
            left: 0,
            right: 0,
            height: sheetHeight,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(45), topRight: Radius.circular(45)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(45), topRight: Radius.circular(45)),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(alignment: Alignment.topCenter, children: <Widget>[...previousChildren, if (currentChild != null) currentChild]);
                  },
                  child: _getBottomSheetContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header Routing ---
  Widget _getTopHeader() {
    switch (_authState) {
      case AuthState.splash:
        return _buildSplashHeader(key: const ValueKey('splash'));
      case AuthState.selection:
        return _buildSelectionHeader(key: const ValueKey('selection'));
      case AuthState.login:
      case AuthState.register:
      case AuthState.forgotPassword:
        return const SizedBox.shrink(key: ValueKey('empty_header'));
    }
  }

  // --- Bottom Sheet Routing ---
  Widget _getBottomSheetContent() {
    switch (_authState) {
      case AuthState.splash:
        return const SizedBox(key: ValueKey('empty_sheet'));
      case AuthState.selection:
        return _SelectionButtonsWidget(key: const ValueKey('selection_sheet'), onGoToLogin: _goToLogin, onGoToRegister: _goToRegister);
      case AuthState.login:
        return _LoginForm(key: const ValueKey('login_sheet'), onGoToRegister: _goToRegister, onGoToForgotPassword: _goToForgotPassword);
      case AuthState.register:
        return _RegisterForm(key: const ValueKey('register_sheet'), onGoToLogin: _goToLogin);
      case AuthState.forgotPassword:
        return _ForgotPasswordForm(key: const ValueKey('forgot_password_sheet'), onGoToLogin: _goToLogin);
    }
  }

  Widget _buildSharedTitleAndLogo({bool showDescription = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, size: 50, color: AppTheme.primaryColor),
            const SizedBox(width: 1),
            const Text(
              'CarbonSense',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ],
        ),
        if (showDescription) ...[
          const SizedBox(height: 10),
          const Text(
            'Your AI-driven Carbon Footprint tracker',
            style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildSplashHeader({Key? key}) {
    return Container(
      key: key,
      width: MediaQuery.of(context).size.width,
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(opacity: _fadeAnimation, child: _buildSharedTitleAndLogo(showDescription: true)),
      ),
    );
  }

  Widget _buildSelectionHeader({Key? key}) {
    return Container(
      key: key,
      width: MediaQuery.of(context).size.width,
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(top: 350.0),
      child: _buildSharedTitleAndLogo(showDescription: true),
    );
  }
}

// ============================================================================
// SELECTION BUTTONS WIDGET
// ============================================================================
class _SelectionButtonsWidget extends StatefulWidget {
  final VoidCallback onGoToLogin;
  final VoidCallback onGoToRegister;

  const _SelectionButtonsWidget({super.key, required this.onGoToLogin, required this.onGoToRegister});

  @override
  State<_SelectionButtonsWidget> createState() => _SelectionButtonsWidgetState();
}

class _SelectionButtonsWidgetState extends State<_SelectionButtonsWidget> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push('/terms-of-use');
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push('/privacy-policy');
      };
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              onPressed: widget.onGoToLogin,
              child: const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                  side: const BorderSide(color: AppTheme.primaryColor, width: 1),
                ),
                elevation: 0,
              ),
              onPressed: widget.onGoToRegister,
              child: const Text('SIGN UP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 20),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    recognizer: _termsRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    recognizer: _privacyRecognizer,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOGIN FORM WIDGET
// ============================================================================
class _LoginForm extends StatefulWidget {
  final VoidCallback onGoToRegister;
  final VoidCallback onGoToForgotPassword;

  const _LoginForm({super.key, required this.onGoToRegister, required this.onGoToForgotPassword});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  void _showCustomBanDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFED7D7), width: 2),
                ),
                child: const Center(child: Text('🚫', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Color(0xFF718096), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Acknowledge', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());

      if (response.user != null) {
        final profile = await Supabase.instance.client.from('user_profiles').select('is_banned, is_archived').eq('user_id', response.user!.id).maybeSingle();

        if (profile != null) {
          final isBanned = profile['is_banned'] as bool? ?? false;
          final isArchived = profile['is_archived'] as bool? ?? false;

          if (isBanned || isArchived) {
            await Supabase.instance.client.auth.signOut();
            if (mounted) {
              _showCustomBanDialog(
                title: isBanned ? 'Account Suspended' : 'Account Archived',
                message: isBanned ? 'Your account has been suspended by an administrator due to violations of platform terms.' : 'Your account has been archived. Please contact support.',
              );
            }
            return;
          }
        }

        if (mounted) context.go('/home');
      }
    } on AuthException catch (e) {
      if (mounted) {
        final errorMsg = e.message.toLowerCase();
        if (errorMsg.contains('banned') || e.statusCode == '400') {
          _showCustomBanDialog(title: 'Account Suspended', message: 'Your account is currently suspended. Access is restricted by an administrator.');
        } else {
          setState(() {
            _errorMessage = 'Incorrect email or password. Please try again.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Incorrect email or password. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Static Header
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 36, 28, 12),
            child: Text(
              'Log In',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          // Scrollable Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, 12, 28, 20 + bottomInset),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (val) {
                      if (_errorMessage != null) setState(() => _errorMessage = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(fontSize: 18, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
                      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter your email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    obscureText: _obscurePassword,
                    onChanged: (val) {
                      if (_errorMessage != null) setState(() => _errorMessage = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(fontSize: 18, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
                      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onGoToForgotPassword,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      GestureDetector(
                        onTap: widget.onGoToRegister,
                        child: const Text(
                          'SIGN UP',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FORGOT PASSWORD FORM WIDGET
// ============================================================================
class _ForgotPasswordForm extends StatefulWidget {
  final VoidCallback onGoToLogin;
  const _ForgotPasswordForm({super.key, required this.onGoToLogin});

  @override
  State<_ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<_ForgotPasswordForm> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email address.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: 'io.supabase.carbonsense://reset-password');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery link sent! Check your inbox.'), backgroundColor: Colors.green));
        widget.onGoToLogin();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${error.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 36, 28, 20 + bottomInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: widget.onGoToLogin,
              ),
              const SizedBox(width: 12),
              const Text(
                'Reset Password',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Enter your email to receive a password reset link.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: const TextStyle(fontSize: 18, color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
              errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter your email';
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _resetPassword,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Send Recovery Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REGISTER FORM WIDGET
// ============================================================================
class _RegisterForm extends StatefulWidget {
  final VoidCallback onGoToLogin;
  const _RegisterForm({super.key, required this.onGoToLogin});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push('/terms-of-use');
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push('/privacy-policy');
      };
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
    if (!_formKey.currentState!.validate()) return;

    if (!_hasMinLength || !_hasUppercase || !_hasNumber) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please ensure your password meets all requirements.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'full_name': _fullNameController.text.trim()},
        emailRedirectTo: 'io.supabase.carbonsense://login',
      );
      if (mounted) _showSuccessDialog(_emailController.text.trim());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: ${error.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Almost There!'),
        content: Text('We sent a verification link to $email. Please confirm it.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onGoToLogin();
            },
            child: const Text('Continue to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.radio_button_unchecked, color: isMet ? Colors.green : Colors.grey, size: 14),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: isMet ? Colors.green : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Static Header
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 36, 28, 12),
            child: Text(
              'Sign Up',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          // Scrollable Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, 12, 28, 20 + bottomInset),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
                      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter full name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
                      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter email';
                      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegExp.hasMatch(value)) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
                      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildRequirement('At least 6 characters', _hasMinLength),
                  _buildRequirement('At least 1 uppercase letter', _hasUppercase),
                  _buildRequirement('At least 1 number', _hasNumber),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _confirmPasswordController,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(fontSize: 16, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1)),
                      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                      children: [
                        const TextSpan(text: 'By signing up, you agree to our '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          recognizer: _termsRecognizer,
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          recognizer: _privacyRecognizer,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SIGN UP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      GestureDetector(
                        onTap: widget.onGoToLogin,
                        child: const Text(
                          'LOG IN',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
