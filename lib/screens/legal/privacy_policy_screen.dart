import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../widgets/app_header.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: 'Privacy Policy',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.mutedForegroundColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      '1. Introduction',
                      'Sahayak ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
                    ),
                    _buildSection(
                      context,
                      '2. Information We Collect',
                      'We collect information that you provide directly to us, including:\n\n• Personal Information: Name, email address, phone number, profile photo\n• Location Data: Your location to find nearby service providers\n• Payment Information: Payment details processed through secure payment gateways\n• Service Information: Booking history, preferences, and reviews\n• Device Information: Device type, operating system, unique device identifiers',
                    ),
                    _buildSection(
                      context,
                      '3. How We Use Your Information',
                      'We use the information we collect to:\n\n• Provide and maintain our services\n• Process transactions and send related information\n• Send you notifications about bookings and services\n• Improve and personalize your experience\n• Communicate with you about our services\n• Detect and prevent fraud or abuse\n• Comply with legal obligations',
                    ),
                    _buildSection(
                      context,
                      '4. Information Sharing',
                      'We do not sell your personal information. We may share your information only in the following circumstances:\n\n• With service providers you book through our platform\n• With third-party service providers who assist us in operating our app\n• When required by law or to protect our rights\n• In connection with a business transfer or merger',
                    ),
                    _buildSection(
                      context,
                      '5. Location Services',
                      'We collect location data to help you find nearby service providers. You can control location permissions through your device settings. Disabling location services may limit certain features of the app.',
                    ),
                    _buildSection(
                      context,
                      '6. Data Security',
                      'We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the internet or electronic storage is 100% secure.',
                    ),
                    _buildSection(
                      context,
                      '7. Data Retention',
                      'We retain your personal information for as long as necessary to provide our services and comply with legal obligations. You may request deletion of your account and associated data at any time.',
                    ),
                    _buildSection(
                      context,
                      '8. Your Rights',
                      'You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Request deletion of your data\n• Object to processing of your data\n• Data portability\n• Withdraw consent at any time',
                    ),
                    _buildSection(
                      context,
                      '9. Cookies and Tracking',
                      'We use cookies and similar tracking technologies to track activity on our app and hold certain information. You can instruct your device to refuse all cookies or to indicate when a cookie is being sent.',
                    ),
                    _buildSection(
                      context,
                      '10. Third-Party Services',
                      'Our app may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to read their privacy policies.',
                    ),
                    _buildSection(
                      context,
                      '11. Children\'s Privacy',
                      'Our services are not intended for children under 18 years of age. We do not knowingly collect personal information from children. If you believe we have collected information from a child, please contact us immediately.',
                    ),
                    _buildSection(
                      context,
                      '12. Changes to Privacy Policy',
                      'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.',
                    ),
                    _buildSection(
                      context,
                      '13. Contact Us',
                      'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@suvidhaconnect.com\nPhone: +91-XXXXXXXXXX\nAddress: [Your Company Address]',
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
}

