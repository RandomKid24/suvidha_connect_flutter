import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/booking_card_refresh.dart';
import '../../services/api_service.dart';
import '../../utils/icon_mapper.dart';
import '../../widgets/app_header.dart';

class SavedServicesScreen extends StatefulWidget {
  const SavedServicesScreen({super.key});

  @override
  State<SavedServicesScreen> createState() => _SavedServicesScreenState();
}

class _SavedServicesScreenState extends State<SavedServicesScreen> {
  List<dynamic> _providers = [];
  List<dynamic> _serviceCategories = [];
  int? _selectedServiceId;
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  LatLng? _userLocation;
  final MapController _mapController = MapController();
  double _radius = 30.0; // Default 30 km radius
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen to search controller changes
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    // Load service categories
    final categoriesResult = await ApiService.getServiceCategories(forceRefresh: forceRefresh);
    if (mounted) {
      if (categoriesResult['success'] == true) {
        final data = categoriesResult['data'];
        if (data is List) {
          _serviceCategories = data;
        } else if (data is Map && data.containsKey('results')) {
          _serviceCategories = data['results'] as List;
        }
      }
    }

    // Get user location first
    await _getUserLocation();

    // Load providers
    await _loadProviders(forceRefresh: forceRefresh);
  }

  Future<void> _loadProviders({bool forceRefresh = false}) async {
    final searchQuery = _searchController.text.isNotEmpty ? _searchController.text : null;
    print('🔍 [Saved Services] Searching for: "$searchQuery"');
    print('📍 Service category ID: $_selectedServiceId');
    print('📍 User location: $_userLocation');
    print('📍 Radius: $_radius km');
    
    final providersResult = await ApiService.getProviders(
      serviceCategoryId: _selectedServiceId,
      searchQuery: searchQuery,
      latitude: _userLocation != null ? _userLocation!.latitude : null,
      longitude: _userLocation != null ? _userLocation!.longitude : null,
      radius: _userLocation != null ? _radius : null, // Apply radius filter when location is available
      forceRefresh: forceRefresh, // Force refresh when user changes filter so results update
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (providersResult['success'] == true) {
          _providers = providersResult['data'] as List;
          print('✅ Found ${_providers.length} providers');
          if (_providers.isNotEmpty) {
            print('📋 First provider: ${_providers[0]['name']}');
          }
        } else {
          print('❌ Error loading providers: ${providersResult['error']}');
        }
      });
    }
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        // Move map to user location with a slight delay to ensure map is ready
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_userLocation != null && mounted) {
            _mapController.move(_userLocation!, 13.0);
          }
        });
        
        // Reload providers with location-based radius filter
        await _loadProviders();
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _applyFilters() {
    _loadProviders(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData(forceRefresh: true);
            BookingCardRefreshNotifier.notifyRefresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const AppHeader(),
            
            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Saved Services',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
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
                    // Update UI immediately
                    setState(() {});
                    // Cancel previous timer
                    _debounceTimer?.cancel();
                    // Start new timer for search
                    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                      if (value.length >= 1 || value.isEmpty) {
                        _applyFilters();
                      }
                    });
                  },
                  onSubmitted: (value) {
                    _debounceTimer?.cancel();
                    _applyFilters();
                  },
                ),
              ),
            ),
            
            // Filter dropdowns
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(
                  bottom: BorderSide(color: context.borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _selectedServiceId,
                      decoration: InputDecoration(
                        labelText: 'Filter by Service',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Services'),
                        ),
                        ..._serviceCategories.map((category) {
                          return DropdownMenuItem<int?>(
                            value: category['id'],
                            child: Text(category['name'] ?? ''),
                          );
                        }),
                      ],
                      onChanged: (value) async {
                        setState(() {
                          _selectedServiceId = value;
                          _isLoading = true;
                        });
                        await _loadProviders(forceRefresh: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      value: _radius,
                      decoration: InputDecoration(
                        labelText: 'Radius',
                        prefixIcon: Icon(Iconsax.location, size: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _radius = value;
                            _isLoading = true;
                          });
                          await _loadProviders(forceRefresh: true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Map - use fixed height so the list is scrollable and pull-to-refresh works
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _userLocation ?? const LatLng(19.9975, 73.7898), // Default to Nashik
                            initialZoom: _userLocation != null ? 13.0 : 12.0,
                            minZoom: 5.0,
                            maxZoom: 18.0,
                            onMapReady: () {
                              // Center map on user location when ready
                              if (_userLocation != null) {
                                _mapController.move(_userLocation!, 13.0);
                              }
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.suvidha_connect',
                            ),
                            MarkerLayer(
                              markers: _buildMarkers(),
                            ),
                          ],
                        ),
                        
                        // User location button
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: AppColors.primary,
                            onPressed: _getUserLocation,
                            child: _isLoadingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Iconsax.location, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Add user location marker (make it prominent)
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Iconsax.location, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    // Add provider markers with service-specific icons
    print('🗺️ Building markers for ${_providers.length} providers');
    int markersAdded = 0;
    int providersWithoutLocation = 0;
    
    for (var provider in _providers) {
      final lat = provider['latitude'];
      final lon = provider['longitude'];
      final providerName = provider['name'] ?? 'Unknown';
      
      if (lat != null && lon != null) {
        try {
          final latitude = double.tryParse(lat.toString());
          final longitude = double.tryParse(lon.toString());
          
          if (latitude != null && longitude != null) {
            print('✅ Adding marker for: $providerName at ($latitude, $longitude)');
            // Get the first service category to determine icon
            final services = provider['services'] as List? ?? [];
            IconData serviceIcon = Iconsax.location; // Default icon
            Color iconColor = AppColors.primary;
            
            if (services.isNotEmpty) {
              final firstService = services[0];
              final serviceCategory = firstService['service_category'];
              // Use icon from service category if available, otherwise use slug
              final iconName = serviceCategory?['icon'] ?? serviceCategory?['slug'] ?? '';
              serviceIcon = IconMapper.getIconFromName(iconName);
            }
            
            markers.add(
              Marker(
                point: LatLng(latitude, longitude),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () {
                    final providerId = provider['id'];
                    if (providerId != null) {
                      context.push('/provider/$providerId');
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: iconColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      serviceIcon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
            markersAdded++;
          } else {
            print('⚠️ Invalid coordinates for: $providerName (lat: $lat, lon: $lon)');
            providersWithoutLocation++;
          }
        } catch (e) {
          print('❌ Error parsing coordinates for provider ${provider['id']}: $e');
          providersWithoutLocation++;
        }
      } else {
        print('⚠️ No location data for: $providerName');
        providersWithoutLocation++;
      }
    }
    
    print('📊 Markers summary: $markersAdded added, $providersWithoutLocation without location');
    return markers;
  }

  IconData _getServiceIcon(String slug) {
    // First try to get icon from the service category's icon field
    // If slug is provided, try to get icon from slug (for backward compatibility)
    // Otherwise return location icon as default
    return IconMapper.getIconFromName(slug);
  }
}
