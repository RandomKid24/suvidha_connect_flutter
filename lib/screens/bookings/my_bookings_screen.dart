import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/booking_card_refresh.dart';
import '../../services/api_service.dart';
import '../../services/notification_scheduler_service.dart';
import '../../widgets/app_header.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<dynamic> _bookings = [];
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPolling();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _refreshDataSilently();
      }
    });
  }

  Future<void> _refreshDataSilently() async {
    // Use cache first, but refresh if data is stale
    final bookingsResult = await ApiService.getUserBookings(forceRefresh: false);
    if (mounted && bookingsResult['success'] == true) {
      setState(() {
        _bookings = bookingsResult['data'] as List;
      });
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Load bookings and reviews in parallel (use cache by default)
    final bookingsResult = await ApiService.getUserBookings(forceRefresh: forceRefresh);
    final reviewsResult = await ApiService.getReviews(forceRefresh: forceRefresh);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (bookingsResult['success'] == true) {
          _bookings = bookingsResult['data'] as List;
          // Schedule reminders for upcoming bookings
          _scheduleUpcomingReminders();
        }
        if (reviewsResult['success'] == true) {
          _reviews = reviewsResult['data'] as List;
        }
        if (bookingsResult['success'] != true) {
          _error = bookingsResult['error']?['message'] ?? 'Failed to load bookings';
        }
      });
    }
  }

  /// Booking-based: true if this booking already has a review.
  bool _hasReviewedBooking(int bookingId) {
    if (_reviews.isEmpty) return false;
    return _reviews.any((review) {
      final rid = review['booking_id'] ?? review['booking']?['id'] ?? review['booking'];
      if (rid == null) return false;
      return rid == bookingId || rid.toString() == bookingId.toString();
    });
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id'];
    if (bookingId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Optimistic update: Remove booking from list immediately
    final previousBookings = List<Map<String, dynamic>>.from(_bookings);
    setState(() {
      _bookings = _bookings.where((b) => b['id'] != bookingId).toList();
    });

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelling booking...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final result = await ApiService.cancelBooking(
      bookingId,
      onError: () {
        // Revert optimistic update on error
        if (mounted) {
          setState(() {
            _bookings = previousBookings;
          });
        }
      },
    );
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        // Refresh to get updated data from server
        _loadData(forceRefresh: true);
      } else {
        // Error already handled by onError callback (reverted state)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to cancel booking',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id'];
    if (bookingId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text('Are you sure you want to delete this booking from your history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Optimistic update: Remove booking from list immediately
    final previousBookings = List<Map<String, dynamic>>.from(_bookings);
    setState(() {
      _bookings = _bookings.where((b) => b['id'] != bookingId).toList();
    });

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting booking...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final result = await ApiService.deleteBooking(
      bookingId,
      onError: () {
        // Revert optimistic update on error
        if (mounted) {
          setState(() {
            _bookings = previousBookings;
          });
        }
      },
    );
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        // Refresh to get updated data from server
        _loadData(forceRefresh: true);
      } else {
        // Error already handled by onError callback (reverted state)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to delete booking',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _scheduleUpcomingReminders() {
    for (var booking in _bookings) {
      final status = booking['status'];
      if (status == 'accepted' || status == 'in_progress') {
        NotificationSchedulerService.scheduleBookingReminders(booking);
      }
    }
  }

  Future<void> _showReviewDialog(Map<String, dynamic> booking) async {
    final providerId = booking['provider']?['id'];
    
    // Extract service category ID properly
    dynamic serviceCategoryIdRaw;
    if (booking['service_category'] is Map) {
      serviceCategoryIdRaw = booking['service_category']?['id'];
    } else {
      serviceCategoryIdRaw = booking['service_category'];
    }
    final serviceCategoryId = serviceCategoryIdRaw is int 
        ? serviceCategoryIdRaw 
        : (serviceCategoryIdRaw != null ? int.tryParse(serviceCategoryIdRaw.toString()) : null);
    
    final bookingIdRaw = booking['id'];
    final bookingId = bookingIdRaw is int ? bookingIdRaw : int.tryParse(bookingIdRaw?.toString() ?? '');
    if (providerId == null || bookingId == null) return;

    // Booking-based: one review per booking
    if (_hasReviewedBooking(bookingId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reviewed this booking')),
      );
      return;
    }

    int? selectedRating;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Write a Review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Service: ${booking['service_name'] ?? 'Service'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Provider: ${booking['provider_name'] ?? 'Provider'}',
                  style: TextStyle(color: context.mutedForegroundColor),
                ),
                const SizedBox(height: 16),
                const Text('Rating:'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    return IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = rating;
                        });
                      },
                      icon: Icon(
                        selectedRating != null && rating <= selectedRating!
                            ? Iconsax.star1
                            : Iconsax.star,
                        color: selectedRating != null && rating <= selectedRating!
                            ? Colors.amber
                            : context.mutedForegroundColor,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comment (Optional)',
                    hintText: 'Share your experience...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedRating == null
                  ? null
                  : () async {
                      final reviewData = {
                        'booking_id': bookingId,
                        'rating': selectedRating,
                        'comment': commentController.text.trim(),
                      };

                      // Optimistic update: Add review to local list immediately
                      final optimisticReview = {
                        'id': DateTime.now().millisecondsSinceEpoch,
                        'booking_id': bookingId,
                        'rating': selectedRating,
                        'comment': commentController.text.trim(),
                        'customer_name': 'You',
                        'created_at': DateTime.now().toIso8601String(),
                      };
                      final previousReviews = List<dynamic>.from(_reviews);
                      setState(() {
                        _reviews = [optimisticReview, ..._reviews];
                      });

                      final result = await ApiService.createReview(
                        reviewData,
                        onError: () {
                          // Revert optimistic update on error
                          if (mounted) {
                            setState(() {
                              _reviews = previousReviews;
                            });
                          }
                        },
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review submitted successfully')),
                          );
                          // Refresh to get the actual review from server
                          _loadData(forceRefresh: true);
                        } else {
                          // Error already handled by onError callback (reverted state)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['error']?['message'] ?? 'Failed to submit review',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.primary;
      case 'in_progress':
        return AppColors.suvidhaCyan;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.primary; // Use primary color as fallback instead of muted
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
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
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadData(forceRefresh: true);
                  BookingCardRefreshNotifier.notifyRefresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Bookings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'View all your service bookings',
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
                    else if (_error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
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
                                _error!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_bookings.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Icon(
                              Iconsax.briefcase,
                              size: 80,
                              color: context.mutedForegroundColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No bookings yet',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your bookings will appear here',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._bookings.asMap().entries.map((entry) {
                        final index = entry.key;
                        final booking = entry.value;
                        return _buildBookingCard(booking, index);
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

  Widget _buildBookingCard(Map<String, dynamic> booking, int index) {
    final status = booking['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    
    // Extract service category ID properly
    dynamic serviceCategoryIdRaw;
    if (booking['service_category'] is Map) {
      serviceCategoryIdRaw = booking['service_category']?['id'];
    } else {
      serviceCategoryIdRaw = booking['service_category'];
    }
    final serviceCategoryId = serviceCategoryIdRaw is int 
        ? serviceCategoryIdRaw 
        : (serviceCategoryIdRaw != null ? int.tryParse(serviceCategoryIdRaw.toString()) : null);
    
    print('📦 Booking $index - Service Category ID: $serviceCategoryId');
    print('   Booking data: ${booking['service_category']}');
    
    final providerName = booking['provider_name'] ?? booking['provider']?['name'] ?? 'Unknown Provider';
    final serviceName = booking['service_name'] ?? booking['service_category']?['name'] ?? 'Unknown Service';
    final description = booking['description'] ?? 'No description';
    final address = booking['address'] ?? 'Address not specified';
    final price = booking['price'] != null ? 'Rs. ${booking['price']}/-' : 'Price not specified';
    
    String? scheduledDateStr;
    if (booking['scheduled_date'] != null) {
      try {
        final date = DateTime.parse(booking['scheduled_date']);
        scheduledDateStr = DateFormat('MMM d, yyyy hh:mm a').format(date);
      } catch (e) {
        scheduledDateStr = booking['scheduled_date'];
      }
    }
    
    String? createdDateStr;
    if (booking['created_at'] != null) {
      try {
        final date = DateTime.parse(booking['created_at']);
        createdDateStr = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        createdDateStr = booking['created_at'];
      }
    }

    final bookingId = booking['id'];
    if (bookingId == null) {
      // Return a non-clickable card if bookingId is missing
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
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
    
    return GestureDetector(
      onTap: () => context.push('/booking-details/${bookingId.toString()}'),
      child: Container(
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
                      serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Provider: $providerName',
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.document_text, size: 16, color: context.mutedForegroundColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Iconsax.location, size: 16, color: context.mutedForegroundColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (scheduledDateStr != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Iconsax.calendar, size: 16, color: context.mutedForegroundColor),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduled: $scheduledDateStr',
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Iconsax.card, size: 16, color: context.mutedForegroundColor),
                    const SizedBox(width: 8),
                    Text(
                      price,
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (createdDateStr != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Iconsax.clock, size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 8),
                      Text(
                        'Booked on: $createdDateStr',
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Action buttons
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // Cancel button for non-completed, non-cancelled bookings
              if (status != 'completed' && status != 'cancelled') {
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelBooking(booking),
                    icon: const Icon(Iconsax.close_circle),
                    label: const Text('Cancel Booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                );
              }
              
              // For completed or cancelled bookings, show review/delete options
              if (status == 'completed' || status == 'cancelled') {
                final bookingIdRaw = booking['id'];
                final bookingIdForReview = bookingIdRaw is int ? bookingIdRaw : int.tryParse(bookingIdRaw?.toString() ?? '') ?? 0;
                final hasReviewed = status == 'completed' &&
                                   bookingIdForReview != 0 &&
                                   _hasReviewedBooking(bookingIdForReview);
                
                return Column(
                  children: [
                    // Review button for completed bookings
                    if (status == 'completed')
                      SizedBox(
                        width: double.infinity,
                        child: hasReviewed
                            ? Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.success),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Iconsax.tick_circle, color: AppColors.success, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reviewed',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _showReviewDialog(booking),
                                icon: const Icon(Iconsax.star),
                                label: const Text('Write Review'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                      ),
                    // Delete button for completed or cancelled bookings
                    if (status == 'completed' || status == 'cancelled') ...[
                      if (status == 'completed') const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteBooking(booking),
                          icon: const Icon(Iconsax.trash),
                          label: const Text('Delete from History'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }
}

