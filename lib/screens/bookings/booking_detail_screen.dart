import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../services/notification_scheduler_service.dart';
import '../../widgets/app_header.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  String? _error;
  String? _userRole;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadBookingDetails();
    _startPolling();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _refreshBookingDetailsSilently();
      }
    });
  }

  Future<void> _loadUserRole() async {
    final result = await ApiService.getCurrentUserInfo();
    if (result['success'] == true) {
      setState(() {
        _userRole = result['data']?['role'];
      });
    }
  }

  Future<void> _loadBookingDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid booking ID';
      });
      return;
    }

    // Get all bookings and find the one we need
    final result = await ApiService.getUserBookings();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final bookings = result['data'] as List;
          _booking = bookings.firstWhere(
            (b) => b['id'] == bookingId,
            orElse: () => null,
          );
          if (_booking == null) {
            _error = 'Booking not found';
          } else {
            // Schedule reminders if it is an accepted/in_progress booking
            final status = _booking!['status'];
            if (status == 'accepted' || status == 'in_progress') {
              NotificationSchedulerService.scheduleBookingReminders(_booking!);
            }
          }
        } else {
          _error = result['error']?['message'] ?? 'Failed to load booking details';
        }
      });
    }
  }

  Future<void> _refreshBookingDetailsSilently() async {
    final bId = int.tryParse(widget.bookingId);
    if (bId == null) return;

    final result = await ApiService.getUserBookings();
    
    if (mounted && result['success'] == true) {
      final bookings = result['data'] as List;
      final newBooking = bookings.firstWhere(
        (b) => b['id'] == bId,
        orElse: () => null,
      );
      
      if (newBooking != null) {
        // Only update if something changed
        if (_booking == null || 
            _booking!['status'] != newBooking['status'] ||
            _booking!['proposed_price'] != newBooking['proposed_price'] ||
            _booking!['price_locked'] != newBooking['price_locked']) {
          setState(() {
            _booking = newBooking;
          });
        }
      }
    }
  }

  Future<void> _handleStartNegotiation() async {
    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final result = await ApiService.startNegotiation(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Negotiation started. You can now chat with the customer.')),
        );
        _loadBookingDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to start negotiation')),
        );
      }
    }
  }

  Future<void> _handleAcceptBooking() async {
    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final result = await ApiService.acceptBooking(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking accepted successfully')),
        );
        _loadBookingDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to accept booking')),
        );
      }
    }
  }

  Future<void> _handleStartChat() async {
    if (_booking == null) return;
    
    final customerId = _booking!['customer']?['id'] ?? _booking!['customer_id'];
    final providerId = _booking!['provider']?['id'] ?? _booking!['provider_id'];
    
    // Navigate to chat screen
    context.push('/chat/${widget.bookingId}', extra: {
      'customerId': customerId,
      'providerId': providerId,
      'bookingId': int.tryParse(widget.bookingId),
    });
  }

  Future<void> _handlePayBooking() async {
    // Use the final locked price (price field) if available, otherwise use proposed_price
    // When price is accepted, it's moved from proposed_price to price and locked
    final priceLocked = _booking?['price_locked'] == true;
    
    // Determine which price to use: locked price takes priority, then price, then proposed_price
    dynamic finalPriceRaw;
    if (priceLocked && _booking?['price'] != null) {
      finalPriceRaw = _booking?['price'];
    } else if (_booking?['price'] != null) {
      finalPriceRaw = _booking?['price'];
    } else if (_booking?['proposed_price'] != null) {
      finalPriceRaw = _booking?['proposed_price'];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking price is not set')),
      );
      return;
    }
    
    if (finalPriceRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking price is not set')),
      );
      return;
    }

    // Convert booking price to double (handle both String and num types)
    // Use the final price (locked price if available, otherwise proposed price)
    double? bookingPriceNullable;
    if (finalPriceRaw is String) {
      bookingPriceNullable = double.tryParse(finalPriceRaw);
    } else if (finalPriceRaw is num) {
      bookingPriceNullable = finalPriceRaw.toDouble();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking price format')),
      );
      return;
    }

    if (bookingPriceNullable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking price')),
      );
      return;
    }

    // Now we know it's not null, store in non-nullable variable
    final bookingPrice = bookingPriceNullable;

    // Check wallet balance first
    final walletResult = await ApiService.getWalletBalance();
    if (walletResult['success'] == true) {
      final balance = walletResult['balance']?.toDouble() ?? 0.0;
      if (balance < bookingPrice) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Insufficient Balance'),
            content: Text(
              'Your wallet balance is Rs. ${balance.toStringAsFixed(2)}/-, but you need Rs. ${bookingPrice.toStringAsFixed(2)}/-.\n\nWould you like to add money to your wallet?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Money'),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          // Show wallet dialog
          // The wallet dialog is accessible from app header
          return;
        }
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Pay Rs. ${bookingPrice.toStringAsFixed(2)}/- for this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Pay'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    setState(() {
      _isLoading = true;
    });
    
    final result = await ApiService.payBooking(bookingId);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookingDetails();
      } else {
        final errorMessage = result['error']?['message'] ?? 
                            result['error']?['error'] ?? 
                            'Payment failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleCancelBooking() async {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final result = await ApiService.cancelBooking(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
        _loadBookingDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to cancel booking')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              showBackButton: true,
              title: 'Booking Details',
            ),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.info_circle, size: 48, color: context.mutedForegroundColor),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(color: context.mutedForegroundColor),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadBookingDetails,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _booking == null
                    ? const Center(child: Text('Booking not found'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Booking Status
                            _buildStatusCard(context),
                            const SizedBox(height: 16),
                            
                            // Booking Details
                            _buildDetailsSection(context),
                            const SizedBox(height: 16),
                            
                            // Service Information
                            _buildServiceSection(context),
                            const SizedBox(height: 16),
                            
                            // Customer/Provider Info
                            _buildUserInfoSection(context),
                            const SizedBox(height: 16),
                            
                            // Actions
                            _buildActionButtons(context),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status = _booking!['status'] ?? 'pending';
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'pending':
        statusColor = AppColors.amber;
        statusText = 'Pending';
        break;
      case 'negotiation':
        statusColor = Colors.orange;
        statusText = 'Negotiation';
        break;
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        break;
      case 'in_progress':
        statusColor = AppColors.primary;
        statusText = 'In Progress';
        break;
      case 'payment':
        statusColor = Colors.purple;
        statusText = 'Payment Pending';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = context.mutedForegroundColor;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.info_circle, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Status: $statusText',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    // Collect all possible date/time fields
    final preferredDate = _booking!['preferred_date'] ?? '';
    final preferredTime = _booking!['preferred_time'] ?? '';
    final scheduledDateRaw = _booking!['scheduled_date'];
    
    String displayDateTime = 'Not specified';
    
    if (scheduledDateRaw != null) {
      try {
        final date = DateTime.parse(scheduledDateRaw);
        displayDateTime = DateFormat('MMM d, yyyy • h:mm a').format(date);
      } catch (e) {
        displayDateTime = scheduledDateRaw.toString();
      }
    } else if (preferredDate.isNotEmpty || preferredTime.isNotEmpty) {
      if (preferredDate.isNotEmpty && preferredTime.isNotEmpty) {
        displayDateTime = '$preferredDate at $preferredTime';
      } else {
        displayDateTime = preferredDate.isNotEmpty ? preferredDate : preferredTime;
      }
    }

    final address = _booking!['address'] ?? 'Not specified';
    final description = _booking!['description'] ?? 'No description';
    
    // Price display logic
    final status = _booking!['status'] as String? ?? '';
    final priceLocked = _booking!['price_locked'] == true;
    final originalPrice = _booking!['price'];
    final proposedPrice = _booking!['proposed_price'];
    final proposedBy = _booking!['proposed_by'];
    final isProvider = _userRole == 'provider';
    
    // Build price display
    Widget priceWidget;
    if (priceLocked && originalPrice != null) {
      // Price is locked (final negotiated price)
      final priceValue = originalPrice is String 
          ? double.tryParse(originalPrice)?.toStringAsFixed(2) ?? originalPrice
          : (originalPrice is num ? originalPrice.toStringAsFixed(2) : originalPrice.toString());
      priceWidget = _buildDetailRow(
        context, 
        Iconsax.dollar_circle, 
        'Final Price (Locked)', 
        'Rs. $priceValue/-',
      );
    } else if (proposedPrice != null) {
      // Show proposed price during negotiation
      final proposedPriceValue = proposedPrice is String 
          ? double.tryParse(proposedPrice)?.toStringAsFixed(2) ?? proposedPrice
          : (proposedPrice is num ? proposedPrice.toStringAsFixed(2) : proposedPrice.toString());
      
      final proposedByName = proposedBy != null 
          ? (proposedBy['name'] ?? proposedBy['username'] ?? 'Unknown')
          : 'Unknown';
      
      final whoProposed = proposedBy != null && proposedBy['id'] != null
          ? (isProvider && proposedBy['id'] == _booking!['customer']?['id'] 
              ? 'Customer' 
              : (!isProvider && proposedBy['id'] == _booking!['provider']?['user']?['id']
                  ? 'Provider'
                  : proposedByName))
          : 'Unknown';
      
      priceWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            context, 
            Iconsax.dollar_circle, 
            'Proposed Price', 
            'Rs. $proposedPriceValue/-',
          ),
          if (status == 'negotiation') ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                'Proposed by: $whoProposed',
                style: TextStyle(
                  fontSize: 12,
                  color: context.mutedForegroundColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (originalPrice != null && originalPrice != proposedPrice) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                'Original: Rs. ${originalPrice is String ? double.tryParse(originalPrice)?.toStringAsFixed(2) ?? originalPrice : (originalPrice is num ? originalPrice.toStringAsFixed(2) : originalPrice.toString())}/-',
                style: TextStyle(
                  fontSize: 12,
                  color: context.mutedForegroundColor,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ],
      );
    } else if (originalPrice != null) {
      // Show original price if no negotiation yet
      final priceValue = originalPrice is String 
          ? double.tryParse(originalPrice)?.toStringAsFixed(2) ?? originalPrice
          : (originalPrice is num ? originalPrice.toStringAsFixed(2) : originalPrice.toString());
      priceWidget = _buildDetailRow(
        context, 
        Iconsax.dollar_circle, 
        'Price', 
        'Rs. $priceValue/-',
      );
    } else {
      priceWidget = _buildDetailRow(
        context, 
        Iconsax.dollar_circle, 
        'Price', 
        'Not specified',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.foregroundColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(context, Iconsax.calendar, 'Date & Time', displayDateTime),
          const SizedBox(height: 12),
          _buildDetailRow(context, Iconsax.location, 'Address', address),
          const SizedBox(height: 12),
          priceWidget,
          const SizedBox(height: 12),
          _buildDetailRow(context, Iconsax.document_text, 'Description', description),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.mutedForegroundColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.mutedForegroundColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceSection(BuildContext context) {
    final serviceName = _booking!['service_name'] ?? _booking!['service_category']?['name'] ?? 'Service';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.suvidhaLightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.category, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.mutedForegroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serviceName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context) {
    final isProvider = _userRole == 'provider';
    final userName = isProvider 
      ? (_booking!['customer_name'] ?? _booking!['customer']?['name'] ?? 'Customer')
      : (_booking!['provider_name'] ?? _booking!['provider']?['name'] ?? 'Provider');
    final userPhone = isProvider
      ? (_booking!['customer']?['phone'] ?? '')
      : (_booking!['provider']?['phone'] ?? '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.mutedColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Iconsax.user, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProvider ? 'Customer' : 'Provider',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.mutedForegroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.foregroundColor,
                  ),
                ),
                if (userPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    userPhone,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.mutedForegroundColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final status = _booking!['status'] ?? 'pending';
    final isProvider = _userRole == 'provider';

    return Column(
      children: [
        if (isProvider && status == 'pending') ...[
          ElevatedButton.icon(
            onPressed: _handleStartNegotiation,
            icon: const Icon(Iconsax.message_question),
            label: const Text('Start Negotiation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (status == 'negotiation' || status == 'accepted' || status == 'in_progress') ...[
          ElevatedButton.icon(
            onPressed: _handleStartChat,
            icon: const Icon(Iconsax.message),
            label: const Text('Start Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Payment button (customer only)
        if (!isProvider && status == 'payment') ...[
          ElevatedButton.icon(
            onPressed: _handlePayBooking,
            icon: const Icon(Iconsax.wallet),
            label: const Text('Pay Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Cancel button for negotiation and accepted states
        if (status == 'negotiation' || status == 'accepted') ...[
          OutlinedButton.icon(
            onPressed: _handleCancelBooking,
            icon: const Icon(Iconsax.close_circle),
            label: const Text('Cancel Booking'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
        if (isProvider && status == 'pending') ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _handleStartNegotiation,
            icon: const Icon(Iconsax.message_question),
            label: const Text('Start Negotiation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ],
    );
  }
}

