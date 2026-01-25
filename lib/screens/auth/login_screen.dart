import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  final String? role;
  
  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your username or email')),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Trim inputs before sending
    final emailOrUsername = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    print('Frontend - Email/Username: $emailOrUsername');
    print('Frontend - Password length: ${password.length}');

    final result = await ApiService.login(
      username: emailOrUsername,
      password: password,
    );

    setState(() => _isLoading = false);
    
    print('Frontend - Login result: $result');

    if (mounted) {
      if (result['success'] == true) {
        final userData = result['data']?['user'];
        final responseData = result['data'];
        
        if (userData != null && userData['role'] == 'provider') {
          // Check if onboarding is incomplete from login response
          final onboardingComplete = responseData['onboarding_complete'] ?? true;
          
          if (onboardingComplete == false) {
            // Onboarding not complete, redirect to onboarding step 1
            print('📍 Provider onboarding incomplete, redirecting to step 1');
            if (mounted) {
              context.go('/provider-onboarding/step1');
            }
            return;
          }
          
          // Onboarding is complete, check verification status
          final statusResult = await ApiService.getProviderStatus(forceRefresh: false);
          if (statusResult['success'] == true) {
            final statusData = statusResult['data'];
            if (statusData['can_login'] == true) {
              // Re-register FCM token after successful login
              await PushNotificationService.reRegisterToken();
              context.go('/home');
            } else {
              // Show verification pending message
              final verificationStatus = statusData['verification_status'] ?? 'unknown';
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Verification Pending'),
                  content: Text(
                    verificationStatus == 'pending'
                        ? 'Your account is pending verification. Please wait for admin approval.'
                        : 'Your account verification is $verificationStatus. Please contact support.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Logout since they can't access the app
                        ApiService.logout();
                        if (mounted) context.go('/role-select');
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          } else {
            // Status check failed, but onboarding is complete
            // Try to go to home anyway
            await PushNotificationService.reRegisterToken();
            context.go('/home');
          }
        } else {
          // Re-register FCM token after successful login
          await PushNotificationService.reRegisterToken();
          context.go('/home');
        }
      } else {
        final error = result['error'];
        
        // Check if error is due to incomplete onboarding
        if (error is Map && error['onboarding_complete'] == false) {
          // Onboarding not complete, redirect to onboarding step 1
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please complete onboarding to continue'),
                duration: Duration(seconds: 2),
              ),
            );
            context.go('/provider-onboarding/step1');
          }
          return;
        }
        
        String errorMessage = 'Login failed';
        List<String> errorMessages = [];
        
        if (error is Map) {
          if (error.containsKey('error')) {
            final errorValue = error['error'];
            if (errorValue is List) {
              errorMessages = errorValue.map((e) => e.toString()).toList();
            } else {
              errorMessages = [errorValue.toString()];
            }
          } else if (error.containsKey('message')) {
            errorMessages = [error['message'].toString()];
          } else {
            // Collect all error messages
            error.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                errorMessages.addAll(value.map((e) => e.toString()));
              } else if (value is String) {
                errorMessages.add(value);
              }
            });
          }
        }
        
        if (errorMessages.isEmpty) {
          errorMessages = [errorMessage];
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessages.join('\n')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => context.go('/role-select'),
                icon: Icon(
                  Iconsax.arrow_left,
                  color: context.foregroundColor,
                ),
                tooltip: 'Back to role selection',
              ).animate().fadeIn(duration: 500.ms),
              
              const SizedBox(height: 16),
              
              // Header
              Text(
                'Hello !',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 4),
              
              Text(
                'WELCOME BACK',
                style: TextStyle(
                  color: context.foregroundColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 40),

              // Email field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email',
                    style: TextStyle(
                      color: context.mutedForegroundColor,
                      fontSize: 14,
                    ),
                  ),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 24),

              // Password field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password',
                    style: TextStyle(
                      color: context.mutedForegroundColor,
                      fontSize: 14,
                    ),
                  ),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      border: const UnderlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Iconsax.eye_slash : Iconsax.eye,
                          color: context.mutedForegroundColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 16),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Forgot Password',
                    style: TextStyle(
                      color: context.foregroundColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
              
              const SizedBox(height: 32),

              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 24),

              // Sign up link
              Center(
                child: TextButton(
                  onPressed: () => context.go('/signup?role=${widget.role ?? "customer"}'),
                  child: Text(
                    'SIGN UP',
                    style: TextStyle(
                      color: context.foregroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}


