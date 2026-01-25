import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../models/service.dart';

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController();
  String? _selectedService;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    // For demo, navigate to login
    context.go('/login?role=provider');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => context.go('/role-select'),
        ),
        title: const Text('Provider Registration'),
      ),
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
              const Text(
                'Join as a Service Provider',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 8),
              
              Text(
                'Fill in your details to start offering services',
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 14,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 32),

              // Name field
              _buildTextField(
                label: 'Full Name',
                controller: _nameController,
                icon: Iconsax.user,
                delay: 200,
              ),
              
              const SizedBox(height: 20),

              // Phone field
              _buildTextField(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Iconsax.call,
                keyboardType: TextInputType.phone,
                delay: 300,
              ),
              
              const SizedBox(height: 20),

              // Service selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Category',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedService,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        prefixIcon: Icon(Iconsax.category, color: AppColors.mutedForeground),
                      ),
                      hint: const Text('Select a service'),
                      items: ServiceCategory.services.map((service) {
                        return DropdownMenuItem(
                          value: service.id,
                          child: Text(service.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedService = value;
                        });
                      },
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 20),

              // Experience field
              _buildTextField(
                label: 'Years of Experience',
                controller: _experienceController,
                icon: Iconsax.briefcase,
                keyboardType: TextInputType.number,
                delay: 500,
              ),
              
              const SizedBox(height: 40),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms).moveY(begin: 20, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    required int delay,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(icon, color: AppColors.mutedForeground),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).moveY(begin: 20, end: 0);
  }
}


