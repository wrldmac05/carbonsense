
import 'package:carbonsense/utils/constants.dart';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:carbonsense/theme/app_theme.dart';



class RegisterScreen extends StatefulWidget {

  const RegisterScreen({super.key});



  @override

  State<RegisterScreen> createState() => _RegisterScreenState();

}



class _RegisterScreenState extends State<RegisterScreen> {

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final _fullNameController = TextEditingController();

  bool _isLoading = false;



  Future<void> _register() async {

    final email = _emailController.text.trim();

    final password = _passwordController.text.trim();

    final fullName = _fullNameController.text.trim();



    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Please fill all fields')),

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

      );



      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

              content: Text('Registration successful! Please check your email for verification.')),

        );

        context.push('/login');

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

    _emailController.dispose();

    _passwordController.dispose();

    _fullNameController.dispose();

    super.dispose();

  }



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

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [

                    const Icon(

                      Icons.eco,

                      size: 80,

                      color: AppTheme.primaryColor,

                    ),

                    const SizedBox(height: 16),

                    Text(

                      'Create Account',

                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(

                            color: AppTheme.primaryColor,

                            fontWeight: FontWeight.bold,

                          ),

                    ),

                    const SizedBox(height: 32),

                    TextField(

                      controller: _fullNameController,

                      decoration: const InputDecoration(

                        hintText: 'Full Name',

                      ),

                    ),

                    const SizedBox(height: 16),

                    TextField(

                      controller: _emailController,

                      decoration: const InputDecoration(

                        hintText: 'Email',

                      ),

                      keyboardType: TextInputType.emailAddress,

                    ),

                    const SizedBox(height: 16),

                    TextField(

                      controller: _passwordController,

                      obscureText: true,

                      decoration: const InputDecoration(

                        hintText: 'Password',

                      ),

                    ),

                    const SizedBox(height: 32),

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: _isLoading ? null : _register,

                        child: _isLoading

                            ? const CircularProgressIndicator(color: Colors.white)

                            : const Text('Register'),

                      ),

                    ),

                    const SizedBox(height: 16),

                    TextButton(

                      onPressed: () => context.go('/login'),

                      child: const Text(

                        'Already have an account? Login here',

                        style: TextStyle(color: AppTheme.primaryColor),

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

}


