import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_extensions.dart';
import '../core/wallet_refresh.dart';
import '../services/api_service.dart';

class AppHeader extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final String? location;
  final String? title;

  const AppHeader({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.location,
    this.title,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String? _userLocation;
  bool _isLoadingLocation = true;
  double? _walletBalance;
  bool _isLoadingWallet = false;

  @override
  void initState() {
    super.initState();
    if (widget.location == null) {
      _loadUserLocation();
    } else {
      _userLocation = widget.location;
      _isLoadingLocation = false;
    }
    _loadWalletBalance();
    WalletRefreshNotifier.trigger.addListener(_onWalletRefreshRequested);
  }

  @override
  void dispose() {
    WalletRefreshNotifier.trigger.removeListener(_onWalletRefreshRequested);
    super.dispose();
  }

  void _onWalletRefreshRequested() {
    if (mounted) _loadWalletBalance(forceRefresh: true);
  }
  
  Future<void> _loadWalletBalance({bool forceRefresh = false}) async {
    try {
      setState(() => _isLoadingWallet = true);
      final result = await ApiService.getWalletBalance(forceRefresh: forceRefresh);
      if (result['success'] == true && mounted) {
        setState(() {
          _walletBalance = result['balance']?.toDouble();
          _isLoadingWallet = false;
        });
      } else {
        setState(() => _isLoadingWallet = false);
      }
    } catch (e) {
      print('Error loading wallet balance: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      // Try to get default saved address first (use cache by default)
      final addressesResult = await ApiService.getSavedAddresses(forceRefresh: false);
      if (addressesResult['success'] == true) {
        final addresses = addressesResult['data'] as List;
        if (addresses.isNotEmpty) {
          // Find default address, or use first one
          dynamic defaultAddress;
          try {
            defaultAddress = addresses.firstWhere(
              (addr) => addr['is_default'] == true,
            );
          } catch (e) {
            // No default found, use first address
            defaultAddress = addresses[0];
          }
          
          if (defaultAddress != null && mounted) {
            // Construct address from available fields
            String addressText = '';
            if (defaultAddress['full_address'] != null && defaultAddress['full_address'].toString().isNotEmpty) {
              addressText = defaultAddress['full_address'].toString();
            } else {
              // Build address from components
              final parts = <String>[];
              if (defaultAddress['address_line1'] != null && defaultAddress['address_line1'].toString().isNotEmpty) {
                parts.add(defaultAddress['address_line1'].toString());
              }
              if (defaultAddress['city'] != null && defaultAddress['city'].toString().isNotEmpty) {
                parts.add(defaultAddress['city'].toString());
              }
              if (defaultAddress['state'] != null && defaultAddress['state'].toString().isNotEmpty) {
                parts.add(defaultAddress['state'].toString());
              }
              addressText = parts.isNotEmpty ? parts.join(', ') : (defaultAddress['label'] ?? 'Default Address');
            }
            
            setState(() {
              _userLocation = addressText;
              _isLoadingLocation = false;
            });
            return;
          }
        }
      }
      
      // If no saved address, try to get from user profile (use cache by default)
      final userResult = await ApiService.getCurrentUserInfo(forceRefresh: false);
      if (userResult['success'] == true && mounted) {
        final userData = userResult['data'];
        final location = userData['location_string'] ?? userData['address'];
        if (location != null && location.toString().isNotEmpty) {
          setState(() {
            _userLocation = location.toString();
            _isLoadingLocation = false;
          });
          return;
        }
      }
      
      // If still no location, set a default message
      if (mounted) {
        setState(() {
          _userLocation = 'Set your address';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error loading location: $e');
      if (mounted) {
        setState(() {
          _userLocation = 'Set your address';
          _isLoadingLocation = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // If title is provided, show simple header with title
    if (widget.title != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (widget.showBackButton)
              IconButton(
                icon: const Icon(Iconsax.arrow_left),
                onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (widget.showBackButton) const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.foregroundColor,
                ),
              ),
            ),
            // Wallet balance button
            _buildWalletButton(context),
          ],
        ),
      );
    }
    
    // Default location header
    final displayLocation = widget.location ?? _userLocation ?? 'Loading...';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (widget.showBackButton) const SizedBox(width: 8),
          Icon(
            Iconsax.location,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Address',
                  style: TextStyle(
                    color: context.mutedForegroundColor,
                    fontSize: 10,
                  ),
                ),
                if (_isLoadingLocation && widget.location == null)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                else
                  Text(
                    displayLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Wallet balance button
          _buildWalletButton(context),
        ],
      ),
    );
  }
  
  Widget _buildWalletButton(BuildContext context) {
    return InkWell(
      onTap: () => _showWalletDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.wallet,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            _isLoadingWallet
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : Text(
                  _walletBalance != null 
                    ? 'Rs. ${_walletBalance!.toStringAsFixed(0)}'
                    : 'Rs. 0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showWalletDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => WalletDialog(
        onBalanceUpdated: () {
          _loadWalletBalance();
        },
      ),
    );
  }
}

// Wallet Dialog Widget
class WalletDialog extends StatefulWidget {
  final VoidCallback? onBalanceUpdated;
  
  const WalletDialog({super.key, this.onBalanceUpdated});
  
  @override
  State<WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<WalletDialog> {
  double? _balance;
  bool _isLoading = true;
  final TextEditingController _amountController = TextEditingController();
  String _selectedPaymentMethod = 'UPI';
  
  final List<String> _paymentMethods = ['UPI', 'Credit Card', 'Debit Card', 'Net Banking', 'Wallet'];
  
  @override
  void initState() {
    super.initState();
    _loadBalance();
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getWalletBalance(forceRefresh: false);
    if (mounted) {
      setState(() {
        _balance = result['balance']?.toDouble();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addMoney() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    
    final result = await ApiService.addMoneyToWallet(amount, _selectedPaymentMethod);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Money added successfully')),
        );
        _amountController.clear();
        _loadBalance();
        widget.onBalanceUpdated?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to add money')),
        );
      }
    }
  }
  
  static const List<double> _quickAmounts = [100, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return Dialog(
      backgroundColor: context.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Iconsax.wallet_3, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'My Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Iconsax.close_circle, color: context.mutedForegroundColor, size: 22),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: context.mutedColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Current Balance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.mutedForegroundColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const SizedBox(
                            height: 36,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : Text(
                            'Rs. ${(_balance ?? 0).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add money',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.foregroundColor,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixIcon: const Icon(Iconsax.dollar_circle, size: 20, color: AppColors.primary),
                  prefixText: 'Rs. ',
                  prefixStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.foregroundColor,
                  ),
                  filled: true,
                  fillColor: context.mutedColor.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Text(
                'Quick add',
                style: TextStyle(
                  fontSize: 12,
                  color: context.mutedForegroundColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amount) {
                  final entered = double.tryParse(_amountController.text.trim());
                  final isSelected = entered != null && entered == amount;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _amountController.text = amount.toStringAsFixed(0);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : context.mutedColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : context.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        'Rs. ${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : context.foregroundColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 12,
                  color: context.mutedForegroundColor,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.mutedColor.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor),
                ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method, style: TextStyle(fontSize: 14, color: context.foregroundColor)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedPaymentMethod = value);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addMoney,
                icon: const Icon(Iconsax.add, size: 20),
                label: const Text('Add Money'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Simulation only. No real payment will be made.',
                style: TextStyle(
                  fontSize: 11,
                  color: context.mutedForegroundColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

