import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../services/api_service.dart';

class OnboardingStep3Screen extends StatefulWidget {
  const OnboardingStep3Screen({super.key});

  @override
  State<OnboardingStep3Screen> createState() => _OnboardingStep3ScreenState();
}

class _OnboardingStep3ScreenState extends State<OnboardingStep3Screen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  
  File? _profilePhoto;
  File? _panCard;
  File? _registrationCertificate;
  
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          if (type == 'profile') {
            _profilePhoto = File(image.path);
          } else if (type == 'pan') {
            _panCard = File(image.path);
          } else if (type == 'registration') {
            _registrationCertificate = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Iconsax.camera, color: context.foregroundColor),
              title: Text('Camera', style: TextStyle(color: context.foregroundColor)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: Icon(Iconsax.gallery, color: context.foregroundColor),
              title: Text('Gallery', style: TextStyle(color: context.foregroundColor)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter provider name (firm or company name)')),
      );
      return;
    }

    if (_contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter provider contact number')),
      );
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter address')),
      );
      return;
    }

    if (_panCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your PAN card')),
      );
      return;
    }

    if (_registrationCertificate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your registration certificate')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.onboardingStep3(
      name: _nameController.text,
      contact: _contactController.text,
      address: _addressController.text,
      profilePhotoPath: _profilePhoto?.path,
      panCardPath: _panCard!.path,
      registrationCertificatePath: _registrationCertificate!.path,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        // Show success message and navigate
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.cardColor,
            title: Text(
              'Registration Complete!',
              style: TextStyle(color: context.foregroundColor),
            ),
            content: Text(
              'Your registration has been submitted successfully. '
              'Please wait for admin verification. You will be notified once your account is approved.',
              style: TextStyle(color: context.foregroundColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/login?role=provider');
                },
                child: Text('OK', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to submit registration',
            ),
          ),
        );
      }
    }
  }

  Widget _buildFilePicker(
    BuildContext context, {
    required String label,
    String? hint,
    required File? file,
    required String type,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.mutedForegroundColor,
                fontSize: 14,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              color: context.mutedForegroundColor.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showImageSourceDialog(type),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border.all(
                color: file != null ? AppColors.primary : context.borderColor,
                width: file != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  file != null ? Iconsax.tick_circle : Iconsax.document_upload,
                  color: file != null ? AppColors.primary : context.mutedForegroundColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file != null ? 'File selected' : 'Tap to upload',
                    style: TextStyle(
                      color: file != null ? AppColors.primary : context.mutedForegroundColor,
                      fontWeight: file != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (file != null)
                  IconButton(
                    icon: Icon(Iconsax.close_circle, size: 20, color: context.mutedForegroundColor),
                    onPressed: () {
                      setState(() {
                        if (type == 'profile') {
                          _profilePhoto = null;
                        } else if (type == 'pan') {
                          _panCard = null;
                        } else if (type == 'registration') {
                          _registrationCertificate = null;
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.foregroundColor),
        title: Text(
          'Step 3: Documents',
          style: TextStyle(
            color: context.foregroundColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: context.foregroundColor),
          onPressed: () => context.go('/provider-onboarding/step2'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
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
                    Text(
                      'Provider Information & Documents',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Enter your business/firm details and upload documents. Provider name and profile photo can be edited later in Provider Settings.',
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 32),

                    // Provider / business name
                    _buildTextField(
                      context,
                      label: 'Provider name (Firm / Company name)',
                      hint: 'e.g. ABC Plumbing Services',
                      controller: _nameController,
                      icon: Iconsax.building,
                      delay: 200,
                    ),
                    
                    const SizedBox(height: 20),

                    // Provider contact
                    _buildTextField(
                      context,
                      label: 'Provider contact number',
                      hint: 'Business contact number',
                      controller: _contactController,
                      icon: Iconsax.call,
                      keyboardType: TextInputType.phone,
                      delay: 300,
                    ),
                    
                    const SizedBox(height: 20),

                    // Address
                    _buildTextField(
                      context,
                      label: 'Address',
                      hint: 'Business or service address',
                      controller: _addressController,
                      icon: Iconsax.location,
                      maxLines: 3,
                      delay: 400,
                    ),
                    
                    const SizedBox(height: 20),

                    // Provider profile photo (editable in Provider Settings)
                    _buildFilePicker(
                      context,
                      label: 'Provider profile photo',
                      hint: 'Can be updated later in Provider Settings',
                      file: _profilePhoto,
                      type: 'profile',
                      isRequired: false,
                    ).animate().fadeIn(duration: 500.ms, delay: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 20),

                    // PAN card
                    _buildFilePicker(
                      context,
                      label: 'PAN Card',
                      file: _panCard,
                      type: 'pan',
                      isRequired: true,
                    ).animate().fadeIn(duration: 500.ms, delay: 600.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 20),

                    // Registration certificate
                    _buildFilePicker(
                      context,
                      label: 'Registration Certificate',
                      file: _registrationCertificate,
                      type: 'registration',
                      isRequired: true,
                    ).animate().fadeIn(duration: 500.ms, delay: 700.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 40),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
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
                                'Submit Registration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 800.ms).moveY(begin: 20, end: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    String? hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(color: context.foregroundColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(icon, color: context.mutedForegroundColor),
              hintText: hint,
              hintStyle: TextStyle(color: context.mutedForegroundColor),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).moveY(begin: 20, end: 0);
  }
}

