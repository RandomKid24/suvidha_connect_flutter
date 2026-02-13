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
import '../../widgets/provider_avatar.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  List<dynamic> _providers = [];
  List<dynamic> _serviceCategories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  
  int? _selectedServiceId;
  final TextEditingController _searchController = TextEditingController();
  double? _selectedRadius = 30.0; // Default 30 km radius
  bool _availableOnly = false;
  String? _sortBy; // 'price_low' or 'price_high'
  Position? _userPosition;
  String _lastSearchQuery = '';
  bool _filtersExpanded = false;
  
  final List<Map<String, dynamic>> _radiusOptions = [
    {'value': 5.0, 'label': '5 km'},
    {'value': 10.0, 'label': '10 km'},
    {'value': 15.0, 'label': '15 km'},
    {'value': 20.0, 'label': '20 km'},
    {'value': 30.0, 'label': '30 km'},
    {'value': 50.0, 'label': '50 km'},
  ];

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load from cache first, don't call API on every navigation
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (_hasInitialized) {
      // Already initialized, just use cached data
      return;
    }
    _hasInitialized = true;
    
    // Load service categories (use cache)
    await _loadServiceCategories(forceRefresh: false);
    // Get user location (non-blocking)
    _getUserLocation();
    // Load providers from cache first
    await _loadProviders(reset: true, forceRefresh: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more when user is 200px from bottom
      if (!_isLoadingMore && _hasMore) {
        _loadProviders(reset: false);
      }
    }
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
      });
    }
  }

  Future<void> _loadProviders({bool reset = false, bool forceRefresh = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _providers = [];
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }
    
    final result = await ApiService.getProviders(
      serviceCategoryId: _selectedServiceId,
      searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      latitude: _selectedRadius != null && _userPosition != null ? _userPosition!.latitude : null,
      longitude: _selectedRadius != null && _userPosition != null ? _userPosition!.longitude : null,
      forceRefresh: forceRefresh, // Use forceRefresh parameter
      radius: _selectedRadius,
      availableOnly: _availableOnly ? true : null,
      sortBy: _sortBy,
      page: reset ? 1 : _currentPage,
    );
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (result['success'] == true) {
          final newProviders = result['data'] as List;
          if (reset) {
            _providers = newProviders;
            _currentPage = 1;
          } else {
            _providers.addAll(newProviders);
          }
          // Check if there are more pages (assuming 20 items per page from backend)
          _hasMore = newProviders.length >= 20;
          if (_hasMore && !reset) {
            _currentPage++;
          }
        }
      });
    }
  }

  void _applyFilters() {
    _loadProviders(reset: true, forceRefresh: false); // Use cache when applying filters
  }

  Future<void> _handleRefresh() async {
    // Force refresh from API when user pulls to refresh
    await _loadProviders(reset: true, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: Column(
                children: [
                  // Search and Filters Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: context.backgroundColor,
                    child: Column(
                      children: [
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search providers...',
                              hintStyle: TextStyle(color: context.mutedForegroundColor),
                              prefixIcon: Icon(Iconsax.search_normal, color: context.mutedForegroundColor),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            style: TextStyle(color: context.foregroundColor),
                            onChanged: (value) {
                              // Debounce search
                              _lastSearchQuery = value;
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (mounted && _searchController.text == _lastSearchQuery) {
                                  _applyFilters();
                                }
                              });
                            },
                            onSubmitted: (_) => _applyFilters(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Filters (Collapsible)
                        Container(
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            children: [
                              // Filter Header (Always Visible)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _filtersExpanded = !_filtersExpanded;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      Icon(
                                        _filtersExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_2,
                                        color: context.mutedForegroundColor,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Filter Content (Collapsible)
                              if (_filtersExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                              
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
                                  });
                                  _applyFilters();
                                },
                                style: TextStyle(color: context.foregroundColor),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Location Filter (Distance)
                              DropdownButtonFormField<double?>(
                                value: _selectedRadius,
                                decoration: InputDecoration(
                                  labelText: 'Distance',
                                  labelStyle: TextStyle(color: context.mutedForegroundColor),
                                  prefixIcon: Icon(Iconsax.location, color: context.mutedForegroundColor),
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
                                  const DropdownMenuItem<double?>(
                                    value: null,
                                    child: Text('Any Distance'),
                                  ),
                                  ..._radiusOptions.map((option) {
                                    return DropdownMenuItem<double?>(
                                      value: option['value'] as double,
                                      child: Text(option['label'] as String),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRadius = value;
                                  });
                                  _applyFilters();
                                },
                                style: TextStyle(color: context.foregroundColor),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Available Only Filter
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
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
                              
                              const SizedBox(height: 12),
                              
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
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Providers List with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: _isLoading && _providers.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _providers.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.4,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Iconsax.user_search,
                                              size: 80,
                                              color: context.mutedForegroundColor.withOpacity(0.5),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No providers found',
                                              style: TextStyle(
                                                color: context.mutedForegroundColor,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 16,
                                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                                  ),
                                  itemCount: _providers.length + (_isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _providers.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return _buildProviderCard(context, _providers[index], index);
                                  },
                                ),
                    ),
                  ),
                ],
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
            ProviderAvatar(
              imageUrl: profilePhoto,
              size: 48,
              borderRadius: BorderRadius.circular(24),
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
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn(duration: 400.ms).moveX(begin: 30, end: 0);
  }
}
