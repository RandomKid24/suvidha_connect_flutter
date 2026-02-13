import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../core/theme/theme_extensions.dart';

/// A widget that displays a provider's profile photo with automatic fallback to avatar on error
/// Shows avatar when image URL is null, empty, or fails to load (including 404)
class ProviderAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProviderAvatar({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // If no image URL, show avatar directly
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildAvatar(context);
    }

    // Try to load image, fallback to avatar on any error (including 404)
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: fit,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) {
          // Silently handle 404 and other errors - just show avatar
          // Note: Exception may still be logged, but avatar is displayed
          return _buildAvatar(context);
        },
        // Use memCacheWidth/Height to optimize
        memCacheWidth: size.toInt(),
        memCacheHeight: size.toInt(),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.mutedColor,
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Iconsax.user,
        size: size * 0.5,
        color: context.mutedForegroundColor,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: context.mutedColor,
      child: Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(context.mutedForegroundColor),
          ),
        ),
      ),
    );
  }
}
