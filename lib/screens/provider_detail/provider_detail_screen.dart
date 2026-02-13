import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/provider_avatar.dart';

class ProviderDetailScreen extends StatefulWidget {
  final String providerId;
  
  const ProviderDetailScreen({super.key, required this.providerId});

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  Map<String, dynamic>? _providerData;
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    print('🔍 Loading provider data for ID: ${widget.providerId}');
    final providerId = int.tryParse(widget.providerId);
    if (providerId == null) {
      print('❌ Invalid provider ID: ${widget.providerId}');
      setState(() {
        _isLoading = false;
        _error = 'Invalid provider ID: ${widget.providerId}';
      });
      return;
    }
    
    print('✅ Parsed provider ID: $providerId');
    
    // Load provider details and reviews in parallel (use cache by default)
    final providerResult = await ApiService.getProviderDetails(providerId, forceRefresh: forceRefresh);
    print('📊 Provider result: success=${providerResult['success']}, error=${providerResult['error']}');
    
    final reviewsResult = await ApiService.getReviews(providerId: providerId, forceRefresh: forceRefresh);
    print('📊 Reviews result: success=${reviewsResult['success']}');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (providerResult['success'] == true) {
          _providerData = providerResult['data'];
          print('✅ Provider data loaded: ${_providerData?['name']}');
        } else {
          final errorMsg = providerResult['error']?['message'] ?? providerResult['error']?['detail'] ?? 'Failed to load provider details';
          print('❌ Error loading provider: $errorMsg');
          _error = errorMsg;
        }
        
