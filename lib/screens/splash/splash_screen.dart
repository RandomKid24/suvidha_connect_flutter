import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  void _checkSessionAndNavigate() async {
    // Show splash for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Check if user is logged in
    final isLoggedIn = await ApiService.isLoggedIn();
    
    if (!mounted) return;
    
    if (isLoggedIn) {
      // User is logged in, get fresh user data from API to check role
      final userInfoResult = await ApiService.getCurrentUserInfo(forceRefresh: false);
      
      if (userInfoResult['success'] == true && userInfoResult['data'] != null) {
        final userData = userInfoResult['data'];
        
        if (userData['role'] == 'provider') {
          final statusResult = await ApiService.getProviderStatus(forceRefresh: true);
          if (statusResult['success'] == true && statusResult['data'] != null) {
            final statusData = statusResult['data'] as Map<String, dynamic>;
            final onboardingComplete = statusData['is_onboarding_complete'] ?? statusData['onboarding_complete'] ?? true;
            final canLogin = statusData['can_login'] == true;
            final step = statusData['onboarding_step'] is int
                ? (statusData['onboarding_step'] as int).clamp(1, 3)
                : 1;

            if (onboardingComplete == false) {
              if (mounted) context.go('/provider-onboarding/step$step');
              return;
            }
            if (!canLogin) {
              if (mounted) context.go('/provider-pending-approval');
              return;
            }
            if (mounted) context.go('/home');
            return;
          } else {
            if (statusResult['error']?['message']?.toString().toLowerCase().contains('not found') == true ||
                statusResult['error']?['message']?.toString().toLowerCase().contains('complete onboarding') == true) {
              if (mounted) context.go('/provider-onboarding/step1');
              return;
            }
          }
        }
        
        // Consumer or provider with issues, go to home
        if (mounted) context.go('/home');
      } else {
        // Failed to get user info, session might be invalid
        // Clear session and redirect to role select
        await ApiService.logout();
        if (mounted) context.go('/role-select');
      }
    } else {
      // User not logged in, go to role select
      if (mounted) context.go('/role-select');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo container
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .rotate(
                          duration: 6000.ms,
                          curve: Curves.linear,
                        ),
                    // Inner pulsing circle
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.15, 1.15),
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .scale(
                          begin: const Offset(1.15, 1.15),
                          end: const Offset(1.0, 1.0),
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        ),
                    // Main icon
                    Icon(
                      Icons.handshake_rounded,
                      size: 56,
                      color: Colors.white,
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .moveY(
                          begin: 0,
                          end: -6,
                          duration: 1000.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .moveY(
                          begin: -6,
                          end: 0,
                          duration: 1000.ms,
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // App name
              Text(
                'Sahayak',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms)
                  .moveY(begin: 10, end: 0, duration: 600.ms, delay: 200.ms),
              
              const SizedBox(height: 8),
              
              // Tagline
              Text(
                'Connecting services, building trust',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.3,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .moveY(begin: 10, end: 0, duration: 600.ms, delay: 400.ms),
              
              const SizedBox(height: 48),
              
              // Modern loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(8, (index) {
                    return Transform.rotate(
                      angle: (index * 3.14159 * 2) / 8,
                      child: Container(
                        width: 4,
                        height: 12,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                          .animate(
                            onPlay: (controller) => controller.repeat(),
                            delay: Duration(milliseconds: index * 100),
                          )
                          .fadeIn(
                            duration: 300.ms,
                            begin: 0.2,
                          )
                          .then()
                          .fadeOut(
                            duration: 300.ms,
                          ),
                    );
                  }),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 600.ms),
            ],
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .moveY(begin: 20, end: 0, duration: 500.ms),
        ),
      ),
    );
  }
}


