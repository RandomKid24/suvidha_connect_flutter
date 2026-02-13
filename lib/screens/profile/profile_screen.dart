import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../models/user.dart';
import '../../widgets/app_header.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh profile when app comes back to foreground
    // Use a debounce to prevent rapid lifecycle changes from causing rebuild loops
    if (state == AppLifecycleState.resumed && mounted) {
      // Only refresh if it's been more than 5 seconds since last load
      if (_lastLoadTime == null || 
          DateTime.now().difference(_lastLoadTime!) > const Duration(seconds: 5)) {
        // Schedule the load to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadUserData(forceRefresh: true);
          }
        });
      }
    }
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final result = await ApiService.getCurrentUserInfo(forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _lastLoadTime = DateTime.now();
        if (result['success'] == true) {
          _userData = result['data'];
        }
      });
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(imageUrl: imageUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get full name from first_name and last_name, fallback to name field, then username
    final firstName = _userData?['first_name'] ?? '';
    final lastName = _userData?['last_name'] ?? '';
    final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '${firstName} ${lastName}'.trim()
        : (_userData?['name'] ?? _userData?['username'] ?? 'User');
    final userEmail = _userData?['email'] ?? '';
    final userPhone = _userData?['phone'] ?? '';
    final profilePhoto = _userData?['profile_photo'];
    final userRole = _userData?['role'] ?? 'customer';

    final menuItems = <_MenuItem>[
      if (userRole == 'provider')
        _MenuItem(
          icon: Iconsax.document,
          label: 'Service Requests',
          description: 'View and manage service requests',
          route: '/requests',
        ),
      if (userRole == 'provider')
        _MenuItem(
          icon: Iconsax.setting_2,
          label: 'Provider Settings',
          description: 'Manage availability and pricing',
          route: '/provider-settings',
        ),
      if (userRole == 'provider')
        _MenuItem(
          icon: Iconsax.wallet,
          label: 'Payment Methods',
          description: 'Manage wallet and bank accounts',
          route: '/payment-methods',
        ),
      _MenuItem(
        icon: Iconsax.briefcase,
        label: 'My Bookings',
        description: 'View your service bookings',
        route: '/my-bookings',
      ),
      _MenuItem(
        icon: Iconsax.location,
        label: 'Saved Addresses',
        description: 'Manage your saved addresses',
        route: '/addresses',
      ),
      _MenuItem(
        icon: Iconsax.star,
        label: 'Reviews',
        description: 'Reviews for 5 items',
        route: '/reviews',
      ),
      _MenuItem(
        icon: Iconsax.setting,
        label: 'Setting',
        description: 'Notification, Password, FAQ, Contact',
        route: '/settings',
      ),
      _MenuItem(
        icon: Iconsax.document_text,
        label: 'Terms & Conditions',
        description: 'Read our terms and conditions',
        route: '/terms-conditions',
      ),
      _MenuItem(
        icon: Iconsax.shield_tick,
        label: 'Privacy Policy',
        description: 'Learn how we protect your data',
        route: '/privacy-policy',
      ),
      _MenuItem(
        icon: Iconsax.info_circle,
        label: 'About Us',
        description: 'Learn more about Sahayak',
        route: '/about-us',
      ),
      _MenuItem(
        icon: Iconsax.moon,
        label: 'Theme',
        description: 'Change app theme (Light/Dark)',
        route: '',
        isThemeToggle: true,
      ),
      _MenuItem(
        icon: Iconsax.logout,
        label: 'Logout',
        description: 'Sign out from your account',
        route: '',
        isLogout: true,
      ),
    ];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadUserData(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  children: [
                    // Profile Header
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                    else ...[
                      // Profile Image (Clickable to enlarge)
                      Center(
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: profilePhoto != null ? () => _showFullScreenImage(context, profilePhoto) : null,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                    width: 4,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: profilePhoto != null
                                      ? CachedNetworkImage(
                                          imageUrl: profilePhoto,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            width: 80,
                                            height: 80,
                                            color: context.mutedColor,
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            width: 80,
                                            height: 80,
                                            color: context.mutedColor,
                                            child: const Icon(Iconsax.user),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: context.mutedColor,
                                          child: const Icon(Iconsax.user, size: 40),
                                        ),
                                ),
                              ),
                            ),
                            // Zoom icon indicator (only shown if profile photo exists)
                            if (profilePhoto != null)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.backgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Iconsax.eye,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ).animate(delay: 100.ms).fadeIn(duration: 500.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Name
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate(delay: 200.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      if (userEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            color: context.mutedForegroundColor,
                            fontSize: 14,
                          ),
                        ).animate(delay: 250.ms).fadeIn(duration: 500.ms),
                      ],
                      
                      if (userPhone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📞 $userPhone',
                          style: TextStyle(
                            color: context.mutedForegroundColor,
                            fontSize: 14,
                          ),
                        ).animate(delay: 250.ms).fadeIn(duration: 500.ms),
                      ],
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Menu Items
                    ...menuItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildMenuItem(context, item, index);
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

  Widget _buildMenuItem(BuildContext context, _MenuItem item, int index) {
    return GestureDetector(
      onTap: () async {
        if (item.isThemeToggle) {
          // Show theme selection dialog
          final currentTheme = await ThemeService.getThemeMode();
          final selectedTheme = await showDialog<ThemeMode>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Theme'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Iconsax.sun_1,
                      color: currentTheme == ThemeMode.light 
                          ? AppColors.primary 
                          : null,
                    ),
                    title: const Text('Light'),
                    trailing: currentTheme == ThemeMode.light
                        ? Icon(Iconsax.tick_circle, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, ThemeMode.light),
                  ),
                  ListTile(
                    leading: Icon(
                      Iconsax.moon,
                      color: currentTheme == ThemeMode.dark 
                          ? AppColors.primary 
                          : null,
                    ),
                    title: const Text('Dark'),
                    trailing: currentTheme == ThemeMode.dark
                        ? Icon(Iconsax.tick_circle, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, ThemeMode.dark),
                  ),
                  ListTile(
                    leading: Icon(
                      Iconsax.setting_2,
                      color: currentTheme == ThemeMode.system 
                          ? AppColors.primary 
                          : null,
                    ),
                    title: const Text('System Default'),
                    trailing: currentTheme == ThemeMode.system
                        ? Icon(Iconsax.tick_circle, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, ThemeMode.system),
                  ),
                ],
              ),
            ),
          );
          
          if (selectedTheme != null) {
            await ThemeService.setThemeMode(selectedTheme);
          }
          return;
        }
        
        if (item.isLogout) {
          // Show confirmation dialog
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
          
          if (shouldLogout == true) {
            await ApiService.logout();
            if (context.mounted) {
              context.go('/role-select');
            }
          }
        } else if (item.route.isNotEmpty) {
          // Navigate to the route
          await context.push(item.route);
          // Refresh profile when returning from settings or any route
          if (mounted && item.route == '/settings') {
            // Small delay to ensure settings screen has finished updating
            await Future.delayed(const Duration(milliseconds: 300));
            _loadUserData(forceRefresh: true);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                item.icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.description,
                    style: TextStyle(
                      color: context.mutedForegroundColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              color: context.mutedForegroundColor,
              size: 20,
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 300 + index * 50)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String description;
  final String route;
  final bool isLogout;
  final bool isThemeToggle;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.route,
    this.isLogout = false,
    this.isThemeToggle = false,
  });
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(
                Iconsax.image,
                color: Colors.white,
                size: 80,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


