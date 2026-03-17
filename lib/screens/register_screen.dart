
import 'package:carbonsense/theme/app_theme.dart';

import 'package:flutter/material.dart';



class RegisterScreen extends StatelessWidget {

  const RegisterScreen({super.key});



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

                    const TextField(

                      decoration: InputDecoration(

                        hintText: 'Email',

                      ),

                    ),

                    const SizedBox(height: 16),

                    const TextField(

                      decoration: InputDecoration(

                        hintText: 'Username',

                      ),

                    ),

                    const SizedBox(height: 16),

                    const TextField(

                      obscureText: true,

                      decoration: InputDecoration(

                        hintText: 'Password',

                      ),

                    ),

                    const SizedBox(height: 16),

                    const TextField(

                      obscureText: true,

                      decoration: InputDecoration(

                        hintText: 'Confirm Password',

                      ),

                    ),

                    const SizedBox(height: 32),

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: () =>

                            Navigator.pushReplacementNamed(context, '/main-navigation'),

                        child: const Text('Register'),

                      ),

                    ),

                    const SizedBox(height: 16),

                    TextButton(

                      onPressed: () => Navigator.pop(context),

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