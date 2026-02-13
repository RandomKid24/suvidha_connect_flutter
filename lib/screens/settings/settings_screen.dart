import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImage;
  bool _showPasswordFields = false;
  

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final result = await ApiService.getCurrentUserInfo(forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _userData = result['data'];
          _firstNameController.text = _userData?['first_name'] ?? '';
          _lastNameController.text = _userData?['last_name'] ?? '';
          _emailController.text = _userData?['email'] ?? '';
          _phoneController.text = _userData?['phone'] ?? '';
          print('📋 Loaded user data: ${_userData}');
          
        } else {
          print('❌ Failed to load user data: ${result['error']}');
        }
      });
    }
  }


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    
    final updateData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
    };

    print('💾 Saving profile with data: $updateData');

    // Add password change if provided
    if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New passwords do not match'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
      updateData['current_password'] = _currentPasswordController.text;
      updateData['new_password'] = _newPasswordController.text;
    }

    final result = await ApiService.updateProfile(updateData, profilePhoto: _selectedImage);

    if (mounted) {
      setState(() => _isSaving = false);
      
      print('📥 Profile update result: ${result}');
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        // Clear selected image after successful upload
        setState(() {
          _selectedImage = null;
          _showPasswordFields = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        // Reload user data to show updated info
        _loadUserData();
      } else {
        final errorMsg = result['error']?['message'] ?? 
                        result['error']?.toString() ?? 
                        'Failed to update profile';
        print('❌ Profile update error: $errorMsg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const AppHeader(),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final profilePhoto = _userData?['profile_photo'];
    final displayImage = _selectedImage != null 
        ? Image.file(_selectedImage!, fit: BoxFit.cover)
        : (profilePhoto != null 
            ? Image.network(profilePhoto, fit: BoxFit.cover)
            : null);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadUserData(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.foregroundColor,
                        ),
                      ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 24),
                      
                      // Profile Photo
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: displayImage != null
                                    ? displayImage
                                    : Container(
                                        color: context.mutedColor,
                                        child: Icon(
                                          Iconsax.user,
                                          size: 50,
                                          color: context.mutedForegroundColor,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: _pickImage,
                                  icon: const Icon(
                                    Iconsax.camera,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 100.ms).fadeIn(duration: 500.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: const Icon(Iconsax.user),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ).animate(delay: 200.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: const Icon(Iconsax.user),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ).animate(delay: 250.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Iconsax.sms),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ).animate(delay: 300.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: const Icon(Iconsax.call),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ).animate(delay: 400.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 24),
                      
                      // Change Password Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Change Password',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: context.foregroundColor,
                                  ),
                                ),
                                Switch(
                                  value: _showPasswordFields,
                                  onChanged: (value) {
                                    setState(() {
                                      _showPasswordFields = value;
                                      if (!value) {
                                        _currentPasswordController.clear();
                                        _newPasswordController.clear();
                                        _confirmPasswordController.clear();
                                      }
                                    });
                                  },
                                  activeColor: AppColors.primary,
                                ),
                              ],
                            ),
                            if (_showPasswordFields) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _currentPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'Current Password',
                                  prefixIcon: const Icon(Iconsax.lock),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: true,
                                validator: _showPasswordFields
                                    ? (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter current password';
                                        }
                                        return null;
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _newPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  prefixIcon: const Icon(Iconsax.lock_1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password',
                                  prefixIcon: const Icon(Iconsax.lock_1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: true,
                                validator: _showPasswordFields && _newPasswordController.text.isNotEmpty
                                    ? (value) {
                                        if (value != _newPasswordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      }
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ).animate(delay: 500.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 24),
                      
                      // Theme Selection
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Iconsax.moon, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(
                                  'App Theme',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: context.foregroundColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ValueListenableBuilder<ThemeMode>(
                              valueListenable: ThemeService.themeNotifier,
                              builder: (context, currentTheme, child) {
                                return Column(
                                  children: [
                                    _buildThemeOption(
                                      context,
                                      'Light',
                                      ThemeMode.light,
                                      currentTheme,
                                      Iconsax.sun_1,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildThemeOption(
                                      context,
                                      'Dark',
                                      ThemeMode.dark,
                                      currentTheme,
                                      Iconsax.moon,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildThemeOption(
                                      context,
                                      'System Default',
                                      ThemeMode.system,
                                      currentTheme,
                                      Iconsax.setting_2,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ).animate(delay: 550.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 24),
                      
                      // Legal & Support Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Legal & Support',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: context.foregroundColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLegalLink(context, 'Terms & Conditions', '/terms-conditions', Iconsax.document_text),
                            const SizedBox(height: 12),
                            _buildLegalLink(context, 'Privacy Policy', '/privacy-policy', Iconsax.shield_tick),
                            const SizedBox(height: 12),
                            _buildLegalLink(context, 'About Us', '/about-us', Iconsax.info_circle),
                          ],
                        ),
                      ).animate(delay: 600.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ).animate(delay: 600.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode themeMode,
    ThemeMode currentTheme,
    IconData icon,
  ) {
    final isSelected = currentTheme == themeMode;
    return InkWell(
      onTap: () async {
        await ThemeService.setThemeMode(themeMode);
        // Theme will update automatically via ValueNotifier
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : context.mutedForegroundColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : context.foregroundColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Iconsax.tick_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalLink(BuildContext context, String title, String route, IconData icon) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: context.foregroundColor,
                ),
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              color: context.mutedForegroundColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