        if (reviewsResult['success'] == true) {
          _reviews = reviewsResult['data'] as List;
          print('✅ Loaded ${_reviews.length} reviews');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show error state - DO NOT show any mock data
    if (_error != null || _providerData == null) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.warning_2,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Provider not found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.foregroundColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _loadProviderData(),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Only show provider data if we have valid data from API
    final provider = _providerData!;
    final providerName = provider['name'] ?? 'Unknown';
    final profilePhoto = provider['profile_photo'];
    final locationString = provider['location_string'] ?? '';
    final address = provider['address'] ?? '';
    final services = provider['services'] as List? ?? [];
    final serviceNames = services.map((s) => s['service_category']?['name'] ?? '').where((n) => n.isNotEmpty).join(', ');
    final averageRating = (provider['average_rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = provider['total_reviews'] ?? 0;
    final isAvailable = provider['is_available'] ?? false;
    final availableFromDay = provider['available_from_day'];
    final availableToDay = provider['available_to_day'];
    final availableStartTime = provider['available_start_time'];
    final availableEndTime = provider['available_end_time'];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => context.pop(),
        ),
        backgroundColor: context.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Iconsax.location,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Service Address',
                    style: TextStyle(
                      color: context.mutedForegroundColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locationString.isNotEmpty ? locationString : (address.isNotEmpty ? address : 'Location not specified'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.foregroundColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Iconsax.message_question,
                color: context.mutedForegroundColor,
                size: 22,
              ),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadProviderData(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
            children: [
              // Provider Card and rest of content
              Column(
                children: [
                    // Provider Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        children: [
                          // Profile Image
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 4,
                              ),
                            ),
                            child: ProviderAvatar(
                              imageUrl: profilePhoto,
                              size: 96,
                              borderRadius: BorderRadius.circular(48),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Name
                          Text(
                            providerName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.foregroundColor,
                            ),
                          ),
                          
                          if (serviceNames.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            // Services
                            Text(
                              serviceNames,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          
                          // Rating and reviews
                          if (totalReviews > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: AppColors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  averageRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: context.mutedForegroundColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '·',
                                  style: TextStyle(
                                    color: context.mutedForegroundColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                                  style: TextStyle(
                                    color: context.mutedForegroundColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 20),
                    
                    // Book Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            // Get first service category ID if available
                            final firstService = services.isNotEmpty ? services[0] : null;
                            final serviceCategoryId = firstService?['service_category']?['id']?.toString();
                            final serviceName = firstService?['service_category']?['name'];
                            
                            String url = '/create-booking/${widget.providerId}';
                            if (serviceCategoryId != null || serviceName != null) {
                              final params = <String>[];
                              if (serviceCategoryId != null) {
                                params.add('serviceCategoryId=$serviceCategoryId');
                              }
                              if (serviceName != null) {
                                params.add('serviceName=${Uri.encodeComponent(serviceName)}');
                              }
                              if (params.isNotEmpty) {
                                url += '?${params.join('&')}';
                              }
                            }
                            print('Navigating to booking: $url');
                            // Use root navigator to navigate outside shell
                            final router = GoRouter.of(context);
                            router.push(url);
                          } catch (e) {
                            print('Error navigating to booking: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Book my service',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 20),
                    
                    // Provider Info Cards
                    if (address.isNotEmpty) ...[
                      _buildInfoCard(
                        icon: Iconsax.location,
                        title: 'Address',
                        value: address,
                        delay: 200,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    if (locationString.isNotEmpty) ...[
                      _buildInfoCard(
                        icon: Iconsax.map,
                        title: 'Location',
                        value: locationString,
                        delay: 300,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Availability Section
                    _buildAvailabilityCard(
                      isAvailable: isAvailable,
                      availableFromDay: availableFromDay,
                      availableToDay: availableToDay,
                      availableStartTime: availableStartTime,
                      availableEndTime: availableEndTime,
                      delay: 400,
                    ),
                    const SizedBox(height: 12),
                    
                    // Reviews Section
                    if (_reviews.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: context.foregroundColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'view all →',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._reviews.take(3).map((review) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    review['customer_name'] ?? 'Anonymous',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: context.foregroundColor,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        Icons.star,
                                        color: i < (review['rating'] as int? ?? 0)
                                            ? AppColors.amber
                                            : context.mutedColor,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  review['comment'],
                                  style: TextStyle(
                                    color: context.mutedForegroundColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.mutedForegroundColor,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: context.foregroundColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 400.ms).moveY(begin: 20, end: 0);
  }

  String _formatDay(String? day) {
    if (day == null) return '';
    // Capitalize first letter
    return day[0].toUpperCase() + day.substring(1);
  }

  String _formatTime(String? time) {
    if (time == null) return '';
    // Time comes as "HH:MM:SS" or "HH:MM", format to "HH:MM AM/PM"
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  Widget _buildAvailabilityCard({
    required bool isAvailable,
    dynamic availableFromDay,
    dynamic availableToDay,
    dynamic availableStartTime,
    dynamic availableEndTime,
    required int delay,
  }) {
    String availabilityText = '';
    
    if (availableFromDay != null && availableToDay != null && 
        availableStartTime != null && availableEndTime != null) {
      final fromDay = _formatDay(availableFromDay.toString());
      final toDay = _formatDay(availableToDay.toString());
      final startTime = _formatTime(availableStartTime.toString());
      final endTime = _formatTime(availableEndTime.toString());
      
      if (fromDay == toDay) {
        availabilityText = '$fromDay, $startTime - $endTime';
      } else {
        availabilityText = '$fromDay - $toDay, $startTime - $endTime';
      }
    } else if (isAvailable) {
      availabilityText = 'Available now';
    } else {
      availabilityText = 'Availability not specified';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable ? Colors.green : AppColors.border,
          width: isAvailable ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAvailable 
                  ? Colors.green.withOpacity(0.1) 
                  : context.mutedColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAvailable ? Iconsax.tick_circle : Iconsax.clock,
              color: isAvailable ? Colors.green : context.mutedForegroundColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isAvailable ? 'Available' : 'Not Available',
                      style: TextStyle(
                        color: isAvailable ? Colors.green : context.mutedForegroundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  availabilityText,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: context.foregroundColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 400.ms).moveY(begin: 20, end: 0);
  }
}


