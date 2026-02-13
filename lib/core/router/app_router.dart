import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/splash/role_select_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/auth/provider_onboarding_screen.dart';
import '../../screens/auth/provider_pending_approval_screen.dart';
import '../../screens/auth/onboarding/onboarding_step1_screen.dart';
import '../../screens/auth/onboarding/onboarding_step2_screen.dart';
import '../../screens/auth/onboarding/onboarding_step3_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/my_services_screen.dart';
import '../../screens/explore/explore_screen.dart';
import '../../screens/provider_detail/provider_detail_screen.dart';
import '../../screens/booking/booking_success_screen.dart';
import '../../screens/booking/create_booking_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/saved/saved_services_screen.dart';
import '../../screens/requests/provider_requests_screen.dart';
import '../../screens/bookings/my_bookings_screen.dart';
import '../../screens/bookings/booking_detail_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/addresses/saved_addresses_screen.dart';
import '../../screens/addresses/add_address_screen.dart';
import '../../screens/reviews/reviews_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/settings/provider_settings_screen.dart';
import '../../screens/settings/payment_methods_screen.dart';
import '../../screens/legal/terms_conditions_screen.dart';
import '../../screens/legal/privacy_policy_screen.dart';
import '../../screens/legal/about_us_screen.dart';
import '../../widgets/bottom_nav.dart';

import '../../core/booking_card_refresh.dart';
import '../../core/wallet_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Exposed for system back button handling in main.dart (check canPop).
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Splash Screen
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // Role Select
    GoRoute(
      path: '/role-select',
      builder: (context, state) => const RoleSelectScreen(),
    ),

    // Provider Onboarding (Old - kept for backward compatibility)
    GoRoute(
      path: '/provider-onboarding',
      builder: (context, state) => const ProviderOnboardingScreen(),
    ),

    // Provider Onboarding Steps
    GoRoute(
      path: '/provider-onboarding/step1',
      builder: (context, state) => const OnboardingStep1Screen(),
    ),
    GoRoute(
      path: '/provider-onboarding/step2',
      builder: (context, state) => const OnboardingStep2Screen(),
    ),
    GoRoute(
      path: '/provider-onboarding/step3',
      builder: (context, state) => const OnboardingStep3Screen(),
    ),

    // Provider pending admin approval (onboarding done, not yet approved)
    GoRoute(
      path: '/provider-pending-approval',
      builder: (context, state) => const ProviderPendingApprovalScreen(),
    ),

    // Login
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'];
        return LoginScreen(role: role);
      },
    ),

    // Forgot Password (email → code → new password)
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Verify Email (after signup or when login blocked for unverified)
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'];
        final role = state.uri.queryParameters['role'];
        return VerifyEmailScreen(email: email, role: role);
      },
    ),

    // Signup
    GoRoute(
      path: '/signup',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'];
        return SignupScreen(role: role);
      },
    ),

    // Main App Shell with Bottom Navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      pageBuilder: (context, state, child) {
        return NoTransitionPage<void>(
          child: MainShell(child: child),
        );
      },
      routes: [
        // Home
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),

        // Saved Services
        GoRoute(
          path: '/saved',
          builder: (context, state) => const SavedServicesScreen(),
        ),

        // My Services
        GoRoute(
          path: '/services',
          builder: (context, state) => const MyServicesScreen(),
        ),

        // Notifications
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),

        // Profile
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        // Provider Requests
        GoRoute(
          path: '/requests',
          builder: (context, state) => const ProviderRequestsScreen(),
        ),

        // My Bookings
        GoRoute(
          path: '/my-bookings',
          builder: (context, state) => const MyBookingsScreen(),
        ),

        // Saved Addresses
        GoRoute(
          path: '/addresses',
          builder: (context, state) => const SavedAddressesScreen(),
        ),

        // Add Address
        GoRoute(
          path: '/add-address',
          builder: (context, state) => const AddAddressScreen(),
        ),

        // Reviews
        GoRoute(
          path: '/reviews',
          builder: (context, state) => const ReviewsScreen(),
        ),

        // Settings
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // Provider Settings
        GoRoute(
          path: '/provider-settings',
          builder: (context, state) => const ProviderSettingsScreen(),
        ),

        // Payment Methods
        GoRoute(
          path: '/payment-methods',
          builder: (context, state) => const PaymentMethodsScreen(),
        ),

        // Legal Screens
        GoRoute(
          path: '/terms-conditions',
          builder: (context, state) => const TermsConditionsScreen(),
        ),

        GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),

        GoRoute(
          path: '/about-us',
          builder: (context, state) => const AboutUsScreen(),
        ),


      ],
    ),

    // Explore (outside shell for different nav behavior)
    GoRoute(
      path: '/explore/:serviceId',
      builder: (context, state) {
        final serviceId = state.pathParameters['serviceId'] ?? '';
        return ExploreScreen(serviceId: serviceId);
      },
    ),

    // Provider Detail
    GoRoute(
      path: '/provider/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId'] ?? '';
        return ProviderDetailScreen(providerId: providerId);
      },
    ),

    // Booking Details (Moved out of ShellRoute)
    GoRoute(
      path: '/booking-details/:bookingId',
      // Use builder instead of pageBuilder for standard transition
      builder: (context, state) {
        final bookingId = state.pathParameters['bookingId'] ?? '';
        // Note: NoTransitionPage handling was removed as we are now using standard transitions
        // and error handling is better done within the screen or via redirect
        return BookingDetailScreen(bookingId: bookingId);
      },
    ),

    // Chat Screen (Moved out of ShellRoute)
    GoRoute(
      path: '/chat/:bookingId',
      builder: (context, state) {
        final bookingId = state.pathParameters['bookingId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        return ChatScreen(
          bookingId: bookingId,
          customerId: extra?['customerId'],
          providerId: extra?['providerId'],
        );
      },
    ),

    // Create Booking (outside shell)
    GoRoute(
      path: '/create-booking/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId'] ?? '';
        final serviceCategoryId = state.uri.queryParameters['serviceCategoryId'];
        final serviceName = state.uri.queryParameters['serviceName'];
        return CreateBookingScreen(
          providerId: providerId,
          serviceCategoryId: serviceCategoryId,
          serviceName: serviceName,
        );
      },
    ),

    // Booking Success (outside shell)
    GoRoute(
      path: '/booking-success',
      builder: (context, state) => const BookingSuccessScreen(),
    ),
  ],
);

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/saved')) return 1;
    if (location.startsWith('/services')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Main content
          Expanded(child: child),
          // Latest Service card - widget returns SizedBox.shrink() when hidden (no white box)
          const _FloatingBookingWidget(),
          // Bottom navigation bar
          BottomNav(
            currentIndex: _calculateSelectedIndex(context),
          ),
        ],
      ),
    );
  }
}

