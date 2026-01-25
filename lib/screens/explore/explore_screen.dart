import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class ExploreScreen extends StatefulWidget {
  final String serviceId;
  
  const ExploreScreen({super.key, required this.serviceId});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _providers = [];
  List<dynamic> _serviceCategories = [];
  bool _isLoading = true;
  String _serviceName = '';
  int? _selectedServiceId;
  final TextEditingController _searchController = TextEditingController();
  bool _useLocationFilter = true; // Enabled by default to show 30km radius providers
  bool _availableOnly = false;
  String? _sortBy; // 'price_low' or 'price_high'
  Position? _userPosition;
  double _radius = 30.0; // Default 30 km radius
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _serviceName = _formatServiceName(widget.serviceId);
    _initializeData();
    _getUserLocation();
    
    // Listen to search controller changes to update UI
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  Future<void> _initializeData() async {
    // Load service categories first to set the selected service ID
    await _loadServiceCategories();
    // Then load providers with the correct filter
    await _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadServiceCategories({bool forceRefresh = false}) async {
    final result = await ApiService.getServiceCategories(forceRefresh: forceRefresh);
    if (mounted && result['success'] == true) {
      final data = result['data'];
      List<dynamic> categoriesList = [];
      if (data is List) {
        categoriesList = data;
      } else if (data is Map && data.containsKey('results')) {
        categoriesList = data['results'] as List;
      }
      
      setState(() {
        _serviceCategories = categoriesList.where((s) => s['is_active'] == true).toList();
        
        // Set initial selected service
        final category = categoriesList.firstWhere(
          (cat) => cat['slug'] == widget.serviceId,
          orElse: () => null,
        );
        if (category != null) {
          _selectedServiceId = category['id'];
          _serviceName = category['name'] ?? _serviceName;
        }
      });
    }
  }

  String _formatServiceName(String id) {
    return id
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    
    final searchQuery = _searchController.text.isNotEmpty ? _searchController.text : null;
    print('🔍 Loading providers with search query: "$searchQuery"');
    print('📍 Service category ID: $_selectedServiceId');
    
    // Fetch providers with filters (use cache by default)
    final result = await ApiService.getProviders(
      serviceCategoryId: _selectedServiceId,
      searchQuery: searchQuery,
      latitude: _useLocationFilter && _userPosition != null ? _userPosition!.latitude : null,
      longitude: _useLocationFilter && _userPosition != null ? _userPosition!.longitude : null,
      radius: _useLocationFilter ? _radius : null, // Use selected radius
      availableOnly: _availableOnly ? true : null,
      sortBy: _sortBy,
      forceRefresh: false, // Use cache by default
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        final providers = result['data'] as List;
        print('✅ Found ${providers.length} providers');
        setState(() {
          _providers = providers;
        });
      } else {
        print('❌ Error loading providers: ${result['error']}');
      }
    }
  }

  void _applyFilters() {
    _loadProviders();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Explore Providers',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 12),
                    
                    // Search Bar - More Prominent
                    Container(
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, service, or location...',
                          hintStyle: TextStyle(color: context.mutedForegroundColor, fontSize: 14),
                          prefixIcon: Icon(Iconsax.search_normal, color: AppColors.primary, size: 22),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Iconsax.close_circle, color: context.mutedForegroundColor),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        style: TextStyle(color: context.foregroundColor, fontSize: 15),
                        onChanged: (value) {
                          // Update UI immediately to show/hide clear button
                          setState(() {});
                          // Cancel previous timer
                          _debounceTimer?.cancel();
                          // Start new timer for search
                          _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                            if (value.length >= 1 || value.isEmpty) {
                              print('🔍 Triggering search for: "$value"');
                              _applyFilters();
                            }
                          });
                        },
                        onSubmitted: (value) {
                          print('⌨️ Search submitted: "$value"');
                          _debounceTimer?.cancel();
                          _applyFilters();
                        },
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    // Filters
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              Icon(Iconsax.filter, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.foregroundColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Category Filter
                          DropdownButtonFormField<int?>(
                            value: _selectedServiceId,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: context.mutedForegroundColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.borderColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Categories'),
                              ),
                              ..._serviceCategories.map((category) {
                                return DropdownMenuItem<int?>(
                                  value: category['id'],
                                  child: Text(category['name'] ?? ''),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedServiceId = value;
                                if (value != null) {
                                  final category = _serviceCategories.firstWhere(
                                    (cat) => cat['id'] == value,
                                    orElse: () => null,
                                  );
                                  if (category != null) {
                                    _serviceName = category['name'] ?? '';
                                  }
                                }
                              });
                              _applyFilters();
                            },
                            style: TextStyle(color: context.foregroundColor),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Location Filter
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Iconsax.location, color: context.mutedForegroundColor, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Near Me',
                                          style: TextStyle(
                                            color: context.foregroundColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _useLocationFilter,
                                    onChanged: (value) {
                                      setState(() {
                                        _useLocationFilter = value;
                                      });
                                      _applyFilters();
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                ],
                              ),
                              // Radius selector (always visible, but disabled when location filter is off)
                              const SizedBox(height: 8),
                              DropdownButtonFormField<double>(
                                value: _radius,
                                decoration: InputDecoration(
                                  labelText: 'Search Radius',
                                  labelStyle: TextStyle(color: context.mutedForegroundColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: context.borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: context.borderColor),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem<double>(
                                    value: 5.0,
                                    child: Text('5 km'),
                                  ),
                                  DropdownMenuItem<double>(
                                    value: 10.0,
                                    child: Text('10 km'),
                                  ),
                                  DropdownMenuItem<double>(
                                    value: 15.0,
                                    child: Text('15 km'),
                                  ),
                                  DropdownMenuItem<double>(
                                    value: 20.0,
                                    child: Text('20 km'),
                                  ),
                                  DropdownMenuItem<double>(
                                    value: 30.0,
                                    child: Text('30 km'),
                                  ),
                                  DropdownMenuItem<double>(
                                    value: 50.0,
                                    child: Text('50 km'),
                                  ),
                                ],
                                onChanged: _useLocationFilter ? (value) {
                                  if (value != null) {
                                    setState(() {
                                      _radius = value;
                                    });
                                    _applyFilters();
                                  }
                                } : null,
                                style: TextStyle(color: context.foregroundColor),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Available Only Filter
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Iconsax.tick_circle, color: context.mutedForegroundColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Available Only',
                                      style: TextStyle(
                                        color: context.foregroundColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _availableOnly,
                                onChanged: (value) {
                                  setState(() {
                                    _availableOnly = value;
                                  });
                                  _applyFilters();
                                },
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Sort By Price
                          DropdownButtonFormField<String?>(
                            value: _sortBy,
                            decoration: InputDecoration(
                              labelText: 'Sort By',
                              labelStyle: TextStyle(color: context.mutedForegroundColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.borderColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Default'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'price_low',
                                child: Text('Price: Low to High'),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'price_high',
                                child: Text('Price: High to Low'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _sortBy = value;
                              });
                              _applyFilters();
                            },
                            style: TextStyle(color: context.foregroundColor),
                          ),
                        ],
                      ),
                    ).animate(delay: 150.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 12),
                    
                    // Provider List
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_providers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'No providers available for $_serviceName',
                            style: TextStyle(color: context.mutedForegroundColor),
                          ),
                        ),
                      )
                    else
                      ..._providers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final provider = entry.value;
                        return _buildProviderCard(context, provider, index);
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, dynamic provider, int index) {
    final providerId = provider['id'] ?? 0;
    final providerName = provider['name'] ?? 'Unknown';
    final profilePhoto = provider['profile_photo'];
    final services = provider['services'] as List? ?? [];
    final serviceNames = services.map((s) => s['service_category']?['name'] ?? '').where((n) => n.isNotEmpty).join(', ');
    
    return GestureDetector(
      onTap: () => context.push('/provider/$providerId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider image
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: profilePhoto != null
                  ? CachedNetworkImage(
                      imageUrl: profilePhoto,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: context.mutedColor,
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 48,
                        height: 48,
                        color: context.mutedColor,
                        child: const Icon(Iconsax.user),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: context.mutedColor,
                      child: const Icon(Iconsax.user),
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Provider info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              providerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: context.foregroundColor,
                              ),
                            ),
                            if (serviceNames.isNotEmpty)
                              Text(
                                serviceNames,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Iconsax.add,
                          color: context.mutedForegroundColor,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (provider['address'] != null && provider['address'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      provider['address'],
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Price range
                  if (provider['min_price'] != null || provider['max_price'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Iconsax.dollar_circle, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          provider['min_price'] != null && provider['max_price'] != null
                              ? '₹${provider['min_price']} - ₹${provider['max_price']}'
                              : provider['min_price'] != null
                                  ? 'From ₹${provider['min_price']}'
                                  : 'Up to ₹${provider['max_price']}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Availability indicator
                  if (provider['is_available'] == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Iconsax.tick_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Available',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 30, end: 0);
  }
}


