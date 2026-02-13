import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/booking_card_refresh.dart';
import '../../core/wallet_refresh.dart';
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
  bool _arrivedLoading = false;
  bool _arrivedSent = false;
  /// Exact backend error when Mark as Complete fails (e.g. insufficient balance). Shown in card above actions.
  String? _completeErrorMessage;

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
    final result = await ApiService.getCurrentUserInfo(forceRefresh: false);
    if (result['success'] == true) {
      setState(() {
        _userRole = result['data']?['role'];
      });
    }
  }

  Future<void> _loadBookingDetails({bool forceRefresh = false}) async {
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
    final result = await ApiService.getUserBookings(forceRefresh: forceRefresh);
    
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

    final result = await ApiService.getUserBookings(forceRefresh: false);
    
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

  Future<void> _handleArrivedAtLocation() async {
    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;
    setState(() => _arrivedLoading = true);
    final result = await ApiService.arrivedAtLocation(bookingId);
    if (mounted) {
      setState(() {
        _arrivedLoading = false;
        if (result['success'] == true) _arrivedSent = true;
      });
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer has been notified that you arrived.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to send notification')),
        );
      }
    }
  }

  Future<void> _openDialer(String phone) async {
    final tel = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (tel.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer.')),
      );
    }
  }

  Future<void> _handleCompleteBooking() async {
    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    setState(() => _completeErrorMessage = null);

    final result = await ApiService.completeBooking(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        setState(() => _completeErrorMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service marked as completed. Payment will be processed.')),
        );
        WalletRefreshNotifier.notifyRefresh();
        BookingCardRefreshNotifier.notifyRefresh();
        _loadBookingDetails();
      } else {
        final String message = _parseCompleteBookingError(result['error']);
        setState(() => _completeErrorMessage = message);
      }
    }
  }

  /// Parse backend error so provider sees exact reason (e.g. insufficient balance with amounts).
  String _parseCompleteBookingError(dynamic err) {
    if (err == null) return 'Failed to complete booking.';
    if (err is String) return err.isNotEmpty ? err : 'Failed to complete booking.';
    if (err is Map) {
      final msg = err['error'] ?? err['message'] ?? err['detail'];
      if (msg != null && msg.toString().trim().isNotEmpty) return msg.toString().trim();
      if (err.length == 1) return err.values.first?.toString().trim() ?? 'Failed to complete booking.';
    }
    return 'Failed to complete booking.';
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
    final walletResult = await ApiService.getWalletBalance(forceRefresh: false);
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
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadBookingDetails(forceRefresh: true);
                          BookingCardRefreshNotifier.notifyRefresh();
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
                            
                            // Complete booking error card (provider): exact backend reason e.g. insufficient balance
                            if (_completeErrorMessage != null) ...[
                              _buildCompleteErrorCard(context),
                              const SizedBox(height: 16),
                            ],
                            
                            // Actions
                            _buildActionButtons(context),
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
          _buildLocationSection(context, address),
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

  /// Service address with optional map and "Get direction" on Google Maps.
  Widget _buildLocationSection(BuildContext context, String addressText) {
    final savedAddress = _booking!['saved_address'] as Map<String, dynamic>?;
    final latRaw = savedAddress?['latitude'];
    final lngRaw = savedAddress?['longitude'];
    double? lat;
    double? lng;
    if (latRaw != null && lngRaw != null) {
      lat = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw.toString());
      lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw.toString());
    }
    final hasCoords = lat != null && lng != null;
    final LatLng? location = hasCoords ? LatLng(lat!, lng!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Iconsax.location, size: 20, color: context.mutedForegroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mutedForegroundColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addressText,
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
        ),
        if (location != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suvidha.connect',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Iconsax.location, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openGoogleMapsDirections(lat: lat, lng: lng, address: addressText),
          icon: const Icon(Iconsax.driver_2, size: 20),
          label: const Text('Get direction on Google Maps'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        // Provider only: notify customer that provider has arrived
        if (_userRole == 'provider') ...[
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final status = _booking!['status'] ?? '';
              final showArrived = (status == 'accepted' || status == 'in_progress') && !_arrivedSent;
              if (!showArrived) {
                if (_arrivedSent)
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Iconsax.tick_circle5, size: 20, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'Customer notified (you arrived)',
                          style: TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                return const SizedBox.shrink();
              }
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _arrivedLoading ? null : _handleArrivedAtLocation,
                  icon: _arrivedLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Icon(Iconsax.location_tick, size: 20),
                  label: Text(_arrivedLoading ? 'Sending…' : 'Arrived at location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _openGoogleMapsDirections({double? lat, double? lng, String? address}) async {
    String url;
    if (lat != null && lng != null) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else if (address != null && address.isNotEmpty && address != 'Not specified') {
      url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No location or address available for directions.')),
        );
      }
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
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
      ? (_booking!['customer_name'] ?? _booking!['customer']?['name'] ?? _booking!['customer']?['first_name'] ?? 'Customer')
      : (_booking!['provider_name'] ?? _booking!['provider']?['name'] ?? 'Provider');
    final userPhone = isProvider
      ? (_booking!['customer']?['phone'] ?? '')
      : (_booking!['provider']?['contact'] ?? _booking!['provider']?['phone'] ?? '');

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
                if (userPhone.toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openDialer(userPhone.toString().trim()),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.call, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            userPhone.toString().trim(),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCompleteErrorCard(BuildContext context) {
    final message = _completeErrorMessage ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.warning_2, color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not complete order',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.foregroundColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Iconsax.close_circle, color: AppColors.error, size: 22),
            onPressed: () => setState(() => _completeErrorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
        // Mark as Complete (provider only, when accepted or in_progress)
        if (isProvider && (status == 'accepted' || status == 'in_progress')) ...[
          ElevatedButton.icon(
            onPressed: _handleCompleteBooking,
            icon: const Icon(Iconsax.tick_circle),
            label: const Text('Mark as Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
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