// Floating widget to show latest booking for providers
class _FloatingBookingWidget extends StatefulWidget {
  const _FloatingBookingWidget();
  
  @override
  State<_FloatingBookingWidget> createState() => _FloatingBookingWidgetState();
}

class _FloatingBookingWidgetState extends State<_FloatingBookingWidget> {
  Map<String, dynamic>? _latestBooking;
  bool _isLoading = true;
  String? _userRole;
  bool _shouldShow = false;
  bool _actionLoading = false;
  /// Error from Mark Complete (e.g. insufficient balance). Shown on the card.
  String? _completeErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadLatestBooking();
    BookingCardRefreshNotifier.trigger.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    BookingCardRefreshNotifier.trigger.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    if (mounted) _loadLatestBooking(forceRefresh: true);
  }

  Future<void> _loadLatestBooking({bool forceRefresh = false}) async {
    final result = await ApiService.getCurrentUserInfo(forceRefresh: forceRefresh);
    if (result['success'] == true) {
      final userData = result['data'];
      final role = userData['role'] ?? 'customer';

      List<dynamic> activeBookings = [];
      if (role == 'provider') {
        final bookingsResult = await ApiService.getProviderRequests(forceRefresh: forceRefresh);
        if (bookingsResult['success'] == true) {
          final bookings = bookingsResult['data'] as List;
          activeBookings = bookings.where((b) {
            final status = b['status'] as String? ?? '';
            return status != 'completed' && status != 'cancelled' && status != 'payment';
          }).toList();
        }
      } else {
        final bookingsResult = await ApiService.getUserBookings(forceRefresh: forceRefresh);
        if (bookingsResult['success'] == true) {
          final bookings = bookingsResult['data'] as List;
          activeBookings = bookings.where((b) {
            final status = b['status'] as String? ?? '';
            return status != 'completed' && status != 'cancelled' && status != 'payment';
          }).toList();
        }
      }
      if (mounted && activeBookings.isNotEmpty) {
        activeBookings.sort((a, b) {
          final aDate = a['created_at'] as String? ?? '';
          final bDate = b['created_at'] as String? ?? '';
          return bDate.compareTo(aDate);
        });
        setState(() {
          _latestBooking = activeBookings.first;
          _userRole = role;
          _isLoading = false;
          _shouldShow = true;
          _completeErrorMessage = null;
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _shouldShow = false;
        _completeErrorMessage = null;
      });
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'negotiation':
        return 'Negotiating';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      default:
        return status ?? 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'negotiation':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'in_progress':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _acceptBooking(int bookingId) async {
    if (_actionLoading || !mounted) return;
    setState(() => _actionLoading = true);
    final result = await ApiService.acceptBooking(bookingId);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking accepted'), backgroundColor: Colors.green),
        );
        _loadLatestBooking(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to accept'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static String _parseCompleteError(dynamic err) {
    if (err == null) return 'Failed to complete booking.';
    if (err is String) return err.isNotEmpty ? err : 'Failed to complete booking.';
    if (err is Map) {
      final msg = err['error'] ?? err['message'] ?? err['detail'];
      if (msg != null && msg.toString().trim().isNotEmpty) return msg.toString().trim();
      if (err.length == 1) return err.values.first?.toString().trim() ?? 'Failed to complete booking.';
    }
    return 'Failed to complete booking.';
  }

  Future<void> _completeBooking(int bookingId) async {
    if (_actionLoading || !mounted) return;
    setState(() {
      _actionLoading = true;
      _completeErrorMessage = null;
    });
    final result = await ApiService.completeBooking(bookingId);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (result['success'] == true) {
        setState(() => _completeErrorMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking completed'), backgroundColor: Colors.green),
        );
        WalletRefreshNotifier.notifyRefresh();
        _loadLatestBooking(forceRefresh: true);
      } else {
        final message = _parseCompleteError(result['error']);
        setState(() => _completeErrorMessage = message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow || _latestBooking == null || _isLoading) {
      return const SizedBox.shrink();
    }

    final booking = _latestBooking!;
    final status = booking['status'] as String? ?? '';
    final serviceName = booking['service_name'] as String? ?? 'Service';
    final isProvider = _userRole == 'provider';
    final otherPartyName = isProvider
        ? (booking['customer_name'] ?? booking['customer']?['name'] ?? 'Customer')
        : (booking['provider_name'] ?? booking['provider']?['name'] ?? 'Provider');
    final bookingId = booking['id'];
    final id = bookingId is int ? bookingId : int.tryParse(bookingId?.toString() ?? '');

    // Action button for provider: Accept (pending), Negotiate (negotiation), Mark Complete (accepted/in_progress)
    Widget? actionButton;
    if (isProvider && id != null) {
      if (status == 'pending') {
        actionButton = _buildActionChip(
          context,
          label: 'Accept',
          onTap: () => _acceptBooking(id),
        );
      } else if (status == 'negotiation') {
        actionButton = _buildActionChip(
          context,
          label: 'Negotiate',
          onTap: () => context.push('/chat/$id', extra: {'bookingId': id}),
        );
      } else if (status == 'accepted' || status == 'in_progress') {
        actionButton = _buildActionChip(
          context,
          label: 'Mark Complete',
          onTap: () => _completeBooking(id),
        );
      }
    } else if (!isProvider && id != null && status == 'negotiation') {
      actionButton = _buildActionChip(
        context,
        label: 'Negotiate',
        onTap: () => context.push('/chat/$id', extra: {'bookingId': id}),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: GestureDetector(
        onTap: () {
          if (id != null) context.push('/booking-details/$id');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _completeErrorMessage != null
                  ? AppColors.error.withOpacity(0.5)
                  : _getStatusColor(status).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _completeErrorMessage != null
                          ? AppColors.error
                          : _getStatusColor(status),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          serviceName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.foregroundColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          otherPartyName,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.mutedForegroundColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  if (actionButton != null) ...[
                    const SizedBox(width: 6),
                    if (_actionLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      actionButton,
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: context.mutedForegroundColor,
                  ),
                ],
              ),
              if (_completeErrorMessage != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {}, // absorb tap so card tap doesn't navigate
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _completeErrorMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            height: 1.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _completeErrorMessage = null),
                        child: Icon(Icons.close, size: 16, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, {required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}


