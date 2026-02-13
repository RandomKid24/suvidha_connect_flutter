import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<dynamic> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getSavedAddresses(forceRefresh: forceRefresh);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _addresses = result['data'] as List;
        } else {
          _error = result['error']?['message'] ?? 'Failed to load addresses';
        }
      });
    }
  }

  Future<void> _deleteAddress(int addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Optimistic update: Remove address from list immediately
      final previousAddresses = List<Map<String, dynamic>>.from(_addresses);
      setState(() {
        _addresses = _addresses.where((a) => a['id'] != addressId).toList();
      });

      final result = await ApiService.deleteSavedAddress(addressId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted successfully')),
          );
          _loadAddresses(); // Force refresh after delete
        } else {
          // Revert optimistic update on error
          setState(() {
            _addresses = previousAddresses;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']?['message'] ?? 'Failed to delete address'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
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
                onRefresh: () => _loadAddresses(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saved Addresses',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.foregroundColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/add-address'),
                          icon: const Icon(Iconsax.add),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Manage your saved addresses for quick booking',
                      style: TextStyle(
                        color: context.mutedForegroundColor,
                        fontSize: 14,
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms),
                    
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
                                onPressed: _loadAddresses,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_addresses.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Icon(
                              Iconsax.location,
                              size: 80,
                              color: context.mutedForegroundColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved addresses',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add an address to use it for bookings',
                              style: TextStyle(
                                color: context.mutedForegroundColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/add-address'),
                              icon: const Icon(Iconsax.add),
                              label: const Text('Add Address'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._addresses.asMap().entries.map((entry) {
                        final index = entry.key;
                        final address = entry.value;
                        return _buildAddressCard(address, index);
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

  Widget _buildAddressCard(Map<String, dynamic> address, int index) {
    final isDefault = address['is_default'] == true;
    final label = address['label'] ?? 'Address';
    final fullAddress = address['full_address'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? AppColors.primary : context.borderColor,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Iconsax.location,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: context.foregroundColor,
                    ),
                  ),
                  if (isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Default',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _deleteAddress(address['id']),
                    icon: const Icon(Iconsax.trash),
                    color: AppColors.error,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fullAddress,
            style: TextStyle(
              color: context.mutedForegroundColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).moveX(begin: 20, end: 0);
  }
}

