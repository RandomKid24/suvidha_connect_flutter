import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load from cache first, don't call API on every navigation
    _loadNotifications(forceRefresh: false);
  }

  Future<void> _loadNotifications({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final result = await ApiService.getNotifications(forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        setState(() {
          _notifications = result['data'] as List;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    // Force refresh from API when user pulls to refresh
    await _loadNotifications(forceRefresh: true);
  }

  String _formatTime(String? dateTimeString) {
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
        return DateFormat('MMM d, y').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'booking_created':
        return Iconsax.document;
      case 'booking_confirmed':
      case 'booking_accepted':
        return Iconsax.tick_circle;
      case 'booking_completed':
      case 'service_completed':
        return Iconsax.star;
      case 'payment_received':
        return Iconsax.card;
      case 'new_provider':
        return Iconsax.notification;
      case 'verification_approved':
        return Iconsax.tick_circle;
      case 'verification_rejected':
        return Iconsax.close_circle;
      default:
        return Iconsax.notification;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'booking_created':
        return AppColors.primary;
      case 'booking_confirmed':
      case 'booking_accepted':
      case 'verification_approved':
        return AppColors.success;
      case 'booking_completed':
      case 'service_completed':
        return AppColors.amber;
      case 'payment_received':
        return AppColors.primary;
      case 'new_provider':
        return AppColors.accent;
      case 'verification_rejected':
        return AppColors.error;
      default:
        return AppColors.primary;
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
                onRefresh: _handleRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even when content is short
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.foregroundColor,
                        ),
                      ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 20),
                      
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_notifications.isEmpty)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.notification,
                                  size: 80,
                                  color: context.mutedForegroundColor.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notifications yet',
                                  style: TextStyle(
                                    color: context.mutedForegroundColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._notifications.asMap().entries.map((entry) {
                          final index = entry.key;
                          final notification = entry.value;
                          return _buildNotificationCard(notification, index);
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

  Widget _buildNotificationCard(dynamic notification, int index) {
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final time = _formatTime(notification['created_at']);
    final type = notification['notification_type'] ?? 'general';
    final icon = _getIcon(type);
    final iconColor = _getIconColor(type);
    final isRead = notification['is_read'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? context.borderColor : AppColors.primary.withOpacity(0.3),
          width: isRead ? 1 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                          color: context.foregroundColor,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: context.mutedForegroundColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }
}


