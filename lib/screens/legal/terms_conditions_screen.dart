import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../widgets/app_header.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: 'Terms & Conditions',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms and Conditions',
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
                      '1. Acceptance of Terms',
                      'By accessing and using Sahayak ("the App"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
                    ),
                    _buildSection(
                      context,
                      '2. Description of Service',
                      'Sahayak is a platform that connects service providers with customers seeking various services. We facilitate the connection between users but are not directly involved in the actual service provision.',
                    ),
                    _buildSection(
                      context,
                      '3. User Accounts',
                      'You are responsible for maintaining the confidentiality of your account credentials. You agree to notify us immediately of any unauthorized use of your account. We reserve the right to suspend or terminate accounts that violate these terms.',
                    ),
                    _buildSection(
                      context,
                      '4. Service Provider Obligations',
                      'Service providers must:\n• Provide accurate information about their services\n• Maintain professional standards\n• Complete services as agreed with customers\n• Comply with all applicable laws and regulations',
                    ),
                    _buildSection(
                      context,
                      '5. Customer Obligations',
                      'Customers must:\n• Provide accurate booking information\n• Pay for services as agreed\n• Treat service providers with respect\n• Provide honest feedback and reviews',
                    ),
                    _buildSection(
                      context,
                      '6. Payments and Refunds',
                      'All payments are processed through our secure payment system. Refund policies vary by service type and will be communicated at the time of booking. We reserve the right to withhold payments in cases of disputes or violations.',
                    ),
                    _buildSection(
                      context,
                      '7. Cancellation Policy',
                      'Cancellation policies vary by service provider. Customers may cancel bookings according to the terms agreed upon at booking. Service providers may cancel with appropriate notice to customers.',
                    ),
                    _buildSection(
                      context,
                      '8. Dispute Resolution',
                      'In case of disputes between customers and service providers, Sahayak will attempt to facilitate resolution. However, we are not liable for the actions of service providers or customers.',
                    ),
                    _buildSection(
                      context,
                      '9. Limitation of Liability',
                      'Sahayak acts as an intermediary platform. We are not responsible for the quality, safety, or legality of services provided by service providers. Users use the platform at their own risk.',
                    ),
                    _buildSection(
                      context,
                      '10. Intellectual Property',
                      'All content, features, and functionality of the App are owned by Sahayak and are protected by international copyright, trademark, and other intellectual property laws.',
                    ),
                    _buildSection(
                      context,
                      '11. Privacy',
                      'Your use of the App is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices regarding your personal information.',
                    ),
                    _buildSection(
                      context,
                      '12. Modifications to Terms',
                      'We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting. Continued use of the App after changes constitutes acceptance of the modified terms.',
                    ),
                    _buildSection(
                      context,
                      '13. Termination',
                      'We may terminate or suspend your account and access to the App immediately, without prior notice, for any reason, including breach of these Terms.',
                    ),
                    _buildSection(
                      context,
                      '14. Governing Law',
                      'These terms shall be governed by and construed in accordance with the laws of India, without regard to its conflict of law provisions.',
                    ),
                    _buildSection(
                      context,
                      '15. Contact Information',
                      'If you have any questions about these Terms and Conditions, please contact us at:\n\nEmail: support@suvidhaconnect.com\nPhone: +91-XXXXXXXXXX',
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

