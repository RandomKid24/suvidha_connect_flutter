import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../widgets/app_header.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: 'About Us',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Logo/Icon Placeholder
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Iconsax.verify,
                          size: 50,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Sahayak',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: context.foregroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.mutedForegroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSection(
                      context,
                      'Our Mission',
                      'Sahayak is a revolutionary platform that connects customers with trusted service providers in their local area. We make it easy to find, book, and manage services for all your home and business needs.',
                    ),
                    _buildSection(
                      context,
                      'What We Do',
                      'We bridge the gap between service seekers and quality service providers, ensuring a seamless experience for both parties. Our platform verifies all service providers to ensure you get the best service possible.',
                    ),
                    _buildSection(
                      context,
                      'Key Features',
                      '• Verified Service Providers\n• Easy Booking System\n• Secure Payment Processing\n• Real-time Tracking\n• Customer Reviews and Ratings\n• 24/7 Customer Support',
                    ),
                    _buildSection(
                      context,
                      'Our Values',
                      '• Trust: We verify all service providers\n• Quality: We ensure high standards\n• Convenience: We make service booking easy\n• Transparency: Clear pricing and communication\n• Customer Satisfaction: Your needs come first',
                    ),
                    _buildSection(
                      context,
                      'Contact Information',
                      'Email: support@suvidhaconnect.com\nPhone: +91-XXXXXXXXXX\nWebsite: www.suvidhaconnect.com\nAddress: [Your Company Address]',
                    ),
                    const SizedBox(height: 32),
                    // Social Media Links (optional)
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialIcon(context, Icons.public),
                          const SizedBox(width: 16),
                          _buildSocialIcon(context, Iconsax.instagram),
                          const SizedBox(width: 16),
                          _buildSocialIcon(context, Icons.email),
                          const SizedBox(width: 16),
                          _buildSocialIcon(context, Icons.business),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                      Center(
                      child: Text(
                        '© ${DateTime.now().year} Sahayak. All rights reserved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.mutedForegroundColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.foregroundColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: context.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(BuildContext context, IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.borderColor),
      ),
      child: Icon(
        icon,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}

