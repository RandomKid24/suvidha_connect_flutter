import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../services/notification_scheduler_service.dart';
import '../../widgets/app_header.dart';

class ProviderRequestsScreen extends StatefulWidget {
  const ProviderRequestsScreen({super.key});

  @override
  State<ProviderRequestsScreen> createState() => _ProviderRequestsScreenState();
}

class _ProviderRequestsScreenState extends State<ProviderRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _startPolling();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshRequestsSilently();
      }
    });
  }

  Future<void> _refreshRequestsSilently() async {
    final result = await ApiService.getProviderRequests();
    if (mounted && result['success'] == true) {
      setState(() {
        _requests = result['data'] as List;
        _scheduleReminders();
      });
    }
  }

  void _scheduleReminders() {
    for (var request in _requests) {
      final status = request['status'];
      if (status == 'accepted' || status == 'in_progress') {
        NotificationSchedulerService.scheduleBookingReminders(request);
      }
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getProviderRequests();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        setState(() {
          _requests = result['data'] as List;
          // Schedule reminders for accepted requests
          _scheduleReminders();
        });
      }
    }
  }

  Future<void> _acceptRequest(int bookingId) async {
    final result = await ApiService.acceptBooking(bookingId);
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted successfully')),
        );
        _loadRequests(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to accept request'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeRequest(int bookingId) async {
    final result = await ApiService.completeBooking(bookingId);
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service marked as completed')),
        );
        _loadRequests(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to complete request'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null) return 'Not scheduled';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MMM d, y • h:mm a').format(dateTime);
    } catch (e) {
      return 'Not scheduled';
    }
  }

  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.primary;
      case 'in_progress':
        return AppColors.accent;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRequests,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Requests',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Manage your service requests',
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 14,
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms),
                    
                    const SizedBox(height: 20),
                    
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_requests.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Icon(
                              Iconsax.document,
                              size: 80,
                              color: context.mutedForegroundColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No requests yet',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You will see service requests here',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._requests.asMap().entries.map((entry) {
                        final index = entry.key;
                        final request = entry.value;
                        return _buildRequestCard(request, index);
                      }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRequestCard(dynamic request, int index) {
    final requestId = request['id'] ?? 0;
    final customerName = request['customer_name'] ?? 'Unknown';
    final serviceName = request['service_name'] ?? 'Service';
    final status = request['status'] ?? 'pending';
    final description = request['description'] ?? '';
    final address = request['address'] ?? '';
    final scheduledDate = request['scheduled_date'];
    final price = request['price'];
    final createdAt = request['created_at'];
    
    return Builder(
      builder: (context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
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
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: context.mutedForegroundColor,
                fontSize: 14,
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(
                Iconsax.location,
                size: 16,
                color: context.mutedForegroundColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: context.mutedForegroundColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          
          if (scheduledDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Iconsax.calendar,
                  size: 16,
                  color: context.mutedForegroundColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(scheduledDate),
                  style: TextStyle(
                    color: context.mutedForegroundColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          
          if (price != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Iconsax.card,
                  size: 16,
                  color: context.mutedForegroundColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs. $price',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          
          Text(
            'Requested ${_formatTimeAgo(createdAt)}',
            style: TextStyle(
              color: context.mutedForegroundColor,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          if (status == 'pending')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptRequest(requestId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Accept Request'),
              ),
            )
          else if (status == 'accepted')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _completeRequest(requestId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Mark as Completed'),
              ),
            ),
        ],
      ),
      ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0),
    );
  }
}

