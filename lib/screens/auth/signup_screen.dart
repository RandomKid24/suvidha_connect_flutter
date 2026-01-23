import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  final String? role;
  
  const SignupScreen({super.key, this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_firstNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your first name')),
      );
      return;
    }

    if (_lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your last name')),
      );
      return;
    }

    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Normalize role - convert 'consumer' to 'customer' if needed
    String role = widget.role ?? 'customer';
    if (role == 'consumer') {
      role = 'customer';
    }
    // Only allow valid roles
    if (role != 'customer' && role != 'provider' && role != 'admin') {
      role = 'customer';
    }

    print('Registering with role: $role');

    final result = await ApiService.register(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      role: role,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        // For providers, automatically login and go to onboarding
        if (widget.role == 'provider' || role == 'provider') {
          // Auto-login after registration
          print('🔄 Auto-logging in provider after registration...');
          final loginResult = await ApiService.login(
            username: _emailController.text.trim(),
            password: _passwordController.text,
          );
          
          print('🔄 Auto-login result: ${loginResult['success']}');
          
          if (loginResult['success'] == true) {
            // Verify session was saved
            final prefs = await SharedPreferences.getInstance();
            final sessionId = prefs.getString('session_id');
            final isLoggedIn = prefs.getBool('is_logged_in');
            print('✅ Session saved: ${sessionId != null && sessionId.isNotEmpty}');
            print('✅ Login flag: $isLoggedIn');
            
            // Small delay to ensure session is fully saved
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Navigate to onboarding step 1
            if (mounted) {
              context.go('/provider-onboarding/step1');
            }
          } else {
            // If auto-login fails, show error and go to login screen
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Registration successful! ${loginResult['error']?['message'] ?? 'Please login to continue.'}'),
                duration: const Duration(seconds: 3),
                ),
              );
              context.go('/login?role=provider');
            }
          }
        } else {
          // For customers, show success message and go to login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please login.')),
          );
          context.go('/login?role=${widget.role ?? "customer"}');
        }
      } else {
        final error = result['error'];
        String errorMessage = 'Registration failed';
        List<String> errorMessages = [];
        
        if (error is Map) {
          // Collect all error messages
          error.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              errorMessages.addAll(value.map((e) => e.toString()));
            } else if (value is String) {
              errorMessages.add(value);
            }
          });
          
          // If we have specific field errors, show them
          if (error.containsKey('password')) {
            final passwordErrors = error['password'];
            if (passwordErrors is List) {
              errorMessages = passwordErrors.map((e) => e.toString()).toList();
            }
          } else if (error.containsKey('username')) {
            final usernameErrors = error['username'];
            if (usernameErrors is List) {
              errorMessages = usernameErrors.map((e) => e.toString()).toList();
            }
          } else if (error.containsKey('email')) {
            final emailErrors = error['email'];
            if (emailErrors is List) {
              errorMessages = emailErrors.map((e) => e.toString()).toList();
            }
          } else if (error.containsKey('phone')) {
            final phoneErrors = error['phone'];
            if (phoneErrors is List) {
              errorMessages = phoneErrors.map((e) => e.toString()).toList();
            }
          } else if (error.containsKey('message')) {
            errorMessages = [error['message'].toString()];
          }
        }
        
        // Show all error messages
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
          padding: const EdgeInsets.all(24),
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
                'WELCOME',
                style: TextStyle(
                  color: context.foregroundColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 32),

              // First Name field
              _buildTextField(
                label: 'First Name',
                controller: _firstNameController,
                delay: 100,
              ),
              
              const SizedBox(height: 20),

              // Last Name field
              _buildTextField(
                label: 'Last Name',
                controller: _lastNameController,
                delay: 150,
              ),
              
              const SizedBox(height: 20),

              // Email field
              _buildTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                delay: 200,
              ),
              
              const SizedBox(height: 20),

              // Phone field
              _buildTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                delay: 250,
              ),
              
              const SizedBox(height: 20),

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
              
              const SizedBox(height: 20),

              // Confirm Password field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      color: context.mutedForegroundColor,
                      fontSize: 14,
                    ),
                  ),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      border: const UnderlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                          color: context.mutedForegroundColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 32),

              // Signup button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 24),

              // Sign in link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have account? ',
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login?role=${widget.role ?? "customer"}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'SIGN IN',
                        style: TextStyle(
                          color: context.foregroundColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    required int delay,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.mutedForegroundColor,
            fontSize: 14,
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).moveY(begin: 20, end: 0);
  }
}



