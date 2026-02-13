import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<dynamic> _completedBookings = [];
  List<dynamic> _reviews = [];
  List<dynamic> _allReviews = []; // All reviews in the system
  bool _isLoading = true;
  String? _error;
  bool _showAllReviews = true; // Show all reviews by default (from "view all" button)

  @override
  void initState() {
    super.initState();
    // Force refresh on initial load to ensure we get all reviews (not just cached limited ones)
    _loadData(forceRefresh: true);
  }

  Future<void> _loadData({bool forceRefresh = false, bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    // Load all reviews (use cache by default) - this is what "view all" should show
    // Note: Not passing limit parameter to get ALL reviews
    final reviewsResult = await ApiService.getReviews(forceRefresh: forceRefresh);
    print('📊 Reviews API result: success=${reviewsResult['success']}, count=${reviewsResult['success'] == true ? (reviewsResult['data'] as List).length : 0}');
    
    // Also load completed bookings for the "My Reviews" section
    final bookingsResult = await ApiService.getUserBookings(forceRefresh: forceRefresh);
    print('📊 Bookings API result: success=${bookingsResult['success']}, count=${bookingsResult['success'] == true ? (bookingsResult['data'] as List).length : 0}');

    if (mounted) {
      setState(() {
        if (showLoading) {
          _isLoading = false;
        }
        if (reviewsResult['success'] == true) {
          _allReviews = reviewsResult['data'] as List;
          print('✅ Loaded ${_allReviews.length} reviews for "All Reviews" tab');
          // Use all reviews to check if booking was reviewed
          _reviews = _allReviews;
        } else {
          print('❌ Failed to load reviews: ${reviewsResult['error']}');
        }
        if (bookingsResult['success'] == true) {
          final allBookings = bookingsResult['data'] as List;
          _completedBookings = allBookings.where((b) => b['status'] == 'completed').toList();
          print('✅ Loaded ${_completedBookings.length} completed bookings for "My Reviews" tab');
        } else {
          print('❌ Failed to load bookings: ${bookingsResult['error']}');
        }
        // Only set error if both failed
        if (reviewsResult['success'] != true && bookingsResult['success'] != true) {
          _error = 'Failed to load data';
        }
      });
    }
  }

  /// Booking-based: true if this booking already has a review.
  bool _hasReviewedBooking(int bookingId) {
    return _reviews.any((review) {
      final rid = review['booking_id'] ?? review['booking']?['id'] ?? review['booking'];
      if (rid == null) return false;
      return rid == bookingId || rid.toString() == bookingId.toString();
    });
  }

  Future<void> _showReviewDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id'];
    final providerId = booking['provider']?['id'];
    final serviceCategoryId = booking['service_category']?['id'];
    if (bookingId == null || providerId == null) return;

    // Booking-based: one review per booking
    if (_hasReviewedBooking(bookingId is int ? bookingId : int.tryParse(bookingId.toString()) ?? 0)) {
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

                      final result = await ApiService.createReview(reviewData);
                      if (mounted) {
                        Navigator.pop(context);
                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review submitted successfully')),
                          );
                          _loadData(forceRefresh: true); // Force refresh after creating review
                        } else {
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
                  // Refresh both all reviews and completed bookings
                  // Don't show loading spinner during pull-to-refresh (RefreshIndicator handles it)
                  await _loadData(forceRefresh: true, showLoading: false);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Toggle between "All Reviews" and "My Reviews"
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAllReviews = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: _showAllReviews ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _showAllReviews ? AppColors.primary : context.borderColor,
                                ),
                              ),
                              child: Text(
                                'All Reviews',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _showAllReviews ? Colors.white : context.foregroundColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAllReviews = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: !_showAllReviews ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_showAllReviews ? AppColors.primary : context.borderColor,
                                ),
                              ),
                              child: Text(
                                'My Reviews',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !_showAllReviews ? Colors.white : context.foregroundColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: context.foregroundColor,
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
                    else if (_showAllReviews)
                      // Show all reviews
                      _allReviews.isEmpty
                          ? SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Iconsax.star,
                                      size: 80,
                                      color: context.mutedForegroundColor.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No reviews yet',
                                      style: TextStyle(
                                        color: context.mutedForegroundColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: _allReviews.asMap().entries.map((entry) {
                                final index = entry.key;
                                final review = entry.value;
                                return _buildReviewCard(review, index);
                              }).toList(),
                            )
                    else
                      // Show "My Reviews" - completed bookings to review
                      _completedBookings.isEmpty
                          ? SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Iconsax.star,
                                      size: 80,
                                      color: context.mutedForegroundColor.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No completed services',
                                      style: TextStyle(
                                        color: context.mutedForegroundColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Complete a service to review it',
                                      style: TextStyle(
                                        color: context.mutedForegroundColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: _completedBookings.asMap().entries.map((entry) {
                                final index = entry.key;
                                final booking = entry.value;
                                return _buildBookingCard(booking, index);
                              }).toList(),
                            ),
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
    final bookingId = booking['id'];
    final serviceName = booking['service_name'] ?? 'Service';
    final providerName = booking['provider_name'] ?? 'Provider';
    final hasReviewed = bookingId != null &&
                       _hasReviewedBooking(bookingId is int ? bookingId : int.tryParse(bookingId.toString()) ?? 0);

    String? completedDateStr;
    if (booking['completed_at'] != null) {
      try {
        final date = DateTime.parse(booking['completed_at']);
        completedDateStr = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        completedDateStr = booking['completed_at'];
      }
    }

    return Container(
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: context.foregroundColor,
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
                    if (completedDateStr != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Completed: $completedDateStr',
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasReviewed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Reviewed',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (!hasReviewed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReviewDialog(booking),
                icon: const Icon(Iconsax.star),
                label: const Text('Write Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }

  Widget _buildReviewCard(Map<String, dynamic> review, int index) {
    final customerName = review['customer_name'] ?? 'Anonymous';
    final serviceName = review['service_name'] ?? 'Service';
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] ?? '';
    final createdAt = review['created_at'];
    
    String? dateStr;
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        dateStr = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateStr = createdAt.toString();
      }
    }

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: context.foregroundColor,
                      ),
                    ),
                    if (serviceName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'for $serviceName',
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (dateStr != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star,
                    color: i < rating
                        ? AppColors.amber
                        : context.mutedColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                color: context.foregroundColor,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }
}

