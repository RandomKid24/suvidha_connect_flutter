import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/splash/role_select_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/provider_onboarding_screen.dart';
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

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

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

    // Login
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'];
        return LoginScreen(role: role);
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
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        // Home
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),

        // Saved Services
        GoRoute(
          path: '/saved',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SavedServicesScreen(),
          ),
        ),

        // My Services
        GoRoute(
          path: '/services',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MyServicesScreen(),
          ),
        ),

        // Notifications
        GoRoute(
          path: '/notifications',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsScreen(),
          ),
        ),

        // Profile
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),

        // Provider Requests
        GoRoute(
          path: '/requests',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProviderRequestsScreen(),
          ),
        ),

        // My Bookings
        GoRoute(
          path: '/my-bookings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MyBookingsScreen(),
          ),
        ),

        // Saved Addresses
        GoRoute(
          path: '/addresses',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SavedAddressesScreen(),
          ),
        ),

        // Add Address
        GoRoute(
          path: '/add-address',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AddAddressScreen(),
          ),
        ),

        // Reviews
        GoRoute(
          path: '/reviews',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ReviewsScreen(),
          ),
        ),

        // Settings
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),

        // Provider Settings
        GoRoute(
          path: '/provider-settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProviderSettingsScreen(),
          ),
        ),

        // Payment Methods
        GoRoute(
          path: '/payment-methods',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PaymentMethodsScreen(),
          ),
        ),

        // Legal Screens
        GoRoute(
          path: '/terms-conditions',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TermsConditionsScreen(),
          ),
        ),

        GoRoute(
          path: '/privacy-policy',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PrivacyPolicyScreen(),
          ),
        ),

        GoRoute(
          path: '/about-us',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AboutUsScreen(),
          ),
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
    final location = GoRouterState.of(context).matchedLocation;
    final isHomeScreen = location == '/home';
    
    return Scaffold(
      body: child,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          BottomNav(
            currentIndex: _calculateSelectedIndex(context),
          ),
          // Floating widget above bottom nav (only on home screen)
          if (isHomeScreen)
            Positioned(
              bottom: 70, // Above the bottom nav
              left: 16,
              right: 16,
              child: _FloatingBookingWidget(),
            ),
        ],
      ),
    );
  }
}

// Floating widget to show latest booking for providers
class _FloatingBookingWidget extends StatefulWidget {
  @override
  State<_FloatingBookingWidget> createState() => _FloatingBookingWidgetState();
}

class _FloatingBookingWidgetState extends State<_FloatingBookingWidget> {
  Map<String, dynamic>? _latestBooking;
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadLatestBooking();
  }

  Future<void> _loadLatestBooking() async {
    final result = await ApiService.getCurrentUserInfo();
    if (result['success'] == true) {
      final userData = result['data'];
      final role = userData['role'] ?? 'customer';
      
      if (role == 'provider') {
        // Get provider bookings
        final bookingsResult = await ApiService.getProviderRequests();
        if (bookingsResult['success'] == true) {
          final bookings = bookingsResult['data'] as List;
          // Filter bookings that are not completed, cancelled, or payment
          final activeBookings = bookings.where((b) {
            final status = b['status'] as String? ?? '';
            return status != 'completed' && status != 'cancelled' && status != 'payment';
          }).toList();
          
          if (mounted && activeBookings.isNotEmpty) {
            // Sort by created_at (most recent first)
            activeBookings.sort((a, b) {
              final aDate = a['created_at'] as String? ?? '';
              final bDate = b['created_at'] as String? ?? '';
              return bDate.compareTo(aDate);
            });
            
            setState(() {
              _latestBooking = activeBookings.first;
              _userRole = role;
              _isLoading = false;
            });
            return;
          }
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    // Only show for providers with active bookings
    if (_userRole != 'provider' || _latestBooking == null || _isLoading) {
      return const SizedBox.shrink();
    }

    final booking = _latestBooking!;
    final status = booking['status'] as String? ?? '';
    final serviceName = booking['service_name'] as String? ?? 'Service';
    final customerName = booking['customer_name'] as String? ?? 'Customer';
    final bookingId = booking['id'];

    return GestureDetector(
      onTap: () {
        if (bookingId != null) {
          context.push('/booking-details/$bookingId');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor(status).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Booking info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Latest Service',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mutedForegroundColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serviceName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.foregroundColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.mutedForegroundColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusLabel(status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.mutedForegroundColor,
            ),
          ],
        ),
      ),
    );
  }
}


