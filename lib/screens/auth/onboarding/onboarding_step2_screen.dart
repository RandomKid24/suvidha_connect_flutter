import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../utils/icon_mapper.dart';

class ServiceCategory {
  final int id;
  final String name;
  final String icon;
  final bool isActive;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.isActive,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'category',
      // Handle both snake_case and camelCase
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }
}

class OnboardingStep2Screen extends StatefulWidget {
  const OnboardingStep2Screen({super.key});

  @override
  State<OnboardingStep2Screen> createState() => _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState extends State<OnboardingStep2Screen> {
  List<ServiceCategory> _services = [];
  Set<int> _selectedServiceIds = {};
  bool _isLoading = false;
  bool _isLoadingServices = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    
    final result = await ApiService.getServiceCategories(forceRefresh: false);
    
    if (mounted) {
      setState(() => _isLoadingServices = false);
      
      if (result['success'] == true) {
        final data = result['data'];
        print('📦 [OnboardingStep2] Loaded services data type: ${data.runtimeType}');
        print('📦 [OnboardingStep2] Loaded services data: $data');
        
        // Handle both list and object responses
        List<dynamic> servicesList = [];
        try {
          if (data is List) {
            servicesList = data;
            print('📦 [OnboardingStep2] Data is a List with ${servicesList.length} items');
          } else if (data is Map<String, dynamic>) {
            if (data.containsKey('results')) {
              final results = data['results'];
              if (results is List) {
                servicesList = results;
                print('📦 [OnboardingStep2] Data is a Map with results array: ${servicesList.length} items');
              } else {
                print('⚠️ [OnboardingStep2] "results" is not a List, it is: ${results.runtimeType}');
                servicesList = [];
              }
            } else {
              print('⚠️ [OnboardingStep2] Data is a Map but no "results" key. Keys: ${data.keys}');
              servicesList = [];
            }
          } else {
            print('⚠️ [OnboardingStep2] Data is neither List nor Map: ${data.runtimeType}');
            servicesList = [];
          }
        } catch (e) {
          print('❌ [OnboardingStep2] Error extracting services list: $e');
          servicesList = [];
        }
        
        print('📦 [OnboardingStep2] Services list length: ${servicesList.length}');
        print('📦 [OnboardingStep2] Services list items:');
        for (var i = 0; i < servicesList.length; i++) {
          final service = servicesList[i];
          print('   ${i + 1}. $service');
        }
        
        setState(() {
          _services = servicesList
              .map((json) {
                try {
                  return ServiceCategory.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  print('❌ Error parsing service: $json, Error: $e');
                  return null;
                }
              })
              .whereType<ServiceCategory>() // Remove nulls
              .where((service) => service.isActive) // Only show active services
              .toList();
        });
        
        print('✅ [OnboardingStep2] Loaded ${_services.length} active services after filtering');
        print('✅ [OnboardingStep2] Service names: ${_services.map((s) => s.name).toList()}');
        
        if (_services.isEmpty) {
          print('⚠️ [OnboardingStep2] No services after filtering!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No services available. Please contact support.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('❌ Failed to load services: ${result['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to load services',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleService(int serviceId) {
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.onboardingStep2(
      serviceIds: _selectedServiceIds.toList(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        context.go('/provider-onboarding/step3');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to save services',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => context.go('/provider-onboarding/step1'),
        ),
        title: const Text('Step 2: Services'),
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
                        color: AppColors.border,
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
                    const Text(
                      'Select Your Services',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Choose the services you provide',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 24),

                    if (_isLoadingServices)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_services.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.category,
                                size: 64,
                                color: AppColors.mutedForeground,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No services available',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please contact support or try again later',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.mutedForeground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          final isSelected = _selectedServiceIds.contains(service.id);
                          
                          return GestureDetector(
                            onTap: () => _toggleService(service.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.card,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    IconMapper.getIconFromName(service.icon),
                                    size: 32,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    service.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.foreground,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(
                                        Iconsax.tick_circle,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 300.ms,
                            delay: Duration(milliseconds: 50 * index),
                          ).moveY(begin: 20, end: 0);
                        },
                      ),
                    
                    const SizedBox(height: 40),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleContinue,
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
          ],
        ),
      ),
    );
  }
}

