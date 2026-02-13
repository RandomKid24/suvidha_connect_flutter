import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
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
    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : (int.tryParse(idRaw?.toString() ?? '') ?? 0);
    return ServiceCategory(
      id: id,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'category',
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServices({bool forceRefresh = false}) async {
    setState(() => _isLoadingServices = true);
    
    final result = await ApiService.getServiceCategories(forceRefresh: forceRefresh);
    
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

  List<ServiceCategory> get _filteredServices {
    if (_searchQuery.isEmpty) return _services;
    final q = _searchQuery.toLowerCase();
    return _services.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _showCreateCategoryDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final payload = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Form(
          key: formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.category_2, size: 32, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add your own category',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.foregroundColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a new service category to offer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.mutedForegroundColor,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Category name',
                    hintText: 'e.g. Home cleaning',
                    labelStyle: TextStyle(color: context.mutedForegroundColor),
                    hintStyle: TextStyle(color: context.mutedForegroundColor.withOpacity(0.7)),
                    filled: true,
                    fillColor: context.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: context.foregroundColor, fontSize: 15),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief description of this category',
                    labelStyle: TextStyle(color: context.mutedForegroundColor),
                    hintStyle: TextStyle(color: context.mutedForegroundColor.withOpacity(0.7)),
                    filled: true,
                    fillColor: context.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: context.foregroundColor, fontSize: 15),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: context.mutedForegroundColor,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.of(dialogContext).pop({
                            'name': nameController.text.trim(),
                            'description': descController.text.trim(),
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Add category'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Defer dispose until after the dialog is fully removed from the tree
    // to avoid "TextEditingController was used after being disposed"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      descController.dispose();
    });
    if (payload == null || !mounted) return;
    try {
      final res = await ApiService.createServiceCategory(
        name: payload['name']!,
        description: payload['description']!.isEmpty ? null : payload['description'],
      );
      if (!mounted) return;
      if (res['success'] == true) {
        // Backend returns the category object directly (may be in res['data'] or top-level)
        final raw = res['data'];
        Map<String, dynamic>? data;
        if (raw is Map<String, dynamic>) {
          data = raw;
        } else if (raw is Map) {
          data = Map<String, dynamic>.from(raw);
        }
        int? id;
        if (data != null && data.containsKey('id')) {
          final idVal = data['id'];
          if (idVal is int) {
            id = idVal;
          } else if (idVal != null) {
            id = int.tryParse(idVal.toString());
          }
        }
        await _loadServices(forceRefresh: true);
        if (!mounted) return;
        if (id != null) {
          final idValue = id!;
          setState(() => _selectedServiceIds.add(idValue));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category added and selected')),
          );
        }
      } else {
        final err = res['error'];
        final msg = err is Map ? (err['error'] ?? err['message']) : 'Failed to create category';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg?.toString() ?? 'Failed to create category')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Create category error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: ${e.toString()}')),
        );
      }
    }
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
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.foregroundColor),
        title: Text(
          'Step 2: Services',
          style: TextStyle(
            color: context.foregroundColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: context.foregroundColor),
          onPressed: () => context.go('/provider-onboarding/step1'),
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
                        color: context.borderColor,
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
                      'Select Your Services',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Choose the services you provide',
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 20),
                    // Search bar
                    if (!_isLoadingServices && _services.isNotEmpty)
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          prefixIcon: Icon(Iconsax.search_normal_1, color: context.mutedForegroundColor, size: 20),
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: TextStyle(color: context.foregroundColor, fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      ).animate().fadeIn(duration: 300.ms),
                    if (!_isLoadingServices && _services.isNotEmpty) const SizedBox(height: 12),
                    // Add your own category button (when list exists)
                    if (!_isLoadingServices && _services.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showCreateCategoryDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.add_circle, size: 22, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Text(
                                  'Add your own category',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                    if (!_isLoadingServices && _services.isNotEmpty) const SizedBox(height: 16),
                    const SizedBox(height: 8),

                    if (_isLoadingServices)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
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
                                color: context.mutedForegroundColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No categories yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: context.foregroundColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your own category to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.mutedForegroundColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _showCreateCategoryDialog,
                                icon: const Icon(Iconsax.add_circle, size: 22),
                                label: const Text('Create category'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filteredServices.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.search_normal_1, size: 48, color: context.mutedForegroundColor),
                              const SizedBox(height: 12),
                              Text(
                                'No categories match "$_searchQuery"',
                                style: TextStyle(fontSize: 16, color: context.foregroundColor),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Text('Clear search'),
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
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = _filteredServices[index];
                          final isSelected = _selectedServiceIds.contains(service.id);
                          
                          return GestureDetector(
                            onTap: () => _toggleService(service.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : context.cardColor,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : context.borderColor,
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
                                          : context.foregroundColor,
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

