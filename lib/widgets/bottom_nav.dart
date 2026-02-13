import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_extensions.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
        border: Border(
          top: BorderSide(
            color: context.borderColor,
            width: 1,
          ),
        ),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withOpacity(0.05),
      //       blurRadius: 10,
      //       offset: const Offset(0, -2),
      //     ),
      //   ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Iconsax.home,
                activeIcon: Iconsax.home_15,
                label: 'Home',
                index: 0,
                route: '/home',
              ),
              _buildNavItem(
                context,
                icon: Iconsax.map,
                activeIcon: Iconsax.map_1,
                label: 'Explore',
                index: 1,
                route: '/saved',
              ),
              _buildNavItem(
                context,
                icon: Iconsax.briefcase,
                activeIcon: Iconsax.briefcase,
                label: 'Services',
                index: 2,
                route: '/services',
              ),
              _buildNavItem(
                context,
                icon: Iconsax.notification,
                activeIcon: Iconsax.notification5,
                label: 'Alerts',
                index: 3,
                route: '/notifications',
              ),
              _buildNavItem(
                context,
                icon: Iconsax.user,
                activeIcon: Iconsax.user,
                label: 'Profile',
                index: 4,
                route: '/profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required String route,
  }) {
    final isActive = currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isActive) {
            context.go(route);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon container with fixed size and centered alignment
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.primary : context.mutedForegroundColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Text with fixed width using w600 to prevent shifting
              // Using w600 for both states ensures consistent width
              Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? AppColors.primary : context.mutedForegroundColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600, // Same weight for both states
                    height: 1.1,
                    letterSpacing: 0.1, // Slight letter spacing for consistency
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


