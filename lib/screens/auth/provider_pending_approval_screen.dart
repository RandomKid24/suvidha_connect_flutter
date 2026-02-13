import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';

/// Shown when a provider has completed onboarding but admin has not yet approved.
/// User stays logged in and sees a clear message to wait for approval.
class ProviderPendingApprovalScreen extends StatelessWidget {
  const ProviderPendingApprovalScreen({super.key});

  Future<void> _checkStatus(BuildContext context) async {
    final result = await ApiService.getProviderStatus(forceRefresh: true);
    if (!context.mounted) return;
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      if (data['can_login'] == true) {
        context.go('/home');
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your profile is still pending approval')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.clock,
                  size: 64,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Your profile is still pending',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.foregroundColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Get approval from Admin to start receiving bookings. We will notify you once your profile is verified.',
                style: TextStyle(
                  fontSize: 15,
                  color: context.mutedForegroundColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _checkStatus(context),
                  icon: const Icon(Iconsax.refresh, size: 20),
                  label: const Text('Check approval status'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ApiService.logout();
                    if (context.mounted) context.go('/role-select');
                  },
                  icon: const Icon(Iconsax.logout, size: 20),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.foregroundColor,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
