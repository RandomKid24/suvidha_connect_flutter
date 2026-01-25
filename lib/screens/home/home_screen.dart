import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';
import '../../utils/icon_mapper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userRole;
  bool _isLoadingUser = true;
  
  // Customer data
  List<dynamic> _services = [];
  bool _isLoadingServices = true;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  
  // Provider data
  List<dynamic> _bookingRequests = [];
  bool _isLoadingRequests = true;
  int _pendingCount = 0;
  int _acceptedCount = 0;
  int _inProgressCount = 0;
  int _totalBookings = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }
  
  Future<void> _loadUserRole() async {
    setState(() => _isLoadingUser = true);
    final result = await ApiService.getCurrentUserInfo(forceRefresh: false);
    
    if (mounted) {
      setState(() => _isLoadingUser = false);
      if (result['success'] == true) {
        final userData = result['data'];
        final role = userData['role'] ?? 'customer';
        setState(() => _userRole = role);
        
        if (role == 'provider') {
          _loadProviderData();
        } else {
          _loadCustomerData();
        }
      }
    }
  }
  
  Future<void> _loadCustomerData() async {
    _loadServices();
    _loadReviews();
  }
  
  Future<void> _loadProviderData() async {
    _loadBookingRequests();
  }
  
  Future<void> _loadBookingRequests({bool forceRefresh = false}) async {
    setState(() => _isLoadingRequests = true);
    final result = await ApiService.getProviderRequests(forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() => _isLoadingRequests = false);
      if (result['success'] == true) {
        final requests = result['data'] as List;
        setState(() {
          _bookingRequests = requests;
          _pendingCount = requests.where((r) => r['status'] == 'pending').length;
          _acceptedCount = requests.where((r) => r['status'] == 'accepted' || r['status'] == 'negotiation').length;
          _inProgressCount = requests.where((r) => r['status'] == 'in_progress').length;
          _totalBookings = requests.length;
        });
      }
    }
  }

  Future<void> _loadServices({bool forceRefresh = false}) async {
    setState(() => _isLoadingServices = true);
    final result = await ApiService.getServiceCategories(forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() => _isLoadingServices = false);
      if (result['success'] == true) {
        final data = result['data'];
        List<dynamic> servicesList = [];
        if (data is List) {
          servicesList = data;
        } else if (data is Map && data.containsKey('results')) {
          servicesList = data['results'] as List;
        }
        setState(() {
          _services = servicesList.where((s) => s['is_active'] == true).toList();
        });
      }
    }
  }

  Future<void> _loadReviews({bool forceRefresh = false}) async {
    setState(() => _isLoadingReviews = true);
    final result = await ApiService.getReviews(limit: 3, forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() => _isLoadingReviews = false);
      if (result['success'] == true) {
        setState(() {
          _reviews = result['data'] as List;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (_userRole == 'provider') {
                    await _loadBookingRequests(forceRefresh: true);
                  } else {
                    await _loadServices(forceRefresh: true);
                    await _loadReviews(forceRefresh: true);
                  }
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _userRole == 'provider' 
                    ? _buildProviderHome(context)
                    : _buildCustomerHome(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCustomerHome(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Services Grid Section
        Text(
          'What do you need help with?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.foregroundColor,
          ),
        ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
        
        const SizedBox(height: 16),
        
        _buildServicesGrid(context),
        
        const SizedBox(height: 32),
        
        // Reviews Section
        _buildReviewsSection(context),
      ],
    );
  }
  
  Widget _buildProviderHome(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Section
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.foregroundColor,
          ),
        ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
        
        const SizedBox(height: 24),
        
        // Statistics Cards
        _buildStatisticsCards(context),
        
        const SizedBox(height: 24),
        
        // Booking Requests Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Booking Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.foregroundColor,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/requests'),
              child: Text(
                'View All →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
        
        const SizedBox(height: 12),
        
        _buildBookingRequestsList(context),
      ],
    );
  }
  
  Widget _buildStatisticsCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Pending',
            _pendingCount.toString(),
            Iconsax.clock,
            AppColors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Accepted',
            _acceptedCount.toString(),
            Iconsax.tick_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'In Progress',
            _inProgressCount.toString(),
            Iconsax.activity,
            AppColors.primary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0);
  }
  
  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.foregroundColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.mutedForegroundColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBookingRequestsList(BuildContext context) {
    if (_isLoadingRequests) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_bookingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(
              Iconsax.document,
              size: 48,
              color: context.mutedForegroundColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No booking requests yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.foregroundColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New booking requests will appear here',
              style: TextStyle(
                fontSize: 14,
                color: context.mutedForegroundColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: _bookingRequests.take(5).map((request) {
        return _buildBookingRequestCard(context, request);
      }).toList(),
    );
  }
  
  Widget _buildBookingRequestCard(BuildContext context, dynamic request) {
    final bookingId = request['id'];
    if (bookingId == null) {
      // Return a non-clickable card if bookingId is missing
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Text(
          'Invalid booking data',
          style: TextStyle(color: context.mutedForegroundColor),
        ),
      );
    }
    
    final bookingIdStr = bookingId.toString();
    final customerName = request['customer_name'] ?? 'Customer';
    final serviceName = request['service_category_name'] ?? 'Service';
    final status = request['status'] ?? 'pending';
    final date = request['preferred_date'] ?? '';
    final time = request['preferred_time'] ?? '';
    
    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = AppColors.amber;
        statusText = 'Pending';
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        break;
      case 'in_progress':
        statusColor = AppColors.primary;
        statusText = 'In Progress';
        break;
      default:
        statusColor = context.mutedForegroundColor;
        statusText = status;
    }
    
    return GestureDetector(
      onTap: () {
        if (bookingIdStr.isNotEmpty) {
          context.push('/booking-details/$bookingIdStr');
        }
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                      customerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.mutedForegroundColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (date.isNotEmpty || time.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Iconsax.calendar, size: 16, color: context.mutedForegroundColor),
                const SizedBox(width: 8),
                Text(
                  date.isNotEmpty && time.isNotEmpty 
                    ? '$date at $time'
                    : date.isNotEmpty 
                      ? date 
                      : time,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.mutedForegroundColor,
                  ),
                ),
              ],
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleStartNegotiation(context, bookingId),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange),
                    ),
                    child: Text(
                      'Negotiate',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRejectBooking(context, bookingId),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    ).animate().fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }
  
  Future<void> _handleStartNegotiation(BuildContext context, int bookingId) async {
    final result = await ApiService.startNegotiation(bookingId);
    if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Negotiation started. You can now chat with the customer.')),
          );
          _loadBookingRequests(forceRefresh: true);
        } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to start negotiation')),
        );
      }
    }
  }

  Future<void> _handleAcceptBooking(BuildContext context, int bookingId) async {
    final result = await ApiService.acceptBooking(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking accepted successfully')),
        );
        _loadBookingRequests(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to accept booking')),
        );
      }
    }
  }
  
  Future<void> _handleRejectBooking(BuildContext context, int bookingId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: const Text('Are you sure you want to reject this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      final result = await ApiService.cancelBooking(bookingId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking rejected')),
          );
          _loadBookingRequests(forceRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error']?['message'] ?? 'Failed to reject booking')),
          );
        }
      }
    }
  }

  Widget _buildServicesGrid(BuildContext context) {
    if (_isLoadingServices) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_services.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No services available'),
        ),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        final serviceName = service['name'] ?? '';
        final serviceSlug = service['slug'] ?? '';
        
        // Use IconMapper to get icon from backend icon name
        
        return GestureDetector(
          onTap: () => context.push('/explore/$serviceSlug'),
          child: Container(
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.suvidhaLightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    IconMapper.getIconFromName(service['icon'] ?? ''),
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  serviceName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.foregroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: index * 50)).fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
        );
      },
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.foregroundColor,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/reviews'),
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
        ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
        
        const SizedBox(height: 12),
        
        if (_isLoadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No reviews yet',
                style: TextStyle(
                  color: context.mutedForegroundColor,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ..._reviews.asMap().entries.map((entry) {
            final index = entry.key;
            final review = entry.value;
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review['customer_name'] ?? 'Anonymous',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: context.foregroundColor,
                            ),
                          ),
                          if (review['service_name'] != null)
                            Text(
                              'for ${review['service_name']}',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 12,
                              ),
                            ),
                        ],
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
            ).animate(delay: Duration(milliseconds: 450 + index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
          }),
      ],
    );
  }

}

