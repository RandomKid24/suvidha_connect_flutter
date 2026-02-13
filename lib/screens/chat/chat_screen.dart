import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../services/notification_scheduler_service.dart';
import '../../widgets/app_header.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final int? customerId;
  final int? providerId;
  
  const ChatScreen({
    super.key,
    required this.bookingId,
    this.customerId,
    this.providerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _otherUserName;
  String? _userRole;
  int? _currentUserId;
  int? _otherUserId;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _shouldScrollToBottom = true;
  int _previousMessageCount = 0;
  Map<String, dynamic>? _bookingData;
  final TextEditingController _priceController = TextEditingController();
  Timer? _refreshTimer;
  StreamSubscription<DocumentSnapshot>? _chatDocSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _chatDocSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final result = await ApiService.getCurrentUserInfo(forceRefresh: false);
      if (result['success'] == true) {
        final userData = result['data'];
        setState(() {
          _userRole = userData['role'];
          _currentUserId = userData['id'];
          // Determine other user ID
          if (_userRole == 'provider') {
            _otherUserId = widget.customerId;
          } else {
            _otherUserId = widget.providerId;
          }
        });
        await _loadOtherUserName(forceRefresh: false);
        _setupFirestoreListener();
      } else {
        // If API call fails, still try to set up listener with available data
        print('⚠️ Failed to load user info: ${result['message'] ?? 'Unknown error'}');
        _setupFirestoreListener();
      }
    } catch (e) {
      print('❌ Error loading user info: $e');
      // Set loading to false even if there's an error
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadOtherUserName({bool forceRefresh = false}) async {
    if (_otherUserId == null) return;
    
    final bId = int.tryParse(widget.bookingId);
    if (bId == null) return;

    final result = await ApiService.getUserBookings(forceRefresh: forceRefresh);
    if (result['success'] == true) {
      final bookings = result['data'] as List;
      final booking = bookings.firstWhere(
        (b) => b['id'] == bId,
        orElse: () => null,
      );
      
      if (booking != null && mounted) {
        // Helper function to normalize price values for comparison
        dynamic normalizePrice(dynamic price) {
          if (price == null) return null;
          if (price is num) return price.toDouble();
          if (price is String) {
            final parsed = double.tryParse(price);
            return parsed;
          }
          return price;
        }
        
        // Helper function to get user ID from proposed_by (handles both dict and int)
        int? getProposedById(dynamic proposedBy) {
          if (proposedBy == null) return null;
          if (proposedBy is int) return proposedBy;
          if (proposedBy is Map) return proposedBy['id'] as int?;
          return null;
        }
        
        // Compare normalized prices
        final oldProposedPrice = normalizePrice(_bookingData?['proposed_price']);
        final newProposedPrice = normalizePrice(booking['proposed_price']);
        final oldPrice = normalizePrice(_bookingData?['price']);
        final newPrice = normalizePrice(booking['price']);
        final oldProposedById = getProposedById(_bookingData?['proposed_by']);
        final newProposedById = getProposedById(booking['proposed_by']);
        
        // Only update if there's an actual change to avoid unnecessary rebuilding
        if (_bookingData == null || 
            _bookingData!['status'] != booking['status'] || 
            oldProposedPrice != newProposedPrice ||
            oldPrice != newPrice ||
            _bookingData!['price_locked'] != booking['price_locked'] ||
            oldProposedById != newProposedById) {
          setState(() {
            _bookingData = booking;
            if (_userRole == 'provider') {
              _otherUserName = booking['customer_name'] ?? booking['customer']?['name'] ?? 'Customer';
            } else {
              _otherUserName = booking['provider_name'] ?? booking['provider']?['name'] ?? 'Provider';
            }
            
            // Schedule reminders if status is accepted/in_progress
            final status = booking['status'];
            if (status == 'accepted' || status == 'in_progress') {
              NotificationSchedulerService.scheduleBookingReminders(booking);
            }
          });
        }
      }
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        // Use forceRefresh: false for polling to avoid too many API calls
        _loadOtherUserName(forceRefresh: false);
      }
    });
  }

  void _setupFirestoreListener() {
    // Create a chat room ID from booking ID
    final chatRoomId = 'booking_${widget.bookingId}';
    
    print('🔍 Setting up Firestore listener for chat room: $chatRoomId');
    print('   Current User ID: $_currentUserId');
    print('   Other User ID: $_otherUserId');
    print('   Customer ID: ${widget.customerId}');
    print('   Provider ID: ${widget.providerId}');
    
    // Set loading to false after a timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        print('⚠️ Firestore listener timeout - setting loading to false');
        setState(() => _isLoading = false);
      }
    });
    
    try {
      // First, try to get messages without orderBy (to avoid index requirement)
      _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .get()
          .then((snapshot) {
        print('📨 Initial snapshot: ${snapshot.docs.length} messages');
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Sort messages by timestamp manually
            _messages = snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['timestamp'] as Timestamp?;
              return {
                'id': doc.id,
                'message': data['message'] ?? '',
                'sender_id': data['sender_id'],
                'receiver_id': data['receiver_id'],
                'timestamp': timestamp,
                'created_at': timestamp?.toDate().toIso8601String() ?? '',
                'sort_time': timestamp?.millisecondsSinceEpoch ?? 0,
              };
            }).toList();
            // Sort by timestamp
            _messages.sort((a, b) => (a['sort_time'] as int).compareTo(b['sort_time'] as int));
          });
          _scrollToBottom();
        }
      }).catchError((error) {
        print('❌ Error getting initial messages: $error');
        print('   Error code: ${error.code}');
        print('   Error message: ${error.message}');
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
          // Show user-friendly error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Firestore not configured. Please enable Firestore in Firebase Console.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });
      
      // Listen to messages in real-time (without orderBy to avoid index requirement)
      _messagesSubscription = _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .snapshots()
          .listen((snapshot) {
        print('📨 Received ${snapshot.docs.length} messages from Firestore');
        if (mounted) {
          // Check if we should scroll (new message added or initial load)
          final newMessageCount = snapshot.docs.length;
          final wasAtBottom = !_scrollController.hasClients || 
              _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100;
          final isNewMessage = newMessageCount > _previousMessageCount;
          
          setState(() {
            _isLoading = false;
            // Sort messages by timestamp manually
            _messages = snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['timestamp'] as Timestamp?;
              return {
                'id': doc.id,
                'message': data['message'] ?? '',
                'sender_id': data['sender_id'],
                'receiver_id': data['receiver_id'],
                'timestamp': timestamp,
                'created_at': timestamp?.toDate().toIso8601String() ?? '',
                'sort_time': timestamp?.millisecondsSinceEpoch ?? 0,
              };
            }).toList();
            // Sort by timestamp
            _messages.sort((a, b) => (a['sort_time'] as int).compareTo(b['sort_time'] as int));
          });
          
          // Only scroll if we were at bottom or it's a new message
          if (wasAtBottom || isNewMessage || _previousMessageCount == 0) {
            _previousMessageCount = newMessageCount;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          } else {
            _previousMessageCount = newMessageCount;
          }
        }
      }, onError: (error) {
        print('❌ Error listening to messages: $error');
        print('   Error code: ${error.code}');
        print('   Error message: ${error.message}');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        // Show error to user only if not already shown
        if (mounted && _messages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Firestore not configured. Please enable Firestore in Firebase Console.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });

      // Listen to the chat room document for metadata changes (status/price updates)
      _chatDocSubscription = _firestore
          .collection('chats')
          .doc(chatRoomId)
          .snapshots()
          .listen((snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data();
          print('🔔 Chat metadata updated: $data');
          
          // Check if price was updated in Firebase
          if (data != null && data.containsKey('proposed_price')) {
            final firebasePrice = data['proposed_price'];
            final firebaseProposedById = data['proposed_by_id'];
            final firebasePriceLocked = data['price_locked'] ?? false;
            
            // Update local booking data immediately from Firebase
            if (_bookingData != null) {
              final currentPrice = _bookingData!['proposed_price'];
              final currentProposedById = _bookingData!['proposed_by'] is Map 
                  ? _bookingData!['proposed_by']['id'] 
                  : _bookingData!['proposed_by'];
              
              // Only update if price actually changed
              if (currentPrice != firebasePrice || currentProposedById != firebaseProposedById) {
                setState(() {
                  _bookingData = {
                    ..._bookingData!,
                    'proposed_price': firebasePrice,
                    'proposed_by': firebaseProposedById,
                    'price_locked': firebasePriceLocked,
                  };
                });
                print('✅ Updated price from Firebase: $firebasePrice');
              }
            }
          }
          
          // Always refresh from API to get latest status and other fields
          _loadOtherUserName(forceRefresh: true);
        }
      });
      
      // Start background polling as a fallback
      _startPolling();
    } catch (e) {
      print('❌ Exception setting up Firestore listener: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _triggerMetadataUpdate({double? proposedPrice, int? proposedById, bool? priceLocked}) async {
    try {
      final chatRoomId = 'booking_${widget.bookingId}';
      final updateData = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Store price information in Firebase for real-time updates
      if (proposedPrice != null) {
        updateData['proposed_price'] = proposedPrice;
      }
      if (proposedById != null) {
        updateData['proposed_by_id'] = proposedById;
      }
      if (priceLocked != null) {
        updateData['price_locked'] = priceLocked;
      }
      
      await _firestore.collection('chats').doc(chatRoomId).set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Failed to update chat metadata: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentUserId == null || _otherUserId == null) return;

    try {
      final chatRoomId = 'booking_${widget.bookingId}';
      
      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'message': message,
        'sender_id': _currentUserId,
        'receiver_id': _otherUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'booking_id': widget.bookingId,
      });

      // Update chat room metadata
      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .set({
        'booking_id': widget.bookingId,
        'customer_id': widget.customerId,
        'provider_id': widget.providerId,
        'last_message': message,
        'last_message_time': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _messageController.clear();
      // Scroll to bottom after message is sent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send message. Please enable Firestore in Firebase Console.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use jumpTo for immediate scroll without animation delay
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        _scrollController.jumpTo(maxScroll);
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
              title: _otherUserName ?? 'Chat',
            ),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Messages List
                      Expanded(
                        child: _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Iconsax.message,
                                    size: 48,
                                    color: context.mutedForegroundColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      color: context.mutedForegroundColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start the conversation!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.mutedForegroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(context, _messages[index]);
                              },
                            ),
                      ),
                      
                      // Price Display (if in negotiation status)
                      if (_bookingData != null && _bookingData!['status'] == 'negotiation') ...[
                        _buildPriceSection(context),
                      ],
                      
                      // Message Input
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          border: Border(
                            top: BorderSide(color: context.borderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: context.mutedForegroundColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: context.borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: context.borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: AppColors.primary),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: _sendMessage,
                                icon: const Icon(
                                  Iconsax.send_1,
                                  color: Colors.white,
                                ),
                              ),
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
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> message) {
    final isSent = message['sender_id'] == _currentUserId;
    final messageText = message['message'] ?? '';
    final timestamp = message['created_at'] ?? '';
    
    String timeStr = '';
    if (timestamp.isNotEmpty) {
      try {
        final date = DateTime.parse(timestamp);
        timeStr = DateFormat('hh:mm a').format(date);
      } catch (e) {
        timeStr = '';
      }
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSent ? AppColors.primary : context.cardColor,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isSent ? const Radius.circular(4) : null,
            bottomLeft: !isSent ? const Radius.circular(4) : null,
          ),
          border: !isSent ? Border.all(color: context.borderColor) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messageText,
              style: TextStyle(
                color: isSent ? Colors.white : context.foregroundColor,
                fontSize: 14,
              ),
            ),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: TextStyle(
                  color: isSent 
                    ? Colors.white.withOpacity(0.7)
                    : context.mutedForegroundColor,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double? _parsePrice(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    try {
      return double.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  Widget _buildPriceSection(BuildContext context) {
    final bookingStatus = _bookingData?['status'] ?? '';
    final isAccepted = bookingStatus == 'accepted';
    
    // For accepted status, use the final price; otherwise use proposed_price
    final priceRaw = isAccepted 
        ? (_bookingData?['price']) 
        : (_bookingData?['proposed_price']);
    final price = _parsePrice(priceRaw);
    
    // Customer's expected price (booking initial price - what consumer offered)
    final customerExpectedPrice = _parsePrice(_bookingData?['price']);
    
    final proposedBy = _bookingData?['proposed_by'];
    final priceLocked = _bookingData?['price_locked'] ?? false || isAccepted;
    final isProvider = _userRole == 'provider';
    // Check if proposed_by is the current user (handle both dict and int formats)
    final proposedByMe = proposedBy != null && (
      (proposedBy is Map && proposedBy['id'] == _currentUserId) ||
      (proposedBy is int && proposedBy == _currentUserId)
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
          top: BorderSide(color: context.borderColor),
          bottom: BorderSide(color: context.borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Provider in negotiation: show customer's expected price and Accept / Propose options
          if (isProvider && bookingStatus == 'negotiation' && !priceLocked && !isAccepted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Customer's expected price",
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mutedForegroundColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customerExpectedPrice != null
                        ? 'Rs. ${customerExpectedPrice.toStringAsFixed(2)}/-'
                        : 'Not set',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleAcceptAtCustomerPrice,
                          icon: const Icon(Iconsax.tick_circle, size: 18),
                          label: const Text('Accept at this price'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showPriceDialog,
                          icon: const Icon(Iconsax.dollar_circle, size: 18),
                          label: const Text('Propose different'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Current/Proposed Price Display
          InkWell(
            onTap: priceLocked ? null : _showPriceDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: priceLocked 
                  ? Colors.blue.withOpacity(0.1)
                  : proposedByMe
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: priceLocked 
                    ? Colors.blue
                    : proposedByMe
                      ? Colors.orange
                      : Colors.green,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        priceLocked 
                          ? Iconsax.tick_circle
                          : Iconsax.dollar_circle,
                        color: priceLocked 
                          ? Colors.blue
                          : proposedByMe
                            ? Colors.orange
                            : Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        price != null 
                          ? 'Rs. ${(price as double).toStringAsFixed(2)}/-'
                          : 'Tap to set price',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: priceLocked 
                            ? Colors.blue
                            : proposedByMe
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (price != null && !priceLocked && !isAccepted) ...[
                    const SizedBox(height: 8),
                    Text(
                      proposedByMe 
                        ? 'You proposed this price'
                        : '${_otherUserName ?? 'Other party'} proposed this price',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.mutedForegroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to change price',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.mutedForegroundColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (priceLocked || isAccepted) ...[
                    const SizedBox(height: 8),
                    Text(
                      isAccepted ? 'Price Accepted - Booking Confirmed' : 'Price Locked - Booking Accepted',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Accept Price Button (show if price proposed by other party and not locked, and not accepted)
          if (price != null && !proposedByMe && !priceLocked && !isAccepted) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _handleAcceptPrice,
              icon: const Icon(Iconsax.tick_circle, size: 20),
              label: const Text('Accept This Price'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
          
          // Reject button
          if (!priceLocked) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _handleRejectBooking,
              icon: const Icon(Iconsax.close_circle, size: 18),
              label: const Text('Reject Booking'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showPriceDialog() async {
    final currentPrice = _bookingData?['proposed_price'] ?? _bookingData?['price'];
    _priceController.text = currentPrice != null ? currentPrice.toString() : '';

    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propose Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Enter price (Rs.)',
                prefixText: 'Rs. ',
                suffixText: '/-',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final priceText = _priceController.text.trim();
              final price = double.tryParse(priceText);
              if (price != null && price > 0) {
                Navigator.pop(context, price);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price')),
                );
              }
            },
            child: const Text('Propose'),
          ),
        ],
      ),
    );

    if (newPrice != null) {
      await _handleProposePrice(newPrice);
    }
  }

  Future<void> _handleRejectBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: const Text('Are you sure you want to reject this booking? This action cannot be undone.'),
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

    if (confirmed != true) return;

    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final result = await ApiService.rejectBooking(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rejected')),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to reject booking')),
        );
      }
    }
  }

  Future<void> _handleProposePrice(double price) async {
    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final result = await ApiService.proposePrice(bookingId, price);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Price of Rs. $price/- proposed')),
        );
        // Get the proposed_by ID from the result
        final proposedBy = result['data']?['proposed_by'];
        final proposedById = proposedBy is Map ? proposedBy['id'] : proposedBy;
        
        // Trigger Firestore update for the other party with price data
        _triggerMetadataUpdate(
          proposedPrice: price,
          proposedById: proposedById ?? _currentUserId,
          priceLocked: false,
        );
        // Reload booking data with force refresh to get latest price
        await _loadOtherUserName(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to propose price')),
        );
      }
    }
  }

  /// Provider accepts the booking at the customer's expected price (no negotiation).
  Future<void> _handleAcceptAtCustomerPrice() async {
    final customerPrice = _parsePrice(_bookingData?['price']);
    if (customerPrice == null || customerPrice <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Customer's expected price is not set")),
        );
      }
      return;
    }

    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final currentProposed = _parsePrice(_bookingData?['proposed_price']);
    final needProposeFirst = currentProposed == null ||
        (currentProposed - customerPrice).abs() > 0.01;

    if (needProposeFirst) {
      final resultPropose = await ApiService.proposePrice(bookingId, customerPrice);
      if (!mounted) return;
      if (resultPropose['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resultPropose['error']?['message'] ?? 'Failed to set price')),
        );
        return;
      }
      _triggerMetadataUpdate(
        proposedPrice: customerPrice,
        proposedById: _currentUserId,
        priceLocked: false,
      );
      await _loadOtherUserName(forceRefresh: true);
      if (!mounted) return;
    }

    final result = await ApiService.acceptPrice(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking accepted at customer\'s price!')),
        );
        final finalPrice = result['data']?['price'] ?? result['data']?['proposed_price'];
        _triggerMetadataUpdate(
          proposedPrice: finalPrice?.toDouble(),
          priceLocked: true,
        );
        await _loadOtherUserName(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to accept booking')),
        );
      }
    }
  }

  Future<void> _handleAcceptPrice() async {
    final proposedPriceRaw = _bookingData?['proposed_price'];
    if (proposedPriceRaw == null) return;
    
    final proposedPrice = _parsePrice(proposedPriceRaw);
    if (proposedPrice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Price'),
        content: Text('Are you sure you want to accept the price of Rs. ${proposedPrice!.toStringAsFixed(2)}/-? This will lock the price and move the booking to accepted status.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final bookingId = int.tryParse(widget.bookingId);
    if (bookingId == null) return;

    final result = await ApiService.acceptPrice(bookingId);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Price accepted! Booking is now accepted.')),
        );
        // Get the final price from the result
        final finalPrice = result['data']?['price'] ?? result['data']?['proposed_price'];
        
        // Trigger Firestore update for the other party with locked price
        _triggerMetadataUpdate(
          proposedPrice: finalPrice?.toDouble(),
          priceLocked: true,
        );
        // Reload booking data with force refresh to get latest price
        await _loadOtherUserName(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to accept price')),
        );
      }
    }
  }
}
